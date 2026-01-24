#!/usr/bin/env elixir
# Live API Session Resumption Demo
# Run with: mix run examples/13_live_session_resumption.exs
#
# Demonstrates session resumption - the ability to disconnect and
# reconnect to a Live API session while preserving conversation context.
#
# This is useful for:
# - Handling network interruptions gracefully
# - Switching between voice/text modes
# - Long-running conversations that may need reconnection
#
# MODEL NOTE: This example uses the canonical TEXT model from Google's docs:
#   gemini-live-2.5-flash-preview with response_modalities: ["TEXT"]
#
# If this model is not yet available, see examples/12_live_audio_streaming.exs
# for a working AUDIO example using flash_2_5_native_audio_preview_12_2025.

alias Gemini.Live.Models
alias Gemini.Live.Session

IO.puts("=== Live API Session Resumption Demo ===\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("Error: GEMINI_API_KEY environment variable not set")
    IO.puts("Please set your API key: export GEMINI_API_KEY=your_key")
    System.halt(1)

  _ ->
    IO.puts("[OK] API key found")
end

# Store session handle for resumption
Process.put(:session_handle, nil)

# Session resumption callback
resumption_handler = fn %{handle: handle, resumable: resumable} ->
  if resumable && handle do
    Process.put(:session_handle, handle)
    # Truncate for display
    display_handle = String.slice(handle, 0, 20) <> "..."
    IO.puts("[Session handle received: #{display_handle}]")
  end
end

# Message handler
handler = fn
  %{setup_complete: sc} when not is_nil(sc) ->
    IO.puts("[Setup complete]")

  %{server_content: content} when not is_nil(content) ->
    if text = Gemini.Types.Live.ServerContent.extract_text(content) do
      IO.write(text)
    end

    if content.turn_complete do
      IO.puts("\n[Turn complete]")
    end

  %{go_away: ga} when not is_nil(ga) ->
    IO.puts("\n[Warning: Session ending soon]")

  _ ->
    :ok
end

error_handler = fn error ->
  IO.puts("\n[Error: #{inspect(error)}]")
end

close_handler = fn reason ->
  IO.puts("[Session closed: #{inspect(reason)}]")
end

# ============================================
# Part 1: Initial Session
# ============================================
IO.puts("--- Part 1: Initial Session ---\n")
IO.puts("Starting initial session with resumption enabled...")

live_model = Models.resolve(:text)
IO.puts("[Using model: #{live_model}]")

{:ok, session1} =
  Session.start_link(
    model: live_model,
    auth: :gemini,
    generation_config: %{response_modalities: ["TEXT"]},
    # Enable session resumption
    session_resumption:
      %{
        # Handle can be transparent (server-generated) or custom
        # Using transparent for this demo
      },
    on_message: handler,
    on_error: error_handler,
    on_close: close_handler,
    on_session_resumption: resumption_handler
  )

IO.puts("[OK] Session started")

# Connect
case Session.connect(session1) do
  :ok ->
    IO.puts("[OK] Connected\n")

  {:error, reason} ->
    IO.puts("[Error] Connection failed: #{inspect(reason)}")
    System.halt(1)
end

Process.sleep(500)

# Establish context in first session
prompt1 =
  "Hello! I'm working on a secret project called 'Project Phoenix'. Please remember this name."

IO.puts(">>> #{prompt1}\n")
:ok = Session.send_client_content(session1, prompt1)
Process.sleep(5000)

prompt2 = "What project did I just mention?"
IO.puts("\n>>> #{prompt2}\n")
:ok = Session.send_client_content(session1, prompt2)
Process.sleep(5000)

# Get the session handle for resumption
saved_handle = Process.get(:session_handle) || Session.get_session_handle(session1)

if saved_handle do
  IO.puts("\n[Saved session handle for resumption]")
else
  IO.puts("\n[Warning: No session handle available - resumption may not work]")
end

# Close the first session
IO.puts("\nClosing first session...")
Session.close(session1)
Process.sleep(1000)

# ============================================
# Part 2: Resumed Session
# ============================================
IO.puts("\n--- Part 2: Resumed Session ---\n")

if saved_handle do
  IO.puts("Resuming session with saved handle...")

  # Start a new session with the saved handle
  {:ok, session2} =
    Session.start_link(
      model: live_model,
      auth: :gemini,
      generation_config: %{response_modalities: ["TEXT"]},
      # Provide the handle to resume
      resume_handle: saved_handle,
      session_resumption: %{},
      on_message: handler,
      on_error: error_handler,
      on_close: close_handler,
      on_session_resumption: resumption_handler
    )

  IO.puts("[OK] Resumed session started")

  case Session.connect(session2) do
    :ok ->
      IO.puts("[OK] Connected\n")

    {:error, reason} ->
      IO.puts("[Error] Resumption failed: #{inspect(reason)}")
      IO.puts("Note: Session resumption requires server support and valid handle.")
      System.halt(1)
  end

  Process.sleep(500)

  # Test if context was preserved
  prompt3 = "Do you remember what project I mentioned earlier? What was it called?"
  IO.puts(">>> Testing context preservation...")
  IO.puts(">>> #{prompt3}\n")
  :ok = Session.send_client_content(session2, prompt3)
  Process.sleep(5000)

  # Continue conversation
  prompt4 = "Great! Now tell me a fun fact about phoenixes in mythology."
  IO.puts("\n>>> #{prompt4}\n")
  :ok = Session.send_client_content(session2, prompt4)
  Process.sleep(5000)

  # Get new handle
  new_handle = Session.get_session_handle(session2)

  if new_handle do
    IO.puts("\n[New session handle available for future resumption]")
  end

  # Clean up
  IO.puts("\nClosing resumed session...")
  Session.close(session2)
else
  IO.puts("Skipping resumption test - no handle available from first session.")
  IO.puts("Session resumption requires server support for the handle mechanism.")
end

IO.puts("\n=== Demo complete ===")

IO.puts("""

Session Resumption Notes:
- Enable with `session_resumption: %{}` in start_link options
- Save the handle from `on_session_resumption` callback
- Pass handle as `resume_handle:` when starting new session
- Context and conversation history are preserved across reconnections
- Handles have limited validity (typically ~10 minutes)
""")
