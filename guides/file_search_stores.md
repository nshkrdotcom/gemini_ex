# File Search Stores Guide

Complete guide to using File Search Stores for semantic search and retrieval-augmented generation (RAG) in the Gemini Elixir client.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Creating Stores](#creating-stores)
- [Managing Documents](#managing-documents)
- [Querying Stores](#querying-stores)
- [Best Practices](#best-practices)
- [Advanced Usage](#advanced-usage)
- [Error Handling](#error-handling)
- [API Reference](#api-reference)

## Overview

File Search Stores enable semantic search over your documents using vector embeddings. They are part of Google's RAG (Retrieval-Augmented Generation) system and allow you to:

- **Store and index documents** for semantic search
- **Ground AI responses** with your own data
- **Build knowledge bases** from your document collections
- **Search across documents** using natural language queries

### Key Features

- **Automatic Indexing**: Documents are automatically chunked and indexed
- **Semantic Search**: Find relevant content using natural language
- **Vector Embeddings**: Powered by Google's text-embedding models
- **RAG Integration**: Use directly in generation requests for grounded responses
- **Document Management**: Full CRUD operations on stores and documents

### Important Notes

- **Vertex AI Only**: File Search Stores are only available through Vertex AI authentication
- **Asynchronous Processing**: Store creation and document indexing happen asynchronously
- **Automatic Chunking**: Documents are split into chunks optimized for retrieval

## Prerequisites

### Required Setup

1. **Google Cloud Project**: You need an active GCP project
2. **Vertex AI API**: Must be enabled in your project
3. **Authentication**: Valid service account credentials

### Environment Variables

```bash
export GOOGLE_CLOUD_PROJECT="your-project-id"
# Option A: standard ADC file path
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
# Option B: JSON content directly (gemini_ex extension)
export GOOGLE_APPLICATION_CREDENTIALS_JSON='{"type":"service_account",...}'
```

### Elixir Configuration

```elixir
# config/config.exs
config :gemini_ex,
  auth: %{
    type: :vertex_ai,
    credentials: %{
      project_id: System.get_env("GOOGLE_CLOUD_PROJECT"),
      location: "us-central1"  # Choose your region
    }
  }
```

## Quick Start

Here's a complete example of creating a store, adding documents, and using it for search:

```elixir
alias Gemini.APIs.FileSearchStores
alias Gemini.Types.CreateFileSearchStoreConfig

# 1. Create a store
config = %CreateFileSearchStoreConfig{
  display_name: "Product Documentation",
  description: "Technical documentation for all our products"
}

{:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

# 2. Wait for the store to be ready
{:ok, ready_store} = FileSearchStores.wait_for_active(store.name)
IO.puts("Store ready: #{ready_store.name}")

# 3. Upload and import documents
{:ok, doc1} = FileSearchStores.upload_to_store(
  store.name,
  "/path/to/product-manual.pdf",
  display_name: "Product Manual v2.0"
)

{:ok, doc2} = FileSearchStores.upload_to_store(
  store.name,
  "/path/to/api-reference.md",
  display_name: "API Reference"
)

# 4. Wait for documents to be processed
{:ok, _} = FileSearchStores.wait_for_document(doc1.name)
{:ok, _} = FileSearchStores.wait_for_document(doc2.name)

# 5. Use in generation for grounded responses
{:ok, response} = Gemini.generate_content(
  "What are the safety features in the product?",
  tools: [
    %{file_search_stores: [store.name]}
  ]
)

IO.puts(Gemini.extract_text!(response))
```

## Creating Stores

### Basic Store Creation

Create a store with just a name:

```elixir
config = %CreateFileSearchStoreConfig{
  display_name: "My Knowledge Base"
}

{:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)
```

### Store with Description

Add a description for better organization:

```elixir
config = %CreateFileSearchStoreConfig{
  display_name: "Customer Support KB",
  description: "Knowledge base for customer support team with FAQs and troubleshooting guides"
}

{:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)
```

### Store with Custom Vector Config

Specify embedding model and dimensions:

```elixir
config = %CreateFileSearchStoreConfig{
  display_name: "Technical Docs",
  vector_config: %{
    embedding_model: "text-embedding-004",
    dimensions: 768
  }
}

{:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)
```

### Waiting for Store Activation

Stores are created asynchronously. Always wait for activation before adding documents:

```elixir
{:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

# Wait with default settings (2 second intervals, 5 minute timeout)
{:ok, active_store} = FileSearchStores.wait_for_active(store.name)

# Or customize polling
{:ok, active_store} = FileSearchStores.wait_for_active(
  store.name,
  poll_interval: 5000,      # Check every 5 seconds
  timeout: 600_000,         # 10 minute timeout
  on_status: fn s ->
    IO.puts("Store state: #{s.state}")
  end
)
```

## Managing Documents

### Importing Already-Uploaded Files

If you've already uploaded a file using the Files API:

```elixir
# Upload a file first
{:ok, file} = Gemini.upload_file("/path/to/document.pdf")

# Import it into the store
{:ok, doc} = FileSearchStores.import_file(
  store.name,
  file.name,
  auth: :vertex_ai
)

# Wait for processing
{:ok, ready_doc} = FileSearchStores.wait_for_document(doc.name)
IO.puts("Document ready with #{ready_doc.chunk_count} chunks")
```

### Direct Upload to Store

Upload and import in one step:

```elixir
{:ok, doc} = FileSearchStores.upload_to_store(
  store.name,
  "/path/to/document.pdf",
  display_name: "Product Manual",
  mime_type: "application/pdf"  # Optional, auto-detected
)
```

### Batch Upload

Upload multiple documents efficiently:

```elixir
files = [
  "/path/to/doc1.pdf",
  "/path/to/doc2.md",
  "/path/to/doc3.txt"
]

# Upload all files
documents =
  Enum.map(files, fn file_path ->
    {:ok, doc} = FileSearchStores.upload_to_store(
      store.name,
      file_path,
      display_name: Path.basename(file_path)
    )
    doc
  end)

# Wait for all to be processed
Enum.each(documents, fn doc ->
  {:ok, _} = FileSearchStores.wait_for_document(doc.name)
end)

IO.puts("All #{length(documents)} documents are ready!")
```

### Checking Document Status

Get detailed document information:

```elixir
{:ok, doc} = FileSearchStores.get_document(
  "fileSearchStores/store123/documents/doc456"
)

case doc.state do
  :active ->
    IO.puts("✓ Document ready with #{doc.chunk_count} chunks")
    IO.puts("  Size: #{doc.size_bytes} bytes")
    IO.puts("  Type: #{doc.mime_type}")

  :processing ->
    IO.puts("⏳ Still processing...")

  :failed ->
    IO.puts("✗ Processing failed: #{inspect(doc.error)}")
end
```

## Querying Stores

### Using Stores in Generation

The primary way to use File Search Stores is through generation requests:

```elixir
{:ok, response} = Gemini.generate_content(
  "What are the main features of the product?",
  tools: [
    %{file_search_stores: [store.name]}
  ]
)

text = Gemini.extract_text!(response)
IO.puts(text)
```

### Multiple Stores

Query across multiple knowledge bases:

```elixir
{:ok, response} = Gemini.generate_content(
  "Compare the pricing models",
  tools: [
    %{file_search_stores: [
      "fileSearchStores/product-docs",
      "fileSearchStores/pricing-info"
    ]}
  ]
)
```

### With Generation Config

Combine with other generation options:

```elixir
{:ok, response} = Gemini.generate_content(
  "Summarize the safety guidelines",
  tools: [%{file_search_stores: [store.name]}],
  temperature: 0.3,
  max_output_tokens: 500,
  model: "gemini-1.5-pro-002"
)
```

### Accessing Source Citations

Check if the response includes grounding metadata:

```elixir
{:ok, response} = Gemini.generate_content(
  "What are the warranty terms?",
  tools: [%{file_search_stores: [store.name]}]
)

# The response may include grounding metadata showing
# which documents were used for the answer
IO.inspect(response, label: "Full Response")
```

## Best Practices

### 1. Descriptive Naming

Use clear, descriptive names for stores and documents:

```elixir
# Good
config = %CreateFileSearchStoreConfig{
  display_name: "Customer Support FAQ - 2024",
  description: "Frequently asked questions for customer support team"
}

# Less helpful
config = %CreateFileSearchStoreConfig{
  display_name: "Store 1"
}
```

### 2. Wait for Processing

Always wait for stores and documents to be active:

```elixir
# Create store
{:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

# Wait for store
{:ok, store} = FileSearchStores.wait_for_active(store.name)

# Upload document
{:ok, doc} = FileSearchStores.upload_to_store(store.name, path)

# Wait for document
{:ok, doc} = FileSearchStores.wait_for_document(doc.name)

# Now ready to use!
```

### 3. Batch Operations

Upload multiple documents before waiting:

```elixir
# Upload all documents
docs = Enum.map(file_paths, fn path ->
  {:ok, doc} = FileSearchStores.upload_to_store(store.name, path)
  doc
end)

# Then wait for all
Enum.each(docs, fn doc ->
  {:ok, _} = FileSearchStores.wait_for_document(doc.name)
end)
```

### 4. Monitor Store Size

Keep track of document count and total size:

```elixir
{:ok, store} = FileSearchStores.get(store_name)

IO.puts("Documents: #{store.document_count}")
IO.puts("Total size: #{store.total_size_bytes} bytes")

# Set alerts for size limits
if store.total_size_bytes > 10_000_000_000 do
  IO.warn("Store approaching size limit")
end
```

### 5. Organize by Purpose

Create separate stores for different use cases:

```elixir
# Product documentation
{:ok, product_store} = create_store("Product Documentation")

# Customer support
{:ok, support_store} = create_store("Support Knowledge Base")

# Internal policies
{:ok, policy_store} = create_store("Company Policies")
```

### 6. Clean Up Unused Stores

Delete stores you no longer need:

```elixir
# List all stores
{:ok, all_stores} = FileSearchStores.list_all()

# Find old or unused stores
old_stores = Enum.filter(all_stores, fn store ->
  store.document_count == 0 or
  is_older_than_90_days?(store.create_time)
end)

# Delete them
Enum.each(old_stores, fn store ->
  FileSearchStores.delete(store.name, force: true)
end)
```

## Advanced Usage

### Custom Polling Logic

Implement custom waiting logic with callbacks:

```elixir
defmodule StoreManager do
  def create_and_monitor(config) do
    {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

    {:ok, ready_store} = FileSearchStores.wait_for_active(
      store.name,
      poll_interval: 3000,
      timeout: 600_000,
      on_status: fn s ->
        Logger.info("Store #{s.name} state: #{s.state}")

        if s.state == :creating do
          notify_slack("Store creation in progress...")
        end
      end
    )

    Logger.info("Store ready!")
    {:ok, ready_store}
  end
end
```

### Parallel Store Creation

Create multiple stores in parallel:

```elixir
store_configs = [
  %CreateFileSearchStoreConfig{display_name: "Store 1"},
  %CreateFileSearchStoreConfig{display_name: "Store 2"},
  %CreateFileSearchStoreConfig{display_name: "Store 3"}
]

# Create all in parallel
tasks = Enum.map(store_configs, fn config ->
  Task.async(fn ->
    {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)
    {:ok, ready} = FileSearchStores.wait_for_active(store.name)
    ready
  end)
end)

# Wait for all
stores = Enum.map(tasks, &Task.await(&1, 600_000))
IO.puts("Created #{length(stores)} stores!")
```

### Conditional Document Import

Only import documents that meet certain criteria:

```elixir
defmodule DocumentImporter do
  def import_if_valid(store_name, file_path) do
    cond do
      not File.exists?(file_path) ->
        {:error, :file_not_found}

      File.stat!(file_path).size > 50_000_000 ->
        {:error, :file_too_large}

      not valid_mime_type?(file_path) ->
        {:error, :unsupported_type}

      true ->
        FileSearchStores.upload_to_store(
          store_name,
          file_path,
          auth: :vertex_ai
        )
    end
  end

  defp valid_mime_type?(path) do
    ext = Path.extname(path)
    ext in [".pdf", ".txt", ".md", ".html"]
  end
end
```

### Pagination Helper

List all stores with automatic pagination:

```elixir
defmodule StoreUtils do
  def list_all_with_details do
    {:ok, stores} = FileSearchStores.list_all(auth: :vertex_ai)

    Enum.map(stores, fn store ->
      %{
        name: store.name,
        display_name: store.display_name,
        documents: store.document_count,
        size_mb: div(store.total_size_bytes || 0, 1_000_000),
        state: store.state
      }
    end)
  end
end
```

## Error Handling

### Common Errors

```elixir
case FileSearchStores.create(config, auth: :vertex_ai) do
  {:ok, store} ->
    IO.puts("Created: #{store.name}")

  {:error, %{status: 403}} ->
    IO.puts("Permission denied - check IAM roles")

  {:error, %{status: 429}} ->
    IO.puts("Rate limited - retry with backoff")

  {:error, %{status: 404}} ->
    IO.puts("Project not found - check configuration")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

### Timeout Handling

Handle timeouts gracefully:

```elixir
case FileSearchStores.wait_for_active(store.name, timeout: 60_000) do
  {:ok, store} ->
    IO.puts("Store ready!")

  {:error, :timeout} ->
    IO.puts("Store creation is taking longer than expected")
    IO.puts("Check status manually with FileSearchStores.get/2")

  {:error, :store_creation_failed} ->
    IO.puts("Store creation failed - check logs")
end
```

### Retry Logic

Implement retry with exponential backoff:

```elixir
defmodule RetryHelper do
  def create_store_with_retry(config, max_attempts \\ 3) do
    do_create(config, 1, max_attempts)
  end

  defp do_create(config, attempt, max_attempts) do
    case FileSearchStores.create(config, auth: :vertex_ai) do
      {:ok, store} ->
        {:ok, store}

      {:error, %{status: 429}} when attempt < max_attempts ->
        wait_ms = :math.pow(2, attempt) * 1000 |> round()
        IO.puts("Rate limited, waiting #{wait_ms}ms...")
        Process.sleep(wait_ms)
        do_create(config, attempt + 1, max_attempts)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## API Reference

### FileSearchStores Functions

#### `create/2`

```elixir
@spec create(CreateFileSearchStoreConfig.t(), create_opts()) ::
  {:ok, FileSearchStore.t()} | {:error, term()}
```

Create a new file search store.

#### `get/2`

```elixir
@spec get(String.t(), store_opts()) ::
  {:ok, FileSearchStore.t()} | {:error, term()}
```

Retrieve a store by name.

#### `delete/2`

```elixir
@spec delete(String.t(), delete_opts()) :: :ok | {:error, term()}
```

Delete a store. Use `force: true` to delete stores with documents.

#### `list/1`

```elixir
@spec list(list_opts()) ::
  {:ok, ListFileSearchStoresResponse.t()} | {:error, term()}
```

List stores with optional pagination.

#### `list_all/1`

```elixir
@spec list_all(list_opts()) :: {:ok, [FileSearchStore.t()]} | {:error, term()}
```

Retrieve all stores across all pages.

#### `import_file/3`

```elixir
@spec import_file(String.t(), String.t(), import_opts()) ::
  {:ok, FileSearchDocument.t()} | {:error, term()}
```

Import an already-uploaded file into a store.

#### `upload_to_store/3`

```elixir
@spec upload_to_store(String.t(), String.t(), upload_opts()) ::
  {:ok, FileSearchDocument.t()} | {:error, term()}
```

Upload a file and import it into a store in one operation.

#### `wait_for_active/2`

```elixir
@spec wait_for_active(String.t(), wait_opts()) ::
  {:ok, FileSearchStore.t()} | {:error, term()}
```

Poll until store reaches `:active` state.

#### `wait_for_document/2`

```elixir
@spec wait_for_document(String.t(), wait_doc_opts()) ::
  {:ok, FileSearchDocument.t()} | {:error, term()}
```

Poll until document reaches `:active` state.

#### `get_document/2`

```elixir
@spec get_document(String.t(), store_opts()) ::
  {:ok, FileSearchDocument.t()} | {:error, term()}
```

Retrieve document metadata.

### Type Specifications

#### FileSearchStore

```elixir
%FileSearchStore{
  name: String.t(),
  display_name: String.t(),
  description: String.t(),
  state: :state_unspecified | :creating | :active | :deleting | :failed,
  create_time: String.t(),
  update_time: String.t(),
  document_count: integer(),
  total_size_bytes: integer(),
  vector_config: map()
}
```

#### FileSearchDocument

```elixir
%FileSearchDocument{
  name: String.t(),
  display_name: String.t(),
  state: :state_unspecified | :processing | :active | :failed,
  create_time: String.t(),
  update_time: String.t(),
  size_bytes: integer(),
  mime_type: String.t(),
  chunk_count: integer(),
  error: map()
}
```

## See Also

- [Files API Guide](files.md) - For uploading files before importing
- [RAG Concepts](https://cloud.google.com/vertex-ai/generative-ai/docs/grounding/retrieval-augmented-generation) - General retrieval-augmented generation patterns
- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs) - Official Google Cloud docs
