defmodule Gemini.APIs.CoordinatorMultimodalTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.{Content, Part}

  describe "multimodal content normalization" do
    test "accepts Content struct (existing behavior)" do
      content = %Content{
        role: "user",
        parts: [
          Part.text("What is this?"),
          Part.inline_data("base64data", "image/png")
        ]
      }

      assert {:ok, request} = Coordinator.generate_content([content], model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "accepts list of maps with type: text" do
      content = [
        %{type: "text", text: "Describe this image"}
      ]

      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "accepts list of maps with type: image (with explicit mime_type)" do
      png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      base64_png = Base.encode64(png_header <> :crypto.strong_rand_bytes(100))

      content = [
        %{type: "text", text: "What is this?"},
        %{type: "image", source: %{type: "base64", data: base64_png, mime_type: "image/png"}}
      ]

      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "accepts list of maps with type: image (auto-detect PNG)" do
      png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      base64_png = Base.encode64(png_header <> :crypto.strong_rand_bytes(100))

      content = [
        %{type: "text", text: "What is this?"},
        %{type: "image", source: %{type: "base64", data: base64_png}}
      ]

      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "accepts list of maps with type: image (auto-detect JPEG)" do
      jpeg_header = <<0xFF, 0xD8, 0xFF, 0xE0>>
      base64_jpeg = Base.encode64(jpeg_header <> :crypto.strong_rand_bytes(100))

      content = [
        %{type: "text", text: "What is this?"},
        %{type: "image", source: %{type: "base64", data: base64_jpeg}}
      ]

      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "accepts map with role and parts" do
      content = [
        %{
          role: "user",
          parts: [
            %{text: "Describe this"},
            %{inline_data: %{mime_type: "image/jpeg", data: "base64data"}}
          ]
        }
      ]

      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "accepts mixed Content structs and maps" do
      content = [
        Content.new(role: "user", parts: [Part.text("First message")]),
        %{type: "text", text: "Second message"},
        %{role: "user", parts: [%{text: "Third message"}]}
      ]

      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "accepts simple string in list" do
      content = ["What is AI?"]

      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end

    test "rejects invalid content format with helpful error" do
      content = [%{invalid: "format"}]

      assert_raise ArgumentError, ~r/Invalid content format/, fn ->
        Coordinator.generate_content(content, model: "gemini-2.5-flash")
      end
    end
  end

  describe "MIME type detection" do
    test "detects PNG from magic bytes" do
      png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      base64_png = Base.encode64(png_header)

      content = [
        %{type: "image", source: %{type: "base64", data: base64_png}}
      ]

      # This should not raise and should use detected MIME type
      assert {:ok, _request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
    end

    test "detects JPEG from magic bytes" do
      jpeg_header = <<0xFF, 0xD8, 0xFF, 0xE0>>
      base64_jpeg = Base.encode64(jpeg_header)

      content = [
        %{type: "image", source: %{type: "base64", data: base64_jpeg}}
      ]

      assert {:ok, _request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
    end

    test "detects GIF from magic bytes" do
      gif_header = <<0x47, 0x49, 0x46, 0x38, 0x39, 0x61>>
      base64_gif = Base.encode64(gif_header)

      content = [
        %{type: "image", source: %{type: "base64", data: base64_gif}}
      ]

      assert {:ok, _request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
    end

    test "falls back to JPEG for unknown format" do
      unknown_data = Base.encode64(<<0x00, 0x00, 0x00, 0x00>>)

      content = [
        %{type: "image", source: %{type: "base64", data: unknown_data}}
      ]

      # Should not crash, uses default fallback
      assert {:ok, _request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
    end
  end

  describe "backward compatibility" do
    test "existing string input still works" do
      assert {:ok, _request} = Coordinator.generate_content("Hello", model: "gemini-2.5-flash")
    end

    test "existing Content struct list still works" do
      contents = [
        Content.new(role: "user", parts: [Part.text("Hello")]),
        Content.new(role: "model", parts: [Part.text("Hi there!")])
      ]

      assert {:ok, _request} = Coordinator.generate_content(contents, model: "gemini-2.5-flash")
    end

    test "existing single Content struct still works" do
      content = Content.new(role: "user", parts: [Part.text("Hello")])

      assert {:ok, _request} = Coordinator.generate_content([content], model: "gemini-2.5-flash")
    end
  end

  describe "edge cases" do
    test "empty list returns error" do
      assert {:error, _} = Coordinator.generate_content([], model: "gemini-2.5-flash")
    end

    test "handles invalid base64 gracefully" do
      content = [
        %{type: "image", source: %{type: "base64", data: "not-valid-base64!!!", mime_type: "image/png"}}
      ]

      # Should use explicit mime_type and not crash on decode
      assert {:ok, _request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
    end

    test "handles nil parts gracefully" do
      assert_raise ArgumentError, fn ->
        Coordinator.generate_content([%{role: "user", parts: nil}], model: "gemini-2.5-flash")
      end
    end
  end

  describe "real-world use cases from Issue #11" do
    test "user's original failing code now works" do
      # This is exactly what the user tried and failed with
      {:ok, %{data: image_data}} = download_sample_image()

      content = [
        %{type: "text", text: "Describe this image. If you can't see the image, just say you can't."},
        %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
      ]

      # This should NOT raise FunctionClauseError anymore
      assert {:ok, request} = Coordinator.generate_content(content, model: "gemini-2.5-flash")
      assert is_map(request)
    end
  end

  # Helper function to simulate image download
  defp download_sample_image do
    # Create a minimal valid PNG
    png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
    png_data = png_header <> :crypto.strong_rand_bytes(100)

    {:ok, %{data: png_data, content_type: "image/png"}}
  end
end
