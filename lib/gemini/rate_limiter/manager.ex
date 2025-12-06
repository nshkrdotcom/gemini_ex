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
  @type streaming_release_fn :: (atom(), map() | nil -> :ok)

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

    config = Config.build(opts)
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)

    # When the limiter is disabled, still record usage for telemetry consumers
    if not Config.enabled?(config) do
      if usage = extract_usage_from_result(result) do
        State.record_usage(
          state_key,
          Map.get(usage, :input_tokens, 0),
          Map.get(usage, :output_tokens, 0),
          window_duration_ms: config.window_duration_ms
        )
      end
    end

    result
  end

  @doc """
  Execute a long-lived streaming request through the rate limiter.

  Returns the start result and a release function that must be called once
  the stream completes, errors, or is stopped to reconcile budget and
  release concurrency permits.
  """
  @spec execute_streaming(request_fn(), String.t(), execute_opts()) ::
          {:ok, {term(), streaming_release_fn()}} | {:error, term()}
  def execute_streaming(start_fn, model, opts \\ []) do
    config = Config.build(opts)

    if Config.enabled?(config) do
      do_execute_streaming(start_fn, model, config, opts)
    else
      {:ok, {start_fn.(), fn _status, _usage -> :ok end}}
    end
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

    case reserve_budget(state_key, opts, config) do
      {:ok, reservation_ctx, estimate_ctx} ->
        execute_with_concurrency(
          request_fn,
          model,
          concurrency_key,
          state_key,
          config,
          start_time,
          opts,
          reservation_ctx,
          estimate_ctx
        )

      {:error, {:rate_limited, retry_at, details}} ->
        emit_rate_limit_error(state_key, :over_budget, start_time, details)
        {:error, {:rate_limited, retry_at, details}}
    end
  end

  defp do_execute_streaming(start_fn, model, config, opts) do
    location = Keyword.get(opts, :location)
    state_key = State.build_key(model, location, :token_count)
    concurrency_key = concurrency_key(model, opts)

    case reserve_budget(state_key, opts, config) do
      {:ok, reservation_ctx, _estimate_ctx} ->
        acquire_stream_permit(
          start_fn,
          model,
          concurrency_key,
          state_key,
          config,
          reservation_ctx,
          opts
        )

      {:error, {:rate_limited, retry_at, details}} ->
        {:error, {:rate_limited, retry_at, details}}
    end
  end

  defp execute_with_concurrency(
         request_fn,
         model,
         concurrency_key,
         state_key,
         config,
         start_time,
         opts,
         reservation_ctx,
         estimate_ctx
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
        result =
          try do
            execute_with_retry(request_fn, model, concurrency_key, state_key, config, opts)
          after
            if Config.concurrency_enabled?(config) do
              ConcurrencyGate.release(concurrency_key)
            end
          end

        reconcile_budget(
          state_key,
          reservation_ctx,
          result,
          config,
          opts,
          estimate_ctx
        )

        emit_request_complete(model, start_time, result, opts)
        result

      {:error, :no_permit_available} ->
        State.release_reservation(state_key, reservation_ctx,
          window_duration_ms: config.window_duration_ms
        )

        emit_request_error(model, start_time, :no_permit_available, opts)
        {:error, {:rate_limited, nil, %{reason: :no_permit_available}}}

      {:error, :concurrency_disabled} ->
        # Concurrency disabled, proceed without permit
        result = execute_with_retry(request_fn, model, concurrency_key, state_key, config, opts)
        reconcile_budget(state_key, reservation_ctx, result, config, opts, estimate_ctx)
        emit_request_complete(model, start_time, result, opts)
        result

      {:error, reason} ->
        State.release_reservation(state_key, reservation_ctx,
          window_duration_ms: config.window_duration_ms
        )

        emit_request_error(model, start_time, reason, opts)
        {:error, reason}
    end
  end

  defp acquire_stream_permit(
         start_fn,
         model,
         concurrency_key,
         state_key,
         config,
         reservation_ctx,
         opts
       ) do
    permit_result =
      if Config.concurrency_enabled?(config) do
        ConcurrencyGate.acquire(concurrency_key, config)
      else
        :ok
      end

    case permit_result do
      :ok ->
        release_fn =
          build_release_fn(
            state_key,
            reservation_ctx,
            concurrency_key,
            config
          )

        case start_fn.() do
          {:ok, value} ->
            emit_stream_event(:started, model, Keyword.get(opts, :location))
            {:ok, {value, release_fn}}

          {:error, reason} ->
            release_fn.(:error, nil)
            {:error, reason}
        end

      {:error, :no_permit_available} ->
        State.release_reservation(state_key, reservation_ctx,
          window_duration_ms: config.window_duration_ms
        )

        {:error, {:rate_limited, nil, %{reason: :no_permit_available}}}

      {:error, :concurrency_disabled} ->
        release_fn =
          build_release_fn(
            state_key,
            reservation_ctx,
            concurrency_key,
            config,
            permit?: false
          )

        case start_fn.() do
          {:ok, value} ->
            emit_stream_event(:started, model, Keyword.get(opts, :location))
            {:ok, {value, release_fn}}

          {:error, reason} ->
            release_fn.(:error, nil)
            {:error, reason}
        end

      {:error, reason} ->
        State.release_reservation(state_key, reservation_ctx,
          window_duration_ms: config.window_duration_ms
        )

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

  defp reserve_budget(state_key, opts, config) do
    estimate_ctx = build_estimate_context(opts, config)

    attempt = fn ->
      State.try_reserve_budget(
        state_key,
        estimate_ctx.estimated_total_tokens,
        estimate_ctx.token_budget,
        window_duration_ms: config.window_duration_ms,
        safety_multiplier: config.budget_safety_multiplier
      )
    end

    case attempt.() do
      {:ok, reservation_ctx} ->
        emit_budget_reserved(state_key, reservation_ctx, estimate_ctx)
        {:ok, reservation_ctx, estimate_ctx}

      {:error, {:over_budget, ctx}} ->
        emit_budget_rejected(state_key, ctx, estimate_ctx)

        handle_reservation_over_budget(
          state_key,
          ctx,
          attempt,
          estimate_ctx,
          config
        )
    end
  end

  defp handle_reservation_over_budget(
         state_key,
         budget_ctx,
         attempt_fun,
         estimate_ctx,
         config
       ) do
    retry_at = Map.get(budget_ctx, :window_end)
    details = rate_limit_details(budget_ctx, estimate_ctx)
    max_wait_ms = config.max_budget_wait_ms

    cond do
      Map.get(budget_ctx, :request_too_large) ->
        {:error, {:rate_limited, nil, details}}

      config.non_blocking ->
        {:error, {:rate_limited, retry_at, details}}

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
            Map.merge(details, %{wait_ms: actual_wait_ms, wait_capped: capped?})

          emit_rate_limit_wait(state_key, retry_at, :over_budget, wait_metadata)

          if actual_wait_ms > 0 do
            Process.sleep(actual_wait_ms)
          end
        end

        case attempt_fun.() do
          {:ok, reservation_ctx} ->
            emit_budget_reserved(state_key, reservation_ctx, estimate_ctx)
            {:ok, reservation_ctx, estimate_ctx}

          {:error, {:over_budget, over_again}} ->
            emit_budget_rejected(state_key, over_again, estimate_ctx)
            next_retry = Map.get(over_again, :window_end)
            {:error, {:rate_limited, next_retry, rate_limit_details(over_again, estimate_ctx)}}
        end
    end
  end

  defp build_estimate_context(opts, config) do
    estimated_input_tokens = Keyword.get(opts, :estimated_input_tokens, 0)
    estimated_cached_tokens = Keyword.get(opts, :estimated_cached_tokens, 0)
    estimated_total_tokens = estimated_input_tokens + estimated_cached_tokens
    budget = Keyword.get(opts, :token_budget_per_window, config.token_budget_per_window)

    %{
      estimated_input_tokens: estimated_input_tokens,
      estimated_cached_tokens: estimated_cached_tokens,
      estimated_total_tokens: estimated_total_tokens,
      token_budget: budget
    }
  end

  defp check_token_budget(state_key, opts, config) do
    estimate_ctx = build_estimate_context(opts, config)
    usage = State.get_current_usage(state_key)

    cond do
      is_nil(estimate_ctx.token_budget) ->
        {:ok, Map.put(estimate_ctx, :usage, usage)}

      estimate_ctx.estimated_total_tokens > estimate_ctx.token_budget ->
        {:over_budget,
         Map.merge(estimate_ctx, %{
           reason: :over_budget,
           request_too_large: true,
           usage: usage
         })}

      usage &&
          usage.input_tokens + usage.output_tokens + usage.reserved_tokens +
            estimate_ctx.estimated_total_tokens > estimate_ctx.token_budget ->
        window_end = DateTime.add(usage.window_start, usage.window_duration_ms, :millisecond)

        {:over_budget,
         Map.merge(estimate_ctx, %{
           reason: :over_budget,
           request_too_large: false,
           usage: usage,
           window_end: window_end
         })}

      true ->
        {:ok, Map.put(estimate_ctx, :usage, usage)}
    end
  end

  defp rate_limit_details(budget_ctx, estimate_ctx) do
    estimate_slice =
      Map.take(estimate_ctx, [
        :estimated_input_tokens,
        :estimated_cached_tokens,
        :estimated_total_tokens,
        :token_budget
      ])

    Map.merge(
      %{reason: :over_budget},
      estimate_slice
    )
    |> Map.merge(Map.take(budget_ctx, [:request_too_large, :reserved_tokens]))
  end

  defp reconcile_budget(state_key, reservation_ctx, result, config, _opts, _estimate_ctx) do
    usage =
      result
      |> extract_usage_from_result()

    State.reconcile_reservation(
      state_key,
      reservation_ctx,
      usage,
      window_duration_ms: config.window_duration_ms
    )
  end

  defp build_release_fn(
         state_key,
         reservation_ctx,
         concurrency_key,
         config,
         opts \\ []
       ) do
    permit? = Keyword.get(opts, :permit?, true) and Config.concurrency_enabled?(config)
    released = :atomics.new(1, [])
    :atomics.put(released, 1, 0)

    fn outcome, usage_map ->
      case :atomics.compare_exchange(released, 1, 0, 1) do
        :ok ->
          if usage_map do
            State.reconcile_reservation(
              state_key,
              reservation_ctx,
              usage_map,
              window_duration_ms: config.window_duration_ms
            )
          else
            State.release_reservation(
              state_key,
              reservation_ctx,
              window_duration_ms: config.window_duration_ms
            )
          end

          if permit?, do: ConcurrencyGate.release(concurrency_key)

          {model, location, _metric} = state_key
          emit_stream_event(outcome_to_stream_event(outcome), model, location)

        _ ->
          :ok
      end
    end
  end

  defp outcome_to_stream_event(:completed), do: :completed
  defp outcome_to_stream_event(:error), do: :error
  defp outcome_to_stream_event(:stopped), do: :stopped
  defp outcome_to_stream_event(_), do: :completed

  defp extract_usage_from_result({:ok, response}) when is_map(response),
    do: extract_usage(response)

  defp extract_usage_from_result(_), do: nil

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

  defp emit_budget_reserved(state_key, reservation_ctx, estimate_ctx) do
    {model, location, _metric} = state_key

    metadata =
      %{
        model: model,
        location: location,
        reserved_tokens: reservation_ctx.reserved_tokens,
        estimated_tokens: reservation_ctx.estimated_tokens,
        estimated_total_tokens: estimate_ctx.estimated_total_tokens,
        estimated_input_tokens: estimate_ctx.estimated_input_tokens,
        estimated_cached_tokens: estimate_ctx.estimated_cached_tokens,
        token_budget: estimate_ctx.token_budget
      }

    Telemetry.execute([:gemini, :rate_limit, :budget, :reserved], %{}, metadata)
  end

  defp emit_budget_rejected(state_key, budget_ctx, estimate_ctx) do
    {model, location, _metric} = state_key

    metadata =
      %{
        model: model,
        location: location,
        retry_at: Map.get(budget_ctx, :window_end)
      }
      |> Map.merge(rate_limit_details(budget_ctx, estimate_ctx))

    Telemetry.execute([:gemini, :rate_limit, :budget, :rejected], %{}, metadata)
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

  defp emit_stream_event(status, model, location) do
    metadata = %{model: model, location: location}
    Telemetry.execute([:gemini, :rate_limit, :stream, status], %{}, metadata)
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
