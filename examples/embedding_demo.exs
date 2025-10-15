#!/usr/bin/env elixir

# Gemini Embedding Demo
#
# This script demonstrates how to use the Gemini embedding API to:
# 1. Generate embeddings for text
# 2. Calculate semantic similarity between texts
# 3. Batch embed multiple texts efficiently
# 4. Use different task types for optimized embeddings
#
# Usage:
#   mix run examples/embedding_demo.exs
#
# Or with custom API key:
#   GEMINI_API_KEY=your_key mix run examples/embedding_demo.exs

require Logger

defmodule EmbeddingDemo do
  @moduledoc """
  Demonstrates various embedding capabilities of the Gemini API.
  """

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.Response.{EmbedContentResponse, BatchEmbedContentsResponse, ContentEmbedding}

  def run do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("GEMINI EMBEDDING API DEMO")
    IO.puts(String.duplicate("=", 80) <> "\n")

    # Run all demos
    demo_simple_embedding()
    demo_semantic_similarity()
    demo_batch_embedding()
    demo_retrieval_embeddings()
    demo_task_types()
  end

  # Demo 1: Simple Embedding
  defp demo_simple_embedding do
    section_header("1. Simple Text Embedding")

    text = "What is the meaning of life?"
    IO.puts("Text: \"#{text}\"\n")

    case Coordinator.embed_content(text) do
      {:ok, response} ->
        values = EmbedContentResponse.get_values(response)
        dimensionality = length(values)

        IO.puts("✓ Embedding generated successfully!")
        IO.puts("  Dimensionality: #{dimensionality}")
        IO.puts("  First 5 values: #{inspect(Enum.take(values, 5))}")
        IO.puts("  Last 5 values:  #{inspect(Enum.take(values, -5))}")
        {:ok, response}

      {:error, reason} ->
        IO.puts("✗ Error: #{inspect(reason)}")
        {:error, reason}
    end

    IO.puts("")
  end

  # Demo 2: Semantic Similarity
  defp demo_semantic_similarity do
    section_header("2. Semantic Similarity Comparison")

    texts = [
      "The cat sat on the mat",
      "A feline rested on the rug",
      "Python is a programming language"
    ]

    IO.puts("Comparing semantic similarity between:")

    Enum.with_index(texts, 1)
    |> Enum.each(fn {text, idx} ->
      IO.puts("  #{idx}. \"#{text}\"")
    end)

    IO.puts("")

    case Coordinator.batch_embed_contents(texts, task_type: :semantic_similarity) do
      {:ok, response} ->
        embeddings = response.embeddings

        IO.puts("✓ Embeddings generated successfully!\n")
        IO.puts("Similarity Matrix:")
        IO.puts("                    Text 1    Text 2    Text 3")

        Enum.with_index(embeddings, 1)
        |> Enum.each(fn {emb1, idx1} ->
          similarities =
            embeddings
            |> Enum.map(fn emb2 ->
              case ContentEmbedding.cosine_similarity(emb1, emb2) do
                {:error, _} -> 0.0
                similarity -> similarity
              end
            end)
            |> Enum.map(&:io_lib.format("~6.3f", [&1]))
            |> Enum.join("    ")

          IO.puts("Text #{idx1}:             #{similarities}")
        end)

        IO.puts("\nInterpretation:")
        IO.puts("  - Values close to 1.0 = very similar")
        IO.puts("  - Values close to 0.0 = unrelated")
        IO.puts("  - Values close to -1.0 = opposite meaning")

      {:error, reason} ->
        IO.puts("✗ Error: #{inspect(reason)}")
    end

    IO.puts("")
  end

  # Demo 3: Batch Embedding
  defp demo_batch_embedding do
    section_header("3. Batch Embedding (Efficient)")

    questions = [
      "What is artificial intelligence?",
      "How does machine learning work?",
      "Explain neural networks",
      "What are transformers in AI?",
      "Define deep learning"
    ]

    IO.puts("Embedding #{length(questions)} questions in a single batch:\n")

    Enum.with_index(questions, 1)
    |> Enum.each(fn {q, idx} ->
      IO.puts("  #{idx}. #{q}")
    end)

    IO.puts("")

    start_time = System.monotonic_time(:millisecond)

    case Coordinator.batch_embed_contents(questions, task_type: :question_answering) do
      {:ok, response} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        all_values = BatchEmbedContentsResponse.get_all_values(response)

        IO.puts("✓ Batch embedding completed!")
        IO.puts("  Total embeddings: #{length(all_values)}")
        IO.puts("  Time taken: #{duration}ms")
        IO.puts("  Average per embedding: #{div(duration, length(questions))}ms")

        # Show dimensionality
        if length(all_values) > 0 do
          IO.puts("  Embedding dimensionality: #{length(Enum.at(all_values, 0))}")
        end

      {:error, reason} ->
        IO.puts("✗ Error: #{inspect(reason)}")
    end

    IO.puts("")
  end

  # Demo 4: Retrieval Document Embeddings
  defp demo_retrieval_embeddings do
    section_header("4. Document Retrieval Embeddings")

    documents = [
      {"Introduction to AI",
       "Artificial Intelligence is the simulation of human intelligence..."},
      {"Machine Learning Basics", "Machine learning is a subset of AI that learns from data..."},
      {"Neural Network Overview",
       "Neural networks are computing systems inspired by biological neural networks..."}
    ]

    IO.puts("Embedding documents with titles for retrieval:\n")

    Enum.with_index(documents, 1)
    |> Enum.each(fn {{title, content}, idx} ->
      IO.puts("  #{idx}. #{title}")
      IO.puts("     \"#{String.slice(content, 0, 50)}...\"\n")

      case Coordinator.embed_content(
             content,
             task_type: :retrieval_document,
             title: title
           ) do
        {:ok, response} ->
          values = EmbedContentResponse.get_values(response)
          IO.puts("     ✓ Embedded (#{length(values)} dimensions)\n")

        {:error, reason} ->
          IO.puts("     ✗ Error: #{inspect(reason)}\n")
      end
    end)

    # Now embed a query
    query = "How do neural networks learn?"
    IO.puts("Query: \"#{query}\"\n")

    case Coordinator.embed_content(query, task_type: :retrieval_query) do
      {:ok, response} ->
        values = EmbedContentResponse.get_values(response)
        IO.puts("✓ Query embedded (#{length(values)} dimensions)")
        IO.puts("  Ready for similarity comparison with document embeddings!")

      {:error, reason} ->
        IO.puts("✗ Error: #{inspect(reason)}")
    end

    IO.puts("")
  end

  # Demo 5: Different Task Types
  defp demo_task_types do
    section_header("5. Task Type Optimization")

    text = "Climate change is a pressing global issue that requires immediate action."

    task_types = [
      {:retrieval_query, "Optimized for search queries"},
      {:semantic_similarity, "Optimized for similarity comparison"},
      {:classification, "Optimized for categorization"},
      {:clustering, "Optimized for grouping similar items"}
    ]

    IO.puts("Embedding the same text with different task types:\n")
    IO.puts("Text: \"#{text}\"\n")

    Enum.each(task_types, fn {task_type, description} ->
      case Coordinator.embed_content(text, task_type: task_type) do
        {:ok, response} ->
          values = EmbedContentResponse.get_values(response)
          IO.puts("✓ #{task_type}")
          IO.puts("  #{description}")
          IO.puts("  Dimensionality: #{length(values)}")
          IO.puts("  Sample: #{inspect(Enum.take(values, 3))}\n")

        {:error, reason} ->
          IO.puts("✗ #{task_type}: #{inspect(reason)}\n")
      end
    end)

    IO.puts("Note: Task type helps optimize embeddings for specific use cases.")
    IO.puts("")
  end

  # Helper: Section header
  defp section_header(title) do
    IO.puts(String.duplicate("-", 80))
    IO.puts(title)
    IO.puts(String.duplicate("-", 80))
    IO.puts("")
  end
end

# Run the demo
EmbeddingDemo.run()

IO.puts(String.duplicate("=", 80))
IO.puts("DEMO COMPLETE")
IO.puts(String.duplicate("=", 80))

IO.puts("""

Key Takeaways:
  1. Simple embedding: embed_content/2 for single texts
  2. Batch embedding: batch_embed_contents/2 for multiple texts (more efficient)
  3. Task types: Optimize embeddings for specific use cases
  4. Similarity: Use cosine_similarity/2 to compare embeddings
  5. Retrieval: Use :retrieval_document for docs and :retrieval_query for queries

For more information, see the Gemini API documentation.
""")
