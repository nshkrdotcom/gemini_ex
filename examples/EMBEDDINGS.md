# Gemini Embeddings Examples

This directory contains examples demonstrating the Gemini embedding API functionality.

## Quick Start

### Simple Embedding

The simplest way to generate an embedding (equivalent to the curl example):

```elixir
alias Gemini.APIs.Coordinator

{:ok, response} = Coordinator.embed_content("What is the meaning of life?")
values = response |> Coordinator.EmbedContentResponse.get_values()
# => [0.123, -0.456, 0.789, ...]
```

**Run:** `mix run examples/simple_embedding.exs`

### Full Demo

Comprehensive demonstration of all embedding features:

**Run:** `mix run examples/embedding_demo.exs`

This demo shows:
1. Simple text embedding
2. Semantic similarity comparison
3. Batch embedding (efficient)
4. Document retrieval embeddings
5. Task type optimization

## API Reference

### Basic Embedding

```elixir
# Simple embedding with default model (text-embedding-004)
{:ok, response} = Coordinator.embed_content("Your text here")

# With specific model
{:ok, response} = Coordinator.embed_content(
  "Your text here",
  model: "gemini-embedding-001"
)

# Get the embedding values
values = EmbedContentResponse.get_values(response)
# => [0.123, -0.456, ...]
```

### Batch Embedding

More efficient when embedding multiple texts:

```elixir
texts = [
  "First text",
  "Second text",
  "Third text"
]

{:ok, response} = Coordinator.batch_embed_contents(texts)
all_values = BatchEmbedContentsResponse.get_all_values(response)
# => [[0.1, 0.2, ...], [0.3, 0.4, ...], [0.5, 0.6, ...]]
```

### Task Types

Optimize embeddings for specific use cases:

```elixir
# For search queries
{:ok, query_emb} = Coordinator.embed_content(
  "How does AI work?",
  task_type: :retrieval_query
)

# For documents being searched
{:ok, doc_emb} = Coordinator.embed_content(
  "AI is the simulation of human intelligence...",
  task_type: :retrieval_document,
  title: "Introduction to AI"
)

# For semantic similarity
{:ok, emb} = Coordinator.embed_content(
  "Text to compare",
  task_type: :semantic_similarity
)

# For classification
{:ok, emb} = Coordinator.embed_content(
  "Text to classify",
  task_type: :classification
)

# For clustering
{:ok, emb} = Coordinator.embed_content(
  "Text to cluster",
  task_type: :clustering
)
```

### Available Task Types

- `:retrieval_query` - Text is a search query
- `:retrieval_document` - Text is a document being searched
- `:semantic_similarity` - For semantic similarity tasks
- `:classification` - For classification tasks
- `:clustering` - For clustering tasks
- `:question_answering` - For Q&A tasks
- `:fact_verification` - For fact verification
- `:code_retrieval_query` - For code retrieval

### Semantic Similarity

Compare embeddings to measure similarity:

```elixir
alias Gemini.Types.Response.ContentEmbedding

# Get two embeddings
{:ok, resp1} = Coordinator.embed_content("The cat sat on the mat")
{:ok, resp2} = Coordinator.embed_content("A feline rested on the rug")

# Calculate cosine similarity
similarity = ContentEmbedding.cosine_similarity(
  resp1.embedding,
  resp2.embedding
)
# => 0.85 (high similarity)
```

Cosine similarity ranges from -1 to 1:
- **1.0** = Identical meaning
- **0.5-0.9** = Very similar
- **0.0** = Unrelated
- **-1.0** = Opposite meaning

### Dimension Reduction

For newer models, you can reduce embedding dimensionality:

```elixir
{:ok, response} = Coordinator.embed_content(
  "Your text here",
  model: "text-embedding-004",
  output_dimensionality: 256
)
```

**Note:** Not supported on older models like `gemini-embedding-001`.

## Available Models

- **`text-embedding-004`** (recommended) - Latest model with best quality
  - 768 dimensions by default
  - Supports dimension reduction
  - Supports all task types

- **`gemini-embedding-001`** - Earlier model
  - 3072 dimensions (fixed)
  - No dimension reduction support
  - Limited task type support

## Use Cases

### 1. Semantic Search

```elixir
# Embed your document corpus
documents = ["Doc 1 text", "Doc 2 text", "Doc 3 text"]
{:ok, doc_response} = Coordinator.batch_embed_contents(
  documents,
  task_type: :retrieval_document
)

# Embed the search query
{:ok, query_response} = Coordinator.embed_content(
  "search query",
  task_type: :retrieval_query
)

# Compare query with each document
doc_response.embeddings
|> Enum.zip(documents)
|> Enum.map(fn {doc_emb, doc_text} ->
  similarity = ContentEmbedding.cosine_similarity(
    query_response.embedding,
    doc_emb
  )
  {doc_text, similarity}
end)
|> Enum.sort_by(fn {_, sim} -> sim end, :desc)
# Returns documents sorted by relevance
```

### 2. Clustering

```elixir
# Embed texts for clustering
texts = ["Text 1", "Text 2", "Text 3", ...]
{:ok, response} = Coordinator.batch_embed_contents(
  texts,
  task_type: :clustering
)

# Use embeddings with a clustering algorithm
# (e.g., K-means, hierarchical clustering)
embeddings = BatchEmbedContentsResponse.get_all_values(response)
```

### 3. Classification

```elixir
# Embed training examples
{:ok, train_response} = Coordinator.batch_embed_contents(
  training_texts,
  task_type: :classification
)

# Embed new text to classify
{:ok, new_response} = Coordinator.embed_content(
  new_text,
  task_type: :classification
)

# Find nearest neighbors in training set
# Use their labels for classification
```

## Authentication

Embeddings support both Gemini API and Vertex AI authentication:

```elixir
# With Gemini API (default)
{:ok, response} = Coordinator.embed_content("Text", auth: :gemini)

# With Vertex AI
{:ok, response} = Coordinator.embed_content("Text", auth: :vertex_ai)
```

## Error Handling

```elixir
case Coordinator.embed_content(text) do
  {:ok, response} ->
    values = EmbedContentResponse.get_values(response)
    # Process embedding values

  {:error, reason} ->
    # Handle error
    Logger.error("Embedding failed: #{inspect(reason)}")
end
```

## Performance Tips

1. **Use batch embedding** when processing multiple texts - it's more efficient:
   ```elixir
   # Good: Single API call
   Coordinator.batch_embed_contents(["text1", "text2", "text3"])

   # Less efficient: Multiple API calls
   Enum.map(["text1", "text2", "text3"], &Coordinator.embed_content/1)
   ```

2. **Use appropriate task types** for better quality embeddings

3. **Consider dimension reduction** for storage/memory constraints:
   ```elixir
   Coordinator.embed_content(text, output_dimensionality: 256)
   ```

## Related Documentation

- [Gemini API Embeddings Guide](https://ai.google.dev/docs/embeddings_guide)
- [Text Embedding Models](https://ai.google.dev/models/gemini#text-embedding)
- [Semantic Retrieval](https://ai.google.dev/docs/semantic_retrieval)

## Examples

- `simple_embedding.exs` - Basic embedding (curl equivalent)
- `embedding_demo.exs` - Comprehensive feature demonstration
