# Video Generation Guide

Generate high-quality videos from text descriptions using Google's Veo models through the Vertex AI API.

## Overview

The Video Generation API (Veo) allows you to:
- Generate high-quality videos from text prompts
- Create videos with customizable duration and aspect ratio
- Monitor generation progress with long-running operations

**Important Notes:**
- Video generation requires Vertex AI authentication (not available on Gemini API)
- Generation is asynchronous and can take 2-5 minutes per video
- Videos are typically 4-8 seconds in duration
- Generated videos are stored in Google Cloud Storage (GCS)
- Subject to Google's safety filters and Responsible AI policies

## Quick Start

```elixir
alias Gemini.APIs.Videos
alias Gemini.Types.Generation.Video.VideoGenerationConfig

# Start video generation
{:ok, operation} = Videos.generate(
  "A cat playing piano in a cozy living room"
)

# Wait for completion (automatic polling)
{:ok, completed_op} = Videos.wait_for_completion(operation.name)

# Extract video URIs
{:ok, videos} = Gemini.Types.Generation.Video.extract_videos(completed_op)

# Get the GCS URI
video_uri = hd(videos).video_uri
IO.puts("Video ready: #{video_uri}")
```

## Generating Videos

### Basic Generation

```elixir
# Default configuration (8 seconds, 16:9)
{:ok, operation} = Videos.generate(
  "A serene mountain landscape with flowing river"
)
```

### Custom Configuration

```elixir
config = %VideoGenerationConfig{
  number_of_videos: 2,
  duration_seconds: 4,
  aspect_ratio: "9:16"  # Vertical for mobile
}

{:ok, operation} = Videos.generate(
  "Cinematic drone shot of a futuristic city at night",
  config
)
```

### Video Durations

Supported durations:
- `4` seconds - Shorter, faster generation
- `8` seconds - Default, more content

```elixir
config = %VideoGenerationConfig{
  duration_seconds: 4
}

{:ok, operation} = Videos.generate("Quick action sequence", config)
```

### Aspect Ratios

Supported aspect ratios:
- `"16:9"` - Horizontal/desktop (1280x720) - default
- `"9:16"` - Vertical/mobile (720x1280)
- `"1:1"` - Square (1024x1024)

```elixir
# Vertical video for social media
config = %VideoGenerationConfig{
  aspect_ratio: "9:16",
  duration_seconds: 4
}

{:ok, operation} = Videos.generate(
  "A person dancing in a vibrant street",
  config
)
```

## Waiting for Completion

### Automatic Polling

The recommended way to wait for video generation:

```elixir
{:ok, operation} = Videos.generate("A beautiful sunset over ocean")

# Wait with automatic polling
{:ok, completed} = Videos.wait_for_completion(
  operation.name,
  poll_interval: 10_000,  # Check every 10 seconds
  timeout: 300_000,       # Wait up to 5 minutes
  on_progress: fn op ->
    if progress = Gemini.Types.Operation.get_progress(op) do
      IO.puts("Progress: #{progress}%")
    end
  end
)

# Check if successful
if Gemini.Types.Operation.succeeded?(completed) do
  {:ok, videos} = Gemini.Types.Generation.Video.extract_videos(completed)
  IO.puts("Success! Video: #{hd(videos).video_uri}")
else
  IO.puts("Failed: #{completed.error.message}")
end
```

### Manual Polling

For more control over the polling process:

```elixir
{:ok, operation} = Videos.generate("A cat playing with toys")

# Poll manually in a loop
defmodule VideoPoller do
  def poll_until_complete(operation_name, max_attempts \\ 30) do
    poll_loop(operation_name, 0, max_attempts)
  end

  defp poll_loop(operation_name, attempt, max_attempts) when attempt < max_attempts do
    {:ok, op} = Videos.get_operation(operation_name)

    cond do
      Gemini.Types.Operation.succeeded?(op) ->
        {:ok, op}

      Gemini.Types.Operation.failed?(op) ->
        {:error, op.error}

      true ->
        # Still running, wait and try again
        Process.sleep(10_000)
        poll_loop(operation_name, attempt + 1, max_attempts)
    end
  end

  defp poll_loop(_operation_name, _attempt, _max_attempts) do
    {:error, "Timeout: Video generation took too long"}
  end
end

case VideoPoller.poll_until_complete(operation.name) do
  {:ok, completed} ->
    {:ok, videos} = Gemini.Types.Generation.Video.extract_videos(completed)
    IO.puts("Video ready!")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

### Progress Tracking

Monitor generation progress:

```elixir
{:ok, operation} = Videos.generate("An animated forest scene")

# Wrap operation for video-specific helpers
video_op = Videos.wrap_operation(operation)

IO.puts("Progress: #{video_op.progress_percent}%")
IO.puts("ETA: #{video_op.estimated_completion_time}")
```

## Working with Generated Videos

### Downloading Videos

Videos are stored in GCS and can be downloaded:

```elixir
{:ok, completed} = Videos.wait_for_completion(operation.name)
{:ok, videos} = Gemini.Types.Generation.Video.extract_videos(completed)

video = hd(videos)

# GCS URI format: gs://bucket-name/path/to/video.mp4
gcs_uri = video.video_uri

# Download using Google Cloud Storage client or gsutil
# gsutil cp #{gcs_uri} ./my_video.mp4
```

### Video Metadata

```elixir
{:ok, videos} = Gemini.Types.Generation.Video.extract_videos(completed_op)
video = hd(videos)

IO.inspect(video.mime_type)          # "video/mp4"
IO.inspect(video.duration_seconds)   # 8.0
IO.inspect(video.resolution)         # %{"width" => 1280, "height" => 720}
IO.inspect(video.safety_attributes)  # Safety classification
IO.inspect(video.rai_info)           # Responsible AI info
```

## Advanced Configuration

### Negative Prompts

Specify what to avoid in the video:

```elixir
config = %VideoGenerationConfig{
  negative_prompt: "blurry, low quality, distorted, shaky camera"
}

{:ok, operation} = Videos.generate("High quality cinematic shot", config)
```

### Reproducible Generation

Use seeds for consistent results:

```elixir
config = %VideoGenerationConfig{
  seed: 12345,
  number_of_videos: 1
}

# Generate the same video multiple times
{:ok, op1} = Videos.generate("A red balloon floating", config)
{:ok, op2} = Videos.generate("A red balloon floating", config)
# Videos will be identical
```

## Veo 3.x Inputs

Veo 3.x models support image-to-video, interpolation, reference images, video extension, and
explicit resolution control.

### Image-to-Video

```elixir
{:ok, image} = Gemini.Types.Blob.from_file("assets/first_frame.png")

config = %VideoGenerationConfig{
  image: image
}

{:ok, operation} =
  Videos.generate("A slow camera pan across the scene", config,
    model: "veo-3.1-generate-preview"
  )
```

### Last Frame (Interpolation)

```elixir
{:ok, first_frame} = Gemini.Types.Blob.from_file("assets/first_frame.png")
{:ok, last_frame} = Gemini.Types.Blob.from_file("assets/last_frame.png")

config = %VideoGenerationConfig{
  image: first_frame,
  last_frame: last_frame
}
```

### Reference Images

```elixir
{:ok, reference} = Gemini.Types.Blob.from_file("assets/reference.png")

ref = %Gemini.Types.Generation.Video.VideoGenerationReferenceImage{
  image: reference,
  reference_type: "asset"
}

config = %VideoGenerationConfig{
  reference_images: [ref]
}
```

### Video Extension

```elixir
config = %VideoGenerationConfig{
  video: %{"gcsUri" => "gs://bucket/previous_video.mp4"}
}
```

### Resolution

```elixir
config = %VideoGenerationConfig{
  resolution: "1080p"
}
```

## Person Generation Policy

Control generation of people in videos:

```elixir
# Don't generate recognizable people (default)
config = %VideoGenerationConfig{
  person_generation: :dont_allow
}

# Allow adult humans (18+)
config = %VideoGenerationConfig{
  person_generation: :allow_adult
}

# Allow people of all ages
config = %VideoGenerationConfig{
  person_generation: :allow_all
}
```

> **Note:** In v0.10.0, the default changed from `:allow_none` to `:dont_allow`. The `:allow_none` atom is still accepted but maps to the same behavior as `:dont_allow`.

## Operation Management

### Listing Operations

```elixir
# List all video generation operations
{:ok, response} = Videos.list_operations()

Enum.each(response.operations, fn op ->
  IO.puts("#{op.name}: #{if op.done, do: "complete", else: "running"}")
end)

# List only completed operations
{:ok, response} = Videos.list_operations(filter: "done=true")

# Pagination
{:ok, response} = Videos.list_operations(page_size: 10)

if Gemini.Types.ListOperationsResponse.has_more_pages?(response) do
  {:ok, next_page} = Videos.list_operations(
    page_token: response.next_page_token
  )
end
```

### Canceling Operations

```elixir
{:ok, operation} = Videos.generate("A long video")

# Cancel if taking too long
:ok = Videos.cancel(operation.name)
```

## Error Handling

```elixir
case Videos.generate("A realistic video") do
  {:ok, operation} ->
    case Videos.wait_for_completion(operation.name) do
      {:ok, completed} ->
        if Gemini.Types.Operation.succeeded?(completed) do
          {:ok, videos} = Gemini.Types.Generation.Video.extract_videos(completed)
          IO.puts("Success! Generated #{length(videos)} videos")
        else
          IO.puts("Generation failed: #{completed.error.message}")
        end

      {:error, :timeout} ->
        IO.puts("Timeout: Video generation took too long")
        # Operation may still complete later
        Videos.cancel(operation.name)

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end

  {:error, %{type: :auth_error}} ->
    IO.puts("Authentication failed. Check Vertex AI credentials.")

  {:error, %{type: :api_error, message: msg}} ->
    IO.puts("API error: #{msg}")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Best Practices

### 1. Be Specific and Descriptive

```elixir
# Vague
"A landscape"

# Specific
"Cinematic aerial drone shot slowly panning over a serene mountain lake at sunrise, with mist rising from the water and golden light illuminating snow-capped peaks in the background"
```

### 2. Specify Camera Movement

```elixir
prompts = [
  "Static shot of a bustling city street",
  "Slow zoom in on a blooming flower",
  "Pan left across a vast desert landscape",
  "Dolly forward through a dark forest",
  "Orbital shot circling around a modern building"
]
```

### 3. Use Temporal Descriptions

```elixir
"Time-lapse of clouds moving across the sky at sunset"
"Slow motion shot of water droplets splashing"
"Quick cut montage of city life"
```

### 4. Batch Processing

```elixir
prompts = [
  "A red car driving down a highway",
  "A blue ocean with waves crashing",
  "A green forest with sunlight filtering through trees"
]

config = %VideoGenerationConfig{
  duration_seconds: 4,
  aspect_ratio: "16:9"
}

# Start all generations
operations = prompts
|> Enum.map(fn prompt ->
  {:ok, op} = Videos.generate(prompt, config)
  op
end)

# Wait for all to complete
results = operations
|> Task.async_stream(fn op ->
  Videos.wait_for_completion(op.name, timeout: 300_000)
end, timeout: 310_000)
|> Enum.to_list()
```

### 5. Handle Long-Running Operations

```elixir
# Start generation
{:ok, operation} = Videos.generate("Epic cinematic scene")

# Store operation name for later
operation_id = operation.name

# Later, in another process/request
{:ok, current_status} = Videos.get_operation(operation_id)

if current_status.done do
  {:ok, videos} = Gemini.Types.Generation.Video.extract_videos(current_status)
  # Process videos
else
  IO.puts("Still generating... #{current_status.metadata}")
end
```

## Performance Considerations

### Generation Time

Typical generation times:
- **4 seconds** video: ~2-3 minutes
- **8 seconds** video: ~3-5 minutes

Factors affecting speed:
- Video duration (longer = slower)
- Complexity of the prompt
- Resolution
- System load

### Resource Management

```elixir
# Limit concurrent video generations
max_concurrent = 3

prompts
|> Task.async_stream(
  fn prompt ->
    {:ok, op} = Videos.generate(prompt)
    Videos.wait_for_completion(op.name)
  end,
  max_concurrency: max_concurrent,
  timeout: 600_000  # 10 minutes per video
)
|> Enum.to_list()
```

## Configuration Options

### `VideoGenerationConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `number_of_videos` | `1..4` | `1` | Number of videos to generate |
| `duration_seconds` | `4` or `8` | `8` | Video duration |
| `aspect_ratio` | `String.t()` | `"16:9"` | Video aspect ratio |
| `negative_prompt` | `String.t()` | `nil` | What to avoid |
| `seed` | `integer()` | `nil` | Random seed for reproducibility |
| `person_generation` | `atom()` | `:dont_allow` | Person generation policy |
| `resolution` | `String.t()` | `nil` | Resolution (e.g., `"1080p"`) for Veo 3.1 |
| `image` | `Blob.t()` | `nil` | Input image for image-to-video |
| `last_frame` | `Blob.t()` | `nil` | Last frame for interpolation (Veo 3.1) |
| `reference_images` | `list()` | `nil` | Reference images (Veo 3.1) |
| `video` | `map()` | `nil` | Input video for extension |

> **Legacy fields:** `fps`, `compression_format`, `safety_filter_level`, and `guidance_scale` are still accepted in the struct for backwards compatibility but are **not sent** in the current API request format.

## Troubleshooting

### Operation Times Out

```elixir
# Increase timeout
{:ok, completed} = Videos.wait_for_completion(
  operation.name,
  timeout: 600_000  # 10 minutes
)

# Or poll manually with longer intervals
{:ok, op} = Videos.get_operation(operation.name)
```

### Content Blocked by Safety Filters

```elixir
{:ok, completed} = Videos.wait_for_completion(operation.name)

if completed.error do
  IO.puts("Error: #{completed.error.message}")
  # Try with different prompt or safety settings
end
```

### Downloading from GCS

```elixir
# Use Google Cloud Storage client
# Or gsutil command line tool:
# gsutil cp gs://bucket/path/video.mp4 ./local_video.mp4

# With authentication
# gcloud auth application-default login
# gsutil cp #{video.video_uri} ./output.mp4
```

## See Also

- [Vertex AI Veo Documentation](https://cloud.google.com/vertex-ai/docs/generative-ai/video/overview)
- [Image Generation Guide](image_generation.md)
- [Operations API Guide](operations.md)
- [Long-Running Operations](../README.md#long-running-operations)
