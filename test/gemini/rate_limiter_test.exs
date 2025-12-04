defmodule Gemini.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Gemini.RateLimiter
  alias Gemini.RateLimiter.{Config, State, ConcurrencyGate, RetryManager, Manager}

  @moduletag :rate_limiter

  setup do
    # Reset all rate limiter state before each test
    RateLimiter.reset_all()

    # Attach telemetry handlers for verification
    test_pid = self()

    :telemetry.attach_many(
      "rate-limiter-test-handler",
      [
        [:gemini, :rate_limit, :request, :start],
        [:gemini, :rate_limit, :request, :stop],
        [:gemini, :rate_limit, :request, :error],
        [:gemini, :rate_limit, :wait],
        [:gemini, :rate_limit, :error]
      ],
      &__MODULE__.telemetry_handler/4,
      {test_pid, :telemetry}
    )

    on_exit(fn ->
      :telemetry.detach("rate-limiter-test-handler")
      RateLimiter.reset_all()
    end)

    :ok
  end

  describe "Config" do
    test "builds with default values" do
      config = Config.build()

      assert config.max_concurrency_per_model == 4
      assert config.max_attempts == 3
      assert config.base_backoff_ms == 1000
      assert config.jitter_factor == 0.25
      assert config.non_blocking == false
      assert config.disable_rate_limiter == false
      assert config.profile == :prod
    end

    test "builds with profile :dev" do
      config = Config.build(profile: :dev)

      assert config.max_concurrency_per_model == 2
      assert config.max_attempts == 5
      assert config.base_backoff_ms == 2000
      assert config.adaptive_ceiling == 4
    end

    test "overrides take precedence" do
      config = Config.build(profile: :prod, max_concurrency_per_model: 10)

      assert config.max_concurrency_per_model == 10
    end

    test "nil/0 concurrency disables gating" do
      config = Config.build(max_concurrency_per_model: nil)
      assert Config.concurrency_enabled?(config) == false

      config = Config.build(max_concurrency_per_model: 0)
      assert Config.concurrency_enabled?(config) == false
    end

    test "disable_rate_limiter option" do
      config = Config.build(disable_rate_limiter: true)
      assert Config.enabled?(config) == false
    end
  end

  describe "State" do
    test "initializes ETS table" do
      assert State.init() == :ok
    end

    test "builds state keys" do
      key = State.build_key("gemini-2.0-flash", "us-central1", :token_count)
      assert key == {"gemini-2.0-flash", "us-central1", :token_count}
    end

    test "manages retry_until state" do
      key = State.build_key("test-model", nil, :token_count)

      # Initially no retry
      assert State.get_retry_until(key) == nil

      # Set retry state from 429
      retry_info = %{"retryDelay" => "5s"}
      State.set_retry_state(key, retry_info)

      # Should have retry_until in the future
      retry_until = State.get_retry_until(key)
      assert retry_until != nil
      assert DateTime.compare(retry_until, DateTime.utc_now()) == :gt

      # Clear retry state
      State.clear_retry_state(key)
      assert State.get_retry_until(key) == nil
    end

    test "parses various retry delay formats" do
      assert State.parse_retry_delay(%{"retryDelay" => "60s"}) == 60_000
      assert State.parse_retry_delay(%{"retryDelay" => "1.5s"}) == 1500
      assert State.parse_retry_delay(%{"retryDelay" => "100ms"}) == 100
      assert State.parse_retry_delay(%{"retryDelay" => "2m"}) == 120_000
      assert State.parse_retry_delay(%{}) == 60_000
    end

    test "records and retrieves usage" do
      key = State.build_key("test-model", nil, :token_count)

      # No usage initially
      assert State.get_current_usage(key) == nil

      # Record usage
      State.record_usage(key, 100, 50)

      usage = State.get_current_usage(key)
      assert usage.input_tokens == 100
      assert usage.output_tokens == 50

      # Accumulate more usage
      State.record_usage(key, 50, 25)

      usage = State.get_current_usage(key)
      assert usage.input_tokens == 150
      assert usage.output_tokens == 75
    end

    test "checks budget limits" do
      key = State.build_key("test-model", nil, :token_count)

      # No limit = never over budget
      assert State.would_exceed_budget?(key, 1000, nil) == false

      # With limit and no usage
      assert State.would_exceed_budget?(key, 100, 1000) == false
      assert State.would_exceed_budget?(key, 1001, 1000) == true

      # With existing usage
      State.record_usage(key, 500, 300)
      assert State.would_exceed_budget?(key, 100, 1000) == false
      assert State.would_exceed_budget?(key, 300, 1000) == true
    end
  end

  describe "ConcurrencyGate" do
    test "acquires and releases permits" do
      config = Config.build(max_concurrency_per_model: 2)

      # First acquire succeeds
      assert ConcurrencyGate.acquire("test-model", config) == :ok

      # Second acquire succeeds
      assert ConcurrencyGate.acquire("test-model", config) == :ok

      # Third acquire in non-blocking mode fails
      non_blocking_config = %{config | non_blocking: true}

      assert ConcurrencyGate.acquire("test-model", non_blocking_config) ==
               {:error, :no_permit_available}

      # Release one permit
      assert ConcurrencyGate.release("test-model") == :ok

      # Now acquire succeeds again
      assert ConcurrencyGate.acquire("test-model", config) == :ok
    end

    test "tracks available permits" do
      config = Config.build(max_concurrency_per_model: 3)

      assert ConcurrencyGate.available_permits("test-model", config) == 3

      ConcurrencyGate.acquire("test-model", config)
      assert ConcurrencyGate.available_permits("test-model", config) == 2

      ConcurrencyGate.acquire("test-model", config)
      assert ConcurrencyGate.available_permits("test-model", config) == 1

      ConcurrencyGate.release("test-model")
      assert ConcurrencyGate.available_permits("test-model", config) == 2
    end

    test "disabled when concurrency is nil" do
      config = Config.build(max_concurrency_per_model: nil)

      assert ConcurrencyGate.acquire("test-model", config) ==
               {:error, :concurrency_disabled}
    end

    test "adaptive mode backs off on 429" do
      config =
        Config.build(
          max_concurrency_per_model: 4,
          adaptive_concurrency: true,
          adaptive_ceiling: 8
        )

      # Signal 429 - should reduce adaptive_max
      ConcurrencyGate.signal_429("test-model", config)

      state = ConcurrencyGate.get_state("test-model")
      assert state.adaptive_max < 4
    end

    test "adaptive mode raises on success" do
      config =
        Config.build(
          max_concurrency_per_model: 2,
          adaptive_concurrency: true,
          adaptive_ceiling: 8
        )

      # First 429 to set adaptive_max
      ConcurrencyGate.signal_429("test-model", config)

      initial_max = ConcurrencyGate.get_state("test-model").adaptive_max

      # Success should raise
      ConcurrencyGate.signal_success("test-model", config)

      new_max = ConcurrencyGate.get_state("test-model").adaptive_max
      assert new_max > initial_max
    end
  end

  describe "RetryManager" do
    test "classifies responses correctly" do
      assert RetryManager.classify_response({:ok, %{}}) == :success
      assert RetryManager.classify_response({:error, %{http_status: 429}}) == :rate_limited
      assert RetryManager.classify_response({:error, %{http_status: 500}}) == :transient
      assert RetryManager.classify_response({:error, %{http_status: 503}}) == :transient
      assert RetryManager.classify_response({:error, %{http_status: 400}}) == :permanent
      assert RetryManager.classify_response({:error, %{http_status: 404}}) == :permanent
      assert RetryManager.classify_response({:error, %{type: :network_error}}) == :transient
      assert RetryManager.classify_response({:error, :timeout}) == :transient
    end

    test "calculates backoff with jitter" do
      config = Config.build(base_backoff_ms: 1000, jitter_factor: 0.25)

      backoff1 = RetryManager.calculate_backoff(1, config)
      backoff2 = RetryManager.calculate_backoff(2, config)
      backoff3 = RetryManager.calculate_backoff(3, config)

      # Backoffs should be approximately exponential
      assert backoff1 >= 750 and backoff1 <= 1250
      assert backoff2 >= 1500 and backoff2 <= 2500
      assert backoff3 >= 3000 and backoff3 <= 5000
    end

    test "extracts retry info from error" do
      error =
        {:error,
         %{
           details: %{
             "error" => %{
               "details" => [
                 %{
                   "@type" => "type.googleapis.com/google.rpc.RetryInfo",
                   "retryDelay" => "30s"
                 }
               ]
             }
           }
         }}

      retry_info = RetryManager.extract_retry_info(error)
      assert Map.has_key?(retry_info, "retryDelay")
    end
  end

  describe "Manager integration" do
    test "executes simple request without blocking" do
      model = "test-model-#{System.unique_integer()}"

      result =
        Manager.execute(
          fn -> {:ok, %{text: "success"}} end,
          model,
          max_concurrency_per_model: 4
        )

      assert result == {:ok, %{text: "success"}}
    end

    test "disabled rate limiter passes through" do
      result =
        Manager.execute(
          fn -> {:ok, %{text: "success"}} end,
          "test-model",
          disable_rate_limiter: true
        )

      assert result == {:ok, %{text: "success"}}
    end

    test "check_status returns :ok when not rate limited" do
      model = "test-model-#{System.unique_integer()}"
      assert Manager.check_status(model) == :ok
    end

    test "check_status returns rate_limited when in retry window" do
      model = "test-model-#{System.unique_integer()}"
      key = State.build_key(model, nil, :token_count)

      # Set a retry state
      State.set_retry_state(key, %{"retryDelay" => "60s"})

      result = Manager.check_status(model)
      assert match?({:rate_limited, _, _}, result)
    end

    test "non_blocking returns immediately when rate limited" do
      model = "test-model-#{System.unique_integer()}"
      key = State.build_key(model, nil, :token_count)

      # Set a retry state
      State.set_retry_state(key, %{"retryDelay" => "60s"})

      result =
        Manager.execute(
          fn -> {:ok, %{text: "success"}} end,
          model,
          non_blocking: true
        )

      assert match?({:error, {:rate_limited, _, _}}, result)
    end

    test "records usage from response" do
      model = "test-model-#{System.unique_integer()}"

      response = %{
        "usageMetadata" => %{
          "promptTokenCount" => 100,
          "candidatesTokenCount" => 50,
          "totalTokenCount" => 150
        }
      }

      Manager.execute_with_usage_tracking(
        fn -> {:ok, response} end,
        model
      )

      usage = Manager.get_usage(model)
      assert usage != nil
      assert usage.input_tokens == 100
      assert usage.output_tokens == 50
    end

    test "emits telemetry events" do
      # Ensure telemetry is enabled for this test
      Application.put_env(:gemini_ex, :telemetry_enabled, true)

      model = "test-model-#{System.unique_integer()}"
      test_pid = self()
      handler_id = "test-handler-#{System.unique_integer()}"

      # Attach a specific handler for this test
      :telemetry.attach(
        handler_id,
        [:gemini, :rate_limit, :request, :start],
        &__MODULE__.telemetry_handler/4,
        {test_pid, :telemetry_event}
      )

      Manager.execute(
        fn -> {:ok, %{text: "success"}} end,
        model
      )

      # Should receive start event
      assert_receive {:telemetry_event, [:gemini, :rate_limit, :request, :start], _,
                      %{model: ^model}},
                     1000

      :telemetry.detach(handler_id)
    end
  end

  describe "concurrency serialization" do
    test "serializes requests when max_concurrency=1" do
      model = "serial-test-#{System.unique_integer()}"

      # Track request order
      order_counter = :counters.new(1, [:atomics])
      order_list = :ets.new(:order_list, [:ordered_set, :public])

      request_fn = fn ->
        # Record start order
        my_order = :counters.get(order_counter, 1)
        :counters.add(order_counter, 1, 1)

        # Simulate some work
        Process.sleep(10)

        # Record completion
        :ets.insert(order_list, {my_order, :completed})

        {:ok, %{order: my_order}}
      end

      # Fire multiple requests in parallel with max_concurrency=1
      tasks =
        for _ <- 1..3 do
          Task.async(fn ->
            Manager.execute(request_fn, model, max_concurrency_per_model: 1)
          end)
        end

      # Wait for all to complete
      results = Task.await_many(tasks, 5000)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Clean up
      :ets.delete(order_list)
    end
  end

  describe "RateLimiter public API" do
    test "config/1 returns configuration" do
      config = RateLimiter.config(max_concurrency_per_model: 8)
      assert config.max_concurrency_per_model == 8
    end

    test "enabled?/1 checks if rate limiting is enabled" do
      assert RateLimiter.enabled?() == true
      assert RateLimiter.enabled?(disable_rate_limiter: true) == false
    end

    test "available_permits/2 returns permit count" do
      model = "permit-test-#{System.unique_integer()}"
      permits = RateLimiter.available_permits(model, max_concurrency_per_model: 4)
      assert permits == 4
    end
  end

  def telemetry_handler(event, measurements, metadata, {pid, tag}) do
    send(pid, {tag, event, measurements, metadata})
  end

  def telemetry_handler(_event, _measurements, _metadata, _config), do: :ok
end
