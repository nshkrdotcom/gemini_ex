#!/usr/bin/env elixir

# Tool Calling Demo
# This example demonstrates the deserialization and serialization of tool calling data

Mix.install([
  {:gemini_ex, path: "."},
  {:jason, "~> 1.4"}
])

alias Gemini.Generate
alias Gemini.Types.Content
alias Altar.ADM.ToolResult

# Example 1: Parsing a mock API response with function calls
IO.puts("=== Example 1: Parsing Function Calls ===")

mock_api_response = %{
  "candidates" => [
    %{
      "content" => %{
        "role" => "model",
        "parts" => [
          %{
            "text" => "I'll help you get the weather information."
          },
          %{
            "functionCall" => %{
              "name" => "get_weather",
              "args" => %{"location" => "San Francisco", "units" => "celsius"},
              "call_id" => "call_weather_123"
            }
          }
        ]
      },
      "finishReason" => "STOP"
    }
  ]
}

case Generate.parse_generate_response(mock_api_response) do
  {:ok, response} ->
    IO.puts("✅ Successfully parsed response!")

    [candidate] = response.candidates
    [text_part, function_part] = candidate.content.parts

    IO.puts("Text part: #{text_part.text}")
    IO.puts("Function call: #{function_part.function_call.name}")
    IO.puts("Arguments: #{inspect(function_part.function_call.args)}")
    IO.puts("Call ID: #{function_part.function_call.call_id}")

  {:error, error} ->
    IO.puts("❌ Error parsing response: #{error.message}")
end

IO.puts("\n=== Example 2: Creating Tool Results ===")

# Example 2: Creating tool results for function responses
{:ok, result1} = ToolResult.new(%{
  call_id: "call_weather_123",
  content: %{
    "temperature" => 22,
    "condition" => "sunny",
    "humidity" => 65,
    "location" => "San Francisco"
  },
  is_error: false
})

{:ok, result2} = ToolResult.new(%{
  call_id: "call_time_456",
  content: "2024-01-15 14:30:00 PST",
  is_error: false
})

tool_results = [result1, result2]

content = Content.from_tool_results(tool_results)

IO.puts("✅ Created tool response content!")
IO.puts("Role: #{content.role}")
IO.puts("Number of parts: #{length(content.parts)}")

# Show the JSON structure that would be sent to the API
json_structure = Jason.encode!(content, pretty: true)
IO.puts("JSON structure:")
IO.puts(json_structure)

IO.puts("\n=== Example 3: Error Handling ===")

# Example 3: Handling malformed function calls
malformed_response = %{
  "candidates" => [
    %{
      "content" => %{
        "role" => "model",
        "parts" => [
          %{
            "functionCall" => %{
              # Missing required "name" field
              "args" => %{"location" => "Paris"},
              "call_id" => "call_invalid"
            }
          }
        ]
      },
      "finishReason" => "STOP"
    }
  ]
}

case Generate.parse_generate_response(malformed_response) do
  {:ok, _response} ->
    IO.puts("❌ Should have failed!")

  {:error, error} ->
    IO.puts("✅ Correctly caught malformed function call!")
    IO.puts("Error: #{error.message}")
end

IO.puts("\n=== Demo Complete ===")
IO.puts("The tool calling deserialization and serialization is working correctly!")
