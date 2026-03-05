# Files API Guide

The Files API allows you to upload, manage, and use files with Gemini models for multimodal content generation.

## Overview

Files uploaded to the Gemini API can be:
- Used in content generation requests (images, audio, video, documents)
- Referenced by URI in multimodal prompts
- Managed with list, get, and delete operations

**Important Notes:**
- Files API requests require Gemini Developer API auth (`auth: :gemini`); they are not supported on Vertex AI
- Files expire after 48 hours
- Project storage is capped by Gemini at 20 GB across uploaded files
- Maximum file size is 2GB for most file types
- Video files may take time to process before they can be used for inference

## Quick Start

```elixir
# Upload an image
{:ok, file} = Gemini.APIs.Files.upload("path/to/image.png", auth: :gemini)

# Use the File struct directly in content generation
{:ok, response} = Gemini.generate([file, "What's in this image?"])

# Clean up when done
:ok = Gemini.APIs.Files.delete(file.name, auth: :gemini)
```

## Uploading Files

### From File Path

```elixir
# Simple upload
{:ok, file} = Gemini.APIs.Files.upload("document.pdf", auth: :gemini)

# With options
{:ok, file} = Gemini.APIs.Files.upload("video.mp4",
  display_name: "My Video",
  mime_type: "video/mp4",
  auth: :gemini
)
```

### From Binary Data

When you have file content in memory:

```elixir
image_data = File.read!("image.png")

{:ok, file} = Gemini.APIs.Files.upload_data(image_data,
  mime_type: "image/png",
  display_name: "In-Memory Image",
  auth: :gemini
)
```

### With Progress Tracking

All uploads use the resumable upload protocol, so progress callbacks work well for large files:

```elixir
{:ok, file} = Gemini.APIs.Files.upload("large_video.mp4",
  on_progress: fn uploaded, total ->
    percent = Float.round(uploaded / total * 100, 1)
    IO.puts("Uploaded: #{percent}%")
  end,
  auth: :gemini
)
```

## File States

After upload, files go through processing states:

| State | Description |
|-------|-------------|
| `:processing` | File is being processed |
| `:active` | Ready for use |
| `:failed` | Processing failed |

### Waiting for Processing

Most text, image, audio, and PDF uploads are ready immediately. Poll only when a file is still `:processing`, especially for video uploads:

```elixir
{:ok, file} = Gemini.APIs.Files.upload("video.mp4", auth: :gemini)

# Wait with default settings (5 min timeout)
{:ok, ready} = Gemini.APIs.Files.wait_for_processing(file.name, auth: :gemini)

# Or with custom options
{:ok, ready} = Gemini.APIs.Files.wait_for_processing(file.name,
  poll_interval: 5000,      # Check every 5 seconds
  timeout: 600_000,         # 10 minute timeout
  on_status: fn f -> IO.puts("State: #{f.state}") end,
  auth: :gemini
)
```

## Listing Files

### List with Pagination

```elixir
{:ok, response} = Gemini.APIs.Files.list(auth: :gemini)

Enum.each(response.files, fn file ->
  IO.puts("#{file.name}: #{file.mime_type} (#{file.state})")
end)

# With pagination options (Gemini currently supports up to 100 items per page)
{:ok, response} = Gemini.APIs.Files.list(page_size: 10, auth: :gemini)

if Gemini.Types.ListFilesResponse.has_more_pages?(response) do
  {:ok, page2} =
    Gemini.APIs.Files.list(page_token: response.next_page_token, auth: :gemini)
end
```

### List All Files

Automatically handles pagination:

```elixir
{:ok, all_files} = Gemini.APIs.Files.list_all(auth: :gemini)
IO.puts("Total files: #{length(all_files)}")

# Filter active files
active = Enum.filter(all_files, &Gemini.Types.File.active?/1)
```

## Getting File Metadata

```elixir
{:ok, file} = Gemini.APIs.Files.get("files/abc123", auth: :gemini)

IO.puts("Name: #{file.display_name}")
IO.puts("MIME type: #{file.mime_type}")
IO.puts("Size: #{file.size_bytes} bytes")
IO.puts("State: #{file.state}")
IO.puts("URI: #{file.uri}")
```

## Deleting Files

```elixir
:ok = Gemini.APIs.Files.delete("files/abc123", auth: :gemini)
```

## Using Files in Generation

Once a file is active, use it in content generation:

```elixir
{:ok, file} = Gemini.APIs.Files.upload("photo.jpg", auth: :gemini)

{:ok, response} = Gemini.generate([file, "Describe this image in detail"])
```

For video files, wait until the file becomes active:

```elixir
{:ok, video} = Gemini.APIs.Files.upload("clip.mp4", auth: :gemini)
{:ok, ready_video} = Gemini.APIs.Files.wait_for_processing(video.name, auth: :gemini)

{:ok, response} = Gemini.generate([ready_video, "Describe this video clip"])
```

## Supported MIME Types

### Images
- `image/png`, `image/jpeg`, `image/gif`, `image/webp`, `image/heic`, `image/heif`

### Videos
- `video/mp4`, `video/mpeg`, `video/mov`, `video/avi`, `video/webm`, `video/wmv`, `video/flv`, `video/mkv`

### Audio
- `audio/wav`, `audio/mp3`, `audio/aiff`, `audio/aac`, `audio/ogg`, `audio/flac`, `audio/m4a`

### Documents
- `application/pdf`, `text/plain`, `text/html`, `text/css`, `text/javascript`, `application/json`, `text/csv`, `text/markdown`

## File Helper Functions

```elixir
alias Gemini.Types.File

# Check file state
File.active?(file)      # Ready for use?
File.processing?(file)  # Still processing?
File.failed?(file)      # Processing failed?

# Get file ID from name
File.get_id(file)  # "abc123" from "files/abc123"

# Check if downloadable (for generated files)
File.downloadable?(file)
```

## Error Handling

```elixir
case Gemini.APIs.Files.upload("file.pdf") do
  {:ok, file} ->
    IO.puts("Uploaded: #{file.name}")

  {:error, %Gemini.Error{type: :config_error, message: message}} ->
    IO.puts("Configuration error: #{message}")

  {:error, {:file_not_found, path}} ->
    IO.puts("File not found: #{path}")

  {:error, {:http_error, status, body}} ->
    IO.puts("HTTP error #{status}: #{inspect(body)}")

  {:error, reason} ->
    IO.puts("Upload failed: #{inspect(reason)}")
end
```

## Best Practices

1. **Clean up files** - Delete files when no longer needed to avoid hitting storage limits
2. **Wait only when needed** - Poll while the file is `:processing`, especially for video files
3. **Track progress** - Use `on_progress` callback for large file uploads
4. **Handle expiration** - Files expire after 48 hours; re-upload if needed
5. **Use appropriate MIME types** - Let auto-detection work, or specify explicitly

## API Reference

- `Gemini.APIs.Files.upload/2` - Upload a file from path
- `Gemini.APIs.Files.upload_data/2` - Upload binary data
- `Gemini.APIs.Files.get/2` - Get file metadata
- `Gemini.APIs.Files.list/1` - List files with pagination
- `Gemini.APIs.Files.list_all/1` - List all files
- `Gemini.APIs.Files.delete/2` - Delete a file
- `Gemini.APIs.Files.wait_for_processing/2` - Wait for file to become active
- `Gemini.APIs.Files.download/2` - Download generated file content
