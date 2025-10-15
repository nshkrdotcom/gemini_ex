defmodule Gemini.Types.Response.ContentEmbedding do
  @moduledoc """
  A list of floats representing an embedding.

  Embeddings are numerical representations of text that can be used for
  various purposes such as similarity comparison, clustering, and retrieval.

  ## Fields

  - `values`: List of float values representing the embedding vector

  ## Examples

      %ContentEmbedding{
        values: [0.123, -0.456, 0.789, 0.234, ...]
      }
  """

  @enforce_keys [:values]
  defstruct [:values]

  @type t :: %__MODULE__{
          values: [float()]
        }

  @doc """
  Creates a new content embedding from API response data.

  ## Parameters

  - `data`: Map containing the embedding values

  ## Examples

      ContentEmbedding.from_api_response(%{"values" => [0.1, 0.2, 0.3]})
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(%{"values" => values}) when is_list(values) do
    %__MODULE__{values: values}
  end

  @doc """
  Gets the embedding values.

  ## Examples

      embedding = %ContentEmbedding{values: [0.1, 0.2, 0.3]}
      ContentEmbedding.get_values(embedding)
      # => [0.1, 0.2, 0.3]
  """
  @spec get_values(t()) :: [float()]
  def get_values(%__MODULE__{values: values}), do: values

  @doc """
  Gets the dimensionality of the embedding.

  ## Examples

      embedding = %ContentEmbedding{values: [0.1, 0.2, 0.3]}
      ContentEmbedding.dimensionality(embedding)
      # => 3
  """
  @spec dimensionality(t()) :: non_neg_integer()
  def dimensionality(%__MODULE__{values: values}), do: length(values)

  @doc """
  Normalizes the embedding to unit length (L2 norm = 1).

  Per the Gemini API specification, embeddings with dimensions other than 3072
  should be normalized for accurate semantic similarity comparison.

  The 3072-dimensional embeddings are already normalized by the API, but
  embeddings with other dimensions (768, 1536, etc.) need explicit normalization.

  ## Examples

      embedding = %ContentEmbedding{values: [3.0, 4.0]}
      normalized = ContentEmbedding.normalize(embedding)
      # => %ContentEmbedding{values: [0.6, 0.8]}

      ContentEmbedding.norm(normalized)
      # => 1.0
  """
  @spec normalize(t()) :: t()
  def normalize(%__MODULE__{values: values} = embedding) do
    magnitude = norm(embedding)

    if magnitude == 0 do
      # Zero vector remains zero
      embedding
    else
      normalized_values = Enum.map(values, &(&1 / magnitude))
      %__MODULE__{values: normalized_values}
    end
  end

  @doc """
  Calculates the L2 norm (Euclidean magnitude) of the embedding.

  The norm represents the length of the vector in multidimensional space.
  For normalized embeddings, the norm should be 1.0.

  ## Examples

      embedding = %ContentEmbedding{values: [3.0, 4.0]}
      ContentEmbedding.norm(embedding)
      # => 5.0

      normalized = ContentEmbedding.normalize(embedding)
      ContentEmbedding.norm(normalized)
      # => 1.0
  """
  @spec norm(t()) :: float()
  def norm(%__MODULE__{values: values}) do
    values
    |> Enum.map(&(&1 * &1))
    |> Enum.sum()
    |> :math.sqrt()
  end

  @doc """
  Calculates cosine similarity between two embeddings.

  Cosine similarity measures the cosine of the angle between two vectors,
  ranging from -1 (opposite) to 1 (identical).

  This metric focuses on direction rather than magnitude, making it ideal
  for semantic similarity. For best results with dimensions other than 3072,
  normalize embeddings first using `normalize/1`.

  ## Parameters

  - `embedding1`: First embedding
  - `embedding2`: Second embedding

  ## Returns

  - Float value between -1.0 and 1.0, or
  - `{:error, reason}` if embeddings have different dimensions

  ## Examples

      emb1 = %ContentEmbedding{values: [1.0, 0.0, 0.0]}
      emb2 = %ContentEmbedding{values: [0.0, 1.0, 0.0]}
      ContentEmbedding.cosine_similarity(emb1, emb2)
      # => 0.0

      # For best results with non-3072 dimensions, normalize first
      norm1 = ContentEmbedding.normalize(emb1)
      norm2 = ContentEmbedding.normalize(emb2)
      ContentEmbedding.cosine_similarity(norm1, norm2)
  """
  @spec cosine_similarity(t(), t()) :: float() | {:error, String.t()}
  def cosine_similarity(%__MODULE__{values: v1}, %__MODULE__{values: v2}) do
    if length(v1) != length(v2) do
      {:error, "Embeddings must have the same dimensionality"}
    else
      dot_prod = calculate_dot_product(v1, v2)
      magnitude1 = calculate_magnitude(v1)
      magnitude2 = calculate_magnitude(v2)

      if magnitude1 == 0 or magnitude2 == 0 do
        0.0
      else
        dot_prod / (magnitude1 * magnitude2)
      end
    end
  end

  @doc """
  Calculates Euclidean distance between two embeddings.

  Euclidean distance represents the straight-line distance between two points
  in multidimensional space. Unlike cosine similarity, it considers both
  direction and magnitude.

  ## Parameters

  - `embedding1`: First embedding
  - `embedding2`: Second embedding

  ## Returns

  - Float value >= 0, or
  - `{:error, reason}` if embeddings have different dimensions

  ## Examples

      emb1 = %ContentEmbedding{values: [0.0, 0.0]}
      emb2 = %ContentEmbedding{values: [3.0, 4.0]}
      ContentEmbedding.euclidean_distance(emb1, emb2)
      # => 5.0
  """
  @spec euclidean_distance(t(), t()) :: float() | {:error, String.t()}
  def euclidean_distance(%__MODULE__{values: v1}, %__MODULE__{values: v2}) do
    if length(v1) != length(v2) do
      {:error, "Embeddings must have the same dimensionality"}
    else
      Enum.zip(v1, v2)
      |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
      |> Enum.sum()
      |> :math.sqrt()
    end
  end

  @doc """
  Calculates the dot product between two embeddings.

  The dot product is a fundamental vector operation used in many similarity
  metrics. For normalized vectors, the dot product equals the cosine similarity.

  ## Parameters

  - `embedding1`: First embedding
  - `embedding2`: Second embedding

  ## Returns

  - Float value, or
  - `{:error, reason}` if embeddings have different dimensions

  ## Examples

      emb1 = %ContentEmbedding{values: [1.0, 2.0, 3.0]}
      emb2 = %ContentEmbedding{values: [4.0, 5.0, 6.0]}
      ContentEmbedding.dot_product(emb1, emb2)
      # => 32.0 (1*4 + 2*5 + 3*6)
  """
  @spec dot_product(t(), t()) :: float() | {:error, String.t()}
  def dot_product(%__MODULE__{values: v1}, %__MODULE__{values: v2}) do
    if length(v1) != length(v2) do
      {:error, "Embeddings must have the same dimensionality"}
    else
      calculate_dot_product(v1, v2)
    end
  end

  # Private helper functions

  defp calculate_dot_product(v1, v2) do
    Enum.zip(v1, v2)
    |> Enum.map(fn {a, b} -> a * b end)
    |> Enum.sum()
  end

  defp calculate_magnitude(values) do
    values
    |> Enum.map(&(&1 * &1))
    |> Enum.sum()
    |> :math.sqrt()
  end
end
