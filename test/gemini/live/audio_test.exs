defmodule Gemini.Live.AudioTest do
  @moduledoc """
  Unit tests for Gemini.Live.Audio.
  """

  use ExUnit.Case, async: true

  alias Gemini.Live.Audio

  describe "sample rates" do
    test "input_sample_rate returns 16000" do
      assert Audio.input_sample_rate() == 16_000
    end

    test "output_sample_rate returns 24000" do
      assert Audio.output_sample_rate() == 24_000
    end
  end

  describe "MIME types" do
    test "input_mime_type returns correct format" do
      assert Audio.input_mime_type() == "audio/pcm;rate=16000"
    end

    test "output_mime_type returns correct format" do
      assert Audio.output_mime_type() == "audio/pcm;rate=24000"
    end
  end

  describe "create_input_blob/2" do
    test "creates blob with raw data by default" do
      pcm_data = <<0, 1, 2, 3>>
      blob = Audio.create_input_blob(pcm_data)

      assert blob.data == pcm_data
      assert blob.mime_type == "audio/pcm;rate=16000"
    end

    test "creates blob with encoded data when encode: true" do
      pcm_data = <<0, 1, 2, 3>>
      blob = Audio.create_input_blob(pcm_data, encode: true)

      assert blob.data == Base.encode64(pcm_data)
      assert blob.mime_type == "audio/pcm;rate=16000"
    end

    test "returns map with correct keys" do
      blob = Audio.create_input_blob(<<0>>)

      assert Map.has_key?(blob, :data)
      assert Map.has_key?(blob, :mime_type)
    end
  end

  describe "decode_output/1" do
    test "decodes base64 data" do
      original = <<1, 2, 3, 4>>
      encoded = Base.encode64(original)

      assert Audio.decode_output(encoded) == original
    end

    test "raises on invalid base64" do
      assert_raise ArgumentError, fn ->
        Audio.decode_output("not valid base64!!!")
      end
    end
  end

  describe "decode_output_safe/1" do
    test "returns {:ok, data} for valid base64" do
      original = <<1, 2, 3, 4>>
      encoded = Base.encode64(original)

      assert {:ok, ^original} = Audio.decode_output_safe(encoded)
    end

    test "returns {:error, :invalid_base64} for invalid data" do
      assert {:error, :invalid_base64} = Audio.decode_output_safe("not valid base64!!!")
    end
  end

  describe "duration_ms/2" do
    test "calculates duration for input sample rate" do
      # 16000 samples/sec, 2 bytes/sample
      # 32000 bytes = 1 second = 1000ms
      pcm_data = :binary.copy(<<0, 0>>, 16_000)

      assert Audio.duration_ms(pcm_data) == 1000
    end

    test "calculates duration for output sample rate" do
      # 24000 samples/sec, 2 bytes/sample
      # 48000 bytes = 1 second = 1000ms
      pcm_data = :binary.copy(<<0, 0>>, 24_000)

      assert Audio.duration_ms(pcm_data, Audio.output_sample_rate()) == 1000
    end

    test "calculates duration for partial second" do
      # 8000 samples = 0.5 seconds at 16kHz = 500ms
      pcm_data = :binary.copy(<<0, 0>>, 8_000)

      assert Audio.duration_ms(pcm_data) == 500
    end
  end

  describe "bytes_for_duration/2" do
    test "calculates bytes for 1 second at input rate" do
      # 16000 samples/sec * 2 bytes/sample = 32000 bytes
      assert Audio.bytes_for_duration(1000) == 32_000
    end

    test "calculates bytes for 100ms at input rate" do
      # 1600 samples * 2 bytes/sample = 3200 bytes
      assert Audio.bytes_for_duration(100) == 3200
    end

    test "calculates bytes for output rate" do
      # 24000 samples/sec * 2 bytes/sample = 48000 bytes
      assert Audio.bytes_for_duration(1000, Audio.output_sample_rate()) == 48_000
    end
  end

  describe "chunk_audio/3" do
    test "splits audio into chunks" do
      # Create 200ms of audio (6400 bytes at 16kHz)
      pcm_data = :binary.copy(<<0, 0>>, 3200)

      # Split into 100ms chunks (3200 bytes each)
      chunks = Audio.chunk_audio(pcm_data, 100)

      assert length(chunks) == 2
      assert byte_size(hd(chunks)) == 3200
    end

    test "handles audio that doesn't divide evenly" do
      # Create 150ms of audio (4800 bytes at 16kHz)
      pcm_data = :binary.copy(<<0, 0>>, 2400)

      # Split into 100ms chunks
      chunks = Audio.chunk_audio(pcm_data, 100)

      assert length(chunks) == 2
      assert byte_size(hd(chunks)) == 3200
      assert byte_size(List.last(chunks)) == 1600
    end

    test "returns single chunk for small audio" do
      # Create 50ms of audio
      pcm_data = :binary.copy(<<0, 0>>, 800)

      # Try to split into 100ms chunks
      chunks = Audio.chunk_audio(pcm_data, 100)

      assert length(chunks) == 1
      assert hd(chunks) == pcm_data
    end

    test "returns empty list for empty data" do
      chunks = Audio.chunk_audio(<<>>, 100)

      assert chunks == []
    end
  end
end
