#!/usr/bin/env elixir

# Production-Scale Async Batch Embedding Demo
#
# Demonstrates realistic production scenarios for async batch embedding:
# - Large-scale knowledge base indexing
# - Error handling and retry strategies
# - Cost-effective batch processing
# - Asynchronous workflow patterns
#
# Run with:
#   mix run examples/async_batch_production_demo.exs  (within project)
#   elixir examples/async_batch_production_demo.exs   (standalone)
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
IO.puts("Production-Scale Async Batch Embedding Demo")
IO.puts(String.duplicate("=", 80) <> "\n")

# Check for API key
case System.get_env("GEMINI_API_KEY") do
  nil ->
    IO.puts("❌ Error: GEMINI_API_KEY environment variable not set")
    System.halt(1)

  api_key ->
    masked_key = String.slice(api_key, 0..7) <> "..." <> String.slice(api_key, -4..-1)
    IO.puts("✓ Using API key: #{masked_key}\n")
end

# Production Scenario: Building a comprehensive knowledge base
IO.puts("📚 Scenario: Building Technical Documentation Search Index")
IO.puts(String.duplicate("-", 80))
IO.puts("")

# Simulated large dataset (in production, this could be 1000s-millions of docs)
documentation_corpus = [
  # Elixir Language Docs
  "Elixir is a dynamic, functional language designed for building scalable and maintainable applications. It leverages the Erlang VM, known for running low-latency, distributed, and fault-tolerant systems.",
  "Pattern matching is one of Elixir's most powerful features. It allows you to match against data structures and extract values in a declarative way, making code more readable and concise.",
  "The pipe operator |> takes the output of one expression and passes it as the first argument to the next function. This creates clean, readable data transformation pipelines.",
  "Processes are the foundation of concurrency in Elixir. They are lightweight, isolated, and communicate via message passing, following the Actor model of computation.",
  "Supervisors implement the 'let it crash' philosophy by monitoring child processes and restarting them according to defined strategies when they fail.",

  # Phoenix Framework Docs
  "Phoenix Framework provides a productive development experience for building rich, interactive web applications. It leverages Elixir's performance characteristics and OTP patterns.",
  "Phoenix Channels enable bidirectional, real-time communication between clients and servers. They're built on top of WebSockets with fallback to long-polling.",
  "Phoenix LiveView allows you to build rich, real-time experiences with server-rendered HTML. Updates are pushed to the client over a persistent connection.",
  "Contexts in Phoenix are dedicated modules that expose and group related functionality. They provide clear boundaries between different parts of your application.",
  "Phoenix uses a layered architecture: Router -> Controller -> Context -> Schema. This separation of concerns makes applications more maintainable.",

  # Ecto Database Library Docs
  "Ecto is Elixir's database wrapper and integrated query language. It provides a standardized API for interacting with databases and emphasizes explicit, composable queries.",
  "Ecto Schemas define the mapping between your Elixir structs and database tables. They specify field types, associations, and validation rules.",
  "Ecto Changesets provide a way to filter, cast, validate, and define constraints on data before it's inserted or updated in the database.",
  "Ecto Queries are composable, allowing you to build complex database queries by combining smaller query fragments. The query syntax is converted to SQL at compile time.",
  "Ecto Migrations provide a way to modify your database schema over time in a consistent and reversible way. They're version-controlled with your application code.",

  # OTP Design Patterns
  "GenServer is a behaviour module for implementing the server part of a client-server relation. It provides a standard set of interface functions and includes common functionality.",
  "GenStage and Flow provide back-pressure and allow for concurrent, multi-stage data processing pipelines with proper resource management.",
  "Agents provide a simple abstraction around state. They're useful when you only need to store state without complex behavior logic.",
  "Tasks are used for one-off computations. They can be awaited for their result or used in a fire-and-forget manner for background processing.",
  "The Registry module provides a local, decentralized, and scalable key-value process storage. It's useful for process discovery and pub-sub patterns."
]

IO.puts("Dataset characteristics:")
IO.puts("  - Total documents: #{length(documentation_corpus)}")
IO.puts("  - Categories: Language, Framework, Database, Patterns")
IO.puts("  - Use case: Technical documentation search and retrieval")
IO.puts("  - Target: RAG system for developer Q&A")
IO.puts("")

# Demonstrate cost calculation
interactive_cost = length(documentation_corpus) * 1.0
async_cost = length(documentation_corpus) * 0.5
savings = interactive_cost - async_cost

IO.puts("💰 Cost Comparison (relative units):")
IO.puts("  - Interactive API: #{interactive_cost} units")
IO.puts("  - Async Batch API: #{async_cost} units")
IO.puts("  - Savings: #{savings} units (50% reduction)")
IO.puts("  - For 1M documents: Save ~500K units!")
IO.puts("")

# Strategy 1: Submit and Store for Async Retrieval
IO.puts("🎯 Strategy 1: Submit and Store (Non-blocking Pattern)")
IO.puts(String.duplicate("-", 80))

case Gemini.async_batch_embed_contents(
       documentation_corpus,
       display_name: "Technical Docs Index - #{DateTime.utc_now() |> DateTime.to_unix()}",
       task_type: :retrieval_document,
       output_dimensionality: 768,
       priority: 5
     ) do
  {:ok, batch} ->
    IO.puts("✅ Batch submitted successfully")
    IO.puts("  - Batch ID: #{batch.name}")
    IO.puts("  - State: #{batch.state}")
    IO.puts("")

    # In production: Store this batch ID in your database
    IO.puts("📝 Production Pattern:")
    IO.puts("  1. Store batch.name in your database: \"#{batch.name}\"")
    IO.puts("  2. Return immediately to user (non-blocking)")
    IO.puts("  3. Set up background job to poll status")
    IO.puts("  4. Notify user when complete via webhook/notification")
    IO.puts("")

    # Strategy 2: Active Polling with Progress Tracking
    IO.puts("🎯 Strategy 2: Active Polling with Progress Monitoring")
    IO.puts(String.duplicate("-", 80))

    poll_start = System.monotonic_time(:millisecond)
    last_progress = 0

    result =
      Gemini.await_batch_completion(
        batch.name,
        poll_interval: 2_000,
        timeout: 120_000,
        on_progress: fn updated_batch ->
          if updated_batch.batch_stats do
            stats = updated_batch.batch_stats
            progress = EmbedContentBatchStats.progress_percentage(stats)

            # Only print when progress changes significantly
            if abs(progress - last_progress) >= 5 do
              IO.puts(
                "  [#{DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()}] " <>
                  "State: #{updated_batch.state} | " <>
                  "Progress: #{Float.round(progress, 1)}% | " <>
                  "Success: #{stats.successful_request_count || 0} | " <>
                  "Failed: #{stats.failed_request_count || 0} | " <>
                  "Pending: #{stats.pending_request_count || 0}"
              )
            end
          end
        end
      )

    poll_duration = System.monotonic_time(:millisecond) - poll_start

    case result do
      {:ok, completed_batch} ->
        IO.puts("")
        IO.puts("✅ Batch completed in #{Float.round(poll_duration / 1000, 2)}s")
        IO.puts("")

        # Detailed final analysis
        if completed_batch.batch_stats do
          stats = completed_batch.batch_stats

          IO.puts("📊 Final Statistics:")
          IO.puts("  - Total requests: #{stats.request_count}")
          IO.puts("  - Successful: #{stats.successful_request_count || 0}")
          IO.puts("  - Failed: #{stats.failed_request_count || 0}")

          IO.puts(
            "  - Success rate: #{Float.round(EmbedContentBatchStats.success_rate(stats), 2)}%"
          )

          if stats.failed_request_count && stats.failed_request_count > 0 do
            IO.puts("")
            IO.puts("⚠️  Error Handling Strategy:")
            IO.puts("  1. Identify failed requests from batch output")
            IO.puts("  2. Retry failed requests individually or in new batch")
            IO.puts("  3. Log errors for monitoring and debugging")
            IO.puts("  4. Consider exponential backoff for retries")
          end

          IO.puts("")
        end

        # Retrieve and analyze embeddings
        case Gemini.get_batch_embeddings(completed_batch) do
          {:ok, embeddings} ->
            IO.puts("📦 Embedding Retrieval:")
            IO.puts("  - Retrieved: #{length(embeddings)} embeddings")
            IO.puts("  - Dimensions: #{ContentEmbedding.dimensionality(List.first(embeddings))}")
            IO.puts("")

            # Normalize all embeddings for production use
            IO.puts("🔧 Production Processing:")
            IO.puts("  - Normalizing all embeddings for similarity calculations...")

            normalized_embeddings = Enum.map(embeddings, &ContentEmbedding.normalize/1)

            IO.puts("  ✓ All embeddings normalized")
            IO.puts("")

            # Demonstrate semantic search capability
            IO.puts("🔍 Semantic Search Demo:")

            # Query: "How do I handle state in Elixir?"
            # Should match Agent and GenServer docs
            query_text = "How do I handle state in Elixir?"
            IO.puts("  Query: \"#{query_text}\"")
            IO.puts("")

            case Gemini.embed_content(query_text,
                   task_type: :retrieval_query,
                   output_dimensionality: 768
                 ) do
              {:ok, query_response} ->
                query_embedding = ContentEmbedding.normalize(query_response.embedding)

                # Calculate similarities
                similarities =
                  normalized_embeddings
                  |> Enum.with_index()
                  |> Enum.map(fn {doc_embedding, idx} ->
                    sim = ContentEmbedding.cosine_similarity(query_embedding, doc_embedding)
                    {idx, sim}
                  end)
                  |> Enum.sort_by(fn {_idx, sim} -> sim end, :desc)
                  |> Enum.take(3)

                IO.puts("  Top 3 matches:")

                Enum.each(similarities, fn {idx, sim} ->
                  doc_preview = String.slice(Enum.at(documentation_corpus, idx), 0..80) <> "..."

                  IO.puts(
                    "    #{idx + 1}. Similarity: #{Float.round(sim, 4)} - \"#{doc_preview}\""
                  )
                end)

                IO.puts("")

              {:error, reason} ->
                IO.puts("  ❌ Query embedding failed: #{inspect(reason)}")
                IO.puts("")
            end

            # Performance summary
            IO.puts("⚡ Performance Summary:")
            IO.puts("  - Batch processing time: #{Float.round(poll_duration / 1000, 2)}s")

            IO.puts(
              "  - Average time per doc: #{Float.round(poll_duration / length(documentation_corpus), 0)}ms"
            )

            IO.puts("  - Cost savings: 50%")
            IO.puts("  - Ready for semantic search: ✓")
            IO.puts("")

            # Storage and scalability
            bytes_per_float = 4
            dimensions = ContentEmbedding.dimensionality(List.first(embeddings))
            storage_per_embedding = dimensions * bytes_per_float
            total_storage = length(embeddings) * storage_per_embedding

            IO.puts("💾 Storage & Scalability:")
            IO.puts("  - Current batch: #{Float.round(total_storage / 1024, 2)} KB")

            IO.puts(
              "  - For 1M docs (768d): #{Float.round(1_000_000 * storage_per_embedding / 1024 / 1024, 2)} MB"
            )

            IO.puts(
              "  - For 1M docs (3072d): #{Float.round(1_000_000 * 3072 * 4 / 1024 / 1024, 2)} MB"
            )

            IO.puts("  - Storage savings (768d): 75%")
            IO.puts("")

          {:error, reason} ->
            IO.puts("❌ Failed to retrieve embeddings: #{inspect(reason)}")
            IO.puts("")
        end

      {:error, :timeout} ->
        IO.puts("")
        IO.puts("⏱️  Batch processing exceeded timeout")
        IO.puts("")
        IO.puts("💡 Production Handling:")
        IO.puts("  1. Store the batch ID for later retrieval")
        IO.puts("  2. Set up periodic polling (e.g., every 1-5 minutes)")
        IO.puts("  3. Send notification when complete")
        IO.puts("  4. Implement exponential backoff for polling")
        IO.puts("")

        # Show how to check status asynchronously
        case Gemini.get_batch_status(batch.name) do
          {:ok, status_batch} ->
            IO.puts("Current status check:")
            IO.puts("  - State: #{status_batch.state}")

            if status_batch.batch_stats do
              progress = EmbedContentBatchStats.progress_percentage(status_batch.batch_stats)
              IO.puts("  - Progress: #{Float.round(progress, 1)}%")
            end

            IO.puts("")

          {:error, reason} ->
            IO.puts("Status check failed: #{inspect(reason)}")
            IO.puts("")
        end

      {:error, reason} ->
        IO.puts("")
        IO.puts("❌ Polling failed: #{inspect(reason)}")
        IO.puts("")
    end

  {:error, reason} ->
    IO.puts("❌ Failed to submit batch: #{inspect(reason)}")
    IO.puts("")
end

# Production best practices summary
IO.puts(String.duplicate("=", 80))
IO.puts("🎓 Production Best Practices")
IO.puts(String.duplicate("=", 80))
IO.puts("")

IO.puts("1. Cost Optimization:")
IO.puts("   - Use async batch API for non-urgent, large-scale indexing")
IO.puts("   - Achieve 50% cost savings vs interactive API")
IO.puts("   - Batch 1000s-millions of documents efficiently")
IO.puts("")

IO.puts("2. Workflow Pattern:")
IO.puts("   - Submit batch and store batch.name in database")
IO.puts("   - Return immediately (non-blocking for users)")
IO.puts("   - Poll status asynchronously with background jobs")
IO.puts("   - Use webhooks or notifications for completion alerts")
IO.puts("")

IO.puts("3. Error Handling:")
IO.puts("   - Monitor batch_stats for failure tracking")
IO.puts("   - Implement retry logic for failed requests")
IO.puts("   - Use exponential backoff for retries")
IO.puts("   - Log errors for debugging and monitoring")
IO.puts("")

IO.puts("4. Performance Tuning:")
IO.puts("   - Use poll_interval: 10_000+ (10+ seconds) for large batches")
IO.puts("   - Set appropriate timeouts based on batch size")
IO.puts("   - Normalize embeddings immediately after retrieval")
IO.puts("   - Cache normalized embeddings for repeated use")
IO.puts("")

IO.puts("5. Scalability:")
IO.puts("   - Use 768d embeddings for 75% storage savings")
IO.puts("   - Index during off-peak hours for large batches")
IO.puts("   - Implement batch priority for urgent indexing")
IO.puts("   - Monitor API rate limits and quotas")
IO.puts("")

IO.puts(String.duplicate("=", 80))
IO.puts("Demo completed - Ready for production deployment!")
IO.puts(String.duplicate("=", 80) <> "\n")
