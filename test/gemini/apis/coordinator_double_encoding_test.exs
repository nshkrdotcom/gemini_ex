defmodule Gemini.APIs.CoordinatorDoubleEncodingTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{Content, Part, Blob}

  # Helper to normalize input
  defp normalize_test_input(input) do
    Gemini.APIs.Coordinator.__test_normalize_content__(input)
  end

  @moduledoc """
  Tests to expose and verify the fix for Issue #11 comment:
  Double-encoding bug where data gets base64'd twice.

  User @jaimeiniesta reported:
  "I had to pass the raw data, without encoding it as Base64"
  "Maybe you're also encoding it? Then it's a bit confusing as it gets double-encoded"
  """

  describe "FIXED: base64 data now handled correctly" do
    test "base64 data stays base64 (no double-encoding)" do
      # Create a simple PNG header (raw bytes)
      raw_image_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00>>

      # User follows the documentation and encodes it
      base64_encoded = Base.encode64(raw_image_data)

      # Pass it as the docs suggest: with Base.encode64()
      input = %{
        type: "image",
        source: %{type: "base64", data: base64_encoded, mime_type: "image/png"}
      }

      # Normalize through the coordinator
      result = normalize_test_input(input)

      # Extract the blob data
      assert %Content{parts: [%Part{inline_data: blob}]} = result
      blob_data = blob.data

      # FIXED: The blob data should be the SAME as what we passed (already base64)
      assert blob_data == base64_encoded, """
      Base64 data should stay as-is!

      Expected: #{base64_encoded}
      Got:      #{blob_data}
      """

      # Verify decoding once gives raw data (not a base64 string)
      decoded = Base.decode64!(blob_data)
      assert decoded == raw_image_data, "Decoding once should give raw data"
    end

    test "type='base64' means data IS base64-encoded" do
      raw_image_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00>>
      base64_data = Base.encode64(raw_image_data)

      # User passes base64-encoded data
      input = %{
        type: "image",
        source: %{type: "base64", data: base64_data, mime_type: "image/png"}
      }

      result = normalize_test_input(input)
      assert %Content{parts: [%Part{inline_data: blob}]} = result

      # The data should remain unchanged
      assert blob.data == base64_data

      # And decoding should give us the original raw data
      assert Base.decode64!(blob.data) == raw_image_data
    end

    test "Part.inline_data causes double-encoding" do
      # Direct usage of Part.inline_data
      raw_data = "Hello World"
      base64_data = Base.encode64(raw_data)

      # User might reasonably do this:
      part = Part.inline_data(base64_data, "text/plain")

      # But the data gets encoded AGAIN
      assert part.inline_data.data == Base.encode64(base64_data)
      refute part.inline_data.data == base64_data

      # Proof of double-encoding:
      # First decode gets base64
      assert Base.decode64!(part.inline_data.data) == base64_data
      # Second decode gets raw
      assert Base.decode64!(Base.decode64!(part.inline_data.data)) == raw_data
    end

    test "Blob.new always encodes" do
      # Blob.new always calls Base.encode64
      raw = "test"
      already_encoded = Base.encode64(raw)

      blob1 = Blob.new(raw, "text/plain")
      blob2 = Blob.new(already_encoded, "text/plain")

      # blob1 is correctly encoded
      assert blob1.data == already_encoded

      # blob2 is DOUBLE-encoded (this is the bug!)
      assert blob2.data == Base.encode64(already_encoded)
      refute blob2.data == already_encoded
    end
  end

  describe "expected behavior after fix" do
    @tag :skip
    test "FUTURE: API should accept base64 when type is 'base64'" do
      raw_image_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      base64_encoded = Base.encode64(raw_image_data)

      # This SHOULD work: when type is "base64", data should be treated as already encoded
      input = %{
        type: "image",
        source: %{type: "base64", data: base64_encoded, mime_type: "image/png"}
      }

      result = normalize_test_input(input)
      assert %Content{parts: [%Part{inline_data: blob}]} = result

      # After fix: the data should stay as base64 (not double-encoded)
      assert blob.data == base64_encoded
    end

    @tag :skip
    test "FUTURE: API should also accept raw data when type is 'raw' or 'binary'" do
      raw_image_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>

      # This could be an alternative API
      input = %{
        type: "image",
        source: %{type: "raw", data: raw_image_data, mime_type: "image/png"}
      }

      result = normalize_test_input(input)
      assert %Content{parts: [%Part{inline_data: blob}]} = result

      # The library would encode raw data
      assert blob.data == Base.encode64(raw_image_data)
    end
  end
end
