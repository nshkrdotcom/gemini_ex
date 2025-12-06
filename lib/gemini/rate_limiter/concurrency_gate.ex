defmodule Gemini.RateLimiter.ConcurrencyGate do
  @moduledoc """
  Per-model concurrency gating using semaphore-like permits.

  Throttles request bursts by limiting concurrent requests per model.
  Supports adaptive mode that adjusts concurrency based on 429 responses.

  ## Features

  - Configurable per-model concurrency limits
  - Adaptive mode: starts low, raises until 429, then backs off
  - Non-blocking mode support for immediate returns
  - ETS-based permit tracking for cross-process visibility
  """

  alias Gemini.RateLimiter.Config

  @ets_table :gemini_concurrency_permits
  @adaptive_backoff_factor 0.75
  @adaptive_raise_amount 1

  @type model_key :: String.t()
  @type permit_state :: %{
          current: non_neg_integer(),
          max: pos_integer(),
          adaptive_max: pos_integer() | nil,
          waiting: list(pid()),
          holders: %{pid() => {non_neg_integer(), pid()}}
        }

  @doc """
  Initialize the ETS table for permit tracking.

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
  Acquire a permit for the given model.

  Returns immediately if a permit is available. If no permit is available:
  - In blocking mode: waits until a permit becomes available
  - In non-blocking mode: returns `{:error, :no_permit_available}`

  ## Parameters

  - `model` - Model name
  - `config` - Rate limiter configuration

  ## Returns

  - `:ok` - Permit acquired
  - `{:error, :no_permit_available}` - No permit available (non-blocking mode)
  - `{:error, :concurrency_disabled}` - Concurrency gating is disabled
  """
  @spec acquire(model_key(), Config.t()) :: :ok | {:error, atom()}
  def acquire(model, %Config{} = config) do
    ensure_table_exists()

    unless Config.concurrency_enabled?(config) do
      {:error, :concurrency_disabled}
    else
      max = effective_max(model, config)
      do_acquire(model, max, config.non_blocking, config.permit_timeout_ms)
    end
  end

  @doc """
  Release a permit for the given model.

  Called after a request completes (success or failure).
  """
  @spec release(model_key()) :: :ok
  def release(model) do
    ensure_table_exists()

    with_lock(model, fn ->
      case :ets.lookup(@ets_table, model) do
        [{^model, state}] ->
          holders = Map.get(state, :holders, %{})
          {new_holders, new_current} = release_holder(holders, state.current, self())
          new_state = %{state | current: new_current, holders: new_holders}
          :ets.insert(@ets_table, {model, new_state})

        [] ->
          :ok
      end
    end)

    :ok
  end

  @doc """
  Signal that a 429 was received for adaptive backoff.

  In adaptive mode, reduces the effective max concurrency.
  """
  @spec signal_429(model_key(), Config.t()) :: :ok
  def signal_429(model, %Config{adaptive_concurrency: true} = config) do
    ensure_table_exists()

    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        current_max = state.adaptive_max || state.max
        # Back off by reducing concurrency
        new_adaptive_max =
          max(1, round(current_max * @adaptive_backoff_factor))

        new_state = %{state | adaptive_max: new_adaptive_max}
        :ets.insert(@ets_table, {model, new_state})

      [] ->
        # Initialize with backed-off concurrency
        base_max = config.max_concurrency_per_model || 4
        backed_off = max(1, round(base_max * @adaptive_backoff_factor))
        init_state(model, base_max, backed_off)
    end

    :ok
  end

  def signal_429(_model, %Config{adaptive_concurrency: false}), do: :ok

  @doc """
  Signal that a request succeeded for adaptive raise.

  In adaptive mode, gradually increases concurrency up to the ceiling.
  """
  @spec signal_success(model_key(), Config.t()) :: :ok
  def signal_success(model, %Config{adaptive_concurrency: true} = config) do
    ensure_table_exists()

    case :ets.lookup(@ets_table, model) do
      [{^model, state}] when not is_nil(state.adaptive_max) ->
        ceiling = config.adaptive_ceiling
        # Raise by 1 up to ceiling
        new_adaptive_max = min(ceiling, state.adaptive_max + @adaptive_raise_amount)
        new_state = %{state | adaptive_max: new_adaptive_max}
        :ets.insert(@ets_table, {model, new_state})

      _ ->
        :ok
    end

    :ok
  end

  def signal_success(_model, %Config{adaptive_concurrency: false}), do: :ok

  @doc """
  Get current permit state for a model.
  """
  @spec get_state(model_key()) :: permit_state() | nil
  def get_state(model) do
    ensure_table_exists()

    case :ets.lookup(@ets_table, model) do
      [{^model, state}] -> state
      [] -> nil
    end
  end

  @doc """
  Get the number of available permits for a model.
  """
  @spec available_permits(model_key(), Config.t()) :: non_neg_integer()
  def available_permits(model, %Config{} = config) do
    ensure_table_exists()

    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        max = state.adaptive_max || state.max
        max(0, max - state.current)

      [] ->
        config.max_concurrency_per_model || 0
    end
  end

  @doc """
  Reset state for a model (useful for testing).
  """
  @spec reset(model_key()) :: :ok
  def reset(model) do
    :ets.delete(@ets_table, model)
    :ok
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

  # Private implementation

  defp do_acquire(model, max, non_blocking, permit_timeout_ms) do
    start_time = System.monotonic_time(:millisecond)
    do_acquire_loop(model, max, non_blocking, permit_timeout_ms, start_time)
  end

  defp do_acquire_loop(model, max, non_blocking, permit_timeout_ms, start_time) do
    case try_acquire(model, max) do
      :ok ->
        :ok

      :full when non_blocking ->
        {:error, :no_permit_available}

      :full ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        if permit_timeout_ms != :infinity and is_integer(permit_timeout_ms) and
             elapsed >= permit_timeout_ms do
          {:error, :timeout_waiting_for_permit}
        else
          Process.sleep(5)
          do_acquire_loop(model, max, non_blocking, permit_timeout_ms, start_time)
        end
    end
  end

  defp try_acquire(model, max) do
    with_lock(model, fn ->
      case :ets.lookup(@ets_table, model) do
        [{^model, state}] ->
          effective = state.adaptive_max || state.max

          if state.current < effective do
            holders = Map.get(state, :holders, %{})
            {new_holders, _watcher} = ensure_holder_tracking(model, self(), holders)

            new_state = %{state | current: state.current + 1, holders: new_holders}
            :ets.insert(@ets_table, {model, new_state})
            :ok
          else
            :full
          end

        [] ->
          # First request for this model, initialize and acquire
          {new_holders, _watcher} = ensure_holder_tracking(model, self(), %{})

          state = %{
            current: 1,
            max: max,
            adaptive_max: nil,
            waiting: [],
            holders: new_holders
          }

          :ets.insert(@ets_table, {model, state})
          :ok
      end
    end)
  end

  defp init_state(model, max, adaptive_max) do
    state = %{
      current: 0,
      max: max,
      adaptive_max: adaptive_max,
      waiting: [],
      holders: %{}
    }

    :ets.insert(@ets_table, {model, state})
  end

  defp ensure_holder_tracking(model, pid, holders) do
    case Map.get(holders, pid) do
      {count, watcher_pid} ->
        {Map.put(holders, pid, {count + 1, watcher_pid}), watcher_pid}

      nil ->
        watcher_pid = start_holder_watcher(model, pid)
        {Map.put(holders, pid, {1, watcher_pid}), watcher_pid}
    end
  end

  defp release_holder(holders, current, holder_pid) do
    case Map.get(holders, holder_pid) do
      {count, watcher_pid} when count > 1 ->
        {Map.put(holders, holder_pid, {count - 1, watcher_pid}), max(0, current - 1)}

      {1, watcher_pid} ->
        send(watcher_pid, :cancel)
        {Map.delete(holders, holder_pid), max(0, current - 1)}

      _ ->
        {holders, max(0, current)}
    end
  end

  defp start_holder_watcher(model, holder_pid) do
    spawn(fn ->
      ref = Process.monitor(holder_pid)

      receive do
        :cancel ->
          Process.demonitor(ref, [:flush])

        {:DOWN, ^ref, :process, ^holder_pid, _reason} ->
          handle_holder_down(model, holder_pid)
      end
    end)
  end

  def handle_holder_down(model, holder_pid) do
    ensure_table_exists()

    with_lock(model, fn ->
      case :ets.lookup(@ets_table, model) do
        [{^model, state}] ->
          holders = Map.get(state, :holders, %{})

          case Map.pop(holders, holder_pid) do
            {nil, _} ->
              :ok

            {{count, _watcher}, remaining_holders} ->
              new_current = max(0, state.current - count)
              new_state = %{state | current: new_current, holders: remaining_holders}
              :ets.insert(@ets_table, {model, new_state})
          end

        [] ->
          :ok
      end
    end)

    :ok
  end

  defp effective_max(model, config) do
    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        state.adaptive_max || state.max

      [] ->
        config.max_concurrency_per_model || 4
    end
  end

  defp with_lock(model, fun) do
    :global.trans({@ets_table, model}, fun)
  end
end
