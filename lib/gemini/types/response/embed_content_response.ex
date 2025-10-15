defmodule Gemini.Types.Response.EmbedContentResponse do
  @moduledoc """
  Response structure for embedding content requests.

  Contains the generated embedding vector from the input content.

  ## Fields

  - `embedding`: The content embedding containing the numerical vector

  ## Examples

      %EmbedContentResponse{
        embedding: %ContentEmbedding{
          values: [0.123, -0.456, 0.789, ...]
        }
      }
  """

  alias Gemini.Types.Response.ContentEmbedding

  @enforce_keys [:embedding]
  defstruct [:embedding]

  @type t :: %__MODULE__{
          embedding: ContentEmbedding.t()
        }

  @doc """
  Creates a new embedding response from API response data.

  ## Parameters

  - `data`: Map containing the API response

  ## Examples

      EmbedContentResponse.from_api_response(%{
        "embedding" => %{"values" => [0.1, 0.2, 0.3]}
      })
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(%{"embedding" => embedding_data}) do
    %__MODULE__{
      embedding: ContentEmbedding.from_api_response(embedding_data)
    }
  end

  @doc """
  Extracts the embedding values as a list of floats.

  ## Examples

      response = %EmbedContentResponse{...}
      values = EmbedContentResponse.get_values(response)
      # => [0.123, -0.456, 0.789, ...]
  """
  @spec get_values(t()) :: [float()]
  def get_values(%__MODULE__{embedding: embedding}) do
    ContentEmbedding.get_values(embedding)
  end
end
