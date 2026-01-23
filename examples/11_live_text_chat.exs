#!/usr/bin/env elixir
# Live API Text Chat Demo
# Run with: mix run examples/11_live_text_chat.exs
#
# Demonstrates a multi-turn text conversation using the Live API
# with streaming responses and conversation context.

alias Gemini.Live.Session

IO.puts("=== Live API Text Chat ===\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("Error: GEMINI_API_KEY environment variable not set")
    IO.puts("Please set your API key: export GEMINI_API_KEY=your_key")
    System.halt(1)

  _ ->
    IO.puts("[OK] API key found")
end

# Track response timing
Process.put(:response_start, nil)

# Message handler - receives all server messages
handler = fn
  %{setup_complete: _} ->
    IO.puts("[Setup complete - session ready]")

  %{server_content: content} when not is_nil(content) ->
    # Mark response start if not set
    if Process.get(:response_start) == nil do
      Process.put(:response_start, System.monotonic_time(:millisecond))
    end

    # Extract text from server content
    if text = Gemini.Types.Live.ServerContent.extract_text(content) do
      IO.write(text)
    end

    # Notify when turn is complete
    if content.turn_complete do
      start_time = Process.get(:response_start)
      elapsed = if start_time, do: System.monotonic_time(:millisecond) - start_time, else: 0
      Process.put(:response_start, nil)
      IO.puts("\n[Turn complete - #{elapsed}ms]")
    end

  %{go_away: go_away} when not is_nil(go_away) ->
    IO.puts("\n[Warning: Session ending soon - #{go_away.time_left}]")

  _ ->
    :ok
end

error_handler = fn error ->
  IO.puts("\n[Error: #{inspect(error)}]")
end

close_handler = fn reason ->
  IO.puts("\n[Session closed: #{inspect(reason)}]")
end

IO.puts("\nStarting Live API chat session...")

# Start session with text-only responses
{:ok, session} =
  Session.start_link(
    model: "gemini-2.5-flash-native-audio-preview-12-2025",
    auth: :gemini,
    generation_config: %{
      response_modalities: ["TEXT"],
      temperature: 0.7
    },
    system_instruction: """
    You are a helpful, friendly assistant. Keep your responses concise
    but informative. Remember context from the conversation.
    """,
    on_message: handler,
    on_error: error_handler,
    on_close: close_handler
  )

IO.puts("[OK] Session started")

# Connect to the Live API
IO.puts("Connecting to Live API...")

case Session.connect(session) do
  :ok ->
    IO.puts("[OK] Connected\n")

  {:error, reason} ->
    IO.puts("[Error] Connection failed: #{inspect(reason)}")
    System.halt(1)
end

# Give setup time to complete
Process.sleep(500)

# Conversation with context
conversations = [
  "Hi! My name is Alex, and I'm learning Elixir. What makes Elixir special?",
  "That sounds interesting! What about pattern matching? Can you give a simple example?",
  "Nice! By the way, do you remember my name?"
]

for {prompt, index} <- Enum.with_index(conversations, 1) do
  IO.puts("\n--- Turn #{index} ---")
  IO.puts(">>> #{prompt}\n")

  Process.put(:response_start, nil)
  :ok = Session.send_client_content(session, prompt)

  # Wait for response
  Process.sleep(5000)
end

# Check session status
status = Session.status(session)
IO.puts("\nSession status: #{status}")

# Clean up
IO.puts("\nClosing session...")
Session.close(session)

IO.puts("\n=== Demo complete ===")
