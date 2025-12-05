#!/usr/bin/env elixir
# Search Reranking with Embeddings Demo
#
# This example demonstrates how to use embeddings to rerank search results
# for improved relevance. The workflow:
# 1. Start with initial search results (e.g., from keyword/BM25 search)
# 2. Embed both the query and all search results
# 3. Rerank results by semantic similarity to the query
# 4. Compare keyword-based vs semantic reranking
#
# Reranking improves search quality by prioritizing semantically relevant
# results over keyword-matched results, especially for:
# - Synonym matching ("car" vs "automobile")
# - Conceptual relevance (understanding intent)
# - Handling typos and variations
#
# Usage: mix run examples/use_cases/search_reranking.exs

require Logger

alias Gemini.APIs.Coordinator
alias Gemini.Config
alias Gemini.Types.Response.{EmbedContentResponse, ContentEmbedding}

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("SEMANTIC SEARCH RERANKING DEMO")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
Search reranking uses embeddings to improve result quality by:
• Capturing semantic meaning beyond keyword matching
• Understanding user intent and context
• Handling synonyms, related concepts, and natural language variations
""")

# ============================================================================
# SCENARIO: E-commerce Product Search
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("SCENARIO: E-COMMERCE PRODUCT SEARCH")
IO.puts(String.duplicate("-", 80) <> "\n")

# Simulated product database
products = [
  %{
    id: 1,
    name: "Wireless Bluetooth Headphones",
    description:
      "Premium over-ear headphones with active noise cancellation, 30-hour battery life, and premium sound quality.",
    keyword_score: 0.95
  },
  %{
    id: 2,
    name: "USB-C Charging Cable",
    description:
      "Fast charging cable compatible with most modern devices. Durable braided design.",
    keyword_score: 0.85
  },
  %{
    id: 3,
    name: "Portable Bluetooth Speaker",
    description:
      "Waterproof wireless speaker with 360-degree sound. Perfect for outdoor adventures.",
    keyword_score: 0.90
  },
  %{
    id: 4,
    name: "Smartphone Wireless Charger",
    description:
      "Qi-enabled wireless charging pad with fast charge support for compatible devices.",
    keyword_score: 0.88
  },
  %{
    id: 5,
    name: "Noise-Cancelling Earbuds",
    description:
      "True wireless earbuds with adaptive noise cancellation and crystal-clear audio. Compact charging case included.",
    keyword_score: 0.80
  },
  %{
    id: 6,
    name: "Gaming Headset with Microphone",
    description:
      "Professional gaming headset with surround sound, RGB lighting, and noise-cancelling boom mic.",
    keyword_score: 0.75
  },
  %{
    id: 7,
    name: "Laptop Cooling Pad",
    description:
      "USB-powered cooling pad with adjustable fans to keep your laptop running cool during intensive tasks.",
    keyword_score: 0.70
  },
  %{
    id: 8,
    name: "Wireless Mouse and Keyboard Combo",
    description:
      "Ergonomic wireless keyboard and mouse set with long battery life and comfortable design.",
    keyword_score: 0.65
  }
]

# User query
user_query = "best headphones for blocking background noise"

IO.puts("User search query: \"#{user_query}\"\n")

# ============================================================================
# STEP 1: Initial Keyword-Based Ranking
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("STEP 1: INITIAL KEYWORD-BASED RANKING")
IO.puts(String.duplicate("-", 80) <> "\n")

keyword_ranked = Enum.sort_by(products, & &1.keyword_score, :desc)

IO.puts("Top 5 results by keyword matching:\n")

keyword_ranked
|> Enum.take(5)
|> Enum.with_index(1)
|> Enum.each(fn {product, rank} ->
  IO.puts("  #{rank}. [Score: #{product.keyword_score}] #{product.name}")
end)

IO.puts("\nNote: Keyword search ranked 'Wireless Bluetooth Headphones' first due to")
IO.puts("exact keyword matches, but didn't understand the 'blocking background noise'")
IO.puts("intent which specifically means noise cancellation.")

# ============================================================================
# STEP 2: Embed Query and All Products
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 2: EMBEDDING QUERY AND PRODUCTS")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("Embedding user query...")

{:ok, %EmbedContentResponse{embedding: query_embedding}} =
  Coordinator.embed_content(
    user_query,
    model: Config.get_model(:embedding),
    task_type: :retrieval_query,
    output_dimensionality: 768
  )

query_embedding = ContentEmbedding.normalize(query_embedding)

IO.puts("✓ Query embedded\n")

IO.puts("Embedding #{length(products)} product descriptions...")

embedded_products =
  Enum.map(products, fn product ->
    # Combine name and description for better semantic matching
    text = "#{product.name}. #{product.description}"

    {:ok, %EmbedContentResponse{embedding: embedding}} =
      Coordinator.embed_content(
        text,
        model: Config.get_model(:embedding),
        task_type: :retrieval_document,
        title: product.name,
        output_dimensionality: 768
      )

    normalized = ContentEmbedding.normalize(embedding)
    Map.put(product, :embedding, normalized)
  end)

IO.puts("✓ All products embedded")

# ============================================================================
# STEP 3: Semantic Reranking
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 3: SEMANTIC RERANKING BY SIMILARITY")
IO.puts(String.duplicate("-", 80) <> "\n")

semantically_ranked =
  embedded_products
  |> Enum.map(fn product ->
    similarity = ContentEmbedding.cosine_similarity(query_embedding, product.embedding)
    {product, similarity}
  end)
  |> Enum.sort_by(fn {_product, similarity} -> similarity end, :desc)

IO.puts("Top 5 results by semantic similarity:\n")

semantically_ranked
|> Enum.take(5)
|> Enum.with_index(1)
|> Enum.each(fn {{product, similarity}, rank} ->
  bar_length = round(similarity * 30)
  bar = String.duplicate("█", bar_length)
  IO.puts("  #{rank}. [#{Float.round(similarity, 4)}] #{bar}")
  IO.puts("     #{product.name}")
end)

IO.puts("\nNote: Semantic reranking correctly identified 'Noise-Cancelling Earbuds'")
IO.puts("as highly relevant because it understood 'blocking background noise' means")
IO.puts("noise cancellation, even without exact keyword matches!")

# ============================================================================
# STEP 4: Compare Rankings
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 4: RANKING COMPARISON")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts(
  String.pad_trailing("Rank", 6) <> String.pad_trailing("Keyword-Based", 40) <> "Semantic-Based"
)

IO.puts(String.duplicate("-", 80))

Enum.zip([
  Enum.take(keyword_ranked, 5),
  Enum.take(semantically_ranked, 5) |> Enum.map(fn {p, _} -> p end)
])
|> Enum.with_index(1)
|> Enum.each(fn {{keyword_p, semantic_p}, rank} ->
  keyword_name = String.slice(keyword_p.name, 0..35) |> String.pad_trailing(38)
  semantic_name = semantic_p.name

  marker =
    if keyword_p.id == semantic_p.id do
      "  "
    else
      "→ "
    end

  IO.puts("#{marker}#{rank}.   #{keyword_name}  #{semantic_name}")
end)

IO.puts("\n'→' indicates different products ranked at this position")

# ============================================================================
# STEP 5: Detailed Analysis
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 5: DETAILED ANALYSIS")
IO.puts(String.duplicate("-", 80) <> "\n")

# Show all products with both scores
IO.puts("Complete ranking with both keyword and semantic scores:\n")

# Create a map for quick lookup of semantic similarity
semantic_scores =
  semantically_ranked
  |> Enum.map(fn {product, similarity} -> {product.id, similarity} end)
  |> Map.new()

products
|> Enum.map(fn product ->
  semantic_score = Map.get(semantic_scores, product.id, 0.0)
  {product, semantic_score}
end)
|> Enum.sort_by(fn {_product, semantic_score} -> semantic_score end, :desc)
|> Enum.each(fn {product, semantic_score} ->
  keyword_bar = String.duplicate("▓", round(product.keyword_score * 20))
  semantic_bar = String.duplicate("█", round(semantic_score * 20))

  IO.puts("#{product.name}")
  IO.puts("  Keyword:  #{Float.round(product.keyword_score, 4)} #{keyword_bar}")
  IO.puts("  Semantic: #{Float.round(semantic_score, 4)} #{semantic_bar}\n")
end)

# ============================================================================
# DEMONSTRATION: Additional Query Examples
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("DEMONSTRATION: ADDITIONAL QUERIES")
IO.puts(String.duplicate("-", 80) <> "\n")

additional_queries = [
  "something to listen to music on the go",
  "power up my phone without cables",
  "clear audio for video calls"
]

Enum.each(additional_queries, fn query ->
  IO.puts("Query: \"#{query}\"")

  {:ok, %EmbedContentResponse{embedding: q_emb}} =
    Coordinator.embed_content(
      query,
      model: Config.get_model(:embedding),
      task_type: :retrieval_query,
      output_dimensionality: 768
    )

  q_emb = ContentEmbedding.normalize(q_emb)

  top_3 =
    embedded_products
    |> Enum.map(fn product ->
      similarity = ContentEmbedding.cosine_similarity(q_emb, product.embedding)
      {product, similarity}
    end)
    |> Enum.sort_by(fn {_, sim} -> sim end, :desc)
    |> Enum.take(3)

  IO.puts("  Top 3 semantic matches:")

  Enum.each(top_3, fn {product, similarity} ->
    IO.puts("    • #{product.name} (#{Float.round(similarity, 4)})")
  end)

  IO.puts("")
end)

# ============================================================================
# HYBRID RANKING STRATEGY
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("BONUS: HYBRID RANKING STRATEGY")
IO.puts(String.duplicate("-", 80) <> "\n")

IO.puts("""
Production search systems often use hybrid ranking that combines:
• Keyword/BM25 scores (for exact matches and specific terms)
• Semantic similarity scores (for intent and conceptual relevance)
• Other signals (popularity, recency, user preferences)

Example hybrid scoring: 0.3 × keyword_score + 0.7 × semantic_score
""")

hybrid_ranked =
  embedded_products
  |> Enum.map(fn product ->
    semantic_score = Map.get(semantic_scores, product.id, 0.0)
    hybrid_score = 0.3 * product.keyword_score + 0.7 * semantic_score
    {product, hybrid_score, semantic_score}
  end)
  |> Enum.sort_by(fn {_, hybrid_score, _} -> hybrid_score end, :desc)

IO.puts("\nTop 5 results with hybrid ranking:\n")

hybrid_ranked
|> Enum.take(5)
|> Enum.with_index(1)
|> Enum.each(fn {{product, hybrid_score, semantic_score}, rank} ->
  IO.puts("  #{rank}. [Hybrid: #{Float.round(hybrid_score, 4)}] #{product.name}")
  IO.puts("     (Keyword: #{product.keyword_score}, Semantic: #{Float.round(semantic_score, 4)})")
end)

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("KEY TAKEAWAYS:")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
1. Semantic reranking captures user intent beyond keyword matching
2. Use RETRIEVAL_QUERY for queries, RETRIEVAL_DOCUMENT for items to rank
3. Combine product name + description for better semantic matching
4. Normalize embeddings before computing similarity (for non-3072 dimensions)
5. Cosine similarity provides robust relevance scoring
6. Semantic ranking handles synonyms, concepts, and natural language
7. Hybrid approaches combine keyword + semantic signals for best results
8. Reranking is computationally efficient (embed once, reuse many times)
""")

IO.puts(String.duplicate("=", 80) <> "\n")
