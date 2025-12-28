defmodule Gemini.APIs.CoordinatorEmbeddingTest do
  use ExUnit.Case, async: true

  alias Gemini.Config
  alias Gemini.Types.Content
  alias Gemini.Types.Request.{BatchEmbedContentsRequest, EmbedContentRequest}
  alias Gemini.Types.Response.{BatchEmbedContentsResponse, ContentEmbedding, EmbedContentResponse}

  import Gemini.Test.ModelHelpers

  # No setup block - tests are auth-aware and validate both Gemini API and Vertex AI behavior
  # Task type handling differs between APIs:
  # - Gemini API (gemini-embedding-001): Uses taskType parameter in struct
  # - Vertex AI (embeddinggemma): Embeds task in prompt text, task_type field is nil

  # Helper to check if current config uses prompt prefixes (Vertex AI)
  defp uses_prompt_prefix? do
    Config.uses_prompt_prefix?(embedding_model())
  end

  # Helper to get text content from request
  defp get_request_text(%EmbedContentRequest{content: content}) do
    content.parts |> hd() |> Map.get(:text)
  end

  describe "embed_content/2" do
    test "creates valid request from text string" do
      text = "Test embedding"

      request = EmbedContentRequest.new(text)

      assert %EmbedContentRequest{} = request
      assert request.model == "models/#{embedding_model()}"
      assert %Content{} = request.content
    end

    test "supports custom model" do
      text = "Test"
      request = EmbedContentRequest.new(text, model: embedding_model())

      assert request.model == "models/#{embedding_model()}"
    end

    test "supports task type" do
      text = "Test"

      request =
        EmbedContentRequest.new(text, task_type: :retrieval_document, title: "Test Document")

      if uses_prompt_prefix?() do
        # Vertex AI (embeddinggemma): Task is embedded in prompt text
        assert request.task_type == nil
        assert request.title == nil
        # Text should contain the prompt prefix with title
        assert get_request_text(request) =~ "title: Test Document"
        assert get_request_text(request) =~ "text: Test"
      else
        # Gemini API: Task type stored in struct field
        assert request.task_type == :retrieval_document
        assert request.title == "Test Document"
      end
    end

    test "supports output dimensionality" do
      text = "Test"
      request = EmbedContentRequest.new(text, output_dimensionality: 768)

      assert request.output_dimensionality == 768
    end
  end

  describe "batch_embed_contents/2" do
    test "creates batch request from list of texts" do
      texts = ["Text 1", "Text 2", "Text 3"]

      request = BatchEmbedContentsRequest.new(texts)

      assert %BatchEmbedContentsRequest{} = request
      assert length(request.requests) == 3

      Enum.each(request.requests, fn req ->
        assert %EmbedContentRequest{} = req
      end)
    end

    test "applies options to all requests in batch" do
      texts = ["Text 1", "Text 2"]

      request =
        BatchEmbedContentsRequest.new(texts,
          model: embedding_model(),
          task_type: :semantic_similarity,
          output_dimensionality: 256
        )

      Enum.each(request.requests, fn req ->
        assert req.model == "models/#{embedding_model()}"
        assert req.output_dimensionality == 256

        if uses_prompt_prefix?() do
          # Vertex AI (embeddinggemma): Task is embedded in prompt text
          assert req.task_type == nil
          # Text should contain the semantic similarity prompt prefix
          assert get_request_text(req) =~ "task: sentence similarity"
        else
          # Gemini API: Task type stored in struct field
          assert req.task_type == :semantic_similarity
        end
      end)
    end
  end

  describe "API response parsing" do
    test "EmbedContentResponse.from_api_response/1" do
      api_response = %{
        "embedding" => %{
          "values" => [0.1, 0.2, 0.3]
        }
      }

      response = EmbedContentResponse.from_api_response(api_response)

      assert %EmbedContentResponse{} = response
      assert %ContentEmbedding{values: [0.1, 0.2, 0.3]} = response.embedding
    end

    test "EmbedContentResponse.get_values/1" do
      response = %EmbedContentResponse{
        embedding: %ContentEmbedding{values: [0.1, 0.2, 0.3]}
      }

      assert EmbedContentResponse.get_values(response) == [0.1, 0.2, 0.3]
    end

    test "BatchEmbedContentsResponse.from_api_response/1" do
      api_response = %{
        "embeddings" => [
          %{"values" => [0.1, 0.2]},
          %{"values" => [0.3, 0.4]},
          %{"values" => [0.5, 0.6]}
        ]
      }

      response = BatchEmbedContentsResponse.from_api_response(api_response)

      assert %BatchEmbedContentsResponse{} = response
      assert length(response.embeddings) == 3

      Enum.each(response.embeddings, fn emb ->
        assert %ContentEmbedding{} = emb
        assert length(emb.values) == 2
      end)
    end

    test "BatchEmbedContentsResponse.get_all_values/1" do
      response = %BatchEmbedContentsResponse{
        embeddings: [
          %ContentEmbedding{values: [0.1, 0.2]},
          %ContentEmbedding{values: [0.3, 0.4]}
        ]
      }

      all_values = BatchEmbedContentsResponse.get_all_values(response)

      assert all_values == [[0.1, 0.2], [0.3, 0.4]]
    end
  end

  describe "task type serialization" do
    test "converts all task types correctly" do
      task_types = [
        {:task_type_unspecified, "TASK_TYPE_UNSPECIFIED", nil},
        {:retrieval_query, "RETRIEVAL_QUERY", "task: search result | query:"},
        {:retrieval_document, "RETRIEVAL_DOCUMENT", "title:"},
        {:semantic_similarity, "SEMANTIC_SIMILARITY", "task: sentence similarity | query:"},
        {:classification, "CLASSIFICATION", "task: classification | query:"},
        {:clustering, "CLUSTERING", "task: clustering | query:"},
        {:question_answering, "QUESTION_ANSWERING", "task: question answering | query:"},
        {:fact_verification, "FACT_VERIFICATION", "task: fact checking | query:"},
        {:code_retrieval_query, "CODE_RETRIEVAL_QUERY", "task: code retrieval | query:"}
      ]

      Enum.each(task_types, fn {atom, expected_string, expected_prefix} ->
        request = EmbedContentRequest.new("test", task_type: atom)
        api_map = EmbedContentRequest.to_api_map(request)

        if uses_prompt_prefix?() do
          # Vertex AI (embeddinggemma): Task is embedded in prompt text, not in API params
          refute Map.has_key?(api_map, "taskType")
          # Verify the prompt prefix is in the content text
          text = get_in(api_map, ["content", "parts", Access.at(0), "text"])

          if expected_prefix do
            assert text =~ expected_prefix,
                   "Expected text to contain '#{expected_prefix}', got: #{text}"
          end
        else
          # Gemini API: Task type serialized to API parameter
          assert api_map["taskType"] == expected_string
        end
      end)
    end

    test "omits task_type when nil" do
      request = EmbedContentRequest.new("test")
      api_map = EmbedContentRequest.to_api_map(request)

      refute Map.has_key?(api_map, "taskType")
    end
  end

  describe "normalization workflow" do
    test "embeddings should be normalized for dimensions != 3072" do
      # Simulate API response with 768 dimensions
      values = Enum.map(1..768, fn i -> :math.sin(i / 10) end)

      embedding = %ContentEmbedding{values: values}

      # Check if normalization is needed
      norm_before = ContentEmbedding.norm(embedding)
      refute_in_delta norm_before, 1.0, 0.01

      # Normalize
      normalized = ContentEmbedding.normalize(embedding)

      # Verify normalization
      norm_after = ContentEmbedding.norm(normalized)
      assert_in_delta norm_after, 1.0, 0.001

      # Direction should be preserved
      # Cosine similarity between original and normalized should be 1.0
      similarity = ContentEmbedding.cosine_similarity(embedding, normalized)
      assert_in_delta similarity, 1.0, 0.001
    end

    test "3072-dimensional embeddings are already normalized (per spec)" do
      # Simulate API response with 3072 dimensions (already normalized by API)
      values =
        Enum.map(1..3072, fn i -> :math.sin(i / 100) end)
        |> then(fn vals ->
          # Normalize to simulate API behavior
          magnitude = :math.sqrt(Enum.map(vals, &(&1 * &1)) |> Enum.sum())
          Enum.map(vals, &(&1 / magnitude))
        end)

      embedding = %ContentEmbedding{values: values}

      # Should already be normalized
      norm = ContentEmbedding.norm(embedding)
      assert_in_delta norm, 1.0, 0.001
    end
  end

  describe "similarity metrics comparison" do
    test "cosine similarity works correctly for semantic similarity task" do
      # Simulate similar texts
      emb1 = %ContentEmbedding{values: [0.8, 0.6, 0.0]}
      emb2 = %ContentEmbedding{values: [0.9, 0.7, 0.1]}

      # Normalize first (best practice for non-3072 dimensions)
      norm1 = ContentEmbedding.normalize(emb1)
      norm2 = ContentEmbedding.normalize(emb2)

      similarity = ContentEmbedding.cosine_similarity(norm1, norm2)

      # Similar vectors should have high similarity
      assert similarity > 0.9
    end

    test "euclidean distance complements cosine similarity" do
      emb1 = %ContentEmbedding{values: [1.0, 0.0, 0.0]}
      emb2 = %ContentEmbedding{values: [0.0, 1.0, 0.0]}

      # Orthogonal vectors
      cosine_sim = ContentEmbedding.cosine_similarity(emb1, emb2)
      assert_in_delta cosine_sim, 0.0, 0.0001

      # But have a defined euclidean distance
      euclidean = ContentEmbedding.euclidean_distance(emb1, emb2)
      # Distance is sqrt(2) for unit vectors at 90 degrees
      assert_in_delta euclidean, :math.sqrt(2), 0.0001
    end

    test "dot product equals cosine similarity for normalized vectors" do
      emb1 = %ContentEmbedding{values: [0.6, 0.8]}
      emb2 = %ContentEmbedding{values: [0.8, 0.6]}

      # Both should already be normalized (magnitude = 1)
      assert_in_delta ContentEmbedding.norm(emb1), 1.0, 0.0001
      assert_in_delta ContentEmbedding.norm(emb2), 1.0, 0.0001

      cosine_sim = ContentEmbedding.cosine_similarity(emb1, emb2)
      dot_prod = ContentEmbedding.dot_product(emb1, emb2)

      # For normalized vectors, dot product = cosine similarity
      assert_in_delta cosine_sim, dot_prod, 0.0001
    end
  end

  describe "error handling" do
    test "returns error for mismatched dimensions in cosine_similarity" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert {:error, "Embeddings must have the same dimensionality"} =
               ContentEmbedding.cosine_similarity(emb1, emb2)
    end

    test "returns error for mismatched dimensions in euclidean_distance" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert {:error, "Embeddings must have the same dimensionality"} =
               ContentEmbedding.euclidean_distance(emb1, emb2)
    end

    test "returns error for mismatched dimensions in dot_product" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert {:error, "Embeddings must have the same dimensionality"} =
               ContentEmbedding.dot_product(emb1, emb2)
    end
  end
end
