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
  - `:estimated_cached_tokens` - Estimated cached-context tokens for budget checking
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
    budget_status = check_token_budget(state_key, opts, config)

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

      match?({:over_budget, _}, budget_status) ->
        {:over_budget, build_over_budget_status(budget_status, state_key)}

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

  defp build_over_budget_status({:over_budget, budget_ctx}, state_key) do
    budget_ctx
    |> Map.put_new(:usage, State.get_current_usage(state_key) || %{})
  end

  defp build_over_budget_status(_status, state_key), do: State.get_current_usage(state_key) || %{}

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
    concurrency_key = concurrency_key(model, opts)

    # Emit telemetry for request start
    start_time = System.monotonic_time()
    emit_request_start(model, opts)

    # Check token budget
    case check_token_budget(state_key, opts, config) do
      {:ok, _budget_ctx} ->
        execute_with_concurrency(
          request_fn,
          model,
          concurrency_key,
          state_key,
          config,
          start_time,
          opts
        )

      {:over_budget, budget_ctx} ->
        handle_over_budget(
          state_key,
          config,
          start_time,
          opts,
          request_fn,
          model,
          concurrency_key,
          budget_ctx
        )
    end
  end

  defp execute_with_concurrency(
         request_fn,
         model,
         concurrency_key,
         state_key,
         config,
         start_time,
         opts
       ) do
    # Acquire concurrency permit if enabled
    permit_result =
      if Config.concurrency_enabled?(config) do
        ConcurrencyGate.acquire(concurrency_key, config)
      else
        :ok
      end

    case permit_result do
      :ok ->
        try do
          result = execute_with_retry(request_fn, model, concurrency_key, state_key, config, opts)
          emit_request_complete(model, start_time, result, opts)
          result
        after
          if Config.concurrency_enabled?(config) do
            ConcurrencyGate.release(concurrency_key)
          end
        end

      {:error, :no_permit_available} ->
        emit_request_error(model, start_time, :no_permit_available, opts)
        {:error, {:rate_limited, nil, %{reason: :no_permit_available}}}

      {:error, :concurrency_disabled} ->
        # Concurrency disabled, proceed without permit
        result = execute_with_retry(request_fn, model, concurrency_key, state_key, config, opts)
        emit_request_complete(model, start_time, result, opts)
        result

      {:error, reason} ->
        emit_request_error(model, start_time, reason, opts)
        {:error, reason}
    end
  end

  defp execute_with_retry(request_fn, _model, concurrency_key, state_key, config, opts) do
    wrapped_fn = fn ->
      result = request_fn.()

      # Signal success/429 to adaptive concurrency
      case RetryManager.classify_response(result) do
        :success ->
          ConcurrencyGate.signal_success(concurrency_key, config)

        :rate_limited ->
          ConcurrencyGate.signal_429(concurrency_key, config)

        _ ->
          :ok
      end

      result
    end

    RetryManager.execute_with_retry(wrapped_fn, state_key, config, opts)
  end

  defp check_token_budget(state_key, opts, config) do
    # ADR-0001/0002: Use estimated tokens from opts, fall back to 0
    estimated_input_tokens = Keyword.get(opts, :estimated_input_tokens, 0)
    estimated_cached_tokens = Keyword.get(opts, :estimated_cached_tokens, 0)
    estimated_total = estimated_input_tokens + estimated_cached_tokens

    # ADR-0002: Fall back to config.token_budget_per_window when not in opts
    budget = Keyword.get(opts, :token_budget_per_window, config.token_budget_per_window)
    usage = State.get_current_usage(state_key)

    cond do
      is_nil(budget) ->
        {:ok,
         %{
           estimated_input_tokens: estimated_input_tokens,
           estimated_cached_tokens: estimated_cached_tokens,
           estimated_total_tokens: estimated_total,
           budget: budget,
           usage: usage
         }}

      estimated_total > budget ->
        {:over_budget,
         %{
           reason: :over_budget,
           request_too_large: true,
           estimated_input_tokens: estimated_input_tokens,
           estimated_cached_tokens: estimated_cached_tokens,
           estimated_total_tokens: estimated_total,
           token_budget: budget,
           usage: usage
         }}

      usage &&
          usage.input_tokens + usage.output_tokens + estimated_total > budget ->
        window_end = DateTime.add(usage.window_start, usage.window_duration_ms, :millisecond)

        {:over_budget,
         %{
           reason: :over_budget,
           request_too_large: false,
           estimated_input_tokens: estimated_input_tokens,
           estimated_cached_tokens: estimated_cached_tokens,
           estimated_total_tokens: estimated_total,
           token_budget: budget,
           usage: usage,
           window_end: window_end
         }}

      true ->
        {:ok,
         %{
           estimated_input_tokens: estimated_input_tokens,
           estimated_cached_tokens: estimated_cached_tokens,
           estimated_total_tokens: estimated_total,
           budget: budget,
           usage: usage
         }}
    end
  end

  defp handle_over_budget(
         state_key,
         config,
         start_time,
         opts,
         request_fn,
         model,
         concurrency_key,
         budget_ctx
       ) do
    retry_at = Map.get(budget_ctx, :window_end)
    base_details = rate_limit_details(budget_ctx)
    max_wait_ms = config.max_budget_wait_ms

    cond do
      Map.get(budget_ctx, :request_too_large) ->
        emit_rate_limit_error(state_key, :over_budget, start_time, base_details)

        {:error, {:rate_limited, nil, rate_limit_details(budget_ctx)}}

      config.non_blocking ->
        emit_rate_limit_error(state_key, :over_budget, start_time, base_details)

        {:error, {:rate_limited, retry_at, rate_limit_details(budget_ctx)}}

      true ->
        # Blocking mode: wait for window to clear once, then re-check
        if retry_at do
          wait_ms = max(0, DateTime.diff(retry_at, DateTime.utc_now(), :millisecond))

          capped_wait =
            case max_wait_ms do
              nil -> {wait_ms, false}
              cap when wait_ms > cap -> {cap, true}
              _ -> {wait_ms, false}
            end

          {actual_wait_ms, capped?} = capped_wait

          wait_metadata =
            Map.merge(base_details, %{wait_ms: actual_wait_ms, wait_capped: capped?})

          emit_rate_limit_wait(state_key, retry_at, :over_budget, wait_metadata)

          if actual_wait_ms > 0 do
            Process.sleep(actual_wait_ms)
          end
        end

        case check_token_budget(state_key, opts, config) do
          {:ok, _} ->
            execute_with_concurrency(
              request_fn,
              model,
              concurrency_key,
              state_key,
              config,
              start_time,
              opts
            )

          {:over_budget, %{request_too_large: true} = over_again} ->
            emit_rate_limit_error(
              state_key,
              :over_budget,
              start_time,
              rate_limit_details(over_again)
            )

            {:error, {:rate_limited, nil, rate_limit_details(over_again)}}

          {:over_budget, over_again} ->
            next_retry = Map.get(over_again, :window_end)

            emit_rate_limit_error(
              state_key,
              :over_budget,
              start_time,
              rate_limit_details(over_again)
            )

            {:error, {:rate_limited, next_retry, rate_limit_details(over_again)}}
        end
    end
  end

  defp rate_limit_details(budget_ctx) do
    Map.merge(
      %{reason: :over_budget},
      Map.take(budget_ctx, [
        :estimated_input_tokens,
        :estimated_cached_tokens,
        :estimated_total_tokens,
        :token_budget,
        :request_too_large
      ])
    )
  end

  defp record_usage_from_response(model, opts, response) do
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)

    # ADR-0002: Get window duration from config
    config = Config.build(opts)

    # Extract usage from response
    usage = extract_usage(response)

    if usage do
      State.record_usage(
        state_key,
        Map.get(usage, :input_tokens, 0),
        Map.get(usage, :output_tokens, 0),
        window_duration_ms: config.window_duration_ms
      )
    end
  end

  defp extract_usage(response) do
    cond do
      Map.has_key?(response, :usage_metadata) ->
        cached_tokens = Map.get(response.usage_metadata, :cached_content_token_count, 0)

        %{
          input_tokens: Map.get(response.usage_metadata, :prompt_token_count, 0) + cached_tokens,
          output_tokens: Map.get(response.usage_metadata, :candidates_token_count, 0)
        }

      Map.has_key?(response, "usageMetadata") ->
        cached_tokens = Map.get(response["usageMetadata"], "cachedContentTokenCount", 0)

        %{
          input_tokens: Map.get(response["usageMetadata"], "promptTokenCount", 0) + cached_tokens,
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

  defp emit_rate_limit_wait(state_key, retry_at, reason, metadata) do
    {model, location, _metric} = state_key

    metadata =
      %{
        model: model,
        location: location,
        retry_at: retry_at,
        reason: reason
      }
      |> Map.merge(metadata)

    Telemetry.execute([:gemini, :rate_limit, :wait], %{}, metadata)
  end

  defp emit_rate_limit_error(state_key, reason, start_time, metadata) do
    {model, location, _metric} = state_key
    duration = Telemetry.calculate_duration(start_time)

    metadata =
      %{
        model: model,
        location: location,
        reason: reason
      }
      |> Map.merge(metadata)

    Telemetry.execute([:gemini, :rate_limit, :error], %{duration: duration}, metadata)
  end

  defp concurrency_key(model, opts) do
    case Keyword.get(opts, :concurrency_key) do
      nil ->
        model

      key ->
        "#{model}:#{to_string(key)}"
    end
  end
end
