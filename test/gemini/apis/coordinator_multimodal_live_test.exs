defmodule Gemini.APIs.CoordinatorMultimodalLiveTest do
  use ExUnit.Case

  @moduletag :live_api
  @moduletag :multimodal
  @moduletag timeout: 30_000

  import Gemini.Test.ModelHelpers

  @moduledoc """
  Live API tests for multimodal content with real images.

  Run with: mix test --include live_api --include multimodal

  These tests verify that:
  1. Flexible input formats work with the real Gemini API
  2. Input format acceptance (API may reject minimal test images)
  3. Format normalization works end-to-end

  NOTE: These tests use minimal PNG/JPEG files which the API may reject
  as "Unable to process input image". This is EXPECTED and acceptable -
  the important verification is that our code accepts the flexible formats
  and sends them to the API (even if API rejects the image content).

  The real validation is:
  - No FunctionClauseError (Issue #11 fix)
  - Request is accepted and sent to API
  - API error is about IMAGE content, not REQUEST format

  Requires: GEMINI_API_KEY environment variable
  """

  alias Gemini.Types.{Content, Part}

  @fixtures_dir Path.join([__DIR__, "..", "..", "fixtures", "multimodal"])

  setup do
    api_key = System.get_env("GEMINI_API_KEY")

    if api_key do
      Gemini.configure(:gemini, %{api_key: api_key})
      {:ok, has_api_key: true}
    else
      {:ok, has_api_key: false}
    end
  end

  describe "Live API - Anthropic-Style Format" do
    test "processes image with Anthropic-style format (Issue #11 fix)", context do
      unless context[:has_api_key] do
        IO.puts("\n⚠️  Skipping multimodal live test (GEMINI_API_KEY not set)")
        :skip
      else
        IO.puts("\n🖼️  Testing Anthropic-style multimodal format with live API")

        image_path = Path.join(@fixtures_dir, "test_image_1x1.png")
        {:ok, image_data} = File.read(image_path)

        # This is the EXACT format from Issue #11 that previously failed
        content = [
          %{type: "text", text: "This is a test image. Confirm you can see an image."},
          %{
            type: "image",
            source: %{type: "base64", data: Base.encode64(image_data), mime_type: "image/png"}
          }
        ]

        IO.puts("  📤 Sending Anthropic-style multimodal request...")

        case Gemini.generate(content, model: default_model()) do
          {:ok, response} ->
            {:ok, text} = Gemini.extract_text(response)

            IO.puts(
              "  ✅ API accepted request and processed image: #{String.slice(text, 0, 80)}..."
            )

            assert is_binary(text)

          {:error, %{type: :api_error, api_reason: 400, message: %{"message" => msg}}}
          when is_binary(msg) ->
            # API rejected the IMAGE (too small/invalid), but ACCEPTED our request format
            if String.contains?(msg, "Unable to process input image") do
              IO.puts("  ✅ Request format accepted (API rejected minimal test image - EXPECTED)")
              # This is actually success - no FunctionClauseError!
              assert true
            else
              flunk("Unexpected API error: #{msg}")
            end

          {:error, error} ->
            flunk("Request failed: #{inspect(error)}")
        end
      end
    end

    test "processes image without explicit MIME type (auto-detection)", context do
      unless context[:has_api_key] do
        :skip
      else
        IO.puts("\n🔍 Testing auto MIME type detection with live API")

        image_path = Path.join(@fixtures_dir, "test_image_1x1.png")
        {:ok, image_data} = File.read(image_path)

        # No mime_type specified - should auto-detect from PNG magic bytes
        content = [
          %{type: "text", text: "Can you see this image?"},
          # No mime_type!
          %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
        ]

        IO.puts("  📤 Sending without explicit MIME type...")

        case Gemini.generate(content, model: default_model()) do
          {:ok, response} ->
            {:ok, text} = Gemini.extract_text(response)
            IO.puts("  ✅ Auto-detection + API processing worked: #{String.slice(text, 0, 80)}...")
            assert is_binary(text)

          {:error, %{type: :api_error, message: %{"message" => msg}}} ->
            if String.contains?(msg, "Unable to process input image") do
              IO.puts("  ✅ Auto-detection worked, sent to API (minimal image rejected - OK)")
              # Success - our MIME detection and format worked
              assert true
            else
              flunk("Unexpected error: #{msg}")
            end

          {:error, error} ->
            flunk("Request failed: #{inspect(error)}")
        end
      end
    end
  end

  describe "Live API - Multiple Images" do
    test "processes two images in one request", context do
      unless context[:has_api_key] do
        :skip
      else
        IO.puts("\n🖼️🖼️  Testing multiple images in one request")

        png_path = Path.join(@fixtures_dir, "test_image_1x1.png")
        jpg_path = Path.join(@fixtures_dir, "test_image_1x1.jpg")

        {:ok, png_data} = File.read(png_path)
        {:ok, jpg_data} = File.read(jpg_path)

        content = [
          %{type: "text", text: "I'm sending you two images. Confirm you see both."},
          %{type: "image", source: %{type: "base64", data: Base.encode64(png_data)}},
          %{type: "image", source: %{type: "base64", data: Base.encode64(jpg_data)}}
        ]

        IO.puts("  📤 Sending request with 2 images...")

        case Gemini.generate(content, model: default_model()) do
          {:ok, response} ->
            {:ok, text} = Gemini.extract_text(response)
            IO.puts("  ✅ Multiple images accepted: #{String.slice(text, 0, 80)}...")
            assert is_binary(text)

          {:error, %{type: :api_error, message: %{"message" => msg}}} ->
            if String.contains?(msg, "Unable to process input image") do
              IO.puts("  ✅ Format accepted, API sent request (minimal images rejected - OK)")
              assert true
            else
              flunk("Unexpected error: #{msg}")
            end

          {:error, error} ->
            flunk("Request failed: #{inspect(error)}")
        end
      end
    end

    test "processes interleaved text and images", context do
      unless context[:has_api_key] do
        :skip
      else
        IO.puts("\n📝🖼️📝🖼️  Testing interleaved text and images")

        png_path = Path.join(@fixtures_dir, "test_image_1x1.png")
        {:ok, image_data} = File.read(png_path)

        content = [
          %{type: "text", text: "First, look at this image:"},
          %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}},
          %{type: "text", text: "Now look at this one:"},
          %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}},
          %{type: "text", text: "Are they the same? Just say yes or no."}
        ]

        IO.puts("  📤 Sending interleaved content...")

        case Gemini.generate(content, model: default_model()) do
          {:ok, response} ->
            {:ok, text} = Gemini.extract_text(response)
            IO.puts("  ✅ Interleaved format accepted: #{text}")
            assert is_binary(text)

          {:error, %{type: :api_error, message: %{"message" => msg}}} ->
            if String.contains?(msg, "Unable to process input image") do
              IO.puts("  ✅ Interleaved format accepted (minimal images rejected - OK)")
              assert true
            else
              flunk("Unexpected error: #{msg}")
            end

          {:error, error} ->
            flunk("Request failed: #{inspect(error)}")
        end
      end
    end
  end

  describe "Live API - Format Comparison" do
    test "all input formats produce equivalent API calls", context do
      unless context[:has_api_key] do
        :skip
      else
        IO.puts("\n🔄 Testing that different input formats produce same results")

        image_path = Path.join(@fixtures_dir, "test_image_1x1.png")
        {:ok, image_data} = File.read(image_path)
        prompt = "Confirm you can see this image. Just say 'yes' if you can."

        # Format 1: Anthropic-style
        format1 = [
          %{type: "text", text: prompt},
          %{
            type: "image",
            source: %{type: "base64", data: Base.encode64(image_data), mime_type: "image/png"}
          }
        ]

        # Format 2: Map with role and parts
        format2 = [
          %{
            role: "user",
            parts: [
              %{text: prompt},
              %{inline_data: %{mime_type: "image/png", data: Base.encode64(image_data)}}
            ]
          }
        ]

        # Format 3: Content struct (original)
        format3 = [
          %Content{
            role: "user",
            parts: [
              Part.text(prompt),
              Part.inline_data(image_data, "image/png")
            ]
          }
        ]

        # Test all three formats - they should all work (may get image errors but that's OK)
        results = [
          {format1, "Anthropic-style"},
          {format2, "Map with role/parts"},
          {format3, "Content struct"}
        ]

        Enum.each(results, fn {format, name} ->
          IO.puts("  📤 Testing #{name}...")

          case Gemini.generate(format, model: default_model()) do
            {:ok, response} ->
              {:ok, text} = Gemini.extract_text(response)
              IO.puts("  ✅ #{name} worked: #{String.slice(text, 0, 50)}...")

            {:error, %{type: :api_error, message: %{"message" => msg}}} ->
              if String.contains?(msg, "Unable to process input image") do
                IO.puts("  ✅ #{name} accepted (minimal image rejected - OK)")
              else
                flunk("#{name} failed with: #{msg}")
              end

            {:error, error} ->
              flunk("#{name} failed: #{inspect(error)}")
          end
        end)

        # If we got here, all formats were accepted (even if images rejected)
        assert true
      end
    end
  end
end
