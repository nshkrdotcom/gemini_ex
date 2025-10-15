#!/usr/bin/env elixir
# MRL (Matryoshka Representation Learning) and Normalization Demo
#
# This example demonstrates:
# 1. How MRL allows flexible embedding dimensions with minimal quality loss
# 2. Why normalization is required for non-3072 dimensions
# 3. Quality vs storage tradeoffs across different dimensions
# 4. MTEB benchmark scores showing performance vs dimension size
#
# Usage: mix run examples/use_cases/mrl_normalization_demo.exs

require Logger

alias Gemini.APIs.Coordinator
alias Gemini.Types.Response.{EmbedContentResponse, ContentEmbedding}

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("MRL (MATRYOSHKA REPRESENTATION LEARNING) AND NORMALIZATION DEMO")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
Matryoshka Representation Learning (MRL) is a technique that teaches models to
create high-dimensional embeddings where smaller prefixes are also useful. This
allows you to truncate embeddings to smaller sizes with minimal quality loss.

The text-embedding-004 model supports flexible dimensions from 128 to 3072, with
recommended sizes: 768, 1536, and 3072 dimensions.
""")

# Test text for embeddings
sample_text = """
The Theory of Relativity revolutionized physics by showing that space and time
are interconnected and relative to the observer's frame of reference. Einstein's
groundbreaking work demonstrated that massive objects curve spacetime, which we
experience as gravity.
"""

IO.puts(String.duplicate("-", 80))
IO.puts("MTEB BENCHMARK SCORES BY DIMENSION")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
MTEB (Massive Text Embedding Benchmark) scores show that performance is not
strictly tied to dimension size. Lower dimensions achieve comparable scores:

| Dimension | MTEB Score | Storage | Performance |
|-----------|------------|---------|-------------|
| 3072      | 68.17*     | 100%    | Baseline    |
| 2048      | 68.16      | 67%     | -0.01%      |
| 1536      | 68.17      | 50%     | Same        |
| 768       | 67.99      | 25%     | -0.26%      |
| 512       | 67.55      | 17%     | -0.91%      |
| 256       | 66.19      | 8%      | -2.90%      |
| 128       | 63.31      | 4%      | -7.12%      |

*Note: 3072-dimensional embeddings are pre-normalized by the API
""")

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("GENERATING EMBEDDINGS AT DIFFERENT DIMENSIONS")
IO.puts(String.duplicate("-", 80) <> "\n")

# Test different dimensions
dimensions = [128, 256, 512, 768, 1536, 3072]

embeddings_by_dimension =
  Enum.map(dimensions, fn dim ->
    IO.puts("Generating #{dim}-dimensional embedding...")

    case Coordinator.embed_content(
           sample_text,
           model: "text-embedding-004",
           output_dimensionality: dim
         ) do
      {:ok, %EmbedContentResponse{embedding: embedding}} ->
        norm = ContentEmbedding.norm(embedding)

        IO.puts(
          "  ✓ Dimension: #{dim}, Values: #{length(embedding.values)}, L2 Norm: #{Float.round(norm, 6)}"
        )

        {dim, embedding, norm}

      {:error, reason} ->
        IO.puts("  ✗ Failed: #{inspect(reason)}")
        nil
    end
  end)
  |> Enum.reject(&is_nil/1)
  |> Map.new(fn {dim, embedding, norm} -> {dim, {embedding, norm}} end)

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("NORMALIZATION REQUIREMENTS")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
CRITICAL: Only 3072-dimensional embeddings are pre-normalized by the API.
All other dimensions MUST be normalized before comparing similarity.

Why? Cosine similarity focuses on vector direction (semantic meaning), not
magnitude. Non-normalized embeddings have varying magnitudes that distort
similarity calculations.
""")

# Show normalization effect
IO.puts("\nNormalization comparison for 768-dimensional embedding:")

if Map.has_key?(embeddings_by_dimension, 768) do
  {embedding_768, original_norm} = embeddings_by_dimension[768]

  IO.puts("  Before normalization:")
  IO.puts("    L2 Norm: #{Float.round(original_norm, 6)}")

  IO.puts(
    "    First 5 values: #{Enum.take(embedding_768.values, 5) |> Enum.map(&Float.round(&1, 4)) |> inspect()}"
  )

  normalized_768 = ContentEmbedding.normalize(embedding_768)
  normalized_norm = ContentEmbedding.norm(normalized_768)

  IO.puts("\n  After normalization:")
  IO.puts("    L2 Norm: #{Float.round(normalized_norm, 6)} (should be 1.0)")

  IO.puts(
    "    First 5 values: #{Enum.take(normalized_768.values, 5) |> Enum.map(&Float.round(&1, 4)) |> inspect()}"
  )
end

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("SIMILARITY COMPARISON: NORMALIZED VS NON-NORMALIZED")
IO.puts(String.duplicate("-", 80) <> "\n")

# Generate a similar and dissimilar text
similar_text = """
Einstein's Theory of Relativity transformed our understanding of physics by
revealing that time and space are not absolute but depend on the observer's
motion. This revolutionary theory explained gravity as the curvature of spacetime.
"""

dissimilar_text = """
Machine learning algorithms use statistical techniques to enable computers to
learn from data. Neural networks, inspired by biological neurons, are particularly
effective at pattern recognition tasks like image classification.
"""

IO.puts("Comparing embeddings for 768 dimensions:")
IO.puts("\nOriginal text: #{String.slice(sample_text, 0..80)}...")
IO.puts("Similar text: #{String.slice(similar_text, 0..80)}...")
IO.puts("Dissimilar text: #{String.slice(dissimilar_text, 0..80)}...")

# Generate embeddings for comparison texts
{:ok, %EmbedContentResponse{embedding: similar_emb}} =
  Coordinator.embed_content(similar_text, model: "text-embedding-004", output_dimensionality: 768)

{:ok, %EmbedContentResponse{embedding: dissimilar_emb}} =
  Coordinator.embed_content(dissimilar_text,
    model: "text-embedding-004",
    output_dimensionality: 768
  )

if Map.has_key?(embeddings_by_dimension, 768) do
  {embedding_768, _} = embeddings_by_dimension[768]

  # Without normalization
  IO.puts("\n❌ WITHOUT normalization (INCORRECT):")
  sim_similar = ContentEmbedding.cosine_similarity(embedding_768, similar_emb)
  sim_dissimilar = ContentEmbedding.cosine_similarity(embedding_768, dissimilar_emb)

  IO.puts("  Original ↔ Similar:    #{Float.round(sim_similar, 4)}")
  IO.puts("  Original ↔ Dissimilar: #{Float.round(sim_dissimilar, 4)}")
  IO.puts("  Difference: #{Float.round(sim_similar - sim_dissimilar, 4)}")

  # With normalization
  IO.puts("\n✅ WITH normalization (CORRECT):")
  norm_768 = ContentEmbedding.normalize(embedding_768)
  norm_similar = ContentEmbedding.normalize(similar_emb)
  norm_dissimilar = ContentEmbedding.normalize(dissimilar_emb)

  norm_sim_similar = ContentEmbedding.cosine_similarity(norm_768, norm_similar)
  norm_sim_dissimilar = ContentEmbedding.cosine_similarity(norm_768, norm_dissimilar)

  IO.puts("  Original ↔ Similar:    #{Float.round(norm_sim_similar, 4)}")
  IO.puts("  Original ↔ Dissimilar: #{Float.round(norm_sim_dissimilar, 4)}")
  IO.puts("  Difference: #{Float.round(norm_sim_similar - norm_sim_dissimilar, 4)}")

  IO.puts("\n  Notice how normalization provides clearer separation between")
  IO.puts("  similar and dissimilar content!")
end

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("DISTANCE METRICS COMPARISON")
IO.puts(String.duplicate("-", 80) <> "\n")

if Map.has_key?(embeddings_by_dimension, 768) do
  {embedding_768, _} = embeddings_by_dimension[768]
  norm_768 = ContentEmbedding.normalize(embedding_768)
  norm_similar = ContentEmbedding.normalize(similar_emb)
  norm_dissimilar = ContentEmbedding.normalize(dissimilar_emb)

  IO.puts("Comparing different distance metrics on normalized embeddings:\n")

  # Cosine similarity
  cos_sim_similar = ContentEmbedding.cosine_similarity(norm_768, norm_similar)
  cos_sim_dissimilar = ContentEmbedding.cosine_similarity(norm_768, norm_dissimilar)

  IO.puts("Cosine Similarity (higher = more similar, range: -1 to 1):")
  IO.puts("  Similar texts:    #{Float.round(cos_sim_similar, 4)}")
  IO.puts("  Dissimilar texts: #{Float.round(cos_sim_dissimilar, 4)}")

  # Euclidean distance
  euc_dist_similar = ContentEmbedding.euclidean_distance(norm_768, norm_similar)
  euc_dist_dissimilar = ContentEmbedding.euclidean_distance(norm_768, norm_dissimilar)

  IO.puts("\nEuclidean Distance (lower = more similar, range: 0 to ∞):")
  IO.puts("  Similar texts:    #{Float.round(euc_dist_similar, 4)}")
  IO.puts("  Dissimilar texts: #{Float.round(euc_dist_dissimilar, 4)}")

  # Dot product
  dot_similar = ContentEmbedding.dot_product(norm_768, norm_similar)
  dot_dissimilar = ContentEmbedding.dot_product(norm_768, norm_dissimilar)

  IO.puts("\nDot Product (higher = more similar, range: -1 to 1 for normalized):")
  IO.puts("  Similar texts:    #{Float.round(dot_similar, 4)}")
  IO.puts("  Dissimilar texts: #{Float.round(dot_dissimilar, 4)}")

  IO.puts("\nNote: For normalized embeddings, cosine similarity equals dot product!")
  IO.puts("  Cosine vs Dot (similar):    #{Float.round(cos_sim_similar - dot_similar, 6)}")
  IO.puts("  Cosine vs Dot (dissimilar): #{Float.round(cos_sim_dissimilar - dot_dissimilar, 6)}")
end

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("CHOOSING THE RIGHT DIMENSION SIZE")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
Dimension size recommendations based on your use case:

🔹 768 dimensions - RECOMMENDED for most applications
   • 25% storage of full embeddings
   • Only 0.26% quality loss vs 3072
   • Excellent balance of quality and efficiency
   • Perfect for: RAG systems, semantic search, clustering

🔹 1536 dimensions - High quality
   • 50% storage of full embeddings
   • Same MTEB score as 3072 (68.17)
   • Best quality without using full dimensions
   • Perfect for: Premium search, fine-grained classification

🔹 3072 dimensions - Maximum quality (default)
   • 100% storage (largest)
   • Pre-normalized by API (no normalization needed)
   • Baseline MTEB: 68.17
   • Use when: Quality is paramount and storage is not a concern

🔹 512 or lower - Extreme efficiency
   • <20% storage of full embeddings
   • Higher quality loss (>1%)
   • Consider for: Massive scale deployments, edge devices
""")

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("KEY TAKEAWAYS:")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
1. MRL allows flexible dimension sizes with minimal quality degradation
2. 768 dimensions offer excellent quality at 25% storage cost
3. 1536 dimensions match full quality at 50% storage cost
4. ALWAYS normalize embeddings for dimensions other than 3072
5. Use ContentEmbedding.normalize/1 before computing similarities
6. Cosine similarity = dot product for normalized embeddings
7. Choose dimension based on quality/storage tradeoff for your use case
""")

IO.puts(String.duplicate("=", 80) <> "\n")
