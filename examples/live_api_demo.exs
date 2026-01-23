#!/usr/bin/env elixir
# Live API Demo
# Run with: mix run examples/live_api_demo.exs
#
# This example demonstrates basic Live API usage for text-based
# real-time conversations with Gemini models.

alias Gemini.Live.Session

IO.puts("=== Live API Demo ===\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("Error: GEMINI_API_KEY environment variable not set")
    IO.puts("Please set your API key: export GEMINI_API_KEY=your_key")
    System.halt(1)

  _ ->
    IO.puts("[OK] API key found")
end

# Message handler - receives all server messages
handler = fn
  %{setup_complete: _} ->
    IO.puts("[Setup complete - session ready]")

  %{server_content: content} when not is_nil(content) ->
    # Extract text from server content
    if text = Gemini.Types.Live.ServerContent.extract_text(content) do
      IO.write(text)
    end

    # Notify when turn is complete
    if content.turn_complete do
      IO.puts("\n[Turn complete]")
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

IO.puts("\nStarting Live API session...")

# Start session
{:ok, session} =
  Session.start_link(
    model: "gemini-2.5-flash-native-audio-preview-12-2025",
    auth: :gemini,
    generation_config: %{response_modalities: ["TEXT"]},
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

# Send first message
prompt1 = "What is 2 + 2? Please answer in one word."
IO.puts(">>> Sending: #{prompt1}\n")
:ok = Session.send_client_content(session, prompt1)

# Wait for response
Process.sleep(3000)

# Send a follow-up message
prompt2 = "Now multiply that result by 10."
IO.puts("\n>>> Sending: #{prompt2}\n")
:ok = Session.send_client_content(session, prompt2)

# Wait for response
Process.sleep(3000)

# Send a more complex question
prompt3 = "Tell me a very short joke (one sentence)."
IO.puts("\n>>> Sending: #{prompt3}\n")
:ok = Session.send_client_content(session, prompt3)

# Wait for response
Process.sleep(5000)

# Check session status
status = Session.status(session)
IO.puts("\nSession status: #{status}")

# Clean up
IO.puts("\nClosing session...")
Session.close(session)

IO.puts("\n=== Demo complete ===")
