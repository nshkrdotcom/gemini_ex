defmodule Gemini.APIs.CoordinatorMultimodalTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{Content, Part}

  # Test the normalization by calling the private functions via a wrapper
  # We test the logic without making real API calls

  describe "multimodal content - flexible input formats" do
    test "normalizes Anthropic-style text map to Content struct" do
      input = %{type: "text", text: "Hello world"}

      # This should not raise and should create proper Content
      assert %Content{role: "user", parts: [%Part{text: "Hello world"}]} =
               normalize_test_input(input)
    end

    test "normalizes Anthropic-style image map with explicit MIME type" do
      # User provides already base64-encoded data
      input = %{
        type: "image",
        source: %{type: "base64", data: "base64data", mime_type: "image/png"}
      }

      result = normalize_test_input(input)
      assert %Content{role: "user", parts: [%Part{inline_data: blob}]} = result
      assert blob.mime_type == "image/png"
      # FIXED: When type is "base64", data is treated as already encoded
      # So "base64data" stays as "base64data" (no double-encoding)
      assert blob.data == "base64data"
    end

    test "normalizes image with auto-detected PNG MIME type" do
      # PNG magic bytes
      png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      base64_png = Base.encode64(png_header)

      input = %{
        type: "image",
        source: %{type: "base64", data: base64_png}
      }

      result = normalize_test_input(input)
      assert %Content{parts: [%Part{inline_data: blob}]} = result
      assert blob.mime_type == "image/png"
    end

    test "normalizes image with auto-detected JPEG MIME type" do
      # JPEG magic bytes
      jpeg_header = <<0xFF, 0xD8, 0xFF, 0xE0>>
      base64_jpeg = Base.encode64(jpeg_header)

      input = %{
        type: "image",
        source: %{type: "base64", data: base64_jpeg}
      }

      result = normalize_test_input(input)
      assert %Content{parts: [%Part{inline_data: blob}]} = result
      assert blob.mime_type == "image/jpeg"
    end

    test "normalizes map with role and parts" do
      input = %{
        role: "user",
        parts: [
          %{text: "What is this?"},
          %{inline_data: %{mime_type: "image/png", data: "base64data"}}
        ]
      }

      result = normalize_test_input(input)
      assert %Content{role: "user", parts: parts} = result
      assert length(parts) == 2
      assert [%Part{text: "What is this?"}, %Part{inline_data: _}] = parts
    end

    test "normalizes simple string to Content" do
      result = normalize_test_input("Hello world")
      assert %Content{role: "user", parts: [%Part{text: "Hello world"}]} = result
    end

    test "passes through Content struct unchanged" do
      content = %Content{
        role: "user",
        parts: [Part.text("Already a struct")]
      }

      result = normalize_test_input(content)
      assert result == content
    end

    test "raises helpful error for invalid format" do
      assert_raise ArgumentError, ~r/Invalid content format/, fn ->
        normalize_test_input(%{invalid: "format"})
      end
    end
  end

  describe "MIME type detection" do
    test "detects PNG" do
      png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      assert detect_mime_test(png_header) == "image/png"
    end

    test "detects JPEG" do
      jpeg_header = <<0xFF, 0xD8, 0xFF, 0xE0>>
      assert detect_mime_test(jpeg_header) == "image/jpeg"
    end

    test "detects GIF" do
      gif_header = <<0x47, 0x49, 0x46, 0x38, 0x39, 0x61>>
      assert detect_mime_test(gif_header) == "image/gif"
    end

    test "detects WebP" do
      webp_header = <<0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00>>
      assert detect_mime_test(webp_header) == "image/webp"
    end

    test "falls back to JPEG for unknown" do
      unknown = <<0x00, 0x00, 0x00, 0x00>>
      assert detect_mime_test(unknown) == "image/jpeg"
    end
  end

  describe "backward compatibility" do
    test "Content struct still works" do
      content = %Content{
        role: "user",
        parts: [Part.text("Hello")]
      }

      result = normalize_test_input(content)
      assert result == content
    end

    test "list of Content structs still works" do
      contents = [
        %Content{role: "user", parts: [Part.text("Hello")]},
        %Content{role: "model", parts: [Part.text("Hi")]}
      ]

      results = Enum.map(contents, &normalize_test_input/1)
      assert results == contents
    end
  end

  describe "mixed formats" do
    test "handles mixed Content structs and maps" do
      inputs = [
        %Content{role: "user", parts: [Part.text("First")]},
        %{type: "text", text: "Second"},
        %{role: "assistant", parts: [%{text: "Third"}]}
      ]

      results = Enum.map(inputs, &normalize_test_input/1)
      assert length(results) == 3
      assert Enum.all?(results, &match?(%Content{}, &1))
    end
  end

  describe "multiple images" do
    test "normalizes multiple images in one request" do
      png_data = Base.encode64(<<0x89, 0x50, 0x4E, 0x47>>)
      jpeg_data = Base.encode64(<<0xFF, 0xD8, 0xFF>>)

      inputs = [
        %{type: "text", text: "Compare these:"},
        %{type: "image", source: %{type: "base64", data: png_data, mime_type: "image/png"}},
        %{type: "image", source: %{type: "base64", data: jpeg_data, mime_type: "image/jpeg"}}
      ]

      results = Enum.map(inputs, &normalize_test_input/1)
      assert length(results) == 3

      # Count parts with inline_data
      image_count =
        results
        |> Enum.flat_map(& &1.parts)
        |> Enum.count(&(&1.inline_data != nil))

      assert image_count == 2
    end

    test "normalizes interleaved text and images" do
      png_data = Base.encode64(<<0x89, 0x50, 0x4E, 0x47>>)

      inputs = [
        %{type: "text", text: "First image:"},
        %{type: "image", source: %{type: "base64", data: png_data}},
        %{type: "text", text: "Second image:"},
        %{type: "image", source: %{type: "base64", data: png_data}}
      ]

      results = Enum.map(inputs, &normalize_test_input/1)
      assert length(results) == 4

      # Verify alternating pattern
      assert Enum.at(results, 0).parts |> hd() |> Map.get(:text) == "First image:"
      assert Enum.at(results, 1).parts |> hd() |> Map.get(:inline_data) != nil
      assert Enum.at(results, 2).parts |> hd() |> Map.get(:text) == "Second image:"
      assert Enum.at(results, 3).parts |> hd() |> Map.get(:inline_data) != nil
    end
  end

  # Helper functions to test private normalization logic
  # We use the actual implementation via the public API but inspect the structure

  defp normalize_test_input(input) do
    Gemini.APIs.Coordinator.__test_normalize_content__(input)
  end

  defp detect_mime_test(binary_data) do
    base64_data = Base.encode64(binary_data)
    Gemini.APIs.Coordinator.__test_detect_mime__(base64_data)
  end
end
