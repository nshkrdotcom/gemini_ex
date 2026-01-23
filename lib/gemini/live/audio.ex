defmodule Gemini.Live.Audio do
  @moduledoc """
  Audio utilities for Live API.

  Provides helper functions for working with audio data in the Live API.
  The Live API uses specific audio formats for input and output.

  ## Audio Formats

  - **Input:** 16-bit PCM, 16kHz, mono
  - **Output:** 16-bit PCM, 24kHz, mono

  ## Usage

      # Create an audio blob for sending
      blob = Audio.create_input_blob(pcm_data)
      Session.send_realtime_input(session, audio: blob)

      # Decode audio from server response
      pcm_data = Audio.decode_output(base64_data)

  ## Sample Rates

  The different sample rates for input and output mean that you may need
  to resample audio when recording from or playing to standard audio devices.

  - Input: 16kHz (16,000 samples per second)
  - Output: 24kHz (24,000 samples per second)
  """

  @input_sample_rate 16_000
  @output_sample_rate 24_000
  @input_mime_type "audio/pcm;rate=16000"
  @output_mime_type "audio/pcm;rate=24000"

  @type audio_blob :: %{
          data: binary() | String.t(),
          mime_type: String.t()
        }

  @doc """
  Returns the input sample rate (16kHz).

  The Live API expects input audio at 16kHz sample rate.

  ## Example

      Audio.input_sample_rate()
      #=> 16000
  """
  @spec input_sample_rate() :: pos_integer()
  def input_sample_rate, do: @input_sample_rate

  @doc """
  Returns the output sample rate (24kHz).

  The Live API returns audio at 24kHz sample rate.

  ## Example

      Audio.output_sample_rate()
      #=> 24000
  """
  @spec output_sample_rate() :: pos_integer()
  def output_sample_rate, do: @output_sample_rate

  @doc """
  Returns the expected input MIME type for audio.

  ## Example

      Audio.input_mime_type()
      #=> "audio/pcm;rate=16000"
  """
  @spec input_mime_type() :: String.t()
  def input_mime_type, do: @input_mime_type

  @doc """
  Returns the output MIME type for audio.

  ## Example

      Audio.output_mime_type()
      #=> "audio/pcm;rate=24000"
  """
  @spec output_mime_type() :: String.t()
  def output_mime_type, do: @output_mime_type

  @doc """
  Creates an audio blob for sending to the Live API.

  Takes raw PCM audio data (16-bit, 16kHz, mono) and returns
  a properly formatted blob for use with `Session.send_realtime_input/2`.

  ## Parameters

  - `pcm_data` - Raw PCM audio data as binary (16-bit, 16kHz, mono)
  - `opts` - Optional options:
    - `:encode` - Whether to base64 encode the data (default: false)

  ## Returns

  A map with `:data` and `:mime_type` keys suitable for the Live API.

  ## Examples

      # With raw binary data
      blob = Audio.create_input_blob(pcm_data)
      Session.send_realtime_input(session, audio: blob)

      # With pre-encoding (if you want to send encoded data)
      blob = Audio.create_input_blob(pcm_data, encode: true)
  """
  @spec create_input_blob(binary(), keyword()) :: audio_blob()
  def create_input_blob(pcm_data, opts \\ []) when is_binary(pcm_data) do
    data =
      if Keyword.get(opts, :encode, false) do
        Base.encode64(pcm_data)
      else
        pcm_data
      end

    %{
      data: data,
      mime_type: @input_mime_type
    }
  end

  @doc """
  Decodes audio data from a server response.

  The Live API returns audio data as base64-encoded strings.
  This function decodes them back to raw PCM data.

  ## Parameters

  - `base64_data` - Base64-encoded audio data from server response

  ## Returns

  Raw PCM audio data as binary (16-bit, 24kHz, mono).

  ## Example

      # From a server response part
      audio_data = response.server_content.model_turn.parts
        |> Enum.find(& &1.inline_data)
        |> Map.get(:inline_data)
        |> Map.get(:data)
        |> Audio.decode_output()
  """
  @spec decode_output(String.t()) :: binary()
  def decode_output(base64_data) when is_binary(base64_data) do
    Base.decode64!(base64_data)
  end

  @doc """
  Safely decodes audio data, returning an error tuple on failure.

  ## Parameters

  - `base64_data` - Base64-encoded audio data

  ## Returns

  - `{:ok, binary}` - Successfully decoded audio data
  - `{:error, reason}` - Decoding failed
  """
  @spec decode_output_safe(String.t()) :: {:ok, binary()} | {:error, term()}
  def decode_output_safe(base64_data) when is_binary(base64_data) do
    case Base.decode64(base64_data) do
      {:ok, data} -> {:ok, data}
      :error -> {:error, :invalid_base64}
    end
  end

  @doc """
  Calculates the duration of audio data in milliseconds.

  ## Parameters

  - `pcm_data` - Raw PCM audio data (16-bit samples)
  - `sample_rate` - Sample rate of the audio (default: input_sample_rate)

  ## Returns

  Duration in milliseconds as an integer.

  ## Example

      # Calculate duration of input audio
      duration_ms = Audio.duration_ms(pcm_data)

      # Calculate duration of output audio
      duration_ms = Audio.duration_ms(output_data, Audio.output_sample_rate())
  """
  @spec duration_ms(binary(), pos_integer()) :: non_neg_integer()
  def duration_ms(pcm_data, sample_rate \\ @input_sample_rate) when is_binary(pcm_data) do
    # 16-bit samples = 2 bytes per sample
    bytes_per_sample = 2
    num_samples = byte_size(pcm_data) / bytes_per_sample
    round(num_samples / sample_rate * 1000)
  end

  @doc """
  Calculates the byte size needed for a given duration of audio.

  ## Parameters

  - `duration_ms` - Duration in milliseconds
  - `sample_rate` - Sample rate (default: input_sample_rate)

  ## Returns

  Number of bytes needed for the given duration.

  ## Example

      # Get bytes needed for 100ms of input audio
      bytes = Audio.bytes_for_duration(100)
      #=> 3200  # (16000 samples/sec * 0.1 sec * 2 bytes/sample)
  """
  @spec bytes_for_duration(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def bytes_for_duration(duration_ms, sample_rate \\ @input_sample_rate) do
    bytes_per_sample = 2
    num_samples = sample_rate * duration_ms / 1000
    round(num_samples * bytes_per_sample)
  end

  @doc """
  Splits audio data into chunks of specified duration.

  Useful for streaming audio to the Live API in appropriately-sized chunks.

  ## Parameters

  - `pcm_data` - Raw PCM audio data
  - `chunk_duration_ms` - Duration of each chunk in milliseconds
  - `sample_rate` - Sample rate (default: input_sample_rate)

  ## Returns

  List of binary chunks, each containing audio for the specified duration.
  The last chunk may be shorter if the audio doesn't divide evenly.

  ## Example

      # Split audio into 100ms chunks for streaming
      chunks = Audio.chunk_audio(pcm_data, 100)
      Enum.each(chunks, fn chunk ->
        blob = Audio.create_input_blob(chunk)
        Session.send_realtime_input(session, audio: blob)
      end)
  """
  @spec chunk_audio(binary(), pos_integer(), pos_integer()) :: [binary()]
  def chunk_audio(pcm_data, chunk_duration_ms, sample_rate \\ @input_sample_rate)
      when is_binary(pcm_data) do
    chunk_size = bytes_for_duration(chunk_duration_ms, sample_rate)
    do_chunk_audio(pcm_data, chunk_size, [])
  end

  defp do_chunk_audio(<<>>, _chunk_size, acc), do: Enum.reverse(acc)

  defp do_chunk_audio(data, chunk_size, acc) when byte_size(data) < chunk_size do
    Enum.reverse([data | acc])
  end

  defp do_chunk_audio(data, chunk_size, acc) do
    <<chunk::binary-size(chunk_size), rest::binary>> = data
    do_chunk_audio(rest, chunk_size, [chunk | acc])
  end
end
