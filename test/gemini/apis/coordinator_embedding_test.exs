defmodule Gemini.APIs.CoordinatorEmbeddingTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Request.{EmbedContentRequest, BatchEmbedContentsRequest}
  alias Gemini.Types.Response.{EmbedContentResponse, BatchEmbedContentsResponse, ContentEmbedding}

  describe "embed_content/2" do
    test "creates valid request from text string" do
      text = "Test embedding"

      request = EmbedContentRequest.new(text)

      assert %EmbedContentRequest{} = request
      assert request.model == "models/text-embedding-004"
      assert %Gemini.Types.Content{} = request.content
    end

    test "supports custom model" do
      text = "Test"
      request = EmbedContentRequest.new(text, model: "gemini-embedding-001")

      assert request.model == "models/gemini-embedding-001"
    end

    test "supports task type" do
      text = "Test"

      request =
        EmbedContentRequest.new(text, task_type: :retrieval_document, title: "Test Document")

      assert request.task_type == :retrieval_document
      assert request.title == "Test Document"
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
          model: "gemini-embedding-001",
          task_type: :semantic_similarity,
          output_dimensionality: 256
        )

      Enum.each(request.requests, fn req ->
        assert req.model == "models/gemini-embedding-001"
        assert req.task_type == :semantic_similarity
        assert req.output_dimensionality == 256
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
        {:task_type_unspecified, "TASK_TYPE_UNSPECIFIED"},
        {:retrieval_query, "RETRIEVAL_QUERY"},
        {:retrieval_document, "RETRIEVAL_DOCUMENT"},
        {:semantic_similarity, "SEMANTIC_SIMILARITY"},
        {:classification, "CLASSIFICATION"},
        {:clustering, "CLUSTERING"},
        {:question_answering, "QUESTION_ANSWERING"},
        {:fact_verification, "FACT_VERIFICATION"},
        {:code_retrieval_query, "CODE_RETRIEVAL_QUERY"}
      ]

      Enum.each(task_types, fn {atom, expected_string} ->
        request = EmbedContentRequest.new("test", task_type: atom)
        api_map = EmbedContentRequest.to_api_map(request)

        assert api_map["taskType"] == expected_string
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
