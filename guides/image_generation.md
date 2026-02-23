# Image Generation Guide

Generate, edit, and upscale images using Google's Imagen models through the Vertex AI API.

## Overview

The Image Generation API (Imagen) allows you to:
- **Generate** high-quality images from text descriptions
- **Edit** existing images with inpainting and outpainting
- **Upscale** images to higher resolutions (2x or 4x)

**Important Notes:**
- Image generation requires Vertex AI authentication (not available on Gemini API)
- As of v0.10.0, `auth: :vertex_ai` is set automatically on all Images API calls — you no longer need to pass it explicitly
- Per-request auth overrides are supported: pass `:project_id`, `:location`, `:service_account`, or `:access_token` in opts
- Location is resolved from per-request credentials if not passed explicitly (default: `us-central1`)
- Each request can generate 1-8 images
- Generated images are returned as base64-encoded data
- Subject to Google's safety filters and Responsible AI policies

## Quick Start

```elixir
# Simple image generation
{:ok, images} = Gemini.APIs.Images.generate(
  "A serene mountain landscape at sunset"
)

image = hd(images)
IO.puts("Generated: #{byte_size(image.image_data)} bytes")

# Save the image
File.write!("output.png", Base.decode64!(image.image_data))
```

## Generating Images

### Basic Generation

```elixir
alias Gemini.APIs.Images
alias Gemini.Types.Generation.Image.ImageGenerationConfig

# Default configuration (1:1 aspect ratio, PNG output)
{:ok, [image]} = Images.generate("A cute cat playing with yarn")
```

### Custom Configuration

```elixir
config = %ImageGenerationConfig{
  number_of_images: 4,
  aspect_ratio: "16:9",
  safety_filter_level: :block_some,
  person_generation: :allow_adult,
  output_mime_type: "image/jpeg",
  output_compression_quality: 90
}

{:ok, images} = Images.generate(
  "Professional headshot photo of a business person",
  config
)
```

### Aspect Ratios

Supported aspect ratios:
- `"1:1"` - Square (1024x1024) - default
- `"9:16"` - Portrait, mobile (768x1344)
- `"16:9"` - Landscape, desktop (1344x768)
- `"4:3"` - Standard portrait (896x1152)
- `"3:4"` - Standard landscape (1152x896)

```elixir
config = %ImageGenerationConfig{
  aspect_ratio: "16:9",
  number_of_images: 2
}

{:ok, images} = Images.generate("Cinematic landscape", config)
```

### Negative Prompts

Specify what to avoid in generated images:

```elixir
config = %ImageGenerationConfig{
  negative_prompt: "blurry, low quality, distorted, watermark",
  guidance_scale: 7.5
}

{:ok, images} = Images.generate("High quality portrait", config)
```

### Reproducible Generation

Use seeds for consistent results:

```elixir
config = %ImageGenerationConfig{
  seed: 12345,
  number_of_images: 1
}

# Generate the same image multiple times
{:ok, images1} = Images.generate("A red car", config)
{:ok, images2} = Images.generate("A red car", config)
# images1 and images2 will be identical
```

## Editing Images

### Inpainting

Edit specific regions of an image using a mask:

```elixir
alias Gemini.Types.Generation.Image.EditImageConfig

# Load your image and mask
image_data = File.read!("photo.png") |> Base.encode64()
mask_data = File.read!("mask.png") |> Base.encode64()

config = %EditImageConfig{
  edit_mode: :inpainting,
  guidance_scale: 15.0,
  number_of_images: 2
}

{:ok, edited} = Images.edit(
  "Replace the background with a beach scene",
  image_data,
  mask_data,
  config
)
```

### Outpainting

Extend an image beyond its original boundaries:

```elixir
config = %EditImageConfig{
  edit_mode: :outpainting,
  mask_dilation: 10
}

{:ok, extended} = Images.edit(
  "Continue the landscape to the right",
  image_data,
  mask_data,
  config
)
```

### Product Image Editing

Specialized editing for product photography:

```elixir
config = %EditImageConfig{
  edit_mode: :product_image,
  number_of_images: 4
}

{:ok, edited} = Images.edit(
  "Place product on white background",
  image_data,
  mask_data,
  config
)
```

## Upscaling Images

### 2x Upscale

Double the resolution of an image:

```elixir
alias Gemini.Types.Generation.Image.UpscaleImageConfig

image_data = File.read!("small_image.png") |> Base.encode64()

config = %UpscaleImageConfig{
  upscale_factor: :x2,
  output_mime_type: "image/png"
}

{:ok, [upscaled]} = Images.upscale(image_data, config)
```

### 4x Upscale

Quadruple the resolution for maximum quality:

```elixir
config = %UpscaleImageConfig{
  upscale_factor: :x4,
  output_mime_type: "image/jpeg",
  output_compression_quality: 95
}

{:ok, [upscaled]} = Images.upscale(image_data, config)

# Save high-quality result
File.write!("upscaled_4x.jpg", Base.decode64!(upscaled.image_data))
```

## Safety and Content Filtering

### Safety Filter Levels

Control content filtering strictness:

```elixir
# Strict filtering (recommended for public applications)
config = %ImageGenerationConfig{
  safety_filter_level: :block_most
}

# Moderate filtering (default)
config = %ImageGenerationConfig{
  safety_filter_level: :block_some
}

# Permissive filtering
config = %ImageGenerationConfig{
  safety_filter_level: :block_few
}

# No filtering (use with caution)
config = %ImageGenerationConfig{
  safety_filter_level: :block_none
}
```

### Person Generation Policy

Control generation of people in images:

```elixir
# Allow adult humans (18+)
config = %ImageGenerationConfig{
  person_generation: :allow_adult,
  safety_filter_level: :block_some
}

# Allow people of all ages
config = %ImageGenerationConfig{
  person_generation: :allow_all
}

# Don't generate recognizable people (default)
config = %ImageGenerationConfig{
  person_generation: :allow_none
}
```

## Working with Generated Images

### Saving Images

```elixir
{:ok, images} = Images.generate("A beautiful sunset")

images
|> Enum.with_index()
|> Enum.each(fn {image, index} ->
  # Decode base64 data
  binary_data = Base.decode64!(image.image_data)

  # Determine extension from MIME type
  ext = if image.mime_type == "image/jpeg", do: "jpg", else: "png"

  # Save to file
  File.write!("output_#{index}.#{ext}", binary_data)
end)
```

### Image Metadata

```elixir
{:ok, [image]} = Images.generate("A cat")

IO.inspect(image.mime_type)          # "image/png"
IO.inspect(image.image_size)         # %{"width" => 1024, "height" => 1024}
IO.inspect(image.safety_attributes)  # Safety classification results
IO.inspect(image.rai_info)           # Responsible AI info
```

## Advanced Configuration

### Output Formats

```elixir
# PNG (lossless, larger file size)
config = %ImageGenerationConfig{
  output_mime_type: "image/png"
}

# JPEG (lossy, smaller file size)
config = %ImageGenerationConfig{
  output_mime_type: "image/jpeg",
  output_compression_quality: 90  # 0-100
}
```

### Guidance Scale

Control how closely the model follows your prompt:

```elixir
# Lower values = more creative/varied
config = %ImageGenerationConfig{
  guidance_scale: 3.0
}

# Default (balanced)
config = %ImageGenerationConfig{
  guidance_scale: 7.0
}

# Higher values = stricter adherence to prompt
config = %ImageGenerationConfig{
  guidance_scale: 15.0
}
```

### Language-Specific Prompts

```elixir
config = %ImageGenerationConfig{
  language: "es"  # Spanish prompt
}

{:ok, images} = Images.generate("Un gato jugando con una pelota", config)
```

### Watermarking

```elixir
# Disable watermark (default is true)
config = %ImageGenerationConfig{
  add_watermark: false
}
```

## Error Handling

```elixir
case Images.generate("A realistic image") do
  {:ok, images} ->
    IO.puts("Generated #{length(images)} images")

  {:error, %{type: :auth_error}} ->
    IO.puts("Authentication failed. Check Vertex AI credentials.")

  {:error, %{type: :api_error, message: msg}} ->
    IO.puts("API error: #{msg}")
    # May be blocked by safety filters

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Best Practices

### 1. Be Specific in Prompts

```elixir
# Vague
"A landscape"

# Specific
"A serene mountain landscape at golden hour with snow-capped peaks, pine trees in the foreground, and a crystal-clear lake reflecting the scenery"
```

### 2. Use Negative Prompts

```elixir
config = %ImageGenerationConfig{
  negative_prompt: "blurry, low quality, distorted, text, watermark, duplicated"
}
```

### 3. Batch Processing

```elixir
prompts = [
  "A red car",
  "A blue house",
  "A green tree"
]

config = %ImageGenerationConfig{number_of_images: 2}

results = prompts
|> Task.async_stream(fn prompt ->
  Images.generate(prompt, config)
end, max_concurrency: 3)
|> Enum.to_list()
```

### 4. Handle Safety Filters

```elixir
case Images.generate(prompt, config) do
  {:ok, images} when length(images) == 0 ->
    IO.puts("Content was blocked by safety filters")

  {:ok, images} ->
    Enum.each(images, fn image ->
      if image.rai_info["blocked_reason"] do
        IO.puts("Image blocked: #{image.rai_info["blocked_reason"]}")
      end
    end)

  {:error, _} = error -> error
end
```

## Configuration Options

### `ImageGenerationConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `number_of_images` | `1..8` | `1` | Number of images to generate |
| `aspect_ratio` | `String.t()` | `"1:1"` | Image aspect ratio |
| `safety_filter_level` | `atom()` | `:block_some` | Content filtering level |
| `person_generation` | `atom()` | `:allow_none` | Person generation policy |
| `output_mime_type` | `String.t()` | `"image/png"` | Output format |
| `output_compression_quality` | `0..100` | `nil` | JPEG quality (JPEG only) |
| `negative_prompt` | `String.t()` | `nil` | What to avoid |
| `seed` | `integer()` | `nil` | Random seed for reproducibility |
| `guidance_scale` | `float()` | `nil` | Prompt adherence (1.0-20.0) |
| `language` | `String.t()` | `nil` | Prompt language code |
| `add_watermark` | `boolean()` | `true` | Add watermark to images |

### `EditImageConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `prompt` | `String.t()` | `nil` | Edit description |
| `edit_mode` | `atom()` | `:inpainting` | Edit type |
| `mask_mode` | `atom()` | `:foreground` | Mask interpretation |
| `mask_dilation` | `0..50` | `0` | Expand mask by pixels |
| `guidance_scale` | `float()` | `nil` | Prompt adherence |
| `number_of_images` | `1..8` | `1` | Number of variations |
| `safety_filter_level` | `atom()` | `:block_some` | Content filtering |
| `seed` | `integer()` | `nil` | Random seed |
| `output_mime_type` | `String.t()` | `"image/png"` | Output format |

### `UpscaleImageConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `upscale_factor` | `:x2` or `:x4` | `:x2` | Scale factor |
| `output_mime_type` | `String.t()` | `"image/png"` | Output format |
| `output_compression_quality` | `0..100` | `nil` | JPEG quality (JPEG only) |

## See Also

- [Vertex AI Imagen Documentation](https://cloud.google.com/vertex-ai/docs/generative-ai/image/overview)
- [Video Generation Guide](video_generation.md)
- [Multimodal Content](../README.md#multimodal-content)
