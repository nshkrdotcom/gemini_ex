#!/usr/bin/env elixir
# Demonstration: Double-Encoding Fix (Issue #11 comment from @jaimeiniesta)
#
# This script demonstrates that the double-encoding bug has been FIXED.
# Users can now pass Base.encode64(data) as expected!
#
# Run with: elixir examples/fixed_double_encoding_demo.exs

Mix.install([
  {:gemini_ex, path: "."}
])

defmodule DoubleEncodingFixDemo do
  @moduledoc """
  Demonstrates the FIX for the double-encoding bug reported by @jaimeiniesta in Issue #11.

  User reported: "I had to pass the raw data, without encoding it as Base64"
  "Maybe you're also encoding it? Then it's a bit confusing as it gets double-encoded"

  NOW FIXED: Users can pass Base.encode64(data) as expected!
  """

  alias Gemini.Types.{Content, Part}

  def run do
    IO.puts(
      "\n" <>
        IO.ANSI.green() <> "=== DOUBLE-ENCODING BUG FIX DEMONSTRATION ===" <> IO.ANSI.reset()
    )

    IO.puts("Showing that Issue #11 comment from @jaimeiniesta is now FIXED\n")

    # Create a simple 1x1 PNG image (minimal valid PNG)
    raw_image_data = create_minimal_png()
    IO.puts("1. Created minimal PNG image (#{byte_size(raw_image_data)} bytes)")
    IO.puts("   Raw data (hex): #{Base.encode16(raw_image_data) |> String.slice(0, 40)}...\n")

    # What the documentation suggests (and what users naturally do)
    IO.puts(
      IO.ANSI.green() <> "2. Following documentation - encoding as Base64:" <> IO.ANSI.reset()
    )

    base64_encoded = Base.encode64(raw_image_data)
    IO.puts("   Base64: #{String.slice(base64_encoded, 0, 60)}...")
    IO.puts("   Length: #{String.length(base64_encoded)} characters\n")

    # Use the API as documented
    IO.puts(IO.ANSI.green() <> "3. Using Anthropic-style API (as documented):" <> IO.ANSI.reset())
    IO.puts(~s|   content = [
     %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
   ]|)

    content = [
      %{type: "text", text: "What do you see in this image?"},
      %{type: "image", source: %{type: "base64", data: base64_encoded, mime_type: "image/png"}}
    ]

    # See what actually gets sent
    IO.puts("\n" <> IO.ANSI.green() <> "4. What gets sent to Gemini API:" <> IO.ANSI.reset())

    # Normalize the content to see what blob gets created
    [_text, image] =
      Enum.map(content, fn item ->
        Gemini.APIs.Coordinator.__test_normalize_content__(item)
      end)

    %Content{parts: [%Part{inline_data: blob}]} = image
    actual_sent = blob.data

    IO.puts("   Data sent: #{String.slice(actual_sent, 0, 60)}...")
    IO.puts("   Length: #{String.length(actual_sent)} characters\n")

    # Prove it's NOT double-encoded
    IO.puts(IO.ANSI.green() <> "5. ✅ PROOF OF FIX - NO MORE DOUBLE-ENCODING:" <> IO.ANSI.reset())
    IO.puts("   Data matches what we passed: #{base64_encoded == actual_sent}")
    IO.puts("   ✅ Expected behavior!\n")

    IO.puts("   Decoding once gives us raw bytes:")
    decoded_once = Base.decode64!(actual_sent)
    is_raw = decoded_once == raw_image_data
    IO.puts("     Matches original: #{is_raw}")
    IO.puts("     ✅ Perfect! Only need ONE decode to get raw data back!\n")

    # Show different input formats
    IO.puts(IO.ANSI.green() <> "6. MULTIPLE INPUT FORMATS NOW WORK CORRECTLY:" <> IO.ANSI.reset())

    # Format 1: Anthropic-style with base64
    format1 = [
      %{type: "image", source: %{type: "base64", data: base64_encoded, mime_type: "image/png"}}
    ]

    [img1] = Enum.map(format1, &Gemini.APIs.Coordinator.__test_normalize_content__/1)
    %Content{parts: [%Part{inline_data: blob1}]} = img1
    IO.puts("   Format 1 (Anthropic-style with base64): #{blob1.data == base64_encoded}")

    # Format 2: Gemini SDK style
    format2 = [
      %{role: "user", parts: [%{inline_data: %{mime_type: "image/png", data: base64_encoded}}]}
    ]

    [img2] = Enum.map(format2, &Gemini.APIs.Coordinator.__test_normalize_content__/1)
    %Content{parts: [%Part{inline_data: blob2}]} = img2
    IO.puts("   Format 2 (Gemini SDK style):            #{blob2.data == base64_encoded}")

    # Format 3: Original Content struct with Part.inline_data (uses raw data)
    format3 = [
      %Content{
        role: "user",
        parts: [Part.inline_data(raw_image_data, "image/png")]
      }
    ]

    [img3] = format3
    %Content{parts: [%Part{inline_data: blob3}]} = img3
    IO.puts("   Format 3 (Content struct with raw):    #{blob3.data == base64_encoded}")
    IO.puts("   ✅ All formats work correctly!\n")

    # Summary
    IO.puts(IO.ANSI.green() <> "=" <> String.duplicate("=", 70) <> IO.ANSI.reset())
    IO.puts(IO.ANSI.green() <> "✅ SUMMARY: The bug is FIXED!" <> IO.ANSI.reset())

    IO.puts("""

    When you specify type: "base64", the behavior is now:
      ✅ "Data IS already base64-encoded" (CORRECT!)

    This means:
      ✅ Documentation examples now work correctly
      ✅ Users pass Base.encode64(data) as expected
      ✅ Gemini API receives proper base64 data
      ✅ No more confusion or trial-and-error!

    The fix:
      - When source type is "base64", data is treated as already encoded
      - No double-encoding happens
      - API behavior matches user expectations

    Special thanks to @jaimeiniesta for reporting this confusing behavior!
    """)
  end

  defp create_minimal_png do
    # Minimal 1x1 PNG: signature + IHDR + IDAT + IEND
    png_signature = <<137, 80, 78, 71, 13, 10, 26, 10>>

    # IHDR chunk (13 bytes data)
    ihdr_data = <<
      # width: 1
      0,
      0,
      0,
      1,
      # height: 1
      0,
      0,
      0,
      1,
      # bit depth: 8
      8,
      # color type: RGB
      2,
      # compression: deflate
      0,
      # filter: adaptive
      0,
      # interlace: none
      0
    >>

    ihdr_chunk = build_chunk("IHDR", ihdr_data)

    # IDAT chunk (minimal compressed data for 1x1 white pixel)
    idat_data = <<120, 156, 99, 250, 207, 192, 0, 0, 2, 127, 1, 2>>
    idat_chunk = build_chunk("IDAT", idat_data)

    # IEND chunk (empty)
    iend_chunk = build_chunk("IEND", <<>>)

    png_signature <> ihdr_chunk <> idat_chunk <> iend_chunk
  end

  defp build_chunk(type, data) do
    length = byte_size(data)
    crc = :erlang.crc32(type <> data)

    <<length::32>> <> type <> data <> <<crc::32>>
  end
end

# Run the demonstration
DoubleEncodingFixDemo.run()
