defmodule Gemini.Tools.FunctionCallingLiveTest do
  @moduledoc """
  Live API tests for function calling functionality.

  These tests verify that:
  1. The model correctly generates function calls when given tools
  2. Multi-turn function calling works (sending results back)
  3. Automatic function calling (AFC) loops work end-to-end
  4. Error handling works correctly

  Run with: mix test --include live_api test/gemini/tools/function_calling_live_test.exs
  """

  use ExUnit.Case, async: false

  @moduletag :live_api

  alias Gemini.APIs.Coordinator
  alias Gemini.Tools.{Executor, AutomaticFunctionCalling}
  alias Altar.ADM.FunctionDeclaration

  # Simple calculator tool for testing
  defp calculator_tool do
    {:ok, tool} =
      FunctionDeclaration.new(
        name: "calculate",
        description: "Perform a mathematical calculation. Use this for any math operations.",
        parameters: %{
          type: "OBJECT",
          properties: %{
            "expression" => %{
              type: "STRING",
              description: "The mathematical expression to evaluate, e.g., '2 + 2' or '10 * 5'"
            }
          },
          required: ["expression"]
        }
      )

    tool
  end

  # Weather lookup tool for testing
  defp weather_tool do
    {:ok, tool} =
      FunctionDeclaration.new(
        name: "get_weather",
        description: "Get the current weather for a specific location.",
        parameters: %{
          type: "OBJECT",
          properties: %{
            "location" => %{
              type: "STRING",
              description: "The city name, e.g., 'San Francisco' or 'New York'"
            }
          },
          required: ["location"]
        }
      )

    tool
  end

  # Simple registry for testing
  defp calculator_registry do
    Executor.create_registry(
      calculate: fn args ->
        expr = args["expression"]
        # Simple evaluation for basic expressions
        result =
          cond do
            String.contains?(expr, "+") ->
              [a, b] =
                String.split(expr, "+")
                |> Enum.map(&String.trim/1)
                |> Enum.map(&String.to_integer/1)

              a + b

            String.contains?(expr, "*") ->
              [a, b] =
                String.split(expr, "*")
                |> Enum.map(&String.trim/1)
                |> Enum.map(&String.to_integer/1)

              a * b

            String.contains?(expr, "-") ->
              [a, b] =
                String.split(expr, "-")
                |> Enum.map(&String.trim/1)
                |> Enum.map(&String.to_integer/1)

              a - b

            true ->
              "Could not evaluate: #{expr}"
          end

        "The result is: #{result}"
      end
    )
  end

  describe "basic function call generation" do
    test "model generates function call when given calculator tool" do
      tool = calculator_tool()

      {:ok, response} =
        Coordinator.generate_content(
          "What is 15 + 27? Use the calculate function to find the answer.",
          tools: [tool],
          model: "gemini-2.0-flash"
        )

      # The model should generate a function call
      assert Coordinator.has_function_calls?(response),
             "Expected model to generate a function call, got: #{inspect(response)}"

      calls = Coordinator.extract_function_calls(response)
      assert length(calls) >= 1

      [call | _] = calls
      assert call.name == "calculate"
      assert is_map(call.args)
      assert Map.has_key?(call.args, "expression")
    end

    test "model generates function call for weather query" do
      tool = weather_tool()

      {:ok, response} =
        Coordinator.generate_content(
          "What's the weather like in Tokyo right now? Use the get_weather function.",
          tools: [tool],
          model: "gemini-2.0-flash"
        )

      assert Coordinator.has_function_calls?(response)

      calls = Coordinator.extract_function_calls(response)
      [call | _] = calls
      assert call.name == "get_weather"
      assert call.args["location"] =~ ~r/tokyo/i
    end

    test "model does not generate function call for simple greeting" do
      tool = calculator_tool()

      {:ok, response} =
        Coordinator.generate_content(
          "Hello! How are you today?",
          tools: [tool],
          model: "gemini-2.0-flash"
        )

      # For a simple greeting, the model should NOT call the calculator
      refute Coordinator.has_function_calls?(response),
             "Model should not call calculator for a greeting"
    end
  end

  describe "manual multi-turn function calling" do
    test "complete multi-turn conversation with function results" do
      tool = calculator_tool()
      registry = calculator_registry()

      # Step 1: Initial request
      {:ok, response1} =
        Coordinator.generate_content(
          "Calculate 25 + 17 using the calculate function.",
          tools: [tool],
          model: "gemini-2.0-flash"
        )

      assert Coordinator.has_function_calls?(response1)

      # Step 2: Execute the function calls
      calls = Coordinator.extract_function_calls(response1)
      results = Executor.execute_all(calls, registry)

      # Verify execution succeeded
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # Step 3: Build function response content
      function_response = AutomaticFunctionCalling.build_function_response_content(calls, results)

      # Step 4: Extract model content from first response (in API format)
      model_content = AutomaticFunctionCalling.extract_model_content_for_api(response1)

      # Step 5: Send the results back to the model
      contents = [
        %{role: "user", parts: [%{text: "Calculate 25 + 17 using the calculate function."}]},
        model_content,
        function_response
      ]

      {:ok, response2} =
        Coordinator.generate_content(
          contents,
          tools: [tool],
          model: "gemini-2.0-flash"
        )

      # The model should now provide a final answer (no more function calls)
      # and it should mention "42" (25 + 17)
      refute Coordinator.has_function_calls?(response2),
             "Model should provide final answer, not more function calls"

      {:ok, text} = Gemini.extract_text(response2)
      assert text =~ "42", "Expected answer to contain '42', got: #{text}"
    end
  end

  describe "automatic function calling (AFC)" do
    test "AFC loop completes calculator query end-to-end" do
      tool = calculator_tool()
      registry = calculator_registry()

      # Initial user content
      initial_contents = [
        %{role: "user", parts: [%{text: "What is 100 - 37? Use the calculate function."}]}
      ]

      # Generate function that we'll pass to AFC
      generate_fn = fn contents, _opts ->
        Coordinator.generate_content(contents, tools: [tool], model: "gemini-2.0-flash")
      end

      # First API call
      {:ok, initial_response} = generate_fn.(initial_contents, [])

      # Run the AFC loop
      config = AutomaticFunctionCalling.config(max_calls: 5)

      {final_response, call_count, history} =
        AutomaticFunctionCalling.loop(
          initial_response,
          initial_contents,
          registry,
          config,
          0,
          [],
          generate_fn
        )

      # Verify the loop executed at least one function call
      assert call_count >= 1, "Expected at least one function call"
      assert length(history) >= 1, "Expected call history to have entries"

      # Verify the final response is not an error
      refute match?({:error, _}, final_response)

      # Verify the final response contains the answer
      {:ok, text} = Gemini.extract_text(final_response)
      assert text =~ "63", "Expected answer to contain '63' (100-37), got: #{text}"
    end

    test "AFC respects max_calls limit" do
      # Create a tool that always triggers more calls
      {:ok, repeating_tool} =
        FunctionDeclaration.new(
          name: "get_next_number",
          description: "Get the next number in a sequence.",
          parameters: %{
            type: "OBJECT",
            properties: %{
              "current" => %{type: "INTEGER", description: "Current number"}
            },
            required: ["current"]
          }
        )

      # Registry that always returns a prompt for more
      registry = %{
        "get_next_number" => fn args ->
          current = args["current"] || 0

          "Next number is #{current + 1}. Call get_next_number with current=#{current + 1} to continue."
        end
      }

      initial_contents = [
        %{
          role: "user",
          parts: [%{text: "Start counting from 1. Use get_next_number for each step."}]
        }
      ]

      generate_fn = fn contents, _opts ->
        Coordinator.generate_content(contents, tools: [repeating_tool], model: "gemini-2.0-flash")
      end

      {:ok, initial_response} = generate_fn.(initial_contents, [])

      # Set a low max_calls limit
      config = AutomaticFunctionCalling.config(max_calls: 3)

      {_final_response, call_count, _history} =
        AutomaticFunctionCalling.loop(
          initial_response,
          initial_contents,
          registry,
          config,
          0,
          [],
          generate_fn
        )

      # Verify we stopped at or before the limit
      assert call_count <= 3, "Expected call_count <= 3, got: #{call_count}"
    end
  end

  describe "multiple tools" do
    test "model can choose between multiple tools" do
      calc_tool = calculator_tool()
      weather_tool = weather_tool()

      # Ask about weather - should use weather tool
      {:ok, response} =
        Coordinator.generate_content(
          "What's the weather in Paris? Use the appropriate function.",
          tools: [calc_tool, weather_tool],
          model: "gemini-2.0-flash"
        )

      assert Coordinator.has_function_calls?(response)
      calls = Coordinator.extract_function_calls(response)
      [call | _] = calls

      assert call.name == "get_weather",
             "Expected get_weather, got: #{call.name}"
    end
  end

  describe "error handling" do
    test "executor handles unknown function gracefully" do
      {:ok, call} =
        Altar.ADM.FunctionCall.new(
          call_id: "test_1",
          name: "nonexistent_function",
          args: %{}
        )

      registry = calculator_registry()

      result = Executor.execute(call, registry)
      assert {:error, {:unknown_function, "nonexistent_function"}} = result
    end

    test "executor handles function execution error" do
      {:ok, call} =
        Altar.ADM.FunctionCall.new(
          call_id: "test_1",
          name: "bad_function",
          args: %{}
        )

      registry = %{
        "bad_function" => fn _args -> raise "Intentional test error" end
      }

      result = Executor.execute(call, registry)
      assert {:error, {:execution_error, %RuntimeError{}}} = result
    end

    test "build_responses handles errors correctly" do
      {:ok, call} =
        Altar.ADM.FunctionCall.new(
          call_id: "error_call",
          name: "failing_function",
          args: %{}
        )

      results = [{:error, {:execution_error, %RuntimeError{message: "Test error"}}}]
      responses = Executor.build_responses([call], results)

      assert length(responses) == 1
      [response] = responses
      assert response.name == "failing_function"
      assert response.response["error"] =~ "Execution error"
    end
  end
end
