defmodule Gemini.RateLimiter do
  @moduledoc """
  Rate limiting, concurrency gating, and retry management for Gemini API requests.

  This module provides automatic rate limit handling that is **enabled by default**.
  All requests are paced to respect Gemini's quota limits, with automatic retries
  and backoff when rate limits are encountered.

  ## Features

  - **Automatic rate limit enforcement** - Requests wait when rate limited (429 responses)
  - **Concurrency gating** - Limits concurrent requests per model (default: 4)
  - **Token budgeting** - Tracks usage to preemptively avoid rate limits
  - **Adaptive mode** - Optionally adjusts concurrency based on 429 responses
  - **Structured errors** - Returns `{:error, {:rate_limited, retry_at, details}}`
  - **Telemetry events** - Observable rate limit wait/error events

  ## Default Behavior

  The rate limiter is ON by default. Requests are:

  1. Checked against the current retry window (from previous 429s)
  2. Gated by concurrency permits (default 4 per model)
  3. Optionally checked against token budget
  4. Retried with backoff on transient failures

  ## Configuration

  Configure globally via application environment:

      config :gemini_ex, :rate_limiter,
        max_concurrency_per_model: 4,    # nil or 0 disables concurrency gating
        permit_timeout_ms: :infinity,     # :infinity (default) or a number to cap wait
        max_attempts: 3,                  # Retry attempts for transient errors
        base_backoff_ms: 1000,           # Base backoff duration
        jitter_factor: 0.25,             # Jitter range (±25%)
        adaptive_concurrency: false,      # Enable adaptive mode
        adaptive_ceiling: 8,              # Max concurrency in adaptive mode
        profile: :prod                    # :dev, :prod, or :custom

  ## Per-Request Options

  Override behavior on individual requests:

      Gemini.generate("Hello", [
        disable_rate_limiter: true,       # Bypass all rate limiting
        non_blocking: true,               # Return immediately if rate limited
        max_concurrency_per_model: 8,     # Override concurrency limit
        permit_timeout_ms: :infinity,     # Per-call override for permit wait
        concurrency_key: "tenant_a"       # Optional partition key for concurrency gate
      ])

  ## Non-Blocking Mode

  When `non_blocking: true`, rate-limited requests return immediately:

      case Gemini.generate("Hello", non_blocking: true) do
        {:ok, response} ->
          handle_response(response)

        {:error, {:rate_limited, retry_at, details}} ->
          # Schedule retry for later
          schedule_retry(retry_at)
      end

  ## Structured Errors

  Rate limit errors include retry information:

      {:error, {:rate_limited, ~U[2025-12-03 10:05:30Z], %{
        quota_metric: "TokensPerMinute",
        quota_id: "gemini-flash-lite-latest",
        attempt: 1
      }}}

      {:error, {:transient_failure, 3, original_error}}

  ## Telemetry Events

  The rate limiter emits telemetry events:

  - `[:gemini_ex, :rate_limit, :request, :start]` - Request submitted
  - `[:gemini_ex, :rate_limit, :request, :stop]` - Request completed
  - `[:gemini_ex, :rate_limit, :wait]` - Waiting for retry window
  - `[:gemini_ex, :rate_limit, :error]` - Rate limit error
  """

  alias Gemini.RateLimiter.{ConcurrencyGate, Config, Manager, State}

  @doc """
  Execute a request through the rate limiter.

  This is the primary entry point for rate-limited requests. It handles:

  1. Rate limit state checking
  2. Concurrency permit acquisition
  3. Token budget verification
  4. Retry with backoff on failures

  ## Parameters

  - `request_fn` - Zero-arity function that makes the actual request
  - `model` - Model name for rate limit tracking
  - `opts` - Options (see module docs for full list)

  ## Examples

      # Basic usage
      {:ok, response} = RateLimiter.execute(
        fn -> HTTP.post(path, body) end,
        "gemini-flash-lite-latest"
      )

      # With options
      {:ok, response} = RateLimiter.execute(
        fn -> HTTP.post(path, body) end,
        "gemini-flash-lite-latest",
        non_blocking: true,
        max_concurrency_per_model: 8
      )
  """
  @spec execute(
          (-> {:ok, term()} | {:error, term()}),
          String.t(),
          keyword()
        ) :: {:ok, term()} | {:error, term()}
  defdelegate execute(request_fn, model, opts \\ []), to: Manager

  @doc """
  Execute a request and track token usage from the response.

  Similar to `execute/3` but also records token usage from successful
  responses for budget tracking.
  """
  @spec execute_with_usage_tracking(
          (-> {:ok, term()} | {:error, term()}),
          String.t(),
          keyword()
        ) :: {:ok, term()} | {:error, term()}
  defdelegate execute_with_usage_tracking(request_fn, model, opts \\ []), to: Manager

  @doc """
  Execute a long-lived streaming request through the rate limiter.

  Holds the concurrency permit and budget reservation until the returned
  `release_fn` is invoked (typically on stream completion/error/stop).
  """
  @spec execute_streaming((-> {:ok, term()} | {:error, term()}), String.t(), keyword()) ::
          {:ok, {term(), (atom(), map() | nil -> :ok)}} | {:error, term()}
  defdelegate execute_streaming(start_fn, model, opts \\ []), to: Manager

  @doc """
  Check if a request would be rate limited without executing.

  Useful for preflight checks before submitting requests.

  ## Returns

  - `:ok` - Request can proceed
  - `{:rate_limited, retry_at, details}` - Currently rate limited
  - `{:over_budget, usage}` - Would exceed token budget
  - `{:no_permits, 0}` - No concurrency permits available
  """
  @spec check_status(String.t(), keyword()) ::
          :ok
          | {:rate_limited, DateTime.t(), map()}
          | {:over_budget, map()}
          | {:no_permits, non_neg_integer()}
  defdelegate check_status(model, opts \\ []), to: Manager

  @doc """
  Get the current retry state for a model.

  Returns information about the current rate limit window, if any.
  """
  @spec get_retry_state(String.t(), keyword()) :: State.retry_state() | nil
  defdelegate get_retry_state(model, opts \\ []), to: Manager

  @doc """
  Get current token usage for a model within the sliding window.
  """
  @spec get_usage(String.t(), keyword()) :: State.usage_window() | nil
  defdelegate get_usage(model, opts \\ []), to: Manager

  @doc """
  Get the number of available concurrency permits for a model.
  """
  @spec available_permits(String.t(), keyword()) :: non_neg_integer()
  def available_permits(model, opts \\ []) do
    config = Config.build(opts)
    ConcurrencyGate.available_permits(concurrency_key(model, opts), config)
  end

  @doc """
  Build a configuration struct from options.

  Useful for inspecting the resolved configuration.
  """
  @spec config(keyword()) :: Config.t()
  def config(opts \\ []), do: Config.build(opts)

  @doc """
  Check if rate limiting is enabled for the given options.
  """
  @spec enabled?(keyword()) :: boolean()
  def enabled?(opts \\ []) do
    opts |> Config.build() |> Config.enabled?()
  end

  @doc """
  Reset all rate limiter state.

  Useful for testing or after configuration changes.
  """
  @spec reset_all() :: :ok
  defdelegate reset_all(), to: Manager

  defp concurrency_key(model, opts) do
    case Keyword.get(opts, :concurrency_key) do
      nil ->
        model

      key ->
        "#{model}:#{to_string(key)}"
    end
  end
end
