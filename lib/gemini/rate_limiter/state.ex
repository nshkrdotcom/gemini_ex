defmodule Gemini.RateLimiter.State do
  @moduledoc """
  ETS-based state management for rate limiting.

  Tracks per-model/location/metric state including:
  - `retry_until` timestamps derived from 429 RetryInfo
  - Token usage sliding windows for budget estimation
  - Concurrency permits for gating

  State is keyed by `{model, location, metric}` tuples for fine-grained tracking.
  """

  @type state_key :: {model :: String.t(), location :: String.t(), metric :: atom()}
  @type retry_state :: %{
          retry_until: DateTime.t() | nil,
          quota_metric: String.t() | nil,
          quota_id: String.t() | nil,
          # ADR-0003: Additional quota metadata for richer diagnostics
          quota_dimensions: map() | nil,
          quota_value: term() | nil,
          last_429_at: DateTime.t() | nil
        }
  @type usage_window :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          window_start: DateTime.t(),
          window_duration_ms: pos_integer()
        }

  @ets_table :gemini_rate_limit_state
  @default_window_duration_ms 60_000
  @default_location "us-central1"

  @doc """
  Initialize the ETS table for state storage.

  Called automatically when the RateLimitManager starts, but also
  lazily initialized on first access to support direct calls without
  the supervisor running.
  """
  @spec init() :: :ok
  def init do
    ensure_table_exists()
    :ok
  end

  # Lazy initialization - ensures table exists before any operation
  defp ensure_table_exists do
    case :ets.whereis(@ets_table) do
      :undefined ->
        # Use try/catch to handle race condition where another process creates the table
        try do
          :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
        catch
          :error, :badarg -> :ok
        end

      _ref ->
        :ok
    end
  end

  @doc """
  Build a state key from model, location, and metric.
  """
  @spec build_key(String.t(), String.t() | nil, atom()) :: state_key()
  def build_key(model, location, metric) do
    {model, location || @default_location, metric}
  end

  @doc """
  Get the current retry_until timestamp for a given key.

  Returns `nil` if no retry is needed or the timestamp has passed.
  """
  @spec get_retry_until(state_key()) :: DateTime.t() | nil
  def get_retry_until(key) do
    ensure_table_exists()

    case :ets.lookup(@ets_table, {:retry, key}) do
      [{_key, %{retry_until: retry_until}}] when not is_nil(retry_until) ->
        if DateTime.compare(retry_until, DateTime.utc_now()) == :gt do
          retry_until
        else
          nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Update the retry_until state from a 429 response with RetryInfo.

  ## Parameters

  - `key` - State key tuple
  - `retry_info` - Map containing retry delay and quota information

  ## RetryInfo format from Gemini API

      %{
        "retryDelay" => "60s",
        "quotaMetric" => "...",
        "quotaId" => "...",
        "quotaDimensions" => %{...}
      }
  """
  @spec set_retry_state(state_key(), map()) :: :ok
  def set_retry_state(key, retry_info) do
    ensure_table_exists()
    retry_delay_ms = parse_retry_delay(retry_info)
    retry_until = DateTime.add(DateTime.utc_now(), retry_delay_ms, :millisecond)

    # ADR-0003: Capture additional quota metadata for richer diagnostics
    state = %{
      retry_until: retry_until,
      quota_metric: extract_quota_metric(retry_info),
      quota_id: Map.get(retry_info, "quotaId"),
      quota_dimensions: Map.get(retry_info, "quotaDimensions"),
      quota_value: Map.get(retry_info, "quotaValue"),
      last_429_at: DateTime.utc_now()
    }

    :ets.insert(@ets_table, {{:retry, key}, state})
    :ok
  end

  # ADR-0003: Extract quota metric from retry_info or nested error.details
  defp extract_quota_metric(retry_info) do
    Map.get(retry_info, "quotaMetric") ||
      get_in(retry_info, ["error", "quotaMetric"])
  end

  @doc """
  Clear the retry state for a key (called after successful request).
  """
  @spec clear_retry_state(state_key()) :: :ok
  def clear_retry_state(key) do
    ensure_table_exists()
    :ets.delete(@ets_table, {:retry, key})
    :ok
  end

  @doc """
  Get the current retry state details for a key.
  """
  @spec get_retry_state(state_key()) :: retry_state() | nil
  def get_retry_state(key) do
    ensure_table_exists()

    case :ets.lookup(@ets_table, {:retry, key}) do
      [{_key, state}] -> state
      [] -> nil
    end
  end

  @doc """
  Record token usage in the sliding window.

  ## Parameters

  - `key` - State key tuple
  - `input_tokens` - Number of input tokens used
  - `output_tokens` - Number of output tokens used
  - `opts` - Options including:
    - `:window_duration_ms` - Custom window duration (default: 60_000)
  """
  @spec record_usage(state_key(), non_neg_integer(), non_neg_integer(), keyword()) :: :ok
  def record_usage(key, input_tokens, output_tokens, opts \\ []) do
    ensure_table_exists()
    now = DateTime.utc_now()
    # ADR-0002: Use configurable window duration
    window_duration = Keyword.get(opts, :window_duration_ms, @default_window_duration_ms)

    current_window =
      case :ets.lookup(@ets_table, {:usage, key}) do
        [{_key, window}] ->
          window_age_ms =
            DateTime.diff(now, window.window_start, :millisecond)

          if window_age_ms < window.window_duration_ms do
            # Within current window, accumulate
            %{
              window
              | input_tokens: window.input_tokens + input_tokens,
                output_tokens: window.output_tokens + output_tokens
            }
          else
            # Window expired, start new one with configured duration
            new_window(input_tokens, output_tokens, now, window_duration)
          end

        [] ->
          new_window(input_tokens, output_tokens, now, window_duration)
      end

    :ets.insert(@ets_table, {{:usage, key}, current_window})
    :ok
  end

  @doc """
  Get current usage within the sliding window.
  """
  @spec get_current_usage(state_key()) :: usage_window() | nil
  def get_current_usage(key) do
    ensure_table_exists()
    now = DateTime.utc_now()

    case :ets.lookup(@ets_table, {:usage, key}) do
      [{_key, window}] ->
        window_age_ms = DateTime.diff(now, window.window_start, :millisecond)

        if window_age_ms < window.window_duration_ms do
          window
        else
          nil
        end

      [] ->
        nil
    end
  end

  @doc """
  Estimate if a request would exceed budget based on current window usage.

  ## Parameters

  - `key` - State key tuple
  - `estimated_input_tokens` - Estimated input tokens for the request
  - `token_budget_per_window` - Maximum tokens allowed per window (nil = no limit)
  """
  @spec would_exceed_budget?(state_key(), non_neg_integer(), non_neg_integer() | nil) :: boolean()
  def would_exceed_budget?(_key, _estimated_tokens, nil), do: false

  def would_exceed_budget?(key, estimated_input_tokens, token_budget_per_window) do
    case get_current_usage(key) do
      nil ->
        estimated_input_tokens > token_budget_per_window

      window ->
        total = window.input_tokens + window.output_tokens + estimated_input_tokens
        total > token_budget_per_window
    end
  end

  @doc """
  Reset all state (useful for testing).
  """
  @spec reset_all() :: :ok
  def reset_all do
    case :ets.whereis(@ets_table) do
      :undefined -> :ok
      _ref -> :ets.delete_all_objects(@ets_table)
    end

    :ok
  end

  # Private helpers

  defp new_window(input_tokens, output_tokens, now, window_duration_ms) do
    %{
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      window_start: now,
      window_duration_ms: window_duration_ms
    }
  end

  @doc false
  def parse_retry_delay(retry_info) do
    case Map.get(retry_info, "retryDelay") do
      nil ->
        # Default fallback if no retry delay provided
        default_retry_delay_ms()

      delay_str when is_binary(delay_str) ->
        parse_duration_string(delay_str)

      delay_ms when is_integer(delay_ms) ->
        delay_ms
    end
  end

  defp parse_duration_string(str) do
    # Parse duration strings like "60s", "1.5s", "100ms"
    cond do
      String.ends_with?(str, "ms") ->
        str |> String.trim_trailing("ms") |> parse_number() |> round()

      String.ends_with?(str, "s") ->
        str |> String.trim_trailing("s") |> parse_number() |> Kernel.*(1000) |> round()

      String.ends_with?(str, "m") ->
        str |> String.trim_trailing("m") |> parse_number() |> Kernel.*(60_000) |> round()

      true ->
        # Try to parse as raw number (assume seconds)
        case Float.parse(str) do
          {secs, _} -> round(secs * 1000)
          :error -> default_retry_delay_ms()
        end
    end
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> default_retry_delay_ms() / 1000
    end
  end

  defp default_retry_delay_ms do
    rate_limiter_config = Application.get_env(:gemini_ex, :rate_limiter, [])
    Keyword.get(rate_limiter_config, :default_retry_delay_ms, 60_000)
  end
end
