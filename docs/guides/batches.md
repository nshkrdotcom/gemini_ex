# Batches API Guide

The Batches API allows you to submit large numbers of requests at once with 50% cost savings compared to interactive API calls.

## Overview

Batch processing is ideal for:
- Processing large document collections for embeddings
- Bulk content generation for content pipelines
- Overnight processing of accumulated requests
- Cost optimization for high-volume workloads

## Quick Start

```elixir
alias Gemini.APIs.{Files, Batches}
alias Gemini.Types.BatchJob

# 1. Prepare input file (JSONL format)
# Each line: {"contents": [{"parts": [{"text": "..."}]}]}

# 2. Upload the input file
{:ok, input_file} = Files.upload("input.jsonl")

# 3. Create batch job
{:ok, batch} = Batches.create("gemini-2.0-flash",
  file_name: input_file.name,
  display_name: "My Batch Job"
)

# 4. Wait for completion
{:ok, completed} = Batches.wait(batch.name,
  poll_interval: 30_000,
  timeout: 3_600_000
)

# 5. Process results
if BatchJob.succeeded?(completed) do
  IO.puts("Completed #{completed.completion_stats.success_count} requests")
end
```

## Input Format

### JSONL File Format

For file-based batch processing, create a JSONL file where each line is a JSON object:

```json
{"contents": [{"parts": [{"text": "Summarize: First document content here"}]}]}
{"contents": [{"parts": [{"text": "Summarize: Second document content here"}]}]}
{"contents": [{"parts": [{"text": "Summarize: Third document content here"}]}]}
```

### Inlined Requests

For small batches, you can pass requests directly:

```elixir
{:ok, batch} = Batches.create("gemini-2.0-flash",
  inlined_requests: [
    %{contents: [%{parts: [%{text: "Request 1"}]}]},
    %{contents: [%{parts: [%{text: "Request 2"}]}]},
    %{contents: [%{parts: [%{text: "Request 3"}]}]}
  ],
  display_name: "Small Batch"
)
```

## Creating Batch Jobs

### Content Generation Batch

```elixir
{:ok, batch} = Batches.create("gemini-2.0-flash",
  file_name: "files/input123",
  display_name: "Content Generation Batch",
  generation_config: %{
    temperature: 0.7,
    maxOutputTokens: 1000
  }
)
```

### Embedding Batch

```elixir
{:ok, batch} = Batches.create_embeddings("text-embedding-004",
  file_name: "files/embeddings-input",
  display_name: "Embedding Batch"
)
```

### With System Instruction

```elixir
{:ok, batch} = Batches.create("gemini-2.0-flash",
  file_name: "files/input123",
  system_instruction: %{
    parts: [%{text: "You are a helpful assistant that summarizes documents concisely."}]
  }
)
```

## Batch Job States

| State | Description |
|-------|-------------|
| `:queued` | Job is queued for processing |
| `:pending` | Job is preparing to run |
| `:running` | Job is actively processing |
| `:succeeded` | Job completed successfully |
| `:failed` | Job failed |
| `:cancelling` | Job is being cancelled |
| `:cancelled` | Job was cancelled |
| `:expired` | Job expired |
| `:partially_succeeded` | Some requests succeeded, some failed |

## Monitoring Batch Jobs

### Get Job Status

```elixir
{:ok, batch} = Batches.get("batches/abc123")

IO.puts("State: #{batch.state}")

if batch.completion_stats do
  stats = batch.completion_stats
  IO.puts("Total: #{stats.total_count}")
  IO.puts("Success: #{stats.success_count}")
  IO.puts("Failed: #{stats.failure_count}")
end
```

### Wait for Completion

```elixir
{:ok, completed} = Batches.wait("batches/abc123",
  poll_interval: 60_000,   # Check every minute
  timeout: 7_200_000,      # Wait up to 2 hours
  on_progress: fn batch ->
    if progress = BatchJob.get_progress(batch) do
      IO.puts("Progress: #{Float.round(progress, 1)}%")
    end
  end
)

cond do
  BatchJob.succeeded?(completed) ->
    IO.puts("Success!")

  BatchJob.failed?(completed) ->
    IO.puts("Failed: #{completed.error.message}")

  BatchJob.cancelled?(completed) ->
    IO.puts("Job was cancelled")
end
```

## Listing Batch Jobs

### List with Pagination

```elixir
{:ok, response} = Batches.list()

Enum.each(response.batch_jobs, fn job ->
  IO.puts("#{job.name}: #{job.state}")
end)

# With pagination
{:ok, response} = Batches.list(page_size: 10)
if ListBatchJobsResponse.has_more_pages?(response) do
  {:ok, page2} = Batches.list(page_token: response.next_page_token)
end
```

### List All Jobs

```elixir
{:ok, all_jobs} = Batches.list_all()
running = Enum.filter(all_jobs, &BatchJob.running?/1)
IO.puts("Running jobs: #{length(running)}")
```

## Cancelling and Deleting

### Cancel a Running Job

```elixir
:ok = Batches.cancel("batches/abc123")
```

### Delete a Completed Job

```elixir
:ok = Batches.delete("batches/abc123")
```

## Getting Results

### Inlined Responses

For batches with inline response output:

```elixir
{:ok, batch} = Batches.get("batches/abc123")

if BatchJob.succeeded?(batch) do
  case Batches.get_responses(batch) do
    {:ok, responses} ->
      Enum.each(responses, fn response ->
        IO.inspect(response)
      end)

    {:error, {:file_output, file_name}} ->
      IO.puts("Results in file: #{file_name}")

    {:error, {:gcs_output, gcs_uri}} ->
      IO.puts("Results in GCS: #{gcs_uri}")
  end
end
```

## Batch Job Helper Functions

```elixir
alias Gemini.Types.BatchJob

# Check job state
BatchJob.complete?(batch)     # Terminal state?
BatchJob.succeeded?(batch)    # Completed successfully?
BatchJob.failed?(batch)       # Failed?
BatchJob.running?(batch)      # Still processing?
BatchJob.cancelled?(batch)    # Was cancelled?

# Get progress percentage
BatchJob.get_progress(batch)  # 75.5 or nil

# Get job ID
BatchJob.get_id(batch)        # "abc123" from "batches/abc123"
```

## GCS and BigQuery Integration

### GCS Source (Vertex AI)

```elixir
{:ok, batch} = Batches.create("gemini-2.0-flash",
  gcs_uri: ["gs://my-bucket/input.jsonl"],
  auth: :vertex_ai
)
```

### BigQuery Source (Vertex AI)

```elixir
{:ok, batch} = Batches.create("gemini-2.0-flash",
  bigquery_uri: "bq://project.dataset.table",
  auth: :vertex_ai
)
```

## Error Handling

```elixir
case Batches.create("gemini-2.0-flash", file_name: "files/input") do
  {:ok, batch} ->
    IO.puts("Created: #{batch.name}")

  {:error, {:http_error, 400, body}} ->
    IO.puts("Invalid request: #{inspect(body)}")

  {:error, {:http_error, 429, _}} ->
    IO.puts("Rate limited, try again later")

  {:error, reason} ->
    IO.puts("Failed: #{inspect(reason)}")
end
```

## Best Practices

1. **Use files for large batches** - Inlined requests are limited in size
2. **Monitor progress** - Use the `on_progress` callback for long-running jobs
3. **Handle failures gracefully** - Check `completion_stats` for partial failures
4. **Clean up completed jobs** - Delete jobs when results are processed
5. **Set appropriate timeouts** - Batch jobs can take hours for large inputs

## Cost Savings

Batch processing offers 50% cost savings compared to interactive API calls:
- Interactive: Full price per request
- Batch: 50% discount, processed during off-peak times

## API Reference

- `Gemini.APIs.Batches.create/2` - Create content generation batch
- `Gemini.APIs.Batches.create_embeddings/2` - Create embedding batch
- `Gemini.APIs.Batches.get/2` - Get batch job status
- `Gemini.APIs.Batches.list/1` - List batch jobs
- `Gemini.APIs.Batches.list_all/1` - List all batch jobs
- `Gemini.APIs.Batches.cancel/2` - Cancel a running batch
- `Gemini.APIs.Batches.delete/2` - Delete a batch job
- `Gemini.APIs.Batches.wait/2` - Wait for batch completion
- `Gemini.APIs.Batches.get_responses/1` - Get inlined responses
