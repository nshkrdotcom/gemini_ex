#!/usr/bin/env elixir

# Simple Embedding Example
#
# This is the Elixir equivalent of:
#
#   curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent" \
#     -H "x-goog-api-key: $GEMINI_API_KEY" \
#     -H 'Content-Type: application/json' \
#     -d '{"model": "models/gemini-embedding-001",
#          "content": {"parts":[{"text": "What is the meaning of life?"}]}
#         }'
#
# Usage:
#   mix run examples/simple_embedding.exs

alias Gemini.APIs.Coordinator
alias Gemini.Config
alias Gemini.Types.Response.EmbedContentResponse

# Simple embedding - equivalent to the curl command
text = "What is the meaning of life?"

IO.puts("\nEmbedding text: \"#{text}\"\n")

case Coordinator.embed_content(text, model: Config.get_model(:embedding)) do
  {:ok, response} ->
    values = EmbedContentResponse.get_values(response)

    IO.puts("✓ Success!")
    IO.puts("  Dimensionality: #{length(values)}")
    IO.puts("  First 10 values:")

    values
    |> Enum.take(10)
    |> Enum.with_index(1)
    |> Enum.each(fn {value, idx} ->
      IO.puts("    [#{idx}] #{value}")
    end)

    IO.puts("\n  Last 5 values:")

    values
    |> Enum.take(-5)
    |> Enum.each(fn value ->
      IO.puts("    #{value}")
    end)

    IO.puts("\n✓ Embedding vector retrieved successfully!")
    IO.puts("  Total dimensions: #{length(values)}")

  {:error, reason} ->
    IO.puts("✗ Error: #{inspect(reason)}")
    System.halt(1)
end

IO.puts("\n" <> String.duplicate("-", 60))
IO.puts("The embedding vector can now be used for:")
IO.puts("  • Semantic search and retrieval")
IO.puts("  • Text similarity comparison")
IO.puts("  • Clustering and classification")
IO.puts("  • Recommendation systems")
IO.puts(String.duplicate("-", 60) <> "\n")
