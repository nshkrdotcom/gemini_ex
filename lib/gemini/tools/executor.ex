defmodule Gemini.Tools.Executor do
  @moduledoc """
  Executes function calls from Gemini API responses against a registry of implementations.

  This module provides the core function execution infrastructure for tool calling.
  It handles:

  - Executing single function calls against a function registry
  - Batch execution of multiple calls (sequential or parallel)
  - Building function responses for multi-turn conversations
  - Error handling and recovery

  ## Function Registry

  A function registry is a map from function names to implementations:

      registry = %{
        "get_weather" => fn args -> WeatherService.get(args["location"]) end,
        "search_database" => fn args -> Database.search(args["query"]) end
      }

  You can also use `create_registry/1` for convenience:

      registry = Executor.create_registry(
        get_weather: &WeatherService.get(&1["location"]),
        search_database: &Database.search(&1["query"])
      )

  ## Examples

      # Single execution
      {:ok, call} = FunctionCall.new(call_id: "1", name: "add", args: %{"a" => 1, "b" => 2})
      registry = %{"add" => fn args -> args["a"] + args["b"] end}

      {:ok, result} = Executor.execute(call, registry)
      #=> {:ok, 3}

      # Batch execution
      calls = [call1, call2, call3]
      results = Executor.execute_all(calls, registry)

      # Parallel execution for I/O-bound functions
      results = Executor.execute_all_parallel(calls, registry)

      # Build responses for Gemini API
      responses = Executor.build_responses(calls, results)
  """

  alias Altar.ADM.FunctionCall
  alias Gemini.Types.FunctionResponse

  @type function_impl :: (map() -> term()) | {module(), atom(), list()}
  @type function_registry :: %{String.t() => function_impl()}
  @type execution_result :: {:ok, term()} | {:error, term()}

  @doc """
  Execute a single function call against the registry.

  ## Parameters

  - `call`: A `FunctionCall` struct with name and args
  - `registry`: Map from function names to implementations

  ## Returns

  - `{:ok, result}` - Function executed successfully
  - `{:error, {:unknown_function, name}}` - Function not found in registry
  - `{:error, {:execution_error, exception}}` - Function raised an exception

  ## Examples

      {:ok, call} = FunctionCall.new(call_id: "1", name: "double", args: %{"n" => 5})
      registry = %{"double" => fn args -> args["n"] * 2 end}

      {:ok, 10} = Executor.execute(call, registry)
  """
  @spec execute(FunctionCall.t(), function_registry()) :: execution_result()
  def execute(%FunctionCall{name: name, args: args}, registry) do
    case Map.get(registry, name) do
      nil ->
        {:error, {:unknown_function, name}}

      func when is_function(func, 1) ->
        execute_function(fn -> func.(args) end)

      {mod, fun, extra_args} when is_atom(mod) and is_atom(fun) and is_list(extra_args) ->
        execute_function(fn -> apply(mod, fun, extra_args) end)
    end
  end

  defp execute_function(fun) do
    {:ok, fun.()}
  rescue
    e -> {:error, {:execution_error, e}}
  end

  @doc """
  Execute multiple function calls sequentially.

  Returns results in the same order as the input calls.

  ## Parameters

  - `calls`: List of `FunctionCall` structs
  - `registry`: Function registry

  ## Returns

  List of execution results, one for each call.

  ## Examples

      results = Executor.execute_all([call1, call2], registry)
      [{:ok, result1}, {:ok, result2}] = results
  """
  @spec execute_all([FunctionCall.t()], function_registry()) :: [execution_result()]
  def execute_all(calls, registry) when is_list(calls) do
    Enum.map(calls, &execute(&1, registry))
  end

  @doc """
  Execute multiple function calls in parallel.

  Uses `Task.async_stream` for concurrent execution. Best for I/O-bound
  functions like HTTP requests or database queries.

  ## Parameters

  - `calls`: List of `FunctionCall` structs
  - `registry`: Function registry
  - `opts`: Options passed to `Task.async_stream` (default: `max_concurrency: 10`)

  ## Returns

  List of execution results, in the same order as input calls.

  ## Examples

      # Execute 3 slow operations in parallel
      results = Executor.execute_all_parallel([call1, call2, call3], registry)
  """
  @spec execute_all_parallel([FunctionCall.t()], function_registry(), keyword()) :: [
          execution_result()
        ]
  def execute_all_parallel(calls, registry, opts \\ []) when is_list(calls) do
    opts = Keyword.merge([max_concurrency: 10, ordered: true], opts)

    calls
    |> Task.async_stream(fn call -> execute(call, registry) end, opts)
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:task_exit, reason}}
    end)
  end

  @doc """
  Build FunctionResponse structs from execution results.

  Creates responses suitable for sending back to the Gemini API
  in multi-turn function calling conversations.

  ## Parameters

  - `calls`: Original function calls
  - `results`: Execution results from `execute_all/2` or `execute_all_parallel/3`

  ## Returns

  List of `FunctionResponse` structs.

  ## Examples

      calls = [call1, call2]
      results = Executor.execute_all(calls, registry)
      responses = Executor.build_responses(calls, results)

      # Use responses in next Gemini API call
      contents = [previous_response, %{role: "function", parts: responses}]
  """
  @spec build_responses([FunctionCall.t()], [execution_result()]) :: [FunctionResponse.t()]
  def build_responses(calls, results) when is_list(calls) and is_list(results) do
    Enum.zip(calls, results)
    |> Enum.map(fn {call, result} ->
      build_single_response(call, result)
    end)
  end

  defp build_single_response(%FunctionCall{name: name, call_id: call_id}, {:ok, result}) do
    %FunctionResponse{
      name: name,
      id: call_id,
      response: %{"result" => result}
    }
  end

  defp build_single_response(%FunctionCall{name: name, call_id: call_id}, {:error, error}) do
    error_message =
      case error do
        {:unknown_function, fn_name} -> "Unknown function: #{fn_name}"
        {:execution_error, exception} -> "Execution error: #{Exception.message(exception)}"
        {:task_exit, reason} -> "Task exited: #{inspect(reason)}"
        other -> "Error: #{inspect(other)}"
      end

    %FunctionResponse{
      name: name,
      id: call_id,
      response: %{"error" => error_message}
    }
  end

  @doc """
  Create a function registry from a keyword list or map.

  Converts atom keys to strings for consistent lookup.

  ## Examples

      # From keyword list
      registry = Executor.create_registry(
        add: fn args -> args["a"] + args["b"] end,
        multiply: fn args -> args["a"] * args["b"] end
      )

      # From map with string keys
      registry = Executor.create_registry(%{
        "add" => fn args -> args["a"] + args["b"] end
      })
  """
  @spec create_registry(keyword() | map()) :: function_registry()
  def create_registry(functions) when is_list(functions) do
    Map.new(functions, fn {name, impl} ->
      {to_string(name), impl}
    end)
  end

  def create_registry(functions) when is_map(functions) do
    Map.new(functions, fn {name, impl} ->
      {to_string(name), impl}
    end)
  end
end
