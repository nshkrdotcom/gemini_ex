#!/usr/bin/env elixir

# Async Batch Embedding Demo
#
# Demonstrates production-scale async batch embedding with 50% cost savings.
# This example shows the complete workflow: submit, poll, and retrieve embeddings.
#
# Run with:
#   mix run examples/async_batch_embedding_demo.exs  (within project)
#   elixir examples/async_batch_embedding_demo.exs   (standalone)
#
# Requirements:
# - GEMINI_API_KEY environment variable set
# - Active internet connection

# Only use Mix.install when running standalone (not in a Mix project)
unless Code.ensure_loaded?(Mix.Project) && Mix.Project.get() do
  Mix.install([
    {:gemini_ex, path: Path.expand("..", __DIR__)}
  ])
end

alias Gemini.Types.Response.{EmbedContentBatchStats, ContentEmbedding}

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("Async Batch Embedding Demo - Production Scale with 50% Cost Savings")
IO.puts(String.duplicate("=", 80) <> "\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("❌ Error: GEMINI_API_KEY environment variable not set")
    IO.puts("\nPlease set your API key:")
    IO.puts("  export GEMINI_API_KEY='your-api-key-here'")
    System.halt(1)

  api_key ->
    masked_key = String.slice(api_key, 0..7) <> "..." <> String.slice(api_key, -4..-1)
    IO.puts("✓ Using API key: #{masked_key}\n")
end

# Sample dataset: Knowledge base articles for RAG system
sample_texts = [
  "Elixir is a functional, concurrent programming language that runs on the Erlang VM. It provides excellent support for building scalable and maintainable applications.",
  "Phoenix Framework is a web framework for Elixir that provides real-time features through WebSockets and Channels. It's known for high performance and developer productivity.",
  "GenServer is a behavior module for implementing the server of a client-server relation. It provides a standard interface for building concurrent applications in Elixir.",
  "OTP (Open Telecom Platform) is a set of Erlang libraries and design principles for building robust, fault-tolerant applications. Elixir leverages OTP extensively.",
  "Pattern matching in Elixir is a powerful feature that allows you to destructure data and match against specific patterns in function clauses and case statements.",
  "Supervisors in Elixir provide fault tolerance by monitoring processes and restarting them if they crash, following the 'let it crash' philosophy.",
  "Ecto is Elixir's database wrapper and query generator. It provides a composable query API and supports migrations, validations, and associations.",
  "LiveView enables rich, real-time user experiences with server-rendered HTML. It minimizes the need for JavaScript while providing interactive features.",
  "Mix is Elixir's build tool that provides tasks for creating, compiling, testing, and managing dependencies for Elixir projects.",
  "Plug is a specification for composable modules in web applications. It provides a unified API for building web apps and servers in Elixir."
]

IO.puts("📊 Dataset Information:")
IO.puts("  - Documents: #{length(sample_texts)}")
IO.puts("  - Use case: Knowledge base for RAG system")
IO.puts("  - Task type: RETRIEVAL_DOCUMENT (optimized for indexing)")
IO.puts("  - Dimensions: 768 (recommended for storage/quality balance)")
IO.puts("")

# Step 1: Submit Async Batch
IO.puts("🚀 Step 1: Submitting Async Batch Job")
IO.puts(String.duplicate("-", 80))

submit_start = System.monotonic_time(:millisecond)

case Gemini.async_batch_embed_contents(
       sample_texts,
       display_name: "Elixir Knowledge Base Index",
       task_type: :retrieval_document,
       output_dimensionality: 768,
       priority: 0
     ) do
  {:ok, batch} ->
    submit_time = System.monotonic_time(:millisecond) - submit_start

    IO.puts("✅ Batch submitted successfully!")
    IO.puts("  - Batch ID: #{batch.name}")
    IO.puts("  - Display Name: #{batch.display_name}")
    IO.puts("  - Model: #{batch.model}")
    IO.puts("  - State: #{batch.state}")
    IO.puts("  - Priority: #{batch.priority}")
    IO.puts("  - Submission time: #{submit_time}ms")
    IO.puts("")

    # Calculate cost savings
    interactive_cost = length(sample_texts) * 1.0
    async_cost = length(sample_texts) * 0.5
    savings = interactive_cost - async_cost
    savings_percent = savings / interactive_cost * 100

    IO.puts("💰 Cost Analysis (relative units):")
    IO.puts("  - Interactive API cost: #{interactive_cost}")
    IO.puts("  - Async batch cost: #{async_cost}")
    IO.puts("  - Savings: #{savings} (#{Float.round(savings_percent)}% reduction)")
    IO.puts("")

    # Step 2: Poll for Status with Progress Tracking
    IO.puts("⏳ Step 2: Polling for Completion with Progress Tracking")
    IO.puts(String.duplicate("-", 80))
    IO.puts("Note: This demo polls quickly for testing. In production, use longer intervals.")
    IO.puts("")

    max_polls = 60
    poll_interval = 2_000

    poll_start = System.monotonic_time(:millisecond)

    case Gemini.await_batch_completion(
           batch.name,
           poll_interval: poll_interval,
           timeout: max_polls * poll_interval,
           on_progress: fn updated_batch ->
             if updated_batch.batch_stats do
               stats = updated_batch.batch_stats
               progress = EmbedContentBatchStats.progress_percentage(stats)

               IO.write(
                 "\r  [#{updated_batch.state}] Progress: #{Float.round(progress, 1)}% " <>
                   "(#{stats.successful_request_count || 0} success, " <>
                   "#{stats.failed_request_count || 0} failed, " <>
                   "#{stats.pending_request_count || 0} pending)    "
               )
             end
           end
         ) do
      {:ok, completed_batch} ->
        poll_time = System.monotonic_time(:millisecond) - poll_start

        IO.puts("\n\n✅ Batch completed!")
        IO.puts("  - Final state: #{completed_batch.state}")
        IO.puts("  - Total polling time: #{Float.round(poll_time / 1000, 2)}s")

        if completed_batch.create_time do
          IO.puts("  - Created at: #{completed_batch.create_time}")
        end

        if completed_batch.end_time do
          IO.puts("  - Completed at: #{completed_batch.end_time}")
        end

        IO.puts("")

        # Display final statistics
        if completed_batch.batch_stats do
          stats = completed_batch.batch_stats

          IO.puts("📈 Final Statistics:")
          IO.puts("  - Total requests: #{stats.request_count}")
          IO.puts("  - Successful: #{stats.successful_request_count || 0}")
          IO.puts("  - Failed: #{stats.failed_request_count || 0}")

          IO.puts(
            "  - Success rate: #{Float.round(EmbedContentBatchStats.success_rate(stats), 1)}%"
          )

          if stats.failed_request_count && stats.failed_request_count > 0 do
            IO.puts(
              "  - Failure rate: #{Float.round(EmbedContentBatchStats.failure_rate(stats), 1)}%"
            )
          end

          IO.puts("")
        end

        # Step 3: Retrieve Embeddings
        IO.puts("📦 Step 3: Retrieving Embeddings")
        IO.puts(String.duplicate("-", 80))

        case Gemini.get_batch_embeddings(completed_batch) do
          {:ok, embeddings} ->
            IO.puts("✅ Retrieved #{length(embeddings)} embeddings")
            IO.puts("")

            # Analyze embeddings
            IO.puts("🔍 Embedding Analysis:")

            if length(embeddings) > 0 do
              first_embedding = List.first(embeddings)
              dimensions = ContentEmbedding.dimensionality(first_embedding)
              norm = ContentEmbedding.norm(first_embedding)

              IO.puts("  - Dimensions: #{dimensions}")
              IO.puts("  - L2 norm (first): #{Float.round(norm, 6)}")

              # Check if normalization needed
              if dimensions != 3072 do
                IO.puts(
                  "  ⚠️  Normalization required for #{dimensions}d embeddings before similarity!"
                )

                normalized = ContentEmbedding.normalize(first_embedding)
                normalized_norm = ContentEmbedding.norm(normalized)
                IO.puts("  - Normalized norm: #{Float.round(normalized_norm, 6)} (should be 1.0)")
              else
                IO.puts("  ✓ 3072d embeddings are pre-normalized by API")
              end

              IO.puts("")

              # Demonstrate similarity calculation
              if length(embeddings) >= 2 do
                IO.puts("🔗 Similarity Demonstration:")

                emb1 = ContentEmbedding.normalize(Enum.at(embeddings, 0))
                emb2 = ContentEmbedding.normalize(Enum.at(embeddings, 1))
                emb3 = ContentEmbedding.normalize(Enum.at(embeddings, 5))

                sim_12 = ContentEmbedding.cosine_similarity(emb1, emb2)
                sim_13 = ContentEmbedding.cosine_similarity(emb1, emb3)

                IO.puts("  - Text 1 (Elixir) vs Text 2 (Phoenix): #{Float.round(sim_12, 4)}")
                IO.puts("  - Text 1 (Elixir) vs Text 6 (Supervisors): #{Float.round(sim_13, 4)}")
                IO.puts("")

                if sim_12 > sim_13 do
                  IO.puts("  ✓ Related concepts (Elixir/Phoenix) show higher similarity")
                end
              end

              # Storage calculation
              bytes_per_float = 4
              storage_per_embedding = dimensions * bytes_per_float
              total_storage = length(embeddings) * storage_per_embedding

              IO.puts("💾 Storage Analysis:")

              IO.puts(
                "  - Per embedding: #{storage_per_embedding} bytes (#{dimensions} × 4 bytes)"
              )

              IO.puts(
                "  - Total storage: #{total_storage} bytes (#{Float.round(total_storage / 1024, 2)} KB)"
              )

              if dimensions == 768 do
                full_storage = length(embeddings) * 3072 * bytes_per_float

                savings = full_storage - total_storage
                savings_percent = savings / full_storage * 100

                IO.puts(
                  "  - Storage savings vs 3072d: #{savings} bytes (#{Float.round(savings_percent)}%)"
                )
              end

              IO.puts("")
            end

            # Success summary
            IO.puts("🎉 Success Summary:")
            IO.puts("  ✓ Batch submitted successfully")
            IO.puts("  ✓ Progress tracked in real-time")
            IO.puts("  ✓ Embeddings retrieved and analyzed")
            IO.puts("  ✓ 50% cost savings achieved")
            IO.puts("")

            # Production recommendations
            IO.puts("🚀 Production Recommendations:")
            IO.puts("  1. Use poll_interval: 10_000+ (10+ seconds) for large batches")
            IO.puts("  2. Set appropriate timeout based on batch size")
            IO.puts("  3. Store batch.name for asynchronous retrieval")
            IO.puts("  4. Normalize embeddings before similarity calculations")
            IO.puts("  5. Monitor batch_stats for failure tracking")
            IO.puts("")

          {:error, reason} ->
            IO.puts("❌ Failed to retrieve embeddings: #{inspect(reason)}")
            IO.puts("")
        end

      {:error, :timeout} ->
        IO.puts("\n\n⏱️  Polling timed out")
        IO.puts("  - This is normal for large batches")
        IO.puts("  - In production, store the batch.name and poll later")
        IO.puts("  - Use get_batch_status/1 to check progress asynchronously")
        IO.puts("")

      {:error, reason} ->
        IO.puts("\n\n❌ Polling failed: #{inspect(reason)}")
        IO.puts("")
    end

  {:error, %ArgumentError{message: message}} ->
    IO.puts("❌ Argument error: #{message}")
    IO.puts("")

  {:error, reason} ->
    IO.puts("❌ Failed to submit batch: #{inspect(reason)}")
    IO.puts("")
    IO.puts("Common issues:")
    IO.puts("  - API key invalid or expired")
    IO.puts("  - Network connectivity problem")
    IO.puts("  - API rate limit exceeded")
    IO.puts("")
end

IO.puts(String.duplicate("=", 80))
IO.puts("Demo completed!")
IO.puts(String.duplicate("=", 80) <> "\n")
