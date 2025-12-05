#!/usr/bin/env elixir

# Automatic Tool Calling Demo
# This example demonstrates the automatic tool execution feature

alias Gemini
alias Gemini.Tools
alias Altar.ADM

# Example tool functions
defmodule DemoTools do
  def get_weather(%{"location" => location}) do
    # Simulate weather API call
    %{
      location: location,
      temperature: Enum.random(15..30),
      condition: Enum.random(["sunny", "cloudy", "rainy", "partly cloudy"]),
      humidity: Enum.random(30..80),
      timestamp: DateTime.utc_now()
    }
  end

  def get_time(%{"timezone" => timezone}) do
    # Simulate time API call
    %{
      timezone: timezone,
      current_time: DateTime.utc_now() |> DateTime.to_string(),
      unix_timestamp: System.system_time(:second)
    }
  end

  def calculate(%{"operation" => op, "a" => a, "b" => b}) do
    result =
      case op do
        "add" -> a + b
        "subtract" -> a - b
        "multiply" -> a * b
        "divide" when b != 0 -> a / b
        "divide" -> {:error, "Division by zero"}
        _ -> {:error, "Unknown operation"}
      end

    %{
      operation: op,
      operand_a: a,
      operand_b: b,
      result: result
    }
  end
end

# Register tools
IO.puts("=== Registering Tools ===")

# Weather tool
{:ok, weather_declaration} =
  ADM.new_function_declaration(%{
    name: "get_weather",
    description: "Gets current weather information for a specified location",
    parameters: %{
      type: "object",
      properties: %{
        location: %{
          type: "string",
          description: "The location to get weather for (e.g., 'San Francisco', 'London')"
        }
      },
      required: ["location"]
    }
  })

:ok = Tools.register(weather_declaration, &DemoTools.get_weather/1)
IO.puts("✅ Registered weather tool")

# Time tool
{:ok, time_declaration} =
  ADM.new_function_declaration(%{
    name: "get_time",
    description: "Gets current time for a specified timezone",
    parameters: %{
      type: "object",
      properties: %{
        timezone: %{
          type: "string",
          description: "The timezone to get time for (e.g., 'UTC', 'America/New_York')"
        }
      },
      required: ["timezone"]
    }
  })

:ok = Tools.register(time_declaration, &DemoTools.get_time/1)
IO.puts("✅ Registered time tool")

# Calculator tool
{:ok, calc_declaration} =
  ADM.new_function_declaration(%{
    name: "calculate",
    description: "Performs basic mathematical calculations",
    parameters: %{
      type: "object",
      properties: %{
        operation: %{
          type: "string",
          description: "The operation to perform",
          enum: ["add", "subtract", "multiply", "divide"]
        },
        a: %{
          type: "number",
          description: "First operand"
        },
        b: %{
          type: "number",
          description: "Second operand"
        }
      },
      required: ["operation", "a", "b"]
    }
  })

:ok = Tools.register(calc_declaration, &DemoTools.calculate/1)
IO.puts("✅ Registered calculator tool")

IO.puts("\n=== Tool Declarations Ready ===")
IO.puts("Available tools:")
IO.puts("- get_weather: Gets weather for a location")
IO.puts("- get_time: Gets current time for a timezone")
IO.puts("- calculate: Performs basic math operations")

# Example usage (commented out since it requires API keys)
IO.puts("\n=== Example Usage (requires API key) ===")

example_code = """
# Standard automatic tool execution
{:ok, response} = Gemini.generate_content_with_auto_tools(
  "What's the weather like in Tokyo and what time is it there?",
  tools: [weather_declaration, time_declaration],
  model: Gemini.Config.default_model(),
  temperature: 0.1
)

case Gemini.extract_text(response) do
  {:ok, text} -> IO.puts("Response: \#{text}")
  {:error, reason} -> IO.puts("Error: \#{reason}")
end

# Streaming automatic tool execution
{:ok, stream_id} = Gemini.stream_generate_with_auto_tools(
  "Calculate 15 * 23 and then tell me the weather in the result city",
  tools: [calc_declaration, weather_declaration],
  model: Gemini.Config.default_model()
)

:ok = Gemini.subscribe_stream(stream_id)

# Handle streaming events
receive do
  {:stream_event, ^stream_id, event} ->
    IO.inspect(event, label: "Stream Event")
  {:stream_complete, ^stream_id} ->
    IO.puts("Stream completed")
  {:stream_error, ^stream_id, error} ->
    IO.puts("Stream error: \#{inspect(error)}")
end
"""

IO.puts(example_code)

IO.puts("\n=== Demo Complete ===")
IO.puts("The automatic tool calling system is ready!")
IO.puts("Set your GEMINI_API_KEY environment variable and uncomment the example code to test.")
