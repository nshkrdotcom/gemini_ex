defmodule Gemini.AutoToolsTest do
  use ExUnit.Case, async: false

  alias Gemini
  alias Gemini.Tools
  alias Altar.ADM

  @moduletag :integration

  setup do
    # Define test tool functions
    weather_tool_fun = fn %{"location" => location} ->
      %{
        temperature: 22,
        condition: "sunny",
        location: location,
        timestamp: DateTime.utc_now()
      }
    end

    time_tool_fun = fn %{"timezone" => timezone} ->
      %{
        current_time: "2024-01-15 14:30:00",
        timezone: timezone,
        timestamp: DateTime.utc_now()
      }
    end

    # Create and register tool declarations
    {:ok, weather_declaration} =
      ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Gets current weather for a location",
        parameters: %{
          type: "object",
          properties: %{
            location: %{
              type: "string",
              description: "The location to get weather for"
            }
          },
          required: ["location"]
        }
      })

    {:ok, time_declaration} =
      ADM.new_function_declaration(%{
        name: "get_time",
        description: "Gets current time for a timezone",
        parameters: %{
          type: "object",
          properties: %{
            timezone: %{
              type: "string",
              description: "The timezone to get time for"
            }
          },
          required: ["timezone"]
        }
      })

    # Register the tools
    :ok = Tools.register(weather_declaration, weather_tool_fun)
    :ok = Tools.register(time_declaration, time_tool_fun)

    %{
      weather_declaration: weather_declaration,
      time_declaration: time_declaration,
      weather_tool_fun: weather_tool_fun,
      time_tool_fun: time_tool_fun
    }
  end

  @tag :skip
  test "standard automatic tool execution completes successfully", %{
    weather_declaration: weather_declaration
  } do
    # Test the standard (non-streaming) automatic tool execution
    result =
      Gemini.generate_content_with_auto_tools(
        "What's the weather like in San Francisco? Please use the get_weather tool.",
        tools: [weather_declaration],
        model: "gemini-1.5-flash",
        temperature: 0.1,
        turn_limit: 5
      )

    case result do
      {:ok, response} ->
        # Should receive a final text response
        assert %Gemini.Types.Response.GenerateContentResponse{} = response
        assert length(response.candidates) > 0

        # Extract text from the response
        case Gemini.extract_text(response) do
          {:ok, text} ->
            assert is_binary(text)
            assert String.length(text) > 0
            # The response should mention the weather information
            assert text =~ "San Francisco" or text =~ "weather" or text =~ "sunny"

          {:error, reason} ->
            flunk("Failed to extract text from response: #{reason}")
        end

      {:error, error} ->
        flunk("Automatic tool execution failed: #{inspect(error)}")
    end
  end

  @tag :skip
  test "turn limit prevents infinite loops", %{weather_declaration: weather_declaration} do
    # Test that the turn limit prevents infinite loops
    result =
      Gemini.generate_content_with_auto_tools(
        "Keep calling the weather tool repeatedly",
        tools: [weather_declaration],
        model: "gemini-1.5-flash",
        temperature: 0.1,
        turn_limit: 1
      )

    case result do
      {:error, %Gemini.Error{type: :turn_limit_exceeded}} ->
        # This is the expected behavior
        :ok

      {:ok, _response} ->
        # This is also acceptable if the model doesn't actually loop
        :ok

      {:error, error} ->
        flunk("Unexpected error: #{inspect(error)}")
    end
  end

  @tag :skip
  test "streaming automatic tool execution works correctly", %{
    weather_declaration: weather_declaration
  } do
    # Test the streaming automatic tool execution
    case Gemini.stream_generate_with_auto_tools(
           "What's the weather in New York? Use the get_weather tool.",
           tools: [weather_declaration],
           model: "gemini-1.5-flash",
           temperature: 0.1,
           turn_limit: 5
         ) do
      {:ok, stream_id} ->
        # Subscribe to the stream
        :ok = Gemini.subscribe_stream(stream_id)

        # Collect all stream events
        final_chunks = collect_stream_events(stream_id, [], 30_000)

        # Verify we received text chunks (not function call chunks)
        assert length(final_chunks) > 0

        # All chunks should be text data, no function calls should be visible to subscriber
        Enum.each(final_chunks, fn chunk ->
          case chunk do
            %{type: :data, data: data} ->
              # Verify this is text data, not function call data
              refute has_function_calls?(data)

            _ ->
              :ok
          end
        end)

        # Combine all text chunks
        combined_text =
          final_chunks
          |> Enum.filter(&match?(%{type: :data}, &1))
          |> Enum.map_join("", fn %{data: data} ->
            extract_text_from_chunk(data)
          end)

        assert String.length(combined_text) > 0
        # The response should mention the weather information
        assert combined_text =~ "New York" or combined_text =~ "weather" or
                 combined_text =~ "sunny"

      {:error, error} ->
        flunk("Failed to start streaming: #{inspect(error)}")
    end
  end

  @tag :skip
  test "multiple tool calls in sequence work correctly", %{
    weather_declaration: weather_declaration,
    time_declaration: time_declaration
  } do
    # Test multiple tool calls in a single automatic execution
    result =
      Gemini.generate_content_with_auto_tools(
        "What's the weather in London and what time is it there? Use both the get_weather and get_time tools.",
        tools: [weather_declaration, time_declaration],
        model: "gemini-1.5-flash",
        temperature: 0.1,
        turn_limit: 10
      )

    case result do
      {:ok, response} ->
        case Gemini.extract_text(response) do
          {:ok, text} ->
            assert is_binary(text)
            assert String.length(text) > 0
            # The response should mention both weather and time information
            assert text =~ "London"
            # Should contain information from both tools
            assert (text =~ "weather" or text =~ "sunny") and
                     (text =~ "time" or text =~ "14:30")

          {:error, reason} ->
            flunk("Failed to extract text from response: #{reason}")
        end

      {:error, error} ->
        flunk("Multiple tool execution failed: #{inspect(error)}")
    end
  end

  # Helper functions for tests

  defp collect_stream_events(stream_id, acc, timeout) do
    receive do
      {:stream_event, ^stream_id, event} ->
        collect_stream_events(stream_id, [event | acc], timeout)

      {:stream_complete, ^stream_id} ->
        Enum.reverse(acc)

      {:stream_error, ^stream_id, error} ->
        flunk("Stream error: #{inspect(error)}")
    after
      timeout ->
        flunk("Stream timeout after #{timeout}ms")
    end
  end

  defp has_function_calls?(%{"candidates" => candidates}) do
    candidates
    |> Enum.any?(fn candidate ->
      case candidate do
        %{"content" => %{"parts" => parts}} ->
          Enum.any?(parts, &Map.has_key?(&1, "functionCall"))

        _ ->
          false
      end
    end)
  end

  defp has_function_calls?(_), do: false

  defp extract_text_from_chunk(%{"candidates" => candidates}) do
    candidates
    |> Enum.flat_map(fn candidate ->
      case candidate do
        %{"content" => %{"parts" => parts}} ->
          parts
          |> Enum.filter(&Map.has_key?(&1, "text"))
          |> Enum.map(& &1["text"])

        _ ->
          []
      end
    end)
    |> Enum.join("")
  end

  defp extract_text_from_chunk(_), do: ""
end
