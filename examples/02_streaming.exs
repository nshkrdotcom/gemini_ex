# Streaming Generation Example
# Run with: mix run examples/02_streaming.exs
#
# Demonstrates:
# - Real-time streaming text generation
# - Stream event handling
# - Progressive text output

defmodule StreamingExample do
  def run do
    print_header("STREAMING TEXT GENERATION")

    check_auth!()

    demo_basic_streaming()
    demo_streaming_with_timing()

    print_footer()
  end

  # ============================================================
  # Demo 1: Basic Streaming
  # ============================================================
  defp demo_basic_streaming do
    print_section("1. Basic Streaming")

    prompt =
      "Write a short story (3 paragraphs) about a programmer who discovers their code has become sentient."

    IO.puts("PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")
    IO.puts("STREAMING RESPONSE:")
    IO.puts("")

    case Gemini.start_stream(prompt) do
      {:ok, stream_id} ->
        IO.puts("[Stream ID: #{stream_id}]")
        IO.puts("")

        # Subscribe to receive events
        :ok = Gemini.subscribe_stream(stream_id)

        # Listen for and display streaming chunks
        receive_stream_events()

      {:error, error} ->
        IO.puts("[ERROR] Failed to start stream: #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Streaming with Timing Information
  # ============================================================
  defp demo_streaming_with_timing do
    print_section("2. Streaming with Timing Analysis")

    prompt = "List 5 interesting facts about the Elixir programming language, one per line."

    IO.puts("PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    start_time = System.monotonic_time(:millisecond)

    case Gemini.start_stream(prompt) do
      {:ok, stream_id} ->
        :ok = Gemini.subscribe_stream(stream_id)

        IO.puts("STREAMING RESPONSE (with chunk timing):")
        IO.puts("")

        {chunk_count, total_chars} = receive_stream_events_with_timing(start_time, 0, 0)

        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        IO.puts("")
        IO.puts("STATISTICS:")
        IO.puts("  Total chunks received: #{chunk_count}")
        IO.puts("  Total characters: #{total_chars}")
        IO.puts("  Total time: #{duration}ms")

        if chunk_count > 0 do
          IO.puts("  Average time per chunk: #{div(duration, chunk_count)}ms")
        end

        IO.puts("")
        IO.puts("[OK] Streaming with timing complete")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Stream Event Handlers
  # ============================================================
  defp receive_stream_events do
    receive do
      {:stream_event, _stream_id, %{type: :data, data: data}} ->
        text = extract_text_from_chunk(data)

        if text && text != "" do
          IO.write(text)
        end

        receive_stream_events()

      {:stream_complete, _stream_id} ->
        IO.puts("")
        IO.puts("")
        IO.puts("[OK] Stream completed successfully")

      {:stream_error, _stream_id, error} ->
        IO.puts("")
        IO.puts("[ERROR] Stream error: #{inspect(error)}")
    after
      30_000 ->
        IO.puts("")
        IO.puts("[TIMEOUT] Stream timed out after 30 seconds")
    end
  end

  defp receive_stream_events_with_timing(start_time, chunk_count, total_chars) do
    receive do
      {:stream_event, _stream_id, %{type: :data, data: data}} ->
        text = extract_text_from_chunk(data)

        if text && text != "" do
          elapsed = System.monotonic_time(:millisecond) - start_time
          IO.write(text)
          # Print timing info for first few chunks
          if chunk_count < 3 do
            IO.write(" [#{elapsed}ms]")
          end

          receive_stream_events_with_timing(
            start_time,
            chunk_count + 1,
            total_chars + String.length(text)
          )
        else
          receive_stream_events_with_timing(start_time, chunk_count, total_chars)
        end

      {:stream_complete, _stream_id} ->
        IO.puts("")
        {chunk_count, total_chars}

      {:stream_error, _stream_id, error} ->
        IO.puts("")
        IO.puts("[ERROR] #{inspect(error)}")
        {chunk_count, total_chars}
    after
      30_000 ->
        IO.puts("")
        IO.puts("[TIMEOUT]")
        {chunk_count, total_chars}
    end
  end

  defp extract_text_from_chunk(%{"candidates" => [%{"content" => %{"parts" => parts}} | _]}) do
    parts
    |> Enum.find(&Map.has_key?(&1, "text"))
    |> case do
      %{"text" => text} -> text
      _ -> nil
    end
  end

  defp extract_text_from_chunk(_), do: nil

  # ============================================================
  # Helper Functions
  # ============================================================
  defp check_auth! do
    cond do
      System.get_env("GEMINI_API_KEY") ->
        key = System.get_env("GEMINI_API_KEY")
        masked = String.slice(key, 0, 4) <> "..." <> String.slice(key, -4, 4)
        IO.puts("AUTH: Using Gemini API Key (#{masked})")
        IO.puts("")

      System.get_env("VERTEX_JSON_FILE") || System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ->
        IO.puts("AUTH: Using Vertex AI / Application Default Credentials")
        IO.puts("")

      true ->
        IO.puts("[ERROR] No authentication configured!")
        IO.puts("Set GEMINI_API_KEY or VERTEX_JSON_FILE environment variable.")
        System.halt(1)
    end
  end

  defp print_header(title) do
    IO.puts("")
    IO.puts(String.duplicate("=", 70))
    IO.puts("  #{title}")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end

  defp print_section(title) do
    IO.puts(String.duplicate("-", 70))
    IO.puts(title)
    IO.puts(String.duplicate("-", 70))
    IO.puts("")
  end

  defp print_footer do
    IO.puts(String.duplicate("=", 70))
    IO.puts("  EXAMPLE COMPLETE")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end
end

StreamingExample.run()
