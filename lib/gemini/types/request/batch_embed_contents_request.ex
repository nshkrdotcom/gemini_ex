defmodule Gemini.Types.Request.BatchEmbedContentsRequest do
  @moduledoc """
  Request structure for batch embedding multiple content items.

  Allows generating embeddings for multiple text inputs in a single API call,
  which is more efficient than individual requests.

  ## Fields

  - `requests`: List of individual embed content requests

  ## Examples

      %BatchEmbedContentsRequest{
        requests: [
          %EmbedContentRequest{
            model: "models/gemini-embedding-001",
            content: %Content{parts: [%Part{text: "First text"}]}
          },
          %EmbedContentRequest{
            model: "models/gemini-embedding-001",
            content: %Content{parts: [%Part{text: "Second text"}]}
          }
        ]
      }
  """

  alias Gemini.Types.Request.EmbedContentRequest

  @enforce_keys [:requests]
  defstruct [:requests]

  @type t :: %__MODULE__{
          requests: [EmbedContentRequest.t()]
        }

  @doc """
  Creates a new batch embedding request from a list of texts.

  ## Parameters

  - `texts`: List of text strings to embed
  - `opts`: Optional keyword list of options to apply to all requests
    - `:model`: Model to use (default: "gemini-embedding-001")
    - `:task_type`: Task type for optimized embeddings
    - `:output_dimensionality`: Dimension reduction

  ## Examples

      BatchEmbedContentsRequest.new([
        "What is AI?",
        "How does machine learning work?",
        "Explain neural networks"
      ])

      BatchEmbedContentsRequest.new(
        ["Doc 1", "Doc 2"],
        task_type: :retrieval_document,
        output_dimensionality: 256
      )
  """
  @spec new([String.t()], keyword()) :: t()
  def new(texts, opts \\ []) when is_list(texts) do
    requests = Enum.map(texts, &EmbedContentRequest.new(&1, opts))

    %__MODULE__{
      requests: requests
    }
  end

  @doc """
  Converts the batch request to API-compatible map format.
  """
  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{requests: requests}) do
    %{
      "requests" => Enum.map(requests, &EmbedContentRequest.to_api_map/1)
    }
  end
end
