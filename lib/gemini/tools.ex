defmodule Gemini.Tools do
  @moduledoc """
  High-level facade for tool registration and execution in the Gemini client.

  This module provides a convenient interface for developers to register tool
  implementations and execute function calls returned by the Gemini API. It
  integrates with the ALTAR LATER runtime for robust tool execution.

  ## Usage

      # Register a tool
      {:ok, declaration} = Altar.ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Gets weather for a location",
        parameters: %{}
      })

      :ok = Gemini.Tools.register(declaration, &MyApp.Tools.get_weather/1)

      # Execute function calls from API response
      function_calls = [%Altar.ADM.FunctionCall{...}]
      {:ok, results} = Gemini.Tools.execute_calls(function_calls)
  """

  alias Altar.ADM.{FunctionCall, FunctionDeclaration, ToolResult}
  alias Altar.LATER.{Executor, Registry}

  @registry_name Gemini.Tools.Registry

  @doc """
  Register a tool implementation with the LATER registry.

  - `declaration` is a validated `%Altar.ADM.FunctionDeclaration{}`
  - `fun` is an arity-1 function that accepts a map of arguments

  Returns `:ok` on success or `{:error, reason}` if registration fails.
  """
  @spec register(FunctionDeclaration.t(), (map() -> any())) :: :ok | {:error, term()}
  def register(%FunctionDeclaration{} = declaration, fun) when is_function(fun, 1) do
    Registry.register_tool(@registry_name, declaration, fun)
  end

  @doc """
  Execute a list of function calls in parallel using the LATER executor.

  Takes a list of `%Altar.ADM.FunctionCall{}` structs (typically from a
  GenerateContentResponse) and executes them concurrently, returning a list
  of `%Altar.ADM.ToolResult{}` structs.

  Returns `{:ok, [ToolResult.t()]}` on success. Individual tool failures
  are captured in the ToolResult's `is_error` field rather than causing
  the entire operation to fail.
  """
  @spec execute_calls([FunctionCall.t()]) :: {:ok, [ToolResult.t()]}
  def execute_calls(function_calls) when is_list(function_calls) do
    results =
      function_calls
      |> Task.async_stream(
        fn call ->
          {:ok, result} = Executor.execute_tool(@registry_name, call)
          result
        end,
        max_concurrency: System.schedulers_online(),
        timeout: 30_000
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> build_error_result("task_exit", reason)
      end)

    {:ok, results}
  end

  # Helper to build error results for task failures
  defp build_error_result(call_id, reason) do
    {:ok, result} =
      Altar.ADM.new_tool_result(%{
        call_id: call_id,
        is_error: true,
        content: %{error: "Task execution failed: #{inspect(reason)}"}
      })

    result
  end
end
