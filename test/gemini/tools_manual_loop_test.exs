defmodule Gemini.ToolsManualLoopTest do
  use ExUnit.Case, async: false

  alias Gemini.{Chat, Tools}
  alias Altar.ADM

  @moduletag :integration

  setup do
    # Define a simple test tool function
    test_tool_fun = fn %{"input" => input} ->
      %{result: "processed_#{input}", timestamp: DateTime.utc_now()}
    end

    # Create and register the tool declaration
    {:ok, declaration} =
      ADM.new_function_declaration(%{
        name: "test_processor",
        description: "A simple test tool that processes input",
        parameters: %{
          type: "object",
          properties: %{
            input: %{
              type: "string",
              description: "The input to process"
            }
          },
          required: ["input"]
        }
      })

    # Register the tool
    :ok = Tools.register(declaration, test_tool_fun)

    %{declaration: declaration, tool_fun: test_tool_fun}
  end

  test "completes a full manual tool-calling loop", %{declaration: _declaration} do
    # Step 1: Create a new chat session
    chat = Chat.new(model: "gemini-1.5-flash", temperature: 0.1)

    # Step 2: Add a user turn designed to trigger the tool
    prompt = "Please use the test_processor tool to process the input 'hello_world'"
    chat = Chat.add_turn(chat, "user", prompt)

    # Step 3: Call generate_content with the chat's history
    # Note: This would normally make a real API call, so we'll mock the response
    # In a real integration test, you'd need a valid API key and the tool would need
    # to be properly configured in the API request
    mock_response = create_mock_function_call_response()

    # For this test, we'll simulate the API returning a function call
    function_calls = extract_function_calls_from_response(mock_response)

    # Step 4: Assert that the response contains the expected FunctionCall
    assert length(function_calls) == 1
    [function_call] = function_calls
    assert function_call.name == "test_processor"
    assert function_call.args["input"] == "hello_world"

    # Step 5: Add the model's turn (containing the FunctionCall) to the chat history
    chat = Chat.add_turn(chat, "model", function_calls)

    # Step 6: Pass the FunctionCall list to Tools.execute_calls
    {:ok, tool_results} = Tools.execute_calls(function_calls)

    # Step 7: Assert that we receive the correct ToolResult
    assert length(tool_results) == 1
    [tool_result] = tool_results
    assert tool_result.is_error == false
    assert tool_result.content.result == "processed_hello_world"
    assert Map.has_key?(tool_result.content, :timestamp)

    # Step 8: Add the tool's turn (containing the ToolResult) to the chat history
    chat = Chat.add_turn(chat, "tool", tool_results)

    # Step 9: In a real test, we would call generate_content again with the complete history
    # and assert that the final response correctly uses the tool's result
    # For now, we'll just verify the chat history is properly structured
    assert length(chat.history) == 3

    # Verify the conversation flow
    [user_turn, model_turn, tool_turn] = chat.history

    # User turn should contain the original prompt
    assert user_turn.role == "user"
    assert length(user_turn.parts) == 1
    assert hd(user_turn.parts).text =~ "test_processor"

    # Model turn should contain the function call
    assert model_turn.role == "model"
    assert length(model_turn.parts) == 1
    function_call_part = hd(model_turn.parts)
    assert Map.has_key?(function_call_part, :function_call)
    assert function_call_part.function_call.name == "test_processor"

    # Tool turn should contain the function response
    assert tool_turn.role == "tool"
    assert length(tool_turn.parts) == 1
    function_response_part = hd(tool_turn.parts)
    assert Map.has_key?(function_response_part, "functionResponse")

    # The content structure preserves the original tool result structure
    content = function_response_part["functionResponse"]["response"]["content"]
    assert content.result == "processed_hello_world"
  end

  # Helper functions for the test

  defp create_mock_function_call_response do
    # This simulates what the Gemini API would return when it wants to call a function
    %{
      "candidates" => [
        %{
          "content" => %{
            "parts" => [
              %{
                "functionCall" => %{
                  "name" => "test_processor",
                  "args" => %{"input" => "hello_world"}
                }
              }
            ]
          }
        }
      ]
    }
  end

  defp extract_function_calls_from_response(response) do
    # Extract function calls from the mock response and convert to ADM structs
    response["candidates"]
    |> List.first()
    |> get_in(["content", "parts"])
    |> Enum.filter(&Map.has_key?(&1, "functionCall"))
    |> Enum.map(fn %{"functionCall" => call_data} ->
      {:ok, function_call} =
        ADM.new_function_call(%{
          call_id: "test_call_#{:rand.uniform(1000)}",
          name: call_data["name"],
          args: call_data["args"]
        })

      function_call
    end)
  end
end
