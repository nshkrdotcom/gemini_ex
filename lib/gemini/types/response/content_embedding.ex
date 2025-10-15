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
  Calculates cosine similarity between two embeddings.

  Cosine similarity measures the cosine of the angle between two vectors,
  ranging from -1 (opposite) to 1 (identical).

  ## Parameters

  - `embedding1`: First embedding
  - `embedding2`: Second embedding

  ## Examples

      emb1 = %ContentEmbedding{values: [1.0, 0.0, 0.0]}
      emb2 = %ContentEmbedding{values: [0.0, 1.0, 0.0]}
      ContentEmbedding.cosine_similarity(emb1, emb2)
      # => 0.0
  """
  @spec cosine_similarity(t(), t()) :: float() | {:error, String.t()}
  def cosine_similarity(%__MODULE__{values: v1}, %__MODULE__{values: v2}) do
    if length(v1) != length(v2) do
      {:error, "Embeddings must have the same dimensionality"}
    else
      dot_product = Enum.zip(v1, v2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
      magnitude1 = :math.sqrt(Enum.map(v1, &(&1 * &1)) |> Enum.sum())
      magnitude2 = :math.sqrt(Enum.map(v2, &(&1 * &1)) |> Enum.sum())

      if magnitude1 == 0 or magnitude2 == 0 do
        0.0
      else
        dot_product / (magnitude1 * magnitude2)
      end
    end
  end
end
