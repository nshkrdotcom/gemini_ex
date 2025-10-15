defmodule Gemini.Types.Response.ContentEmbeddingTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.ContentEmbedding

  describe "from_api_response/1" do
    test "creates embedding from API response" do
      response = %{"values" => [0.1, 0.2, 0.3]}
      embedding = ContentEmbedding.from_api_response(response)

      assert %ContentEmbedding{values: [0.1, 0.2, 0.3]} = embedding
    end
  end

  describe "get_values/1" do
    test "returns embedding values" do
      embedding = %ContentEmbedding{values: [0.1, 0.2, 0.3]}
      assert ContentEmbedding.get_values(embedding) == [0.1, 0.2, 0.3]
    end
  end

  describe "dimensionality/1" do
    test "returns the number of dimensions" do
      embedding = %ContentEmbedding{values: [0.1, 0.2, 0.3]}
      assert ContentEmbedding.dimensionality(embedding) == 3
    end

    test "returns 0 for empty embedding" do
      embedding = %ContentEmbedding{values: []}
      assert ContentEmbedding.dimensionality(embedding) == 0
    end
  end

  describe "normalize/1" do
    test "normalizes embedding to unit length" do
      # Vector [3, 4] has magnitude 5
      embedding = %ContentEmbedding{values: [3.0, 4.0]}
      normalized = ContentEmbedding.normalize(embedding)

      # Normalized should be [0.6, 0.8]
      assert_in_delta Enum.at(normalized.values, 0), 0.6, 0.0001
      assert_in_delta Enum.at(normalized.values, 1), 0.8, 0.0001

      # Check that magnitude is 1
      magnitude = ContentEmbedding.norm(normalized)
      assert_in_delta magnitude, 1.0, 0.0001
    end

    test "handles zero vector" do
      embedding = %ContentEmbedding{values: [0.0, 0.0, 0.0]}
      normalized = ContentEmbedding.normalize(embedding)

      # Zero vector should remain zero
      assert normalized.values == [0.0, 0.0, 0.0]
    end

    test "preserves direction for already normalized vector" do
      # Already normalized vector
      embedding = %ContentEmbedding{values: [0.6, 0.8]}
      normalized = ContentEmbedding.normalize(embedding)

      assert_in_delta Enum.at(normalized.values, 0), 0.6, 0.0001
      assert_in_delta Enum.at(normalized.values, 1), 0.8, 0.0001
    end

    test "works with high-dimensional vectors" do
      # Create a 768-dimensional vector (common embedding size)
      values = Enum.map(1..768, fn i -> :math.sin(i / 10) end)
      embedding = %ContentEmbedding{values: values}

      normalized = ContentEmbedding.normalize(embedding)

      # Check magnitude is 1
      magnitude = ContentEmbedding.norm(normalized)
      assert_in_delta magnitude, 1.0, 0.001
    end
  end

  describe "norm/1" do
    test "calculates L2 norm (Euclidean magnitude)" do
      # Vector [3, 4] has norm 5
      embedding = %ContentEmbedding{values: [3.0, 4.0]}
      assert_in_delta ContentEmbedding.norm(embedding), 5.0, 0.0001
    end

    test "returns 0 for zero vector" do
      embedding = %ContentEmbedding{values: [0.0, 0.0]}
      assert ContentEmbedding.norm(embedding) == 0.0
    end

    test "returns 1 for unit vector" do
      embedding = %ContentEmbedding{values: [0.6, 0.8]}
      assert_in_delta ContentEmbedding.norm(embedding), 1.0, 0.0001
    end
  end

  describe "cosine_similarity/2" do
    test "returns 1.0 for identical vectors" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert_in_delta ContentEmbedding.cosine_similarity(emb1, emb2), 1.0, 0.0001
    end

    test "returns 0.0 for orthogonal vectors" do
      emb1 = %ContentEmbedding{values: [1.0, 0.0, 0.0]}
      emb2 = %ContentEmbedding{values: [0.0, 1.0, 0.0]}

      assert_in_delta ContentEmbedding.cosine_similarity(emb1, emb2), 0.0, 0.0001
    end

    test "returns -1.0 for opposite vectors" do
      emb1 = %ContentEmbedding{values: [1.0, 0.0]}
      emb2 = %ContentEmbedding{values: [-1.0, 0.0]}

      assert_in_delta ContentEmbedding.cosine_similarity(emb1, emb2), -1.0, 0.0001
    end

    test "calculates correct similarity for angled vectors" do
      # These vectors have known cosine similarity
      emb1 = %ContentEmbedding{values: [1.0, 0.0]}
      emb2 = %ContentEmbedding{values: [1.0, 1.0]}

      # cos(45°) ≈ 0.707
      similarity = ContentEmbedding.cosine_similarity(emb1, emb2)
      assert_in_delta similarity, 0.707, 0.01
    end

    test "returns error for different dimensionality" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert {:error, "Embeddings must have the same dimensionality"} =
               ContentEmbedding.cosine_similarity(emb1, emb2)
    end

    test "handles zero magnitude vectors" do
      emb1 = %ContentEmbedding{values: [0.0, 0.0]}
      emb2 = %ContentEmbedding{values: [1.0, 1.0]}

      assert ContentEmbedding.cosine_similarity(emb1, emb2) == 0.0
    end
  end

  describe "euclidean_distance/2" do
    test "returns 0 for identical vectors" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert ContentEmbedding.euclidean_distance(emb1, emb2) == 0.0
    end

    test "calculates correct distance for simple vectors" do
      # Distance between [0,0] and [3,4] is 5
      emb1 = %ContentEmbedding{values: [0.0, 0.0]}
      emb2 = %ContentEmbedding{values: [3.0, 4.0]}

      assert_in_delta ContentEmbedding.euclidean_distance(emb1, emb2), 5.0, 0.0001
    end

    test "is symmetric" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0]}
      emb2 = %ContentEmbedding{values: [4.0, 6.0]}

      dist1 = ContentEmbedding.euclidean_distance(emb1, emb2)
      dist2 = ContentEmbedding.euclidean_distance(emb2, emb1)

      assert_in_delta dist1, dist2, 0.0001
    end

    test "returns error for different dimensionality" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert {:error, "Embeddings must have the same dimensionality"} =
               ContentEmbedding.euclidean_distance(emb1, emb2)
    end
  end

  describe "dot_product/2" do
    test "calculates dot product correctly" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}
      emb2 = %ContentEmbedding{values: [4.0, 5.0, 6.0]}

      # 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      assert ContentEmbedding.dot_product(emb1, emb2) == 32.0
    end

    test "returns 0 for orthogonal vectors" do
      emb1 = %ContentEmbedding{values: [1.0, 0.0]}
      emb2 = %ContentEmbedding{values: [0.0, 1.0]}

      assert ContentEmbedding.dot_product(emb1, emb2) == 0.0
    end

    test "is commutative" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}
      emb2 = %ContentEmbedding{values: [4.0, 5.0, 6.0]}

      dot1 = ContentEmbedding.dot_product(emb1, emb2)
      dot2 = ContentEmbedding.dot_product(emb2, emb1)

      assert dot1 == dot2
    end

    test "returns error for different dimensionality" do
      emb1 = %ContentEmbedding{values: [1.0, 2.0]}
      emb2 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}

      assert {:error, "Embeddings must have the same dimensionality"} =
               ContentEmbedding.dot_product(emb1, emb2)
    end
  end

  describe "integration: normalization improves similarity accuracy" do
    test "normalized embeddings produce better cosine similarity" do
      # Simulate embeddings of different magnitudes but same direction
      emb1 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}
      # Same direction, 2x magnitude
      emb2 = %ContentEmbedding{values: [2.0, 4.0, 6.0]}

      # Without normalization, cosine similarity accounts for direction
      raw_similarity = ContentEmbedding.cosine_similarity(emb1, emb2)
      assert_in_delta raw_similarity, 1.0, 0.0001

      # With normalization (for dimensions != 3072 as per spec)
      norm1 = ContentEmbedding.normalize(emb1)
      norm2 = ContentEmbedding.normalize(emb2)

      norm_similarity = ContentEmbedding.cosine_similarity(norm1, norm2)
      assert_in_delta norm_similarity, 1.0, 0.0001

      # Both should give same result for same-direction vectors
      assert_in_delta raw_similarity, norm_similarity, 0.001
    end
  end
end
