defmodule Gemini.APIs.GenerateParsingTest do
  @moduledoc """
  Tests for Content helper functions related to tool calling.
  """
  use ExUnit.Case, async: true

  alias Altar.ADM.ToolResult
  alias Gemini.Types.Content

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
