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
          waiting: list(pid())
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
      do_acquire(model, max, config.non_blocking)
    end
  end

  @doc """
  Release a permit for the given model.

  Called after a request completes (success or failure).
  """
  @spec release(model_key()) :: :ok
  def release(model) do
    ensure_table_exists()

    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        new_current = max(0, state.current - 1)
        new_state = %{state | current: new_current}
        :ets.insert(@ets_table, {model, new_state})

        # Notify waiting processes if any
        notify_waiters(model, new_state)

      [] ->
        :ok
    end

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

  defp do_acquire(model, max, non_blocking) do
    case try_acquire(model, max) do
      :ok ->
        :ok

      :full ->
        if non_blocking do
          {:error, :no_permit_available}
        else
          wait_for_permit(model, max)
        end
    end
  end

  defp try_acquire(model, max) do
    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        effective = state.adaptive_max || state.max

        if state.current < effective do
          new_state = %{state | current: state.current + 1}
          :ets.insert(@ets_table, {model, new_state})
          :ok
        else
          :full
        end

      [] ->
        # First request for this model, initialize and acquire
        state = %{
          current: 1,
          max: max,
          adaptive_max: nil,
          waiting: []
        }

        :ets.insert(@ets_table, {model, state})
        :ok
    end
  end

  defp init_state(model, max, adaptive_max) do
    state = %{
      current: 0,
      max: max,
      adaptive_max: adaptive_max,
      waiting: []
    }

    :ets.insert(@ets_table, {model, state})
  end

  defp wait_for_permit(model, max) do
    # Register as waiting
    register_waiter(model)

    # Try to acquire again immediately to avoid missing a release that
    # happened before we registered as a waiter.
    case try_acquire(model, max) do
      :ok ->
        unregister_waiter(model)
        drain_permit_message(model)
        :ok

      :full ->
        receive do
          {:permit_available, ^model} ->
            # Try to acquire again
            case try_acquire(model, max) do
              :ok ->
                unregister_waiter(model)
                :ok

              :full ->
                wait_for_permit(model, max)
            end
        after
          # Timeout after 60 seconds to prevent infinite waits
          60_000 ->
            unregister_waiter(model)
            {:error, :timeout_waiting_for_permit}
        end
    end
  end

  defp register_waiter(model) do
    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        new_state = %{state | waiting: [self() | state.waiting]}
        :ets.insert(@ets_table, {model, new_state})

      [] ->
        :ok
    end
  end

  defp unregister_waiter(model) do
    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        new_state = %{state | waiting: List.delete(state.waiting, self())}
        :ets.insert(@ets_table, {model, new_state})

      [] ->
        :ok
    end
  end

  defp notify_waiters(model, state) do
    case state.waiting do
      [waiter | rest] ->
        new_state = %{state | waiting: rest}
        :ets.insert(@ets_table, {model, new_state})
        send(waiter, {:permit_available, model})

      [] ->
        :ok
    end
  end

  # Drain a stray permit message that may arrive after we already acquired.
  defp drain_permit_message(model) do
    receive do
      {:permit_available, ^model} -> :ok
    after
      0 -> :ok
    end
  end

  defp effective_max(model, config) do
    case :ets.lookup(@ets_table, model) do
      [{^model, state}] ->
        state.adaptive_max || state.max

      [] ->
        config.max_concurrency_per_model || 4
    end
  end
end
