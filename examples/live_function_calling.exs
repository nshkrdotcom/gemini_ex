#!/usr/bin/env elixir
# Live API Function Calling Demo
# Run with: mix run examples/live_function_calling.exs
#
# This example demonstrates function calling (tool use) with the Live API.
# The model can request to call functions, and we respond with results.

alias Gemini.Live.Session

IO.puts("=== Live API Function Calling Demo ===\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("Error: GEMINI_API_KEY environment variable not set")
    IO.puts("Please set your API key: export GEMINI_API_KEY=your_key")
    System.halt(1)

  _ ->
    IO.puts("[OK] API key found")
end

# Define our tools
tools = [
  %{
    function_declarations: [
      %{
        name: "get_weather",
        description: "Get current weather information for a location",
        parameters: %{
          type: "object",
          properties: %{
            location: %{
              type: "string",
              description: "The city name (e.g., 'Tokyo', 'San Francisco')"
            }
          },
          required: ["location"]
        }
      },
      %{
        name: "calculate",
        description: "Perform a mathematical calculation",
        parameters: %{
          type: "object",
          properties: %{
            operation: %{
              type: "string",
              enum: ["add", "subtract", "multiply", "divide"],
              description: "The mathematical operation"
            },
            a: %{type: "number", description: "First operand"},
            b: %{type: "number", description: "Second operand"}
          },
          required: ["operation", "a", "b"]
        }
      }
    ]
  }
]

# Mock function implementations
defmodule DemoFunctions do
  def get_weather(location) do
    # Simulated weather data
    weather_data = %{
      "Tokyo" => %{temp: 18, condition: "Cloudy", humidity: 65},
      "San Francisco" => %{temp: 15, condition: "Foggy", humidity: 80},
      "Paris" => %{temp: 12, condition: "Rainy", humidity: 75},
      "Sydney" => %{temp: 25, condition: "Sunny", humidity: 55}
    }

    case Map.get(weather_data, location) do
      nil ->
        %{temperature: 20, condition: "Unknown", humidity: 60, note: "City not in database"}

      data ->
        %{temperature: data.temp, condition: data.condition, humidity: data.humidity}
    end
  end

  def calculate(operation, a, b) do
    result =
      case operation do
        "add" -> a + b
        "subtract" -> a - b
        "multiply" -> a * b
        "divide" when b != 0 -> a / b
        "divide" -> {:error, "Division by zero"}
        _ -> {:error, "Unknown operation"}
      end

    %{operation: operation, a: a, b: b, result: result}
  end
end

# We need to store the session PID to use it in the tool call handler
# Using Process dictionary for simplicity in this demo
Process.put(:session_pid, nil)

# Tool call handler
tool_handler = fn %{function_calls: calls} ->
  IO.puts("\n[Tool calls received]")

  session = Process.get(:session_pid)

  responses =
    Enum.map(calls, fn call ->
      IO.puts("  Executing: #{call.name}")
      IO.puts("  Args: #{inspect(call.args)}")

      result =
        case call.name do
          "get_weather" ->
            location = call.args["location"] || call.args[:location]
            DemoFunctions.get_weather(location)

          "calculate" ->
            args = call.args
            operation = args["operation"] || args[:operation]
            a = args["a"] || args[:a]
            b = args["b"] || args[:b]
            DemoFunctions.calculate(operation, a, b)

          _ ->
            %{error: "Unknown function: #{call.name}"}
        end

      IO.puts("  Result: #{inspect(result)}")

      %{
        id: call.id,
        name: call.name,
        response: result
      }
    end)

  # Send the responses back
  IO.puts("[Sending tool responses]")
  Session.send_tool_response(session, responses)
end

# Message handler
message_handler = fn
  %{setup_complete: _} ->
    IO.puts("[Setup complete]")

  %{server_content: content} when not is_nil(content) ->
    if text = Gemini.Types.Live.ServerContent.extract_text(content) do
      IO.write(text)
    end

    if content.turn_complete do
      IO.puts("\n[Turn complete]")
    end

  %{tool_call: _tc} ->
    # Tool calls are handled by on_tool_call callback
    :ok

  _ ->
    :ok
end

IO.puts("\nStarting Live API session with tools...")

# Start session
{:ok, session} =
  Session.start_link(
    model: "gemini-2.5-flash-native-audio-preview-12-2025",
    auth: :gemini,
    generation_config: %{response_modalities: ["TEXT"]},
    tools: tools,
    on_message: message_handler,
    on_tool_call: tool_handler,
    on_error: fn err -> IO.puts("\n[Error: #{inspect(err)}]") end
  )

# Store session PID for tool handler
Process.put(:session_pid, session)

IO.puts("[OK] Session started")

# Connect
IO.puts("Connecting...")

case Session.connect(session) do
  :ok ->
    IO.puts("[OK] Connected\n")

  {:error, reason} ->
    IO.puts("[Error] Connection failed: #{inspect(reason)}")
    System.halt(1)
end

Process.sleep(500)

# Test 1: Weather query
prompt1 = "What's the weather like in Tokyo?"
IO.puts(">>> Sending: #{prompt1}\n")
:ok = Session.send_client_content(session, prompt1)
Process.sleep(8000)

# Test 2: Calculation
prompt2 = "Please calculate 42 multiplied by 17."
IO.puts("\n>>> Sending: #{prompt2}\n")
:ok = Session.send_client_content(session, prompt2)
Process.sleep(8000)

# Test 3: Multiple tool calls
prompt3 = "What's the weather in Paris, and what's 100 divided by 4?"
IO.puts("\n>>> Sending: #{prompt3}\n")
:ok = Session.send_client_content(session, prompt3)
Process.sleep(10000)

# Clean up
IO.puts("\nClosing session...")
Session.close(session)

IO.puts("\n=== Demo complete ===")
