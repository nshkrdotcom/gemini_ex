defmodule Gemini.Types.Response.BatchEmbedContentsResponse do
  @moduledoc """
  Response structure for batch embedding requests.

  Contains embeddings for multiple content items in the same order as
  the input requests.

  ## Fields

  - `embeddings`: List of content embeddings

  ## Examples

      %BatchEmbedContentsResponse{
        embeddings: [
          %ContentEmbedding{values: [0.1, 0.2, ...]},
          %ContentEmbedding{values: [0.3, 0.4, ...]},
          %ContentEmbedding{values: [0.5, 0.6, ...]}
        ]
      }
  """

  alias Gemini.Types.Response.ContentEmbedding

  @enforce_keys [:embeddings]
  defstruct [:embeddings]

  @type t :: %__MODULE__{
          embeddings: [ContentEmbedding.t()]
        }

  @doc """
  Creates a new batch embedding response from API response data.

  ## Parameters

  - `data`: Map containing the API response

  ## Examples

      BatchEmbedContentsResponse.from_api_response(%{
        "embeddings" => [
          %{"values" => [0.1, 0.2]},
          %{"values" => [0.3, 0.4]}
        ]
      })
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(%{"embeddings" => embeddings_data}) when is_list(embeddings_data) do
    embeddings = Enum.map(embeddings_data, &ContentEmbedding.from_api_response/1)

    %__MODULE__{
      embeddings: embeddings
    }
  end

  @doc """
  Gets all embedding values as a list of lists.

  ## Examples

      response = %BatchEmbedContentsResponse{...}
      all_values = BatchEmbedContentsResponse.get_all_values(response)
      # => [[0.1, 0.2, ...], [0.3, 0.4, ...], ...]
  """
  @spec get_all_values(t()) :: [[float()]]
  def get_all_values(%__MODULE__{embeddings: embeddings}) do
    Enum.map(embeddings, &ContentEmbedding.get_values/1)
  end
end
