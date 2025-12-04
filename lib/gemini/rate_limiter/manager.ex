defmodule Gemini.RateLimiter.Manager do
  @moduledoc """
  Central rate limiter manager that coordinates request submission.

  Wraps outbound requests with:
  - Rate limit checking and enforcement
  - Concurrency gating
  - Token budgeting
  - Retry handling with backoff

  Enabled by default. Use `disable_rate_limiter: true` to opt out.

  ## Features

  - ETS-based state for cross-process visibility
  - Per-model/location/metric tracking
  - Configurable concurrency limits with adaptive mode
  - Token budget estimation and tracking
  - Telemetry event emission

  ## Usage

      # Execute a request through the rate limiter
      {:ok, response} = Manager.execute(
        fn -> HTTP.post(path, body, opts) end,
        "gemini-flash-lite-latest",
        opts
      )

      # Non-blocking mode returns immediately if rate limited
      case Manager.execute(fn -> ... end, model, non_blocking: true) do
        {:ok, response} -> handle_response(response)
        {:error, {:rate_limited, retry_at, details}} -> schedule_retry(retry_at)
      end

  ## Configuration

  Configure via application environment or per-request options:

      config :gemini_ex, :rate_limiter,
        max_concurrency_per_model: 4,
        max_attempts: 3,
        base_backoff_ms: 1000,
        profile: :prod

  Per-request overrides:

      Gemini.generate("Hello", [
        disable_rate_limiter: true,  # Bypass rate limiter
        non_blocking: true,          # Return immediately if rate limited
        max_concurrency_per_model: 8 # Override concurrency
      ])
  """

  use GenServer

  alias Gemini.RateLimiter.{Config, State, ConcurrencyGate, RetryManager}
  alias Gemini.Telemetry

  @type execute_opts :: keyword()
  @type request_fn :: (-> {:ok, term()} | {:error, term()})

  # Client API

  @doc """
  Start the rate limiter manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a request through the rate limiter.

  ## Parameters

  - `request_fn` - Zero-arity function that makes the actual HTTP request
  - `model` - Model name for rate limit tracking
  - `opts` - Options for rate limiting and the underlying request

  ## Options

  - `:location` - Location for rate limit tracking (default: "us-central1")
  - `:disable_rate_limiter` - Bypass all rate limiting (default: false)
  - `:non_blocking` - Return immediately if rate limited (default: false)
  - `:max_concurrency_per_model` - Override concurrency limit
  - `:estimated_input_tokens` - Estimated tokens for budget checking
  - `:token_budget_per_window` - Maximum tokens per window (nil = no limit)

  ## Returns

  - `{:ok, response}` - Request succeeded
  - `{:error, {:rate_limited, retry_at, details}}` - Rate limited
  - `{:error, {:transient_failure, attempts, last_error}}` - Transient failure
  - `{:error, term()}` - Other error
  """
  @spec execute(request_fn(), String.t(), execute_opts()) ::
          {:ok, term()} | {:error, term()}
  def execute(request_fn, model, opts \\ []) do
    config = Config.build(opts)

    if Config.enabled?(config) do
      do_execute(request_fn, model, config, opts)
    else
      # Rate limiter disabled, execute directly
      request_fn.()
    end
  end

  @doc """
  Execute a request, extracting and recording usage from the response.

  Similar to `execute/3` but also records token usage from successful responses.
  """
  @spec execute_with_usage_tracking(request_fn(), String.t(), execute_opts()) ::
          {:ok, term()} | {:error, term()}
  def execute_with_usage_tracking(request_fn, model, opts \\ []) do
    result = execute(request_fn, model, opts)

    # Record usage from successful responses
    case result do
      {:ok, response} when is_map(response) ->
        record_usage_from_response(model, opts, response)

      _ ->
        :ok
    end

    result
  end

  @doc """
  Check if a request would be rate limited without executing it.

  ## Returns

  - `:ok` - Request can proceed
  - `{:rate_limited, retry_at, details}` - Currently rate limited
  - `{:over_budget, usage}` - Would exceed token budget
  - `{:no_permits, available}` - No concurrency permits available
  """
  @spec check_status(String.t(), execute_opts()) ::
          :ok
          | {:rate_limited, DateTime.t(), map()}
          | {:over_budget, map()}
          | {:no_permits, non_neg_integer()}
  def check_status(model, opts \\ []) do
    config = Config.build(opts)
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)

    cond do
      not Config.enabled?(config) ->
        :ok

      retry_until = State.get_retry_until(state_key) ->
        retry_state = State.get_retry_state(state_key)

        {:rate_limited, retry_until,
         %{
           quota_metric: retry_state && retry_state.quota_metric,
           quota_id: retry_state && retry_state.quota_id
         }}

      Config.concurrency_enabled?(config) and
          ConcurrencyGate.available_permits(model, config) == 0 ->
        {:no_permits, 0}

      check_token_budget(state_key, opts, config) == :over_budget ->
        {:over_budget, State.get_current_usage(state_key) || %{}}

      true ->
        :ok
    end
  end

  @doc """
  Get the current retry state for a model.
  """
  @spec get_retry_state(String.t(), keyword()) :: State.retry_state() | nil
  def get_retry_state(model, opts \\ []) do
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)
    State.get_retry_state(state_key)
  end

  @doc """
  Get current token usage for a model.
  """
  @spec get_usage(String.t(), keyword()) :: State.usage_window() | nil
  def get_usage(model, opts \\ []) do
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)
    State.get_current_usage(state_key)
  end

  @doc """
  Reset all rate limiter state (useful for testing).
  """
  @spec reset_all() :: :ok
  def reset_all do
    State.reset_all()
    ConcurrencyGate.reset_all()
    :ok
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Initialize ETS tables
    State.init()
    ConcurrencyGate.init()
    {:ok, %{}}
  end

  # Private implementation

  defp do_execute(request_fn, model, config, opts) do
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)

    # Emit telemetry for request start
    start_time = System.monotonic_time()
    emit_request_start(model, opts)

    # Check token budget
    case check_token_budget(state_key, opts, config) do
      :ok ->
        execute_with_concurrency(request_fn, model, state_key, config, start_time, opts)

      :over_budget ->
        handle_over_budget(state_key, config, start_time, opts)
    end
  end

  defp execute_with_concurrency(request_fn, model, state_key, config, start_time, opts) do
    # Acquire concurrency permit if enabled
    permit_result =
      if Config.concurrency_enabled?(config) do
        ConcurrencyGate.acquire(model, config)
      else
        :ok
      end

    case permit_result do
      :ok ->
        try do
          result = execute_with_retry(request_fn, model, state_key, config, opts)
          emit_request_complete(model, start_time, result, opts)
          result
        after
          if Config.concurrency_enabled?(config) do
            ConcurrencyGate.release(model)
          end
        end

      {:error, :no_permit_available} ->
        emit_request_error(model, start_time, :no_permit_available, opts)
        {:error, {:rate_limited, nil, %{reason: :no_permit_available}}}

      {:error, :concurrency_disabled} ->
        # Concurrency disabled, proceed without permit
        result = execute_with_retry(request_fn, model, state_key, config, opts)
        emit_request_complete(model, start_time, result, opts)
        result

      {:error, reason} ->
        emit_request_error(model, start_time, reason, opts)
        {:error, reason}
    end
  end

  defp execute_with_retry(request_fn, model, state_key, config, opts) do
    wrapped_fn = fn ->
      result = request_fn.()

      # Signal success/429 to adaptive concurrency
      case RetryManager.classify_response(result) do
        :success ->
          ConcurrencyGate.signal_success(model, config)

        :rate_limited ->
          ConcurrencyGate.signal_429(model, config)

        _ ->
          :ok
      end

      result
    end

    RetryManager.execute_with_retry(wrapped_fn, state_key, config, opts)
  end

  defp check_token_budget(state_key, opts, _config) do
    estimated_tokens = Keyword.get(opts, :estimated_input_tokens, 0)
    budget = Keyword.get(opts, :token_budget_per_window)

    if State.would_exceed_budget?(state_key, estimated_tokens, budget) do
      :over_budget
    else
      :ok
    end
  end

  defp handle_over_budget(state_key, config, start_time, opts) do
    retry_until = State.get_retry_until(state_key)

    if config.non_blocking do
      emit_rate_limit_error(state_key, :over_budget, start_time, opts)
      {:error, {:rate_limited, retry_until, %{reason: :over_budget}}}
    else
      # Wait for current window to expire
      case State.get_current_usage(state_key) do
        %{window_start: window_start, window_duration_ms: duration} ->
          window_end = DateTime.add(window_start, duration, :millisecond)
          wait_ms = max(0, DateTime.diff(window_end, DateTime.utc_now(), :millisecond))
          emit_rate_limit_wait(state_key, window_end, :over_budget, opts)
          Process.sleep(wait_ms)

        _ ->
          :ok
      end

      # Budget should be clear now
      {:error, {:rate_limited, nil, %{reason: :over_budget_retry}}}
    end
  end

  defp record_usage_from_response(model, opts, response) do
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)

    # Extract usage from response
    usage = extract_usage(response)

    if usage do
      State.record_usage(
        state_key,
        Map.get(usage, :input_tokens, 0),
        Map.get(usage, :output_tokens, 0)
      )
    end
  end

  defp extract_usage(response) do
    cond do
      Map.has_key?(response, :usage_metadata) ->
        %{
          input_tokens: Map.get(response.usage_metadata, :prompt_token_count, 0),
          output_tokens: Map.get(response.usage_metadata, :candidates_token_count, 0)
        }

      Map.has_key?(response, "usageMetadata") ->
        %{
          input_tokens: Map.get(response["usageMetadata"], "promptTokenCount", 0),
          output_tokens: Map.get(response["usageMetadata"], "candidatesTokenCount", 0)
        }

      true ->
        nil
    end
  end

  # Telemetry helpers

  defp emit_request_start(model, opts) do
    metadata = %{
      model: model,
      location: Keyword.get(opts, :location),
      system_time: System.system_time()
    }

    Telemetry.execute([:gemini, :rate_limit, :request, :start], %{}, metadata)
  end

  defp emit_request_complete(model, start_time, result, opts) do
    duration = Telemetry.calculate_duration(start_time)

    status =
      case result do
        {:ok, _} -> :success
        {:error, {:rate_limited, _, _}} -> :rate_limited
        {:error, {:transient_failure, _, _}} -> :transient_failure
        {:error, _} -> :error
      end

    metadata = %{
      model: model,
      location: Keyword.get(opts, :location),
      status: status
    }

    Telemetry.execute([:gemini, :rate_limit, :request, :stop], %{duration: duration}, metadata)
  end

  defp emit_request_error(model, start_time, reason, opts) do
    duration = Telemetry.calculate_duration(start_time)

    metadata = %{
      model: model,
      location: Keyword.get(opts, :location),
      reason: reason
    }

    Telemetry.execute(
      [:gemini, :rate_limit, :request, :error],
      %{duration: duration},
      metadata
    )
  end

  defp emit_rate_limit_wait(state_key, retry_at, reason, _opts) do
    {model, location, _metric} = state_key

    metadata = %{
      model: model,
      location: location,
      retry_at: retry_at,
      reason: reason
    }

    Telemetry.execute([:gemini, :rate_limit, :wait], %{}, metadata)
  end

  defp emit_rate_limit_error(state_key, reason, start_time, _opts) do
    {model, location, _metric} = state_key
    duration = Telemetry.calculate_duration(start_time)

    metadata = %{
      model: model,
      location: location,
      reason: reason
    }

    Telemetry.execute([:gemini, :rate_limit, :error], %{duration: duration}, metadata)
  end
end
