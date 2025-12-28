defmodule Gemini.Tools.ExecutorTest do
  @moduledoc """
  Tests for the Tools.Executor module that executes function calls.
  """

  use ExUnit.Case, async: true

  alias Altar.ADM.FunctionCall
  alias Gemini.Tools.Executor

  describe "execute/2" do
    test "executes function from registry with args" do
      {:ok, call} =
        FunctionCall.new(
          call_id: "call_123",
          name: "add_numbers",
          args: %{"a" => 1, "b" => 2}
        )

      registry = %{
        "add_numbers" => fn args -> args["a"] + args["b"] end
      }

      assert {:ok, result} = Executor.execute(call, registry)
      assert result == 3
    end

    test "returns error for unknown function" do
      {:ok, call} =
        FunctionCall.new(
          call_id: "call_123",
          name: "unknown_function",
          args: %{}
        )

      registry = %{}

      assert {:error, {:unknown_function, "unknown_function"}} =
               Executor.execute(call, registry)
    end

    test "catches exceptions during execution" do
      {:ok, call} =
        FunctionCall.new(
          call_id: "call_123",
          name: "failing_function",
          args: %{}
        )

      registry = %{
        "failing_function" => fn _args -> raise "Boom!" end
      }

      assert {:error, {:execution_error, %RuntimeError{message: "Boom!"}}} =
               Executor.execute(call, registry)
    end

    test "supports module-function-args tuples in registry" do
      {:ok, call} =
        FunctionCall.new(
          call_id: "call_123",
          name: "get_time",
          args: %{}
        )

      registry = %{
        "get_time" => {DateTime, :utc_now, []}
      }

      assert {:ok, result} = Executor.execute(call, registry)
      assert %DateTime{} = result
    end

    test "passes args to MFA tuple" do
      {:ok, call} =
        FunctionCall.new(
          call_id: "call_123",
          name: "join_strings",
          args: %{"strings" => ["a", "b", "c"], "separator" => "-"}
        )

      registry = %{
        "join_strings" => fn args ->
          Enum.join(args["strings"], args["separator"])
        end
      }

      assert {:ok, "a-b-c"} = Executor.execute(call, registry)
    end
  end

  describe "execute_all/2" do
    test "executes multiple function calls" do
      {:ok, call1} = FunctionCall.new(call_id: "1", name: "double", args: %{"n" => 5})
      {:ok, call2} = FunctionCall.new(call_id: "2", name: "double", args: %{"n" => 10})

      registry = %{
        "double" => fn args -> args["n"] * 2 end
      }

      results = Executor.execute_all([call1, call2], registry)

      assert length(results) == 2
      assert {:ok, 10} = Enum.at(results, 0)
      assert {:ok, 20} = Enum.at(results, 1)
    end

    test "returns individual errors for failed calls" do
      {:ok, call1} = FunctionCall.new(call_id: "1", name: "good", args: %{})
      {:ok, call2} = FunctionCall.new(call_id: "2", name: "bad", args: %{})

      registry = %{
        "good" => fn _args -> :ok end
      }

      results = Executor.execute_all([call1, call2], registry)

      assert {:ok, :ok} = Enum.at(results, 0)
      assert {:error, {:unknown_function, "bad"}} = Enum.at(results, 1)
    end
  end

  describe "execute_all_parallel/2" do
    test "executes calls in parallel" do
      {:ok, call1} = FunctionCall.new(call_id: "1", name: "slow", args: %{"ms" => 50})
      {:ok, call2} = FunctionCall.new(call_id: "2", name: "slow", args: %{"ms" => 50})
      {:ok, call3} = FunctionCall.new(call_id: "3", name: "slow", args: %{"ms" => 50})

      registry = %{
        "slow" => fn args ->
          Process.sleep(args["ms"])
          :done
        end
      }

      start = System.monotonic_time(:millisecond)
      results = Executor.execute_all_parallel([call1, call2, call3], registry)
      elapsed = System.monotonic_time(:millisecond) - start

      assert length(results) == 3
      assert Enum.all?(results, fn r -> r == {:ok, :done} end)
      # Should complete in ~50ms since parallel, not 150ms sequential
      assert elapsed < 120
    end
  end

  describe "build_responses/2" do
    test "builds FunctionResponse list from results" do
      {:ok, call1} = FunctionCall.new(call_id: "1", name: "func1", args: %{})
      {:ok, call2} = FunctionCall.new(call_id: "2", name: "func2", args: %{})

      calls = [call1, call2]
      results = [{:ok, "result1"}, {:ok, %{"key" => "value"}}]

      responses = Executor.build_responses(calls, results)

      assert length(responses) == 2
      assert Enum.at(responses, 0).name == "func1"
      assert Enum.at(responses, 0).response == %{"result" => "result1"}
      assert Enum.at(responses, 1).name == "func2"
      assert Enum.at(responses, 1).response == %{"result" => %{"key" => "value"}}
    end

    test "builds error responses for failed executions" do
      {:ok, call} = FunctionCall.new(call_id: "1", name: "failing", args: %{})

      calls = [call]
      results = [{:error, {:unknown_function, "failing"}}]

      responses = Executor.build_responses(calls, results)

      assert length(responses) == 1
      assert responses |> hd() |> Map.get(:name) == "failing"
      assert %{"error" => _} = responses |> hd() |> Map.get(:response)
    end
  end

  describe "create_registry/1" do
    test "creates registry from keyword list" do
      registry =
        Executor.create_registry(
          add: fn args -> args["a"] + args["b"] end,
          multiply: fn args -> args["a"] * args["b"] end
        )

      assert Map.has_key?(registry, "add")
      assert Map.has_key?(registry, "multiply")
    end

    test "creates registry from map with string keys" do
      registry =
        Executor.create_registry(%{
          "add" => fn args -> args["a"] + args["b"] end
        })

      assert Map.has_key?(registry, "add")
    end
  end
end
