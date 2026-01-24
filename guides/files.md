# Files API Guide

The Files API allows you to upload, manage, and use files with Gemini models for multimodal content generation.

## Overview

Files uploaded to the Gemini API can be:
- Used in content generation requests (images, audio, video, documents)
- Referenced by URI in multimodal prompts
- Managed with list, get, and delete operations

**Important Notes:**
- Files expire after 48 hours
- Maximum file size is 2GB for most file types
- Large files (especially video) may take time to process

## Quick Start

```elixir
# Upload an image
{:ok, file} = Gemini.APIs.Files.upload("path/to/image.png")

# Wait for processing (for video files)
{:ok, ready_file} = Gemini.APIs.Files.wait_for_processing(file.name)

# Use in content generation
{:ok, response} = Gemini.generate([
  "What's in this image?",
  %{file_uri: ready_file.uri, mime_type: ready_file.mime_type}
])

# Clean up when done
:ok = Gemini.APIs.Files.delete(file.name)
```

## Uploading Files

### From File Path

```elixir
# Simple upload
{:ok, file} = Gemini.APIs.Files.upload("document.pdf")

# With options
{:ok, file} = Gemini.APIs.Files.upload("video.mp4",
  display_name: "My Video",
  mime_type: "video/mp4"
)
```

### From Binary Data

When you have file content in memory:

```elixir
image_data = File.read!("image.png")

{:ok, file} = Gemini.APIs.Files.upload_data(image_data,
  mime_type: "image/png",
  display_name: "In-Memory Image"
)
```

### With Progress Tracking

For large files, track upload progress:

```elixir
{:ok, file} = Gemini.APIs.Files.upload("large_video.mp4",
  on_progress: fn uploaded, total ->
    percent = Float.round(uploaded / total * 100, 1)
    IO.puts("Uploaded: #{percent}%")
  end
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

For video and large files that need processing:

```elixir
{:ok, file} = Gemini.APIs.Files.upload("video.mp4")

# Wait with default settings (5 min timeout)
{:ok, ready} = Gemini.APIs.Files.wait_for_processing(file.name)

# Or with custom options
{:ok, ready} = Gemini.APIs.Files.wait_for_processing(file.name,
  poll_interval: 5000,      # Check every 5 seconds
  timeout: 600_000,         # 10 minute timeout
  on_status: fn f -> IO.puts("State: #{f.state}") end
)
```

## Listing Files

### List with Pagination

```elixir
{:ok, response} = Gemini.APIs.Files.list()

Enum.each(response.files, fn file ->
  IO.puts("#{file.name}: #{file.mime_type} (#{file.state})")
end)

# With pagination options
{:ok, response} = Gemini.APIs.Files.list(page_size: 10)

if Gemini.Types.ListFilesResponse.has_more_pages?(response) do
  {:ok, page2} = Gemini.APIs.Files.list(page_token: response.next_page_token)
end
```

### List All Files

Automatically handles pagination:

```elixir
{:ok, all_files} = Gemini.APIs.Files.list_all()
IO.puts("Total files: #{length(all_files)}")

# Filter active files
active = Enum.filter(all_files, &Gemini.Types.File.active?/1)
```

## Getting File Metadata

```elixir
{:ok, file} = Gemini.APIs.Files.get("files/abc123")

IO.puts("Name: #{file.display_name}")
IO.puts("MIME type: #{file.mime_type}")
IO.puts("Size: #{file.size_bytes} bytes")
IO.puts("State: #{file.state}")
IO.puts("URI: #{file.uri}")
```

## Deleting Files

```elixir
:ok = Gemini.APIs.Files.delete("files/abc123")
```

## Using Files in Generation

Once a file is active, use it in content generation:

```elixir
{:ok, file} = Gemini.APIs.Files.upload("photo.jpg")
{:ok, ready} = Gemini.APIs.Files.wait_for_processing(file.name)

{:ok, response} = Gemini.generate([
  "Describe this image in detail",
  %{file_uri: ready.uri, mime_type: ready.mime_type}
])
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
2. **Wait for processing** - Always wait for video/audio files to become active before using
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
