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
          reserved_tokens: non_neg_integer(),
          window_start: DateTime.t(),
          window_duration_ms: pos_integer()
        }
  @type reservation_ctx :: %{
          reserved_tokens: non_neg_integer(),
          estimated_tokens: non_neg_integer(),
          window_start: DateTime.t() | nil,
          window_end: DateTime.t() | nil,
          budget: non_neg_integer() | nil
        }

  @ets_table :gemini_rate_limit_state
  @lock_table :gemini_rate_limit_locks
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

  # Lazy initialization - ensures tables exist before any operation
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

    case :ets.whereis(@lock_table) do
      :undefined ->
        try do
          :ets.new(@lock_table, [:named_table, :public, :set, write_concurrency: true])
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
    window_duration = Keyword.get(opts, :window_duration_ms, @default_window_duration_ms)

    with_lock({:budget, key}, fn ->
      current_window = current_or_new_window(key, now, window_duration)

      updated =
        %{
          current_window
          | input_tokens: current_window.input_tokens + input_tokens,
            output_tokens: current_window.output_tokens + output_tokens
        }

      :ets.insert(@ets_table, {{:usage, key}, updated})
      :ok
    end)
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
        normalized = normalize_window(window)
        window_age_ms = DateTime.diff(now, normalized.window_start, :millisecond)

        if window_age_ms < normalized.window_duration_ms do
          normalized
        else
          nil
        end

      [] ->
        nil
    end
  end

  @doc """
  Atomically reserve tokens in the current window.

  Returns `{:ok, reservation_ctx}` when the reservation fits, or
  `{:error, {:over_budget, details}}` when it would exceed the configured budget.
  """
  @spec try_reserve_budget(state_key(), non_neg_integer(), non_neg_integer() | nil, keyword()) ::
          {:ok, reservation_ctx()} | {:error, {:over_budget, map()}}
  def try_reserve_budget(key, estimated_total_tokens, budget, opts \\ [])

  def try_reserve_budget(_key, estimated_total_tokens, nil, _opts) do
    {:ok,
     %{
       reserved_tokens: 0,
       estimated_tokens: estimated_total_tokens,
       window_start: nil,
       window_end: nil,
       budget: nil
     }}
  end

  def try_reserve_budget(key, estimated_total_tokens, budget, opts) do
    ensure_table_exists()
    multiplier = Keyword.get(opts, :safety_multiplier, 1.0)
    window_duration = Keyword.get(opts, :window_duration_ms, @default_window_duration_ms)
    reserved_tokens = scaled_tokens(estimated_total_tokens, multiplier)

    with_lock({:budget, key}, fn ->
      now = DateTime.utc_now()
      window = current_or_new_window(key, now, window_duration)
      window_end = DateTime.add(window.window_start, window.window_duration_ms, :millisecond)

      cond do
        reserved_tokens > budget ->
          {:error,
           {:over_budget,
            %{
              reason: :over_budget,
              request_too_large: true,
              estimated_total_tokens: estimated_total_tokens,
              reserved_tokens: reserved_tokens,
              token_budget: budget,
              window_end: window_end
            }}}

        window.input_tokens + window.output_tokens + window.reserved_tokens + reserved_tokens >
            budget ->
          {:error,
           {:over_budget,
            %{
              reason: :over_budget,
              request_too_large: false,
              estimated_total_tokens: estimated_total_tokens,
              reserved_tokens: reserved_tokens,
              token_budget: budget,
              usage: window,
              window_end: window_end
            }}}

        true ->
          updated = %{window | reserved_tokens: window.reserved_tokens + reserved_tokens}
          :ets.insert(@ets_table, {{:usage, key}, updated})

          {:ok,
           %{
             reserved_tokens: reserved_tokens,
             estimated_tokens: estimated_total_tokens,
             window_start: updated.window_start,
             window_end: window_end,
             budget: budget
           }}
      end
    end)
  end

  @doc """
  Reconcile a reservation with actual usage, returning surplus or charging shortfall.
  """
  @spec reconcile_reservation(state_key(), reservation_ctx(), map() | nil, keyword()) ::
          usage_window()
  def reconcile_reservation(key, reservation_ctx, usage_map, opts \\ []) do
    ensure_table_exists()
    window_duration = Keyword.get(opts, :window_duration_ms, @default_window_duration_ms)

    reserved = Map.get(reservation_ctx || %{}, :reserved_tokens, 0)
    actual_input = Map.get(usage_map || %{}, :input_tokens, 0)
    actual_output = Map.get(usage_map || %{}, :output_tokens, 0)

    with_lock({:budget, key}, fn ->
      now = DateTime.utc_now()
      window = current_or_new_window(key, now, window_duration)

      updated =
        %{
          window
          | reserved_tokens: max(window.reserved_tokens - reserved, 0),
            input_tokens: window.input_tokens + actual_input,
            output_tokens: window.output_tokens + actual_output
        }

      :ets.insert(@ets_table, {{:usage, key}, updated})
      updated
    end)
  end

  @doc """
  Remove a reservation without adding usage (e.g., when the request never executed).
  """
  @spec release_reservation(state_key(), reservation_ctx(), keyword()) :: usage_window()
  def release_reservation(key, reservation_ctx, opts \\ []) do
    reconcile_reservation(key, reservation_ctx, %{}, opts)
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

    case :ets.whereis(@lock_table) do
      :undefined -> :ok
      _ref -> :ets.delete_all_objects(@lock_table)
    end

    :ok
  end

  # Private helpers

  defp new_window(input_tokens, output_tokens, now, window_duration_ms) do
    %{
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      reserved_tokens: 0,
      window_start: now,
      window_duration_ms: window_duration_ms
    }
  end

  defp current_or_new_window(key, now, window_duration_ms) do
    case :ets.lookup(@ets_table, {:usage, key}) do
      [{_key, window}] ->
        normalized = normalize_window(window)
        window_age_ms = DateTime.diff(now, normalized.window_start, :millisecond)

        if window_age_ms < normalized.window_duration_ms do
          normalized
        else
          new_window(0, 0, now, window_duration_ms)
        end

      [] ->
        new_window(0, 0, now, window_duration_ms)
    end
  end

  defp normalize_window(window) do
    window
    |> Map.put_new(:reserved_tokens, 0)
  end

  defp scaled_tokens(tokens, multiplier) when multiplier == 1.0, do: tokens

  defp scaled_tokens(tokens, multiplier),
    do: tokens |> Kernel.*(multiplier) |> Float.ceil() |> trunc()

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

  # ETS-based locking to replace :global.trans
  defp with_lock(lock_key, fun) do
    acquire_lock(lock_key)

    try do
      fun.()
    after
      release_lock(lock_key)
    end
  end

  defp acquire_lock(lock_key) do
    ensure_table_exists()

    case :ets.insert_new(@lock_table, {lock_key, self()}) do
      true ->
        :ok

      false ->
        cleanup_dead_lock_holder(lock_key)
        Process.sleep(5)
        acquire_lock(lock_key)
    end
  end

  defp release_lock(lock_key) do
    :ets.delete(@lock_table, lock_key)
    :ok
  end

  defp cleanup_dead_lock_holder(lock_key) do
    case :ets.lookup(@lock_table, lock_key) do
      [{^lock_key, pid}] ->
        unless Process.alive?(pid) do
          # Use delete_object to atomically delete only if PID still matches
          # This prevents TOCTOU race where another process acquired the lock
          :ets.delete_object(@lock_table, {lock_key, pid})
        end

      _ ->
        :ok
    end
  end
end
