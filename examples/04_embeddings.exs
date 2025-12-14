# Embeddings Example
# Run with: mix run examples/04_embeddings.exs
#
# Demonstrates:
# - Single text embedding generation
# - Batch embeddings for multiple texts
# - Semantic similarity calculation
# - Different task types (retrieval, classification, clustering)

defmodule EmbeddingsExample do
  alias Gemini.Types.Response.{EmbedContentResponse, BatchEmbedContentsResponse, ContentEmbedding}

  def run do
    print_header("TEXT EMBEDDINGS")

    check_auth!()

    demo_single_embedding()
    demo_semantic_similarity()
    demo_batch_embeddings()
    demo_task_types()

    print_footer()
  end

  # ============================================================
  # Demo 1: Single Text Embedding
  # ============================================================
  defp demo_single_embedding do
    print_section("1. Single Text Embedding")

    text = "Elixir is a functional programming language built on the Erlang VM."

    IO.puts("TEXT:")
    IO.puts("  #{text}")
    IO.puts("")

    case Gemini.embed_content(text) do
      {:ok, response} ->
        values = EmbedContentResponse.get_values(response)
        dimensionality = length(values)

        IO.puts("EMBEDDING GENERATED:")
        IO.puts("  Dimensionality: #{dimensionality}")
        IO.puts("  First 5 values: #{format_floats(Enum.take(values, 5))}")
        IO.puts("  Last 5 values:  #{format_floats(Enum.take(values, -5))}")
        IO.puts("")

        # Calculate L2 norm (magnitude)
        magnitude = :math.sqrt(Enum.reduce(values, 0, fn v, acc -> acc + v * v end))
        IO.puts("  Vector magnitude: #{Float.round(magnitude, 4)}")
        IO.puts("")
        IO.puts("[OK] Single embedding generated successfully")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Semantic Similarity Comparison
  # ============================================================
  defp demo_semantic_similarity do
    print_section("2. Semantic Similarity Comparison")

    texts = [
      "The cat sat on the mat",
      "A feline rested on the rug",
      "Python is a programming language"
    ]

    IO.puts("COMPARING TEXTS:")

    Enum.with_index(texts, 1)
    |> Enum.each(fn {text, idx} ->
      IO.puts("  #{idx}. \"#{text}\"")
    end)

    IO.puts("")

    case Gemini.batch_embed_contents(texts, task_type: :semantic_similarity) do
      {:ok, response} ->
        embeddings = response.embeddings

        IO.puts("SIMILARITY MATRIX:")
        IO.puts("                       Text 1    Text 2    Text 3")

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
            |> Enum.map(&:io_lib.format("~7.3f", [&1]))
            |> Enum.join("   ")

          IO.puts("  Text #{idx1}:            #{similarities}")
        end)

        IO.puts("")
        IO.puts("INTERPRETATION:")
        IO.puts("  - 1.000 = identical (diagonal)")
        IO.puts("  - ~0.8+ = semantically similar (Text 1 & 2)")
        IO.puts("  - ~0.3  = unrelated topics (Text 3 vs others)")
        IO.puts("")
        IO.puts("[OK] Similarity comparison complete")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 3: Batch Embeddings (Efficient)
  # ============================================================
  defp demo_batch_embeddings do
    print_section("3. Batch Embeddings (Efficient)")

    documents = [
      "What is machine learning?",
      "How do neural networks work?",
      "Explain deep learning",
      "What are transformers?",
      "Define reinforcement learning"
    ]

    IO.puts("BATCH REQUEST (#{length(documents)} texts):")

    Enum.with_index(documents, 1)
    |> Enum.each(fn {doc, idx} ->
      IO.puts("  #{idx}. #{doc}")
    end)

    IO.puts("")

    start_time = System.monotonic_time(:millisecond)

    case Gemini.batch_embed_contents(documents) do
      {:ok, response} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        all_values = BatchEmbedContentsResponse.get_all_values(response)

        IO.puts("BATCH RESULTS:")
        IO.puts("  Embeddings generated: #{length(all_values)}")
        IO.puts("  Time taken: #{duration}ms")
        IO.puts("  Average per embedding: #{Float.round(duration / length(documents), 1)}ms")

        if length(all_values) > 0 do
          IO.puts("  Dimensionality: #{length(Enum.at(all_values, 0))}")
        end

        IO.puts("")
        IO.puts("[OK] Batch embeddings complete - much faster than individual requests!")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 4: Different Task Types
  # ============================================================
  defp demo_task_types do
    print_section("4. Embedding Task Types")

    text = "Climate change requires global cooperation and immediate action."

    task_types = [
      {:retrieval_query, "Optimized for search queries"},
      {:retrieval_document, "Optimized for documents to be searched"},
      {:semantic_similarity, "Optimized for comparing meaning"},
      {:classification, "Optimized for categorization"},
      {:clustering, "Optimized for grouping similar items"}
    ]

    IO.puts("TEXT:")
    IO.puts("  \"#{text}\"")
    IO.puts("")
    IO.puts("EMBEDDINGS BY TASK TYPE:")
    IO.puts("")

    Enum.each(task_types, fn {task_type, description} ->
      case Gemini.embed_content(text, task_type: task_type) do
        {:ok, response} ->
          values = EmbedContentResponse.get_values(response)
          IO.puts("  #{task_type}:")
          IO.puts("    #{description}")
          IO.puts("    Dimensions: #{length(values)}")
          IO.puts("    Sample: #{format_floats(Enum.take(values, 3))}...")
          IO.puts("")

        {:error, error} ->
          IO.puts("  #{task_type}: [ERROR] #{inspect(error)}")
          IO.puts("")
      end
    end)

    IO.puts("NOTE: Different task types optimize embeddings for specific use cases.")
    IO.puts("      Use :retrieval_query for search queries and :retrieval_document for docs.")
    IO.puts("")
    IO.puts("[OK] Task types demonstration complete")
    IO.puts("")
  end

  # ============================================================
  # Helper Functions
  # ============================================================
  defp format_floats(list) do
    list
    |> Enum.map(&Float.round(&1, 4))
    |> inspect()
  end

  defp check_auth! do
    cond do
      System.get_env("GEMINI_API_KEY") ->
        key = System.get_env("GEMINI_API_KEY")
        masked = String.slice(key, 0, 4) <> "..." <> String.slice(key, -4, 4)
        IO.puts("AUTH: Using Gemini API Key (#{masked})")
        IO.puts("")

      System.get_env("VERTEX_JSON_FILE") || System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ->
        IO.puts("AUTH: Using Vertex AI / Application Default Credentials")
        IO.puts("")

      true ->
        IO.puts("[ERROR] No authentication configured!")
        IO.puts("Set GEMINI_API_KEY or VERTEX_JSON_FILE environment variable.")
        System.halt(1)
    end
  end

  defp print_header(title) do
    IO.puts("")
    IO.puts(String.duplicate("=", 70))
    IO.puts("  #{title}")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end

  defp print_section(title) do
    IO.puts(String.duplicate("-", 70))
    IO.puts(title)
    IO.puts(String.duplicate("-", 70))
    IO.puts("")
  end

  defp print_footer do
    IO.puts(String.duplicate("=", 70))
    IO.puts("  EXAMPLE COMPLETE")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end
end

EmbeddingsExample.run()
