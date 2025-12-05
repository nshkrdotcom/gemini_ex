#!/usr/bin/env elixir

# Manual Tool Calling Demo
#
# This script demonstrates the complete manual tool-calling loop using the
# new Gemini.Tools and Gemini.Chat modules. It shows how to:
# 1. Register a tool with the LATER runtime
# 2. Create a chat session
# 3. Simulate the tool-calling conversation flow
# 4. Execute tools manually and manage chat history

defmodule ToolCallingDemo do
  alias Gemini.{Chat, Tools}
  alias Altar.ADM

  def run do
    IO.puts("🔧 Manual Tool Calling Demo")
    IO.puts("=" |> String.duplicate(50))

    # Step 1: Define and register a tool
    IO.puts("\n1. Registering a weather tool...")
    register_weather_tool()

    # Step 2: Create a chat session
    IO.puts("\n2. Creating a new chat session...")
    chat = Chat.new(model: Gemini.Config.default_model(), temperature: 0.1)
    IO.puts("   ✅ Chat session created")

    # Step 3: Add user message that should trigger tool calling
    IO.puts("\n3. Adding user message that requests weather...")
    user_message = "What's the weather like in San Francisco?"
    chat = Chat.add_turn(chat, "user", user_message)
    IO.puts("   📝 User: #{user_message}")

    # Step 4: Simulate the model's response with a function call
    IO.puts("\n4. Simulating model's function call response...")
    function_calls = create_mock_function_calls()
    chat = Chat.add_turn(chat, "model", function_calls)

    Enum.each(function_calls, fn call ->
      IO.puts("   🤖 Model wants to call: #{call.name}(#{inspect(call.args)})")
    end)

    # Step 5: Execute the function calls
    IO.puts("\n5. Executing function calls...")
    {:ok, tool_results} = Tools.execute_calls(function_calls)
    chat = Chat.add_turn(chat, "user", tool_results)

    Enum.each(tool_results, fn result ->
      if result.is_error do
        IO.puts("   ❌ Tool error: #{inspect(result.content)}")
      else
        IO.puts("   ✅ Tool result: #{inspect(result.content)}")
      end
    end)

    # Step 6: Show the final chat history structure
    IO.puts("\n6. Final chat history:")
    IO.puts("   📚 Total turns: #{length(chat.history)}")

    chat.history
    |> Enum.with_index(1)
    |> Enum.each(fn {turn, index} ->
      IO.puts("   #{index}. #{turn.role}: #{describe_turn_content(turn)}")
    end)

    IO.puts("\n🎉 Manual tool calling loop completed successfully!")
    IO.puts("\nIn a real application, you would now call Gemini.generate_content/2")
    IO.puts("with the complete chat history to get the model's final response.")
  end

  defp register_weather_tool do
    # Define the tool function
    weather_tool = fn %{"location" => location} ->
      # Simulate weather API call
      %{
        location: location,
        temperature: 72,
        condition: "Sunny",
        humidity: 45,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end

    # Create the function declaration
    {:ok, declaration} =
      ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Get current weather information for a specified location",
        parameters: %{
          type: "object",
          properties: %{
            location: %{
              type: "string",
              description: "The location to get weather for (e.g., 'San Francisco, CA')"
            }
          },
          required: ["location"]
        }
      })

    # Register the tool
    case Tools.register(declaration, weather_tool) do
      :ok ->
        IO.puts("   ✅ Weather tool registered successfully")

      {:error, reason} ->
        IO.puts("   ❌ Failed to register tool: #{inspect(reason)}")
    end
  end

  defp create_mock_function_calls do
    # Create a mock function call that the model would return
    {:ok, function_call} =
      ADM.new_function_call(%{
        call_id: "call_#{:rand.uniform(10000)}",
        name: "get_weather",
        args: %{"location" => "San Francisco, CA"}
      })

    [function_call]
  end

  defp describe_turn_content(%{parts: parts}) do
    cond do
      Enum.any?(parts, &Map.has_key?(&1, :text)) ->
        text_part = Enum.find(parts, &Map.has_key?(&1, :text))
        "\"#{String.slice(text_part.text, 0, 50)}...\""

      Enum.any?(parts, &Map.has_key?(&1, :function_call)) ->
        call_part = Enum.find(parts, &Map.has_key?(&1, :function_call))
        "function_call(#{call_part.function_call.name})"

      Enum.any?(parts, &Map.has_key?(&1, :function_response)) ->
        "function_response"

      true ->
        "#{length(parts)} parts"
    end
  end
end

# Run the demo
ToolCallingDemo.run()
