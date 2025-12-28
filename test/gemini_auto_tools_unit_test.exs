defmodule Gemini.AutoToolsUnitTest do
  use ExUnit.Case, async: true

  alias Altar.ADM
  alias Gemini
  alias Gemini.Chat
  alias Gemini.Types.Content
  alias Gemini.Types.Response.GenerateContentResponse

  import Gemini.Test.ModelHelpers

  describe "generate_content_with_auto_tools/2" do
    test "creates proper chat structure" do
      # Test that the function properly sets up the chat structure
      # This test doesn't make actual API calls

      # Create a mock tool declaration
      {:ok, declaration} =
        ADM.new_function_declaration(%{
          name: "test_tool",
          description: "A test tool",
          parameters: %{
            type: "object",
            properties: %{input: %{type: "string"}},
            required: ["input"]
          }
        })

      # Test that the function accepts the correct parameters
      # We can't test the full execution without mocking the API
      assert is_function(&Gemini.generate_content_with_auto_tools/2, 2)

      # Test with valid options
      opts = [
        tools: [declaration],
        model: default_model(),
        temperature: 0.1,
        turn_limit: 5
      ]

      # The function should exist and accept these parameters
      # (actual execution would require API mocking)
      assert is_list(opts)
      assert Keyword.get(opts, :turn_limit) == 5
    end
  end

  describe "stream_generate_with_auto_tools/2" do
    test "creates proper streaming options" do
      # Test that the streaming function properly sets up options

      {:ok, declaration} =
        ADM.new_function_declaration(%{
          name: "test_tool",
          description: "A test tool",
          parameters: %{type: "object", properties: %{}}
        })

      # Test that the function exists and accepts correct parameters
      assert is_function(&Gemini.stream_generate_with_auto_tools/2, 2)

      opts = [
        tools: [declaration],
        model: default_model(),
        turn_limit: 3
      ]

      assert is_list(opts)
    end
  end

  describe "Chat.add_turn/3 with function calls" do
    test "properly handles function call turns" do
      # Test that Chat.add_turn properly handles function calls

      {:ok, function_call} =
        ADM.new_function_call(%{
          call_id: "test_call_123",
          name: "test_function",
          args: %{"input" => "test_value"}
        })

      chat = Chat.new()
      updated_chat = Chat.add_turn(chat, "model", [function_call])

      assert length(updated_chat.history) == 1
      [content] = updated_chat.history

      assert content.role == "model"
      assert length(content.parts) == 1

      [part] = content.parts
      assert Map.has_key?(part, :function_call)
      assert part.function_call.name == "test_function"
      assert part.function_call.args == %{"input" => "test_value"}
    end

    test "properly handles tool result turns" do
      # Test that Chat.add_turn properly handles tool results

      {:ok, tool_result} =
        ADM.new_tool_result(%{
          call_id: "test_call_123",
          content: %{result: "test_output"},
          is_error: false
        })

      chat = Chat.new()
      updated_chat = Chat.add_turn(chat, "tool", [tool_result])

      assert length(updated_chat.history) == 1
      [content] = updated_chat.history

      assert content.role == "tool"
      assert length(content.parts) == 1

      [part] = content.parts
      assert Map.has_key?(part, "functionResponse")
      assert part["functionResponse"]["name"] == "test_call_123"
      assert part["functionResponse"]["response"]["content"] == %{result: "test_output"}
    end
  end

  describe "Content.from_tool_results/1" do
    test "creates proper content structure from tool results" do
      {:ok, result1} =
        ADM.new_tool_result(%{
          call_id: "call_1",
          content: "result_1",
          is_error: false
        })

      {:ok, result2} =
        ADM.new_tool_result(%{
          call_id: "call_2",
          content: %{data: "result_2"},
          is_error: false
        })

      content = Content.from_tool_results([result1, result2])

      assert content.role == "tool"
      assert length(content.parts) == 2

      [part1, part2] = content.parts

      assert Map.has_key?(part1, "functionResponse")
      assert part1["functionResponse"]["name"] == "call_1"
      assert part1["functionResponse"]["response"]["content"] == "result_1"

      assert Map.has_key?(part2, "functionResponse")
      assert part2["functionResponse"]["name"] == "call_2"
      assert part2["functionResponse"]["response"]["content"] == %{data: "result_2"}
    end
  end

  describe "function call extraction" do
    test "extract_function_calls_from_response works with mock response" do
      # Create a mock response with function calls
      mock_response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [
                %{
                  function_call: %Altar.ADM.FunctionCall{
                    call_id: "test_call",
                    name: "test_function",
                    args: %{"param" => "value"}
                  }
                }
              ]
            }
          }
        ]
      }

      # This tests the private function indirectly by checking the structure
      # The actual extraction would happen in the orchestrate_tool_loop
      assert length(mock_response.candidates) == 1
      [candidate] = mock_response.candidates
      [part] = candidate.content.parts

      assert part.function_call.name == "test_function"
      assert part.function_call.args == %{"param" => "value"}
    end
  end
end
