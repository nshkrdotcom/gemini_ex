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
# Simple embedding with default model (gemini-embedding-001)
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

### Matryoshka Representation Learning (MRL) and Dimension Control

The `gemini-embedding-001` model uses **Matryoshka Representation Learning (MRL)**, a technique that creates high-dimensional embeddings where smaller prefixes are also useful. This allows flexible dimensionality with minimal quality loss.

#### Understanding MRL

MRL teaches the model to learn embeddings where the first N dimensions are independently useful. You can truncate embeddings to smaller sizes while maintaining most of the semantic information. This is different from traditional dimensionality reduction (like PCA) - MRL is built into the model's training.

#### Choosing the Right Dimension

```elixir
# 768 dimensions - RECOMMENDED for most applications
{:ok, response} = Coordinator.embed_content(
  "Your text here",
  model: "gemini-embedding-001",
  output_dimensionality: 768
)
# • 25% storage of full embeddings
# • Only 0.26% quality loss vs 3072
# • Excellent balance of quality and efficiency

# 1536 dimensions - High quality
{:ok, response} = Coordinator.embed_content(
  "Your text here",
  model: "gemini-embedding-001",
  output_dimensionality: 1536
)
# • 50% storage of full embeddings
# • Same MTEB score as 3072 (68.17)

# 3072 dimensions - Maximum quality (default)
{:ok, response} = Coordinator.embed_content(
  "Your text here",
  model: "gemini-embedding-001"
)
# • Full embeddings (largest storage)
# • Pre-normalized by API
# • MTEB: 68.17
```

#### MTEB Benchmark Scores

The following table shows MTEB (Massive Text Embedding Benchmark) scores for different dimensions:

| Dimension | MTEB Score | Storage vs 3072 | Quality Loss |
|-----------|------------|-----------------|--------------|
| 3072      | 68.17      | 100%            | Baseline     |
| 2048      | 68.16      | 67%             | -0.01%       |
| 1536      | 68.17      | 50%             | Same         |
| 768       | 67.99      | 25%             | -0.26%       |
| 512       | 67.55      | 17%             | -0.91%       |
| 256       | 66.19      | 8%              | -2.90%       |
| 128       | 63.31      | 4%              | -7.12%       |

**Key Insight:** Performance is not strictly tied to dimension size - 1536 dimensions achieve the same score as 3072!

#### Critical: Normalization Requirements

**IMPORTANT:** Only 3072-dimensional embeddings are pre-normalized by the API. All other dimensions MUST be normalized before computing similarity metrics.

```elixir
alias Gemini.Types.Response.ContentEmbedding

# Embed with 768 dimensions
{:ok, response} = Coordinator.embed_content(
  "Your text",
  output_dimensionality: 768
)

# MUST normalize for non-3072 dimensions
normalized = ContentEmbedding.normalize(response.embedding)

# Now safe to compute similarity
similarity = ContentEmbedding.cosine_similarity(normalized, other_normalized)
```

**Why normalize?** Cosine similarity focuses on vector direction (semantic meaning), not magnitude. Non-normalized embeddings have varying magnitudes that distort similarity calculations.

#### Normalization and Distance Metrics

```elixir
alias Gemini.Types.Response.ContentEmbedding

# Normalize embeddings (required for non-3072 dimensions)
normalized_emb1 = ContentEmbedding.normalize(embedding1)
normalized_emb2 = ContentEmbedding.normalize(embedding2)

# Cosine similarity (higher = more similar, range: -1 to 1)
similarity = ContentEmbedding.cosine_similarity(normalized_emb1, normalized_emb2)

# Euclidean distance (lower = more similar, range: 0 to ∞)
distance = ContentEmbedding.euclidean_distance(normalized_emb1, normalized_emb2)

# Dot product (higher = more similar, equals cosine for normalized)
dot = ContentEmbedding.dot_product(normalized_emb1, normalized_emb2)

# Check if normalized (L2 norm should be 1.0)
norm = ContentEmbedding.norm(normalized_emb1)
# => ~1.0
```

**Note:** For normalized embeddings, cosine similarity equals dot product!

**Note:** MRL dimension control not supported on older models like `gemini-embedding-001` (fixed at 3072 dimensions).

## Available Models

### Recommended Model

- **`gemini-embedding-001`** (Latest, Recommended)
  - Default: 768 dimensions
  - Supports MRL: 128-3072 dimensions
  - Supports all task types
  - MTEB Score: 67.99 (768d) to 68.17 (1536d/3072d)
  - Requires normalization for non-3072 dimensions

### Legacy Models

- **`gemini-embedding-001`** (Legacy)
  - Fixed: 3072 dimensions
  - No MRL/dimension reduction support
  - Limited task type support
  - Pre-normalized by API

- **`gemini-embedding-exp-03-07`** (Experimental)
  - **Deprecating: October 2025**
  - Not recommended for new projects

### Model Comparison

| Feature | gemini-embedding-001 | gemini-embedding-001 |
|---------|-------------------|---------------------|
| Default Dimensions | 768 | 3072 (fixed) |
| MRL Support | ✅ (128-3072) | ❌ |
| Normalization Required | ✅ (non-3072) | ❌ (pre-normalized) |
| Task Types | All | Limited |
| MTEB Score | 67.99-68.17 | ~68.0 |
| Status | Current | Legacy |

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

## Advanced Use Case Examples

The `use_cases/` directory contains complete, production-ready examples demonstrating real-world applications:

### MRL and Normalization Demo
**File:** `use_cases/mrl_normalization_demo.exs`

Comprehensive demonstration of Matryoshka Representation Learning:
- Quality vs storage tradeoffs across dimensions (128-3072)
- MTEB benchmark comparison
- Normalization requirements and effects
- Distance metrics comparison (cosine, euclidean, dot product)
- Best practices for dimension selection

**Run:** `mix run examples/use_cases/mrl_normalization_demo.exs`

### RAG (Retrieval-Augmented Generation) System
**File:** `use_cases/rag_demo.exs`

Complete RAG pipeline implementation:
- Build and index knowledge base with RETRIEVAL_DOCUMENT task type
- Embed queries with RETRIEVAL_QUERY task type
- Retrieve top-K relevant documents using semantic similarity
- Generate contextually-aware responses
- Compare RAG vs non-RAG generation quality

**Run:** `mix run examples/use_cases/rag_demo.exs`

**Key Features:**
- Document title optimization for better embeddings
- Semantic similarity ranking
- Context-aware generation
- Side-by-side comparison with baseline

### Search Reranking
**File:** `use_cases/search_reranking.exs`

Semantic reranking for improved search relevance:
- Start with keyword-based search results
- Rerank using semantic similarity
- Compare keyword vs semantic ranking
- Hybrid ranking strategy (keyword + semantic)
- Handle synonyms and conceptual relevance

**Run:** `mix run examples/use_cases/search_reranking.exs`

**Key Features:**
- E-commerce product search example
- Visual ranking comparison
- Hybrid scoring (0.3 × keyword + 0.7 × semantic)
- Intent understanding beyond keywords

### K-NN Classification
**File:** `use_cases/classification.exs`

Text classification using K-Nearest Neighbors with embeddings:
- Few-shot learning with minimal training examples
- Customer support ticket categorization
- K-NN classification algorithm
- Confidence scoring and accuracy evaluation
- Dynamically add new categories without retraining

**Run:** `mix run examples/use_cases/classification.exs`

**Key Features:**
- Multi-category classification (technical_support, billing, account, product_inquiry)
- Accuracy evaluation and confidence analysis
- Dynamic category addition demonstration
- No model training required

## Basic Examples

- `simple_embedding.exs` - Basic embedding (curl equivalent)
- `embedding_demo.exs` - Comprehensive feature demonstration

## Async Batch Embedding API

**Note:** Support for the Async Batch Embedding API (50% cost savings, long-running operations) is planned for v0.4.0. The current implementation supports synchronous batch operations via `batch_embed_contents/2`.
