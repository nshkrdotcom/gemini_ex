defmodule Gemini.APIs.GenerateParsingTest do
  use ExUnit.Case, async: true

  alias Altar.ADM.{FunctionCall, ToolResult}
  alias Gemini.Error
  alias Gemini.Generate
  alias Gemini.Types.{Content, Part}
  alias Gemini.Types.Response.{Candidate, GenerateContentResponse}

  describe "parse_generate_response/1 with function calls" do
    test "parses valid functionCall in response" do
      response_data = %{
        "candidates" => [
          %{
            "content" => %{
              "role" => "model",
              "parts" => [
                %{
                  "functionCall" => %{
                    "name" => "get_weather",
                    "args" => %{"location" => "San Francisco"},
                    "call_id" => "call_123"
                  }
                }
              ]
            },
            "finishReason" => "STOP"
          }
        ]
      }

      # Use the private function through a public interface
      # We'll test this by calling the main content function with a mock
      # For now, let's test the parsing logic directly by accessing the private function
      # In a real scenario, this would be tested through integration tests

      # Create a mock response that would come from the API
      result = Generate.parse_generate_response(response_data)

      assert {:ok, %GenerateContentResponse{candidates: [candidate]}} = result
      assert %Candidate{content: %Content{parts: [part]}} = candidate
      assert %Part{function_call: function_call} = part
      assert %FunctionCall{name: "get_weather", call_id: "call_123"} = function_call
      assert function_call.args == %{"location" => "San Francisco"}
    end

    test "returns error for malformed functionCall" do
      response_data = %{
        "candidates" => [
          %{
            "content" => %{
              "role" => "model",
              "parts" => [
                %{
                  "functionCall" => %{
                    # Missing required "name" field
                    "args" => %{"location" => "San Francisco"},
                    "call_id" => "call_123"
                  }
                }
              ]
            },
            "finishReason" => "STOP"
          }
        ]
      }

      result = Generate.parse_generate_response(response_data)

      assert {:error, %Error{type: :invalid_response, message: message}} = result
      assert String.contains?(message, "Model returned malformed FunctionCall")
      assert String.contains?(message, "missing required name")
    end

    test "parses mixed content with text and functionCall" do
      response_data = %{
        "candidates" => [
          %{
            "content" => %{
              "role" => "model",
              "parts" => [
                %{
                  "text" => "I'll check the weather for you."
                },
                %{
                  "functionCall" => %{
                    "name" => "get_weather",
                    "args" => %{"location" => "San Francisco"},
                    "call_id" => "call_123"
                  }
                }
              ]
            },
            "finishReason" => "STOP"
          }
        ]
      }

      result = Generate.parse_generate_response(response_data)

      assert {:ok, %GenerateContentResponse{candidates: [candidate]}} = result
      assert %Candidate{content: %Content{parts: [text_part, function_part]}} = candidate
      assert %Part{text: "I'll check the weather for you."} = text_part
      assert %Part{function_call: %FunctionCall{name: "get_weather"}} = function_part
    end
  end

  describe "Content.from_tool_results/1" do
    test "creates content with functionResponse parts" do
      results = [
        %ToolResult{
          call_id: "call_123",
          content: "The weather in San Francisco is sunny, 72°F",
          is_error: false
        },
        %ToolResult{
          call_id: "call_456",
          content: "The weather in New York is cloudy, 65°F",
          is_error: false
        }
      ]

      content = Content.from_tool_results(results)

      assert %Content{role: "tool", parts: parts} = content
      assert length(parts) == 2

      [part1, part2] = parts

      assert %{
               "functionResponse" => %{
                 "name" => "call_123",
                 "response" => %{"content" => "The weather in San Francisco is sunny, 72°F"}
               }
             } = part1

      assert %{
               "functionResponse" => %{
                 "name" => "call_456",
                 "response" => %{"content" => "The weather in New York is cloudy, 65°F"}
               }
             } = part2
    end

    test "handles error results" do
      results = [
        %ToolResult{
          call_id: "call_error",
          content: %{error: "API key invalid"},
          is_error: true
        }
      ]

      content = Content.from_tool_results(results)

      assert %Content{role: "tool", parts: [part]} = content

      assert %{
               "functionResponse" => %{
                 "name" => "call_error",
                 "response" => %{"content" => %{error: "API key invalid"}}
               }
             } = part
    end

    test "handles empty results list" do
      content = Content.from_tool_results([])

      assert %Content{role: "tool", parts: []} = content
    end

    test "preserves complex content structures" do
      results = [
        %ToolResult{
          call_id: "call_complex",
          content: %{
            "data" => [1, 2, 3],
            "metadata" => %{"source" => "api", "timestamp" => "2024-01-01"}
          },
          is_error: false
        }
      ]

      content = Content.from_tool_results(results)

      assert %Content{role: "tool", parts: [part]} = content

      assert %{
               "functionResponse" => %{
                 "name" => "call_complex",
                 "response" => %{
                   "content" => %{
                     "data" => [1, 2, 3],
                     "metadata" => %{"source" => "api", "timestamp" => "2024-01-01"}
                   }
                 }
               }
             } = part
    end
  end
end
