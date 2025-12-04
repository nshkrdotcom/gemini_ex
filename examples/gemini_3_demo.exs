#!/usr/bin/env elixir
# Gemini 3 Pro Features Demo
#
# This example demonstrates the new features in Gemini 3:
# 1. Thinking levels (replaces thinking_budget for Gemini 3)
# 2. Image generation with gemini-3-pro-image-preview
# 3. Media resolution control for vision tasks
#
# Requirements:
# - GEMINI_API_KEY environment variable set
#
# Usage: mix run examples/gemini_3_demo.exs

alias Gemini.APIs.Coordinator
alias Gemini.Types.GenerationConfig

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("GEMINI 3 PRO FEATURES DEMO")
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
- :low  - Fast responses, minimal reasoning (best for simple tasks)
- :high - Deep reasoning, may have higher latency (default)

Note: :medium is not currently supported.
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
# SECTION 2: Image Generation
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("2. IMAGE GENERATION (gemini-3-pro-image-preview)")
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
    # Extract parts from the first candidate
    [first_candidate | _] = candidates
    parts = get_in(first_candidate, [:content, :parts]) || []

    Enum.each(parts, fn part ->
      cond do
        Map.has_key?(part, :inline_data) ->
          inline_data = part.inline_data
          mime_type = inline_data[:mime_type] || inline_data["mimeType"] || "unknown"
          data = inline_data[:data] || inline_data["data"] || ""
          size = byte_size(data)

          IO.puts("  Generated image:")
          IO.puts("    MIME type: #{mime_type}")
          IO.puts("    Data size: #{size} bytes (base64)")

          # Check for thought_signature (Gemini 3 feature)
          if Map.has_key?(part, :thought_signature) do
            sig = part.thought_signature
            IO.puts("    Thought signature: #{String.slice(sig, 0, 50)}...")
          end

          # Save image to generated/ directory
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

        Map.has_key?(part, :text) ->
          IO.puts("  Text response: #{part.text}")

        true ->
          IO.puts("  Part keys: #{inspect(Map.keys(part))}")
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
# SECTION 3: Media Resolution Control
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("3. MEDIA RESOLUTION CONTROL")
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
# SECTION 4: Thought Signatures
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("4. THOUGHT SIGNATURES (Multi-turn Context)")
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
   GenerationConfig.thinking_level(:low)   # Fast responses
   GenerationConfig.thinking_level(:high)  # Deep reasoning (default)

2. image_config - Image generation settings
   GenerationConfig.image_config(aspect_ratio: "16:9", image_size: "4K")

3. media_resolution - Vision processing control
   Part.inline_data_with_resolution(data, mime, :high)
   Part.with_resolution(part, :low)

4. thought_signature - Reasoning context (automatic in SDK)
   Part.with_thought_signature(part, signature)

Models:
- gemini-3-pro-preview      : Text, reasoning, code
- gemini-3-pro-image-preview: Image generation

Best Practices:
- Keep temperature at 1.0 (Gemini 3 default) for best results
- Use :low thinking for simple tasks, :high for complex reasoning
- Don't mix thinking_level and thinking_budget in same request
""")

IO.puts("Demo complete!")
