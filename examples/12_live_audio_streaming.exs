#!/usr/bin/env elixir
# Live API Audio Streaming Demo
# Run with: mix run examples/12_live_audio_streaming.exs
#
# Demonstrates sending and receiving audio with the Live API.
# Uses a real audio file (test/fixtures/audio/deepspeech.wav) for input.
# Saves received audio to /tmp/gemini_audio_response.pcm
#
# Audio formats:
# - Input:  16-bit PCM, 16kHz, mono (WAV file)
# - Output: 16-bit PCM, 24kHz, mono (saved to /tmp)
#
# To play the output: aplay -f S16_LE -r 24000 -c 1 /tmp/gemini_audio_response.pcm

alias Gemini.Live.Models
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

# Load real audio from WAV file
audio_file_path = Path.join([__DIR__, "..", "test", "fixtures", "audio", "deepspeech.wav"])

audio_pcm_data =
  case File.read(audio_file_path) do
    {:ok, wav_data} ->
      # Skip 44-byte WAV header to get raw PCM data
      <<_header::binary-size(44), pcm_data::binary>> = wav_data
      IO.puts("[OK] Loaded audio file: #{byte_size(pcm_data)} bytes of PCM data")
      pcm_data

    {:error, reason} ->
      IO.puts("[Error] Could not load audio file #{audio_file_path}: #{inspect(reason)}")
      System.halt(1)
  end

# Output file for received audio
output_audio_path = "/tmp/gemini_audio_response.pcm"
File.write!(output_audio_path, "")
IO.puts("[OK] Output audio will be saved to: #{output_audio_path}")

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

        if is_binary(mime_type) && String.contains?(mime_type, "audio") && is_binary(data) do
          # Decode base64 audio data and append to output file
          decoded = Base.decode64!(data)
          File.write!("/tmp/gemini_audio_response.pcm", decoded, [:append])
          AudioStats.record_received(byte_size(decoded))
          IO.write("[Audio: #{byte_size(decoded)} bytes] ")
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

# Start session configured for audio
audio_model = Models.resolve(:audio)
IO.puts("[Using model: #{audio_model}]")

# Native audio extras (affective dialog, proactivity, thinking) require v1alpha.
base_generation_config = %{response_modalities: ["AUDIO"]}

native_generation_config = %{
  response_modalities: ["AUDIO"],
  thinking_config: %{
    thinking_budget: 1024,
    include_thoughts: true
  }
}

base_opts = [
  model: audio_model,
  auth: :gemini,
  generation_config: base_generation_config,
  # Manual activity detection to allow explicit start/end signals
  realtime_input_config: %{automatic_activity_detection: %{disabled: true}},
  # Enable transcription so we can see what was "heard"
  input_audio_transcription: %{},
  output_audio_transcription: %{},
  on_message: handler,
  on_error: error_handler
]

native_opts =
  Keyword.merge(
    base_opts,
    api_version: "v1alpha",
    generation_config: native_generation_config,
    enable_affective_dialog: true,
    proactivity: %{proactive_audio: true}
  )

start_and_connect = fn opts ->
  case Session.start_link(opts) do
    {:ok, session} ->
      case Session.connect(session) do
        :ok ->
          {:ok, session}

        {:error, reason} ->
          GenServer.stop(session)
          {:error, reason}
      end

    {:error, reason} ->
      {:error, reason}
  end
end

IO.puts("Connecting to Live API...")

session_result =
  case start_and_connect.(native_opts) do
    {:ok, session} ->
      {:ok, session}

    {:error, {:setup_failed, {:closed, 1007, reason}}} = error ->
      if is_binary(reason) and String.contains?(reason, "Unknown name") do
        IO.puts("[Warning] Native audio extras not available; retrying with base audio setup.")

        start_and_connect.(base_opts)
      else
        error
      end

    {:error, reason} ->
      {:error, reason}
  end

session =
  case session_result do
    {:ok, session} ->
      IO.puts("[OK] Session started")
      IO.puts("[OK] Connected\n")
      session

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

# Demo 2: Send real audio input from WAV file
IO.puts("\n--- Demo 2: Real audio input (deepspeech.wav) ---")
IO.puts(">>> Sending audio from file...")

# Signal activity start (manual turn detection)
:ok = Session.send_realtime_input(session, activity_start: true)

# Send audio in chunks (3200 bytes = 100ms of 16kHz 16-bit mono audio)
chunk_size = 3200
chunks = for <<chunk::binary-size(chunk_size) <- audio_pcm_data>>, do: chunk

# Also get any remaining partial chunk
remaining_size = rem(byte_size(audio_pcm_data), chunk_size)

chunks =
  if remaining_size > 0 do
    last_chunk =
      binary_part(audio_pcm_data, byte_size(audio_pcm_data) - remaining_size, remaining_size)

    chunks ++ [last_chunk]
  else
    chunks
  end

IO.puts(">>> Sending #{length(chunks)} chunks...")

for chunk <- chunks do
  AudioStats.record_sent(byte_size(chunk))

  audio_blob = %{
    data: chunk,
    mime_type: "audio/pcm;rate=16000"
  }

  :ok = Session.send_realtime_input(session, audio: audio_blob)
  IO.write(".")
  Process.sleep(100)
end

IO.puts(" [#{length(chunks)} chunks sent]")

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

# Show output file info
output_size = File.stat!(output_audio_path).size

IO.puts("""

Audio saved to: #{output_audio_path}
Output file size: #{output_size} bytes

To play the response audio:
  aplay -f S16_LE -r 24000 -c 1 #{output_audio_path}

Or convert to WAV:
  sox -t raw -r 24000 -b 16 -c 1 -e signed-integer #{output_audio_path} /tmp/response.wav
""")
