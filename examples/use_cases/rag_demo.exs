#!/usr/bin/env elixir
# Retrieval-Augmented Generation (RAG) System Demo
#
# This example demonstrates a complete RAG pipeline:
# 1. Embed a knowledge base of documents using RETRIEVAL_DOCUMENT task type
# 2. Embed user queries using RETRIEVAL_QUERY task type
# 3. Retrieve top-K most relevant documents using semantic similarity
# 4. Generate contextually-aware responses using retrieved context
#
# RAG enhances LLM responses with factual accuracy, coherence, and context
# by grounding generation in relevant retrieved information.
#
# Usage: mix run examples/use_cases/rag_demo.exs

require Logger

alias Gemini.APIs.Coordinator
alias Gemini.Config
alias Gemini.Types.Response.{EmbedContentResponse, ContentEmbedding}
# alias Gemini.Types.Request.Content

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("RETRIEVAL-AUGMENTED GENERATION (RAG) SYSTEM DEMO")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
RAG combines the power of semantic search with generative AI:
• Retrieve relevant information from a knowledge base using embeddings
• Provide retrieved context to the LLM for grounded, accurate generation
• Reduce hallucinations and improve factual correctness
""")

# ============================================================================
# STEP 1: Build Knowledge Base
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("STEP 1: BUILDING KNOWLEDGE BASE")
IO.puts(String.duplicate("-", 80) <> "\n")

# Sample knowledge base about space exploration
knowledge_base = [
  %{
    title: "Mars Rovers",
    content: """
    NASA's Mars rovers have been exploring the Red Planet for decades. The most
    recent rovers, Curiosity (landed 2012) and Perseverance (landed 2021), are
    equipped with advanced scientific instruments. Perseverance is collecting samples
    that may be returned to Earth by future missions. The rovers search for signs
    of ancient microbial life and study Mars' geology and climate.
    """
  },
  %{
    title: "International Space Station",
    content: """
    The International Space Station (ISS) is a habitable artificial satellite in
    low Earth orbit. It serves as a microgravity research laboratory where crew
    members conduct experiments in biology, physics, astronomy, and other fields.
    The ISS has been continuously occupied since November 2000 and is a joint
    project involving NASA, Roscosmos, ESA, JAXA, and CSA.
    """
  },
  %{
    title: "James Webb Space Telescope",
    content: """
    The James Webb Space Telescope (JWST) is the largest and most powerful space
    telescope ever built. Launched in December 2021, it observes the universe in
    infrared wavelengths, allowing it to see through cosmic dust and study the
    formation of the first galaxies. JWST can also analyze the atmospheres of
    exoplanets and search for potential signs of habitability.
    """
  },
  %{
    title: "SpaceX Starship",
    content: """
    SpaceX's Starship is a fully reusable launch vehicle designed for missions to
    Earth orbit, the Moon, Mars, and beyond. It consists of two stages: the Super
    Heavy booster and the Starship spacecraft. When complete, it will be the most
    powerful rocket ever built, capable of carrying up to 100 people on long-duration
    interplanetary flights. NASA has selected Starship for lunar landing missions.
    """
  },
  %{
    title: "Artemis Program",
    content: """
    NASA's Artemis program aims to return humans to the Moon and establish a
    sustainable presence there by the end of the decade. The program includes
    the Space Launch System (SLS) rocket, Orion spacecraft, and Gateway lunar
    space station. Artemis will land the first woman and first person of color
    on the Moon and serve as a stepping stone for future Mars missions.
    """
  },
  %{
    title: "Exoplanet Discovery",
    content: """
    Scientists have discovered over 5,000 exoplanets orbiting other stars. The
    Kepler Space Telescope and TESS mission have been instrumental in finding
    these distant worlds. Some exoplanets orbit within their star's habitable zone,
    where liquid water could exist on the surface. The study of exoplanet atmospheres
    may reveal biosignatures indicating the presence of life.
    """
  }
]

IO.puts("Embedding #{length(knowledge_base)} documents using RETRIEVAL_DOCUMENT task type...")
IO.puts("(Using title parameter for better quality embeddings)\n")

# Embed each document using RETRIEVAL_DOCUMENT task type with titles
embedded_docs =
  Enum.map(knowledge_base, fn doc ->
    IO.puts("  • Embedding: #{doc.title}")

    {:ok, %EmbedContentResponse{embedding: embedding}} =
      Coordinator.embed_content(
        doc.content,
        model: Config.get_model(:embedding),
        task_type: :retrieval_document,
        title: doc.title,
        output_dimensionality: 768
      )

    # Normalize for accurate similarity computation
    normalized_embedding = ContentEmbedding.normalize(embedding)

    Map.put(doc, :embedding, normalized_embedding)
  end)

IO.puts("\n✓ Knowledge base indexed with #{length(embedded_docs)} document embeddings")

# ============================================================================
# STEP 2: Process User Query
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 2: PROCESSING USER QUERY")
IO.puts(String.duplicate("-", 80) <> "\n")

user_query = "What are the latest developments in Mars exploration?"

IO.puts("User query: \"#{user_query}\"\n")
IO.puts("Embedding query using RETRIEVAL_QUERY task type...")

{:ok, %EmbedContentResponse{embedding: query_embedding}} =
  Coordinator.embed_content(
    user_query,
    model: Config.get_model(:embedding),
    task_type: :retrieval_query,
    output_dimensionality: 768
  )

# Normalize query embedding
query_embedding = ContentEmbedding.normalize(query_embedding)

IO.puts("✓ Query embedded\n")

# ============================================================================
# STEP 3: Retrieve Relevant Documents
# ============================================================================

IO.puts(String.duplicate("-", 80))
IO.puts("STEP 3: RETRIEVING RELEVANT DOCUMENTS")
IO.puts(String.duplicate("-", 80) <> "\n")

# Calculate similarity scores for all documents
doc_scores =
  embedded_docs
  |> Enum.map(fn doc ->
    similarity = ContentEmbedding.cosine_similarity(query_embedding, doc.embedding)
    {doc, similarity}
  end)
  |> Enum.sort_by(fn {_doc, similarity} -> similarity end, :desc)

IO.puts("Similarity scores for all documents:\n")

Enum.each(doc_scores, fn {doc, similarity} ->
  bar_length = round(similarity * 40)
  bar = String.duplicate("█", bar_length)
  IO.puts("  #{String.pad_trailing(doc.title, 30)} #{Float.round(similarity, 4)} #{bar}")
end)

# Retrieve top-K documents (K=2 for this demo)
top_k = 2
retrieved_docs = Enum.take(doc_scores, top_k) |> Enum.map(fn {doc, _sim} -> doc end)

IO.puts("\n✓ Retrieved top #{top_k} most relevant documents:")

Enum.each(retrieved_docs, fn doc ->
  IO.puts("  • #{doc.title}")
end)

# ============================================================================
# STEP 4: Generate Response with Retrieved Context
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("STEP 4: GENERATING CONTEXTUALLY-AWARE RESPONSE")
IO.puts(String.duplicate("-", 80) <> "\n")

# Build context from retrieved documents
context =
  retrieved_docs
  |> Enum.map(fn doc -> "## #{doc.title}\n#{String.trim(doc.content)}" end)
  |> Enum.join("\n\n")

# Create RAG prompt
rag_prompt = """
You are a knowledgeable assistant answering questions about space exploration.
Use the following context to answer the user's question accurately. If the
context doesn't contain relevant information, say so.

CONTEXT:
#{context}

USER QUESTION: #{user_query}

ANSWER:
"""

IO.puts("Generating response using retrieved context...\n")

case Coordinator.generate_content(rag_prompt, model: Config.default_model()) do
  {:ok, response} ->
    {:ok, answer} = Coordinator.extract_text(response)

    IO.puts(String.duplicate("-", 80))
    IO.puts("RAG-ENHANCED RESPONSE:")
    IO.puts(String.duplicate("-", 80))
    IO.puts(answer)
    IO.puts(String.duplicate("-", 80))

    # ========================================================================
    # COMPARISON: Without RAG
    # ========================================================================

    IO.puts("\n" <> String.duplicate("-", 80))
    IO.puts("COMPARISON: RESPONSE WITHOUT RAG")
    IO.puts(String.duplicate("-", 80) <> "\n")

    simple_prompt = """
    Answer this question about space exploration: #{user_query}

    Provide a brief answer:
    """

    case Coordinator.generate_content(simple_prompt, model: Config.default_model()) do
      {:ok, simple_response} ->
        {:ok, simple_answer} = Coordinator.extract_text(simple_response)

        IO.puts(String.duplicate("-", 80))
        IO.puts("RESPONSE WITHOUT CONTEXT:")
        IO.puts(String.duplicate("-", 80))
        IO.puts(simple_answer)
        IO.puts(String.duplicate("-", 80))

      {:error, reason} ->
        IO.puts("Error generating comparison response: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("Error generating RAG response: #{inspect(reason)}")
end

# ============================================================================
# DEMONSTRATION: Try Different Queries
# ============================================================================

IO.puts("\n" <> String.duplicate("-", 80))
IO.puts("TRYING ADDITIONAL QUERIES")
IO.puts(String.duplicate("-", 80) <> "\n")

additional_queries = [
  "How do scientists search for life on other planets?",
  "What is the purpose of the Gateway space station?"
]

Enum.each(additional_queries, fn query ->
  IO.puts("\nQuery: \"#{query}\"")

  {:ok, %EmbedContentResponse{embedding: q_emb}} =
    Coordinator.embed_content(
      query,
      model: Config.get_model(:embedding),
      task_type: :retrieval_query,
      output_dimensionality: 768
    )

  q_emb = ContentEmbedding.normalize(q_emb)

  top_match =
    embedded_docs
    |> Enum.map(fn doc ->
      similarity = ContentEmbedding.cosine_similarity(q_emb, doc.embedding)
      {doc.title, similarity}
    end)
    |> Enum.max_by(fn {_title, sim} -> sim end)

  {title, similarity} = top_match
  IO.puts("  → Best match: #{title} (similarity: #{Float.round(similarity, 4)})")
end)

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("KEY TAKEAWAYS:")
IO.puts(String.duplicate("=", 80) <> "\n")

IO.puts("""
1. RAG combines semantic search with generation for grounded responses
2. Use RETRIEVAL_DOCUMENT task type when embedding knowledge base documents
3. Use RETRIEVAL_QUERY task type when embedding user queries
4. Provide document titles for better embedding quality
5. Normalize embeddings (non-3072 dimensions) before computing similarity
6. Retrieve top-K relevant documents using cosine similarity
7. Include retrieved context in generation prompt for accurate responses
8. RAG significantly improves factual accuracy vs generation alone
""")

IO.puts(String.duplicate("=", 80) <> "\n")
