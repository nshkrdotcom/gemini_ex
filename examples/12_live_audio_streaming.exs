#!/usr/bin/env elixir
# Live API Audio Streaming Demo
# Run with: mix run examples/12_live_audio_streaming.exs
#
# Demonstrates sending and receiving audio with the Live API.
# This example uses simulated audio data for demonstration purposes.
#
# For real audio applications, you would:
# - Capture microphone input as 16-bit PCM, 16kHz mono
# - Send audio chunks in real-time
# - Play received audio (24kHz PCM output)

alias Gemini.Live.Session

IO.puts("=== Live API Audio Streaming Demo ===\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("Error: GEMINI_API_KEY environment variable not set")
    IO.puts("Please set your API key: export GEMINI_API_KEY=your_key")
    System.halt(1)

  _ ->
    IO.puts("[OK] API key found")
end

# Audio statistics
defmodule AudioStats do
  def init do
    Agent.start_link(
      fn ->
        %{audio_chunks_sent: 0, audio_chunks_received: 0, bytes_sent: 0, bytes_received: 0}
      end,
      name: __MODULE__
    )
  end

  def record_sent(bytes) do
    Agent.update(__MODULE__, fn stats ->
      %{
        stats
        | audio_chunks_sent: stats.audio_chunks_sent + 1,
          bytes_sent: stats.bytes_sent + bytes
      }
    end)
  end

  def record_received(bytes) do
    Agent.update(__MODULE__, fn stats ->
      %{
        stats
        | audio_chunks_received: stats.audio_chunks_received + 1,
          bytes_received: stats.bytes_received + bytes
      }
    end)
  end

  def get_stats do
    Agent.get(__MODULE__, & &1)
  end
end

AudioStats.init()

# Generate synthetic audio data (simulated PCM)
# In a real app, this would be actual microphone input
generate_audio_chunk = fn size ->
  # Generate random PCM-like data (16-bit samples)
  :crypto.strong_rand_bytes(size)
end

# Message handler
handler = fn
  %{setup_complete: sc} when not is_nil(sc) ->
    IO.puts("[Setup complete - audio session ready]")

  %{server_content: content} when not is_nil(content) ->
    # Handle audio output
    if content.model_turn && content.model_turn.parts do
      for part <- content.model_turn.parts do
        inline_data = Map.get(part, :inline_data) || Map.get(part, "inlineData")

        mime_type =
          inline_data && (Map.get(inline_data, :mime_type) || Map.get(inline_data, "mimeType"))

        data = inline_data && (Map.get(inline_data, :data) || Map.get(inline_data, "data"))

        if is_binary(mime_type) && String.contains?(mime_type, "audio") do
          bytes = if is_binary(data), do: byte_size(data), else: 0
          AudioStats.record_received(bytes)
          IO.write("[Audio chunk received: #{bytes} bytes] ")
        end

        text = Map.get(part, :text) || Map.get(part, "text")

        if text do
          IO.write(text)
        end
      end
    end

    # Handle transcription
    if content.input_transcription do
      IO.puts("\n[Input transcription: #{content.input_transcription.text}]")
    end

    if content.output_transcription do
      IO.puts("[Output transcription: #{content.output_transcription.text}]")
    end

    if content.turn_complete do
      IO.puts("\n[Turn complete]")
    end

  %{voice_activity: activity} when not is_nil(activity) ->
    if activity["state"] do
      IO.puts("[Voice activity: #{activity["state"]}]")
    end

  _ ->
    :ok
end

error_handler = fn error ->
  IO.puts("\n[Error: #{inspect(error)}]")
end

IO.puts("Starting Live API audio session...")
IO.puts("Note: Using simulated audio data for demo\n")

# Start session configured for audio
{:ok, session} =
  Session.start_link(
    model: "gemini-2.5-flash-native-audio-preview-12-2025",
    auth: :gemini,
    generation_config: %{
      # Request audio responses
      response_modalities: ["AUDIO"]
    },
    # Manual activity detection to allow explicit start/end signals
    realtime_input_config: %{automatic_activity_detection: %{disabled: true}},
    # Enable transcription so we can see what was "heard"
    input_audio_transcription: %{},
    output_audio_transcription: %{},
    on_message: handler,
    on_error: error_handler
  )

IO.puts("[OK] Session started")

# Connect
IO.puts("Connecting to Live API...")

case Session.connect(session) do
  :ok ->
    IO.puts("[OK] Connected\n")

  {:error, reason} ->
    IO.puts("[Error] Connection failed: #{inspect(reason)}")
    System.halt(1)
end

Process.sleep(500)

# Demo 1: Send text prompt first
IO.puts("--- Demo 1: Text prompt with audio response ---")
prompt = "Say hello in a friendly way!"
IO.puts(">>> Sending text: #{prompt}\n")
:ok = Session.send_client_content(session, prompt)
Process.sleep(5000)

# Demo 2: Simulate sending audio input
IO.puts("\n--- Demo 2: Simulated audio input ---")
IO.puts(">>> Sending simulated audio chunks...")

# Signal activity start (manual turn detection)
:ok = Session.send_realtime_input(session, activity_start: true)

# Send several audio chunks
for _i <- 1..5 do
  # 3200 bytes = 100ms of 16kHz 16-bit mono audio
  chunk = generate_audio_chunk.(3200)
  AudioStats.record_sent(3200)

  audio_blob = %{
    data: chunk,
    mime_type: "audio/pcm;rate=16000"
  }

  :ok = Session.send_realtime_input(session, audio: audio_blob)
  IO.write(".")
  Process.sleep(100)
end

IO.puts(" [#{5} chunks sent]")

# Signal activity end
:ok = Session.send_realtime_input(session, activity_end: true)

# Signal audio stream end
:ok = Session.send_realtime_input(session, audio_stream_end: true)

# Wait for response
IO.puts("Waiting for model response...")
Process.sleep(5000)

# Demo 3: Send text to get audio response
IO.puts("\n--- Demo 3: Text prompt expecting audio ---")
prompt2 = "Count from 1 to 3 slowly."
IO.puts(">>> #{prompt2}\n")
:ok = Session.send_client_content(session, prompt2)
Process.sleep(5000)

# Show statistics
stats = AudioStats.get_stats()
IO.puts("\n--- Audio Statistics ---")
IO.puts("Chunks sent: #{stats.audio_chunks_sent}")
IO.puts("Bytes sent: #{stats.bytes_sent}")
IO.puts("Chunks received: #{stats.audio_chunks_received}")
IO.puts("Bytes received: #{stats.bytes_received}")

# Check session status
status = Session.status(session)
IO.puts("\nSession status: #{status}")

# Clean up
IO.puts("\nClosing session...")
Session.close(session)

IO.puts("\n=== Demo complete ===")

IO.puts("""

Note: This demo uses simulated audio data. For real audio streaming:
- Input:  16-bit PCM, 16kHz sample rate, mono
- Output: 16-bit PCM, 24kHz sample rate, mono

See the documentation for integrating with real audio capture/playback.
""")
