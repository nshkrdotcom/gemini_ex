#!/usr/bin/env elixir
# Gemini 3 Features Demo
#
# This example demonstrates the new features in Gemini 3:
# 1. Thinking levels (replaces thinking_budget for Gemini 3)
# 2. Built-in tools (Google Search, URL Context, Code Execution)
# 3. Image generation with gemini-3-pro-image-preview
# 4. Media resolution control for vision tasks
#
# Requirements:
# - GEMINI_API_KEY environment variable set
#
# Usage: mix run examples/gemini_3_demo.exs

alias Gemini.APIs.Coordinator
alias Gemini.Types.GenerationConfig

defmodule Gemini3DemoHelpers do
  alias Gemini.Types.Blob

  def inline_data_from_part(%{inline_data: inline_data}), do: inline_data
  def inline_data_from_part(%{"inlineData" => inline_data}), do: inline_data
  def inline_data_from_part(%{"inline_data" => inline_data}), do: inline_data
  def inline_data_from_part(_), do: nil

  def inline_data_fields(%Blob{mime_type: mime_type, data: data}), do: {mime_type, data}
  def inline_data_fields(%{"mimeType" => mime_type, "data" => data}), do: {mime_type, data}
  def inline_data_fields(%{"mime_type" => mime_type, "data" => data}), do: {mime_type, data}
  def inline_data_fields(%{mime_type: mime_type, data: data}), do: {mime_type, data}
  def inline_data_fields(_), do: {nil, nil}

  def thought_signature(%{thought_signature: sig}) when is_binary(sig), do: sig
  def thought_signature(%{"thoughtSignature" => sig}) when is_binary(sig), do: sig
  def thought_signature(_), do: nil

  def part_text(%{text: text}) when is_binary(text), do: text
  def part_text(%{"text" => text}) when is_binary(text), do: text
  def part_text(_), do: nil
end

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("GEMINI 3 FEATURES DEMO")
IO.puts(String.duplicate("=", 80) <> "\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("Error: GEMINI_API_KEY environment variable not set")
    System.halt(1)

  _ ->
    :ok
end

# ============================================================================
# SECTION 1: Thinking Levels
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("1. THINKING LEVELS (Gemini 3)")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
Gemini 3 introduces `thinking_level` to control reasoning depth:
- :low  - Fast responses, minimal reasoning (Pro + Flash)
- :high - Deep reasoning, may have higher latency (Pro + Flash, default)
- :minimal - Minimal thinking (Flash only)
- :medium  - Balanced thinking (Flash only)

Note: Gemini 3 Pro supports :low and :high only. Gemini 3 Flash supports all four.
""")

# Example with low thinking level (fast)
IO.puts("Testing with thinking_level: :low (fast responses)...")

config_low = GenerationConfig.thinking_level(:low)

case Coordinator.generate_content(
       "What is 2 + 2?",
       model: "gemini-3-pro-preview",
       generation_config: config_low
     ) do
  {:ok, response} ->
    {:ok, text} = Gemini.extract_text(response)
    IO.puts("Response: #{text}")
    IO.puts("  (Used :low thinking level for fast response)\n")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}\n")
end

# Example with minimal thinking level (Flash only)
IO.puts("Testing with thinking_level: :minimal (Flash only)...")

config_minimal = GenerationConfig.thinking_level(:minimal)

case Coordinator.generate_content(
       "Summarize the benefits of OTP in one sentence.",
       model: "gemini-3-flash-preview",
       generation_config: config_minimal
     ) do
  {:ok, response} ->
    {:ok, text} = Gemini.extract_text(response)
    IO.puts("Response: #{text}")
    IO.puts("  (Used :minimal thinking level on Gemini 3 Flash)\n")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}\n")
end

# Example with high thinking level (deep reasoning)
IO.puts("Testing with thinking_level: :high (deep reasoning)...")

config_high = GenerationConfig.thinking_level(:high)

case Coordinator.generate_content(
       "Explain the philosophical implications of Godel's incompleteness theorems in 2 sentences.",
       model: "gemini-3-pro-preview",
       generation_config: config_high
     ) do
  {:ok, response} ->
    {:ok, text} = Gemini.extract_text(response)
    IO.puts("Response: #{text}")
    IO.puts("  (Used :high thinking level for deep reasoning)\n")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}\n")
end

# ============================================================================
# SECTION 2: Built-in Tools (Gemini 3)
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("2. BUILT-IN TOOLS (GOOGLE SEARCH + URL CONTEXT)")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
Gemini 3 models can call built-in tools without registering local functions:
- :google_search
- :url_context
- :code_execution
""")

case Gemini.generate(
       "Find the latest Elixir release notes and summarize the key changes.",
       model: "gemini-3-flash-preview",
       tools: [:google_search, :url_context],
       response_mime_type: "application/json",
       response_json_schema: %{
         "type" => "object",
         "properties" => %{
           "summary" => %{"type" => "string"},
           "sources" => %{"type" => "array", "items" => %{"type" => "string"}}
         },
         "required" => ["summary"]
       }
     ) do
  {:ok, response} ->
    {:ok, text} = Gemini.extract_text(response)
    IO.puts("Response (JSON text): #{text}\n")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}\n")
end

# ============================================================================
# SECTION 3: Image Generation
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("3. IMAGE GENERATION (gemini-3-pro-image-preview)")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
Gemini 3 Pro Image can generate images from text prompts with:
- Configurable aspect ratios: "16:9", "1:1", "4:3", "3:4", "9:16"
- High resolution output: "2K" or "4K"
- Google Search grounding for real-world information
""")

# Create image config
image_config = GenerationConfig.image_config(aspect_ratio: "16:9", image_size: "2K")

IO.puts("Generating image with config:")
IO.puts("  Aspect Ratio: 16:9")
IO.puts("  Image Size: 2K")
IO.puts("  Prompt: 'A serene mountain lake at sunset with reflection'\n")

case Coordinator.generate_content(
       "Generate an image of a serene mountain lake at sunset with perfect reflection of the mountains in the still water.",
       model: "gemini-3-pro-image-preview",
       generation_config: image_config
     ) do
  {:ok, %{candidates: candidates}} when is_list(candidates) and length(candidates) > 0 ->
    # Extract parts from the first candidate (struct or map)
    [first_candidate | _] = candidates

    parts =
      case first_candidate do
        %{content: %Gemini.Types.Content{parts: parts}} -> parts
        %{content: %{parts: parts}} -> parts
        %{"content" => %{"parts" => parts}} -> parts
        _ -> []
      end

    Enum.each(parts, fn part ->
      case Gemini3DemoHelpers.inline_data_from_part(part) do
        inline_data when not is_nil(inline_data) ->
          {mime_type, data} = Gemini3DemoHelpers.inline_data_fields(inline_data)
          mime_type = mime_type || "unknown"
          data = if is_binary(data), do: data, else: ""
          size = byte_size(data)

          IO.puts("  Generated image:")
          IO.puts("    MIME type: #{mime_type}")
          IO.puts("    Data size: #{size} bytes (base64)")

          # Check for thought_signature (Gemini 3 feature)
          case Gemini3DemoHelpers.thought_signature(part) do
            sig when is_binary(sig) ->
              IO.puts("    Thought signature: #{String.slice(sig, 0, 50)}...")

            _ ->
              :ok
          end

          # Save image to generated/ directory
          if data == "" do
            IO.puts("    (No image data returned)")
          else
            case Base.decode64(data) do
              {:ok, image_bytes} ->
                output_dir = "generated"
                File.mkdir_p!(output_dir)
                filename = "#{output_dir}/generated_image_#{:os.system_time(:second)}.jpg"
                File.write!(filename, image_bytes)
                IO.puts("    Saved to: #{filename}")
                IO.puts("    (Look in the 'generated/' directory)")

              :error ->
                IO.puts("    (Could not decode image data)")
            end
          end

        nil ->
          case Gemini3DemoHelpers.part_text(part) do
            text when is_binary(text) ->
              IO.puts("  Text response: #{text}")

            _ ->
              IO.puts("  Part keys: #{inspect(Map.keys(part))}")
          end
      end
    end)

    IO.puts("")

  {:ok, response} ->
    IO.puts("  Unexpected response format: #{inspect(response)}\n")

  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
    IO.puts("(Image generation may require specific API access)\n")
end

# ============================================================================
# SECTION 4: Media Resolution Control
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("4. MEDIA RESOLUTION CONTROL")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
Gemini 3 allows fine-grained control over vision processing:

Resolution    | Image Tokens | Video Tokens/Frame
--------------|--------------|-------------------
:low          | 280          | 70
:medium       | 560          | 70
:high         | 1120         | 280

Use higher resolution for:
- Reading fine text in images
- Identifying small details
- OCR on dense documents

Use lower resolution for:
- Faster processing
- Cost optimization
- General image understanding

Note: :ultra_high is also supported where available, with higher token costs.
""")

# Demonstrate Part API for media resolution
IO.puts("Part API for media resolution:")
IO.puts("")
IO.puts("  # Create part with high resolution for detailed analysis")
IO.puts("  Part.inline_data_with_resolution(image_data, \"image/jpeg\", :high)")
IO.puts("")
IO.puts("  # Or add resolution to existing part")
IO.puts("  part = Part.inline_data(image_data, \"image/jpeg\")")
IO.puts("  |> Part.with_resolution(:high)")
IO.puts("")

# ============================================================================
# SECTION 5: Thought Signatures
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("5. THOUGHT SIGNATURES (Multi-turn Context)")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
Gemini 3 returns `thought_signature` fields that maintain reasoning context
across API calls. The SDK handles this automatically in chat sessions.

For function calling, signatures are required for proper tool execution.
For text/chat, they improve reasoning quality across turns.

Special migration value for external conversations:
  "context_engineering_is_the_way_to_go"
""")

# ============================================================================
# SUMMARY
# ============================================================================

IO.puts(String.duplicate("=", 80))
IO.puts("GEMINI 3 FEATURES SUMMARY")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
New in Gemini 3:

1. thinking_level - Control reasoning depth
   GenerationConfig.thinking_level(:low)      # Fast responses (Pro + Flash)
   GenerationConfig.thinking_level(:minimal)  # Minimal thinking (Flash only)
   GenerationConfig.thinking_level(:high)     # Deep reasoning (default)

2. built-in tools - Google Search, URL Context, Code Execution
   tools: [:google_search, :url_context]

3. image_config - Image generation settings
   GenerationConfig.image_config(aspect_ratio: "16:9", image_size: "4K")

4. media_resolution - Vision processing control
   Part.inline_data_with_resolution(data, mime, :high)
   Part.with_resolution(part, :low)

5. thought_signature - Reasoning context (automatic in SDK)
   Part.with_thought_signature(part, signature)

Models:
- gemini-3-pro-preview      : Text, reasoning, code
- gemini-3-flash-preview    : Fast thinking + built-in tools
- gemini-3-pro-image-preview: Image generation

Best Practices:
- Keep temperature at 1.0 (Gemini 3 default) for best results
- Use :minimal/:low for simple tasks, :high for complex reasoning
- Don't mix thinking_level and thinking_budget in same request
""")

IO.puts("Demo complete!")
