defmodule Gemini.TaskSupervisor do
  @moduledoc """
  Named task supervisor for Gemini background tasks.
  """

  @type start_child_result :: {:ok, pid()} | {:error, term()}

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_arg) do
    Supervisor.child_spec({Task.Supervisor, name: __MODULE__}, id: __MODULE__)
  end

  @spec start_child((-> any())) :: start_child_result()
  def start_child(fun) when is_function(fun, 0) do
    case ensure_started() do
      :ok -> Task.Supervisor.start_child(__MODULE__, fun)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ensure_started() :: :ok | {:error, term()}
  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        case Task.Supervisor.start_link(name: __MODULE__) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _pid ->
        :ok
    end
  end
end
