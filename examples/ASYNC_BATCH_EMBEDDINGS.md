# Async Batch Embeddings - Production Guide

**Complete guide to production-scale embedding generation with 50% cost savings**

## Table of Contents

- [Overview](#overview)
- [When to Use](#when-to-use)
- [Cost Analysis](#cost-analysis)
- [Quick Start](#quick-start)
- [Complete Workflow](#complete-workflow)
- [Production Patterns](#production-patterns)
- [API Reference](#api-reference)
- [Error Handling](#error-handling)
- [Performance Tuning](#performance-tuning)
- [Best Practices](#best-practices)

---

## Overview

The Async Batch Embedding API allows you to process large-scale embedding jobs asynchronously with **50% cost savings** compared to the interactive embedding API. It's designed for production scenarios where you need to embed thousands to millions of texts for RAG systems, knowledge bases, and large-scale retrieval.

### Key Features

- **50% Cost Reduction**: Half the cost per embedding vs interactive API
- **Long-Running Operations (LRO)**: Submit job and retrieve results later
- **Progress Tracking**: Real-time statistics on success, failure, and pending requests
- **Priority Support**: Control processing order with priority field
- **Multi-auth Compatible**: Works with both Gemini API and Vertex AI
- **Type-safe**: Complete type annotations and error handling

### Architecture

```
Submit Batch → [PENDING] → [PROCESSING] → [COMPLETED]
                                       ↘ [FAILED]
                                       ↘ [CANCELLED]
```

The batch progresses through states, allowing you to track progress and retrieve results when complete.

---

## When to Use

### Use Async Batch API For:

✅ **Large-scale indexing** (1000s-millions of documents)
✅ **RAG system setup** (building knowledge base indices)
✅ **Non-urgent embedding generation** (background processing)
✅ **Cost-sensitive workflows** (50% savings adds up at scale)
✅ **Batch data migration** (moving to new embedding model)

### Use Interactive API For:

❌ **Real-time embedding** (user-facing features)
❌ **Small batches** (<100 texts typically faster with interactive)
❌ **Time-critical workflows** (need immediate results)
❌ **Interactive exploration** (rapid iteration and testing)

---

## Cost Analysis

### Cost Comparison (Relative Units)

| Documents | Interactive API | Async Batch API | Savings |
|-----------|----------------|-----------------|---------|
| 1,000     | 1,000          | 500            | 500     |
| 10,000    | 10,000         | 5,000          | 5,000   |
| 100,000   | 100,000        | 50,000         | 50,000  |
| 1,000,000 | 1,000,000      | 500,000        | 500,000 |

### Break-even Analysis

For typical workflows:
- **Setup time**: ~2-5 minutes additional for batch workflow
- **Cost savings**: 50% per embedding
- **Break-even**: ~100-200 documents (depends on workflow)

**Recommendation**: Use async batch for any job >500 documents or when time is not critical.

---

## Quick Start

### Basic Example

```elixir
# 1. Submit batch
{:ok, batch} = Gemini.async_batch_embed_contents(
  ["Text 1", "Text 2", "Text 3"],
  display_name: "My Batch",
  task_type: :retrieval_document,
  output_dimensionality: 768
)

# 2. Wait for completion
{:ok, completed_batch} = Gemini.await_batch_completion(batch.name)

# 3. Retrieve embeddings
{:ok, embeddings} = Gemini.get_batch_embeddings(completed_batch)
```

### Run Demo

```bash
# Set API key
export GEMINI_API_KEY='your-key-here'

# Run comprehensive demo
mix run examples/async_batch_embedding_demo.exs

# Run production patterns demo
mix run examples/async_batch_production_demo.exs
```

---

## Complete Workflow

### Step 1: Submit Batch Job

```elixir
{:ok, batch} = Gemini.async_batch_embed_contents(
  texts,
  display_name: "Knowledge Base Index - #{timestamp}",
  task_type: :retrieval_document,
  output_dimensionality: 768,
  priority: 5  # Higher = more urgent
)

# Save batch.name for later retrieval
batch_id = batch.name
# => "batches/abc123def456..."
```

**Key Points**:
- `display_name` is **required** - use descriptive names for tracking
- `task_type` optimizes embeddings for specific use cases
- `output_dimensionality` defaults to model default (typically 3072)
- `priority` controls processing order (default: 0)

### Step 2: Poll for Status

#### Option A: Active Polling with Progress

```elixir
{:ok, completed_batch} = Gemini.await_batch_completion(
  batch_id,
  poll_interval: 10_000,  # Poll every 10 seconds
  timeout: 1_800_000,     # 30 minute timeout
  on_progress: fn updated_batch ->
    stats = updated_batch.batch_stats
    progress = EmbedContentBatchStats.progress_percentage(stats)
    IO.puts("Progress: #{Float.round(progress, 1)}%")
  end
)
```

#### Option B: Manual Status Check

```elixir
{:ok, status} = Gemini.get_batch_status(batch_id)

case status.state do
  :completed ->
    # Batch is done, retrieve embeddings
    {:ok, embeddings} = Gemini.get_batch_embeddings(status)

  :processing ->
    # Still working, check again later
    if status.batch_stats do
      progress = EmbedContentBatchStats.progress_percentage(status.batch_stats)
      IO.puts("Still processing: #{progress}%")
    end

  :failed ->
    # Batch failed, check stats for details
    IO.puts("Batch failed")

  :pending ->
    # Batch queued, not yet started
    IO.puts("Waiting to start...")
end
```

### Step 3: Retrieve Embeddings

```elixir
{:ok, completed_batch} = Gemini.get_batch_status(batch_id)

case completed_batch.state do
  :completed ->
    {:ok, embeddings} = Gemini.get_batch_embeddings(completed_batch)

    # IMPORTANT: Normalize if not using 3072 dimensions
    normalized_embeddings = Enum.map(embeddings, &ContentEmbedding.normalize/1)

    # Now safe to use for similarity calculations
    similarity = ContentEmbedding.cosine_similarity(
      Enum.at(normalized_embeddings, 0),
      Enum.at(normalized_embeddings, 1)
    )

  _ ->
    IO.puts("Batch not yet completed")
end
```

---

## Production Patterns

### Pattern 1: Non-blocking Submission

**Best for**: Web applications, user-facing workflows

```elixir
defmodule MyApp.EmbeddingService do
  def index_documents_async(documents, user_id) do
    # 1. Submit batch
    {:ok, batch} = Gemini.async_batch_embed_contents(
      documents,
      display_name: "User #{user_id} - #{DateTime.utc_now()}"
    )

    # 2. Store batch ID in database
    {:ok, job} = MyApp.Repo.insert(%EmbeddingJob{
      batch_id: batch.name,
      user_id: user_id,
      status: "pending",
      document_count: length(documents)
    })

    # 3. Return immediately
    {:ok, job}
  end
end
```

### Pattern 2: Background Worker

**Best for**: Scheduled jobs, cron tasks

```elixir
defmodule MyApp.EmbeddingWorker do
  use Oban.Worker, queue: :embeddings

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"batch_id" => batch_id}}) do
    case Gemini.get_batch_status(batch_id) do
      {:ok, %{state: :completed} = batch} ->
        # Process completed batch
        {:ok, embeddings} = Gemini.get_batch_embeddings(batch)
        store_embeddings(embeddings)
        :ok

      {:ok, %{state: state}} when state in [:pending, :processing] ->
        # Reschedule to check later
        {:snooze, 60}  # Check again in 60 seconds

      {:ok, %{state: :failed}} ->
        # Handle failure
        notify_failure(batch_id)
        {:error, :batch_failed}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Pattern 3: Real-time Progress Dashboard

**Best for**: Admin interfaces, monitoring

```elixir
defmodule MyAppWeb.BatchLive do
  use Phoenix.LiveView

  def mount(%{"batch_id" => batch_id}, _session, socket) do
    # Poll every 5 seconds
    if connected?(socket), do: :timer.send_interval(5000, self(), :update)

    {:ok, assign(socket, batch_id: batch_id, batch: nil)}
  end

  def handle_info(:update, socket) do
    case Gemini.get_batch_status(socket.assigns.batch_id) do
      {:ok, batch} ->
        {:noreply, assign(socket, batch: batch)}
      {:error, _} ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <h2>Batch Status: <%= @batch.state %></h2>
      <%= if @batch.batch_stats do %>
        <div>Progress: <%= progress_percentage(@batch.batch_stats) %>%</div>
        <div>Success: <%= @batch.batch_stats.successful_request_count %></div>
        <div>Failed: <%= @batch.batch_stats.failed_request_count %></div>
      <% end %>
    </div>
    """
  end
end
```

---

## API Reference

### `async_batch_embed_contents/2`

Submit an async batch embedding job.

```elixir
@spec async_batch_embed_contents([String.t()], keyword()) ::
  {:ok, EmbedContentBatch.t()} | {:error, term()}
```

**Parameters**:
- `texts`: List of strings to embed
- `opts`: Keyword list of options

**Options**:
- `:display_name` (required) - Human-readable batch name
- `:model` - Model to use (default: "gemini-embedding-001")
- `:task_type` - Optimization hint (`:retrieval_document`, `:retrieval_query`, etc.)
- `:output_dimensionality` - Output dimensions (128-3072)
- `:priority` - Processing priority (default: 0, higher = more urgent)
- `:auth` - Auth strategy (`:gemini` or `:vertex_ai`)

**Returns**:
- `{:ok, batch}` with `batch.name` for polling
- `{:error, reason}` if submission fails

**Example**:
```elixir
{:ok, batch} = Gemini.async_batch_embed_contents(
  ["text1", "text2"],
  display_name: "My Batch",
  task_type: :retrieval_document,
  output_dimensionality: 768,
  priority: 10
)
```

---

### `get_batch_status/2`

Check the status of a batch job.

```elixir
@spec get_batch_status(String.t(), keyword()) ::
  {:ok, EmbedContentBatch.t()} | {:error, term()}
```

**Parameters**:
- `batch_id`: Batch identifier (format: "batches/{batchId}")
- `opts`: Options (primarily `:auth`)

**Returns**:
- `{:ok, batch}` with current state and stats
- `{:error, reason}` if status check fails

**Example**:
```elixir
{:ok, batch} = Gemini.get_batch_status("batches/abc123")

IO.puts("State: #{batch.state}")
IO.puts("Progress: #{EmbedContentBatchStats.progress_percentage(batch.batch_stats)}%")
```

---

### `get_batch_embeddings/1`

Retrieve embeddings from a completed batch.

```elixir
@spec get_batch_embeddings(EmbedContentBatch.t()) ::
  {:ok, [ContentEmbedding.t()]} | {:error, term()}
```

**Parameters**:
- `batch`: Completed EmbedContentBatch struct

**Returns**:
- `{:ok, embeddings}` - List of ContentEmbedding structs
- `{:error, reason}` if batch not complete or file-based

**Example**:
```elixir
{:ok, batch} = Gemini.get_batch_status(batch_id)

if batch.state == :completed do
  {:ok, embeddings} = Gemini.get_batch_embeddings(batch)
  IO.puts("Retrieved #{length(embeddings)} embeddings")
end
```

---

### `await_batch_completion/2`

Convenience function to poll until completion.

```elixir
@spec await_batch_completion(String.t(), keyword()) ::
  {:ok, EmbedContentBatch.t()} | {:error, term()}
```

**Parameters**:
- `batch_id`: Batch identifier
- `opts`: Polling options

**Options**:
- `:poll_interval` - Milliseconds between polls (default: 5000)
- `:timeout` - Max wait time in milliseconds (default: 600000 = 10min)
- `:on_progress` - Callback function called on each poll
- `:auth` - Auth strategy

**Returns**:
- `{:ok, batch}` when complete
- `{:error, :timeout}` if timeout exceeded
- `{:error, reason}` for other errors

**Example**:
```elixir
{:ok, batch} = Gemini.await_batch_completion(
  batch_id,
  poll_interval: 10_000,
  timeout: 30 * 60 * 1000,  # 30 minutes
  on_progress: fn b ->
    progress = EmbedContentBatchStats.progress_percentage(b.batch_stats)
    IO.puts("Progress: #{progress}%")
  end
)
```

---

## Error Handling

### Common Errors

#### 1. Argument Error

```elixir
{:error, %ArgumentError{message: "display_name is required..."}}
```

**Solution**: Always provide `display_name` option:
```elixir
Gemini.async_batch_embed_contents(texts, display_name: "My Batch")
```

#### 2. Batch Not Complete

```elixir
{:error, "Batch not yet completed (current state: processing)"}
```

**Solution**: Check state before retrieving embeddings:
```elixir
case batch.state do
  :completed -> Gemini.get_batch_embeddings(batch)
  _ -> {:error, :not_ready}
end
```

#### 3. Timeout

```elixir
{:error, :timeout}
```

**Solution**: Increase timeout or poll asynchronously:
```elixir
await_batch_completion(batch_id, timeout: 30 * 60 * 1000)
```

#### 4. Failed Requests in Batch

Some requests may fail while others succeed. Check stats:

```elixir
if batch.batch_stats.failed_request_count > 0 do
  # Get failed request details
  failed = InlinedEmbedContentResponses.failed_responses(batch.output.inlined_responses)

  # Retry failed requests
  retry_texts = Enum.map(failed, fn {idx, _error} -> Enum.at(original_texts, idx) end)
  {:ok, retry_batch} = Gemini.async_batch_embed_contents(retry_texts, ...)
end
```

### Retry Strategy

```elixir
defmodule MyApp.EmbeddingRetry do
  def submit_with_retry(texts, opts, max_retries \\ 3) do
    case Gemini.async_batch_embed_contents(texts, opts) do
      {:ok, batch} -> {:ok, batch}
      {:error, reason} when max_retries > 0 ->
        # Exponential backoff
        :timer.sleep(1000 * (4 - max_retries))
        submit_with_retry(texts, opts, max_retries - 1)
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

---

## Performance Tuning

### Optimal Batch Sizes

| Batch Size | Recommended Poll Interval | Typical Completion Time |
|------------|--------------------------|-------------------------|
| 10-100     | 2-5 seconds             | 30s - 2min             |
| 100-1,000  | 5-10 seconds            | 2-10min                |
| 1,000-10,000 | 10-30 seconds         | 10-30min               |
| 10,000+    | 30-60 seconds           | 30min - 2hr            |

### Dimension Selection

Trade-off between storage and quality:

| Dimensions | Storage | MTEB Score | Use Case |
|------------|---------|------------|----------|
| 128        | 12.5%   | 67.04      | Extreme efficiency |
| 256        | 25%     | 67.75      | High efficiency |
| **768**    | **75%** | **67.99**  | **Recommended** |
| 1536       | 50%     | 68.17      | High quality |
| 3072       | 100%    | 68.17      | Maximum quality |

**Recommendation**: Use 768d for best balance (75% storage savings, <0.3% quality loss).

### Polling Strategy

```elixir
# Calculate adaptive poll interval based on batch size
def calculate_poll_interval(batch_size) do
  cond do
    batch_size < 100 -> 2_000      # 2 seconds
    batch_size < 1000 -> 5_000     # 5 seconds
    batch_size < 10_000 -> 10_000  # 10 seconds
    true -> 30_000                  # 30 seconds
  end
end

# Calculate timeout based on batch size
def calculate_timeout(batch_size) do
  # Estimate: ~1 second per document + 2 minute buffer
  (batch_size * 1000) + (2 * 60 * 1000)
end
```

---

## Best Practices

### 1. Always Normalize Non-3072d Embeddings

```elixir
# ❌ WRONG - Similarity will be incorrect
similarity = ContentEmbedding.cosine_similarity(embedding1, embedding2)

# ✅ CORRECT - Normalize first
normalized1 = ContentEmbedding.normalize(embedding1)
normalized2 = ContentEmbedding.normalize(embedding2)
similarity = ContentEmbedding.cosine_similarity(normalized1, normalized2)
```

### 2. Use Descriptive Batch Names

```elixir
# ❌ WRONG - Hard to track
display_name: "Batch 1"

# ✅ CORRECT - Descriptive and timestamped
display_name: "Product Catalog Index - #{DateTime.utc_now() |> DateTime.to_unix()}"
```

### 3. Store Batch IDs in Database

```elixir
# Create tracking record
{:ok, batch} = Gemini.async_batch_embed_contents(texts, display_name: name)

{:ok, _job} = Repo.insert(%EmbeddingJob{
  batch_id: batch.name,
  status: to_string(batch.state),
  created_at: DateTime.utc_now()
})
```

### 4. Monitor Batch Statistics

```elixir
def monitor_batch(batch_id) do
  {:ok, batch} = Gemini.get_batch_status(batch_id)

  stats = batch.batch_stats
  success_rate = EmbedContentBatchStats.success_rate(stats)

  # Alert if success rate drops below threshold
  if success_rate < 95.0 do
    notify_ops_team("Batch #{batch_id} has #{success_rate}% success rate")
  end
end
```

### 5. Implement Exponential Backoff

```elixir
def poll_with_backoff(batch_id, attempt \\ 1, max_attempts \\ 10) do
  case Gemini.get_batch_status(batch_id) do
    {:ok, %{state: :completed} = batch} ->
      {:ok, batch}

    {:ok, batch} when attempt < max_attempts ->
      # Exponential backoff: 2^attempt * 1000ms
      :timer.sleep(:math.pow(2, attempt) * 1000)
      poll_with_backoff(batch_id, attempt + 1, max_attempts)

    {:error, reason} ->
      {:error, reason}
  end
end
```

### 6. Use Task Types for Better Quality

```elixir
# For indexing documents
Gemini.async_batch_embed_contents(
  documents,
  task_type: :retrieval_document,
  display_name: "Document Index"
)

# For embedding queries
Gemini.embed_content(
  query,
  task_type: :retrieval_query
)
```

### 7. Batch Size Optimization

```elixir
# Split large datasets into manageable batches
def process_large_dataset(texts, batch_size \\ 10_000) do
  texts
  |> Enum.chunk_every(batch_size)
  |> Enum.map(fn chunk ->
    {:ok, batch} = Gemini.async_batch_embed_contents(
      chunk,
      display_name: "Chunk #{System.unique_integer([:positive])}"
    )
    batch.name
  end)
end
```

---

## Summary

The Async Batch Embedding API is your go-to solution for production-scale embedding generation:

- **50% cost savings** for large-scale indexing
- **Non-blocking workflow** for better user experience
- **Progress tracking** for monitoring and alerting
- **Production-ready** with comprehensive error handling

Start with the demos, adapt the patterns to your workflow, and scale to millions of embeddings efficiently!

### Related Resources

- **Live Demos**: `examples/async_batch_embedding_demo.exs`
- **Production Patterns**: `examples/async_batch_production_demo.exs`
- **API Specification**: `oldDocs/docs/spec/GEMINI-API-07-EMBEDDINGS_20251014.md`
- **Sync Embeddings Guide**: `examples/EMBEDDINGS.md`
