# Operations API Guide

The Operations API provides tracking and management for long-running operations like video generation, file imports, and model tuning.

## Overview

Long-running operations are used when:
- Generating video content
- Importing large files
- Tuning custom models
- Any API call that may take significant time

The Operations API allows you to:
- Check operation status and progress
- Wait for completion with configurable polling
- Cancel running operations
- List and manage active operations

## Quick Start

```elixir
alias Gemini.APIs.Operations
alias Gemini.Types.Operation

# Get operation status
{:ok, op} = Operations.get("operations/abc123")
IO.puts("Done: #{op.done}")

# Wait for completion
{:ok, completed} = Operations.wait("operations/abc123")

if Operation.succeeded?(completed) do
  IO.puts("Operation completed successfully!")
  IO.inspect(completed.response)
else
  IO.puts("Operation failed: #{completed.error.message}")
end
```

## Operation States

Operations have a simple state model:

| Field | Description |
|-------|-------------|
| `done: false` | Operation is still running |
| `done: true, error: nil` | Operation succeeded |
| `done: true, error: %{...}` | Operation failed |

## Getting Operation Status

```elixir
{:ok, op} = Operations.get("operations/abc123")

IO.puts("Name: #{op.name}")
IO.puts("Done: #{op.done}")

# Check for progress in metadata
if progress = Operation.get_progress(op) do
  IO.puts("Progress: #{progress}%")
end

# Check result
cond do
  Operation.running?(op) ->
    IO.puts("Still running...")

  Operation.succeeded?(op) ->
    IO.puts("Success!")
    IO.inspect(op.response)

  Operation.failed?(op) ->
    IO.puts("Failed: #{op.error.message}")
end
```

## Waiting for Completion

### Simple Wait

```elixir
{:ok, completed} = Operations.wait("operations/abc123")
```

### With Options

```elixir
{:ok, completed} = Operations.wait("operations/abc123",
  poll_interval: 10_000,  # Check every 10 seconds
  timeout: 600_000,       # 10 minute timeout
  on_progress: fn op ->
    if progress = Operation.get_progress(op) do
      IO.puts("Progress: #{Float.round(progress, 1)}%")
    else
      IO.puts("Running... done=#{op.done}")
    end
  end
)
```

### With Exponential Backoff

For long-running operations, use backoff to reduce API calls:

```elixir
{:ok, completed} = Operations.wait_with_backoff("operations/abc123",
  initial_delay: 1_000,    # Start at 1 second
  max_delay: 60_000,       # Cap at 1 minute
  multiplier: 2.0,         # Double each time
  timeout: 3_600_000,      # 1 hour timeout
  on_progress: fn op ->
    IO.puts("Checking... done=#{op.done}")
  end
)
```

## Listing Operations

### List with Pagination

```elixir
{:ok, response} = Operations.list()

Enum.each(response.operations, fn op ->
  status = if op.done, do: "done", else: "running"
  IO.puts("#{op.name}: #{status}")
end)

# With options
{:ok, response} = Operations.list(page_size: 10)

if ListOperationsResponse.has_more_pages?(response) do
  {:ok, page2} = Operations.list(page_token: response.next_page_token)
end
```

### List All Operations

```elixir
{:ok, all_ops} = Operations.list_all()
running = Enum.filter(all_ops, &Operation.running?/1)
IO.puts("Running operations: #{length(running)}")
```

## Cancelling Operations

```elixir
case Operations.cancel("operations/abc123") do
  :ok -> IO.puts("Operation cancelled")
  {:error, reason} -> IO.puts("Failed to cancel: #{inspect(reason)}")
end
```

## Deleting Operations

Clean up completed operations:

```elixir
:ok = Operations.delete("operations/abc123")
```

## Operation Helper Functions

```elixir
alias Gemini.Types.Operation

# Check state
Operation.complete?(op)    # Done (success or failure)?
Operation.succeeded?(op)   # Completed successfully?
Operation.failed?(op)      # Completed with error?
Operation.running?(op)     # Still in progress?

# Get progress percentage (from metadata)
Operation.get_progress(op) # 75.5 or nil

# Get operation ID
Operation.get_id(op)       # "abc123" from "operations/abc123"
```

## Progress Tracking

Operations may include progress information in their metadata:

```elixir
{:ok, op} = Operations.get("operations/abc123")

# The get_progress function checks multiple common fields
progress = Operation.get_progress(op)
# Checks: metadata["progress"], metadata["progressPercent"],
#         metadata["completionPercentage"]

if progress do
  IO.puts("Progress: #{Float.round(progress, 1)}%")
end
```

## Error Handling

### Operation Errors

```elixir
{:ok, op} = Operations.get("operations/abc123")

if Operation.failed?(op) do
  error = op.error
  IO.puts("Error code: #{error.code}")
  IO.puts("Message: #{error.message}")

  if error.details do
    Enum.each(error.details, fn detail ->
      IO.puts("Detail: #{inspect(detail)}")
    end)
  end
end
```

### API Errors

```elixir
case Operations.get("operations/abc123") do
  {:ok, op} ->
    IO.inspect(op)

  {:error, {:http_error, 404, _}} ->
    IO.puts("Operation not found")

  {:error, {:http_error, status, body}} ->
    IO.puts("HTTP error #{status}: #{inspect(body)}")

  {:error, :timeout} ->
    IO.puts("Request timed out")

  {:error, reason} ->
    IO.puts("Failed: #{inspect(reason)}")
end
```

## Common Use Cases

### Video Generation

```elixir
# Start video generation (returns operation)
{:ok, op} = start_video_generation(prompt)

# Wait for completion with progress
{:ok, completed} = Operations.wait(op.name,
  poll_interval: 30_000,
  on_progress: fn op ->
    if progress = Operation.get_progress(op) do
      IO.puts("Video generation: #{progress}%")
    end
  end
)

# Get the generated video URI from response
video_uri = completed.response["generatedVideo"]["uri"]
```

### Model Tuning

```elixir
# Start tuning job (returns operation)
{:ok, op} = start_tuning_job(config)

# Wait with exponential backoff (tuning can take hours)
{:ok, completed} = Operations.wait_with_backoff(op.name,
  initial_delay: 60_000,   # Start at 1 minute
  max_delay: 300_000,      # Cap at 5 minutes
  timeout: 86_400_000,     # 24 hour timeout
  on_progress: fn op ->
    IO.puts("Tuning in progress...")
  end
)
```

## Best Practices

1. **Use appropriate polling intervals** - Don't poll too frequently for long operations
2. **Implement progress callbacks** - Keep users informed of progress
3. **Handle timeouts gracefully** - Operations can exceed expected duration
4. **Use exponential backoff** - For very long operations to reduce API calls
5. **Clean up completed operations** - Delete when results are processed
6. **Store operation names** - In case you need to resume monitoring later

## API Reference

- `Gemini.APIs.Operations.get/2` - Get operation status
- `Gemini.APIs.Operations.list/1` - List operations
- `Gemini.APIs.Operations.list_all/1` - List all operations
- `Gemini.APIs.Operations.cancel/2` - Cancel an operation
- `Gemini.APIs.Operations.delete/2` - Delete an operation
- `Gemini.APIs.Operations.wait/2` - Wait for completion
- `Gemini.APIs.Operations.wait_with_backoff/2` - Wait with exponential backoff
