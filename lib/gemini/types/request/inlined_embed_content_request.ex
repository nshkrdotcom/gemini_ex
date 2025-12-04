defmodule Gemini.Types.Request.InlinedEmbedContentRequest do
  @moduledoc """
  A single embedding request within an async batch, with optional metadata.

  Used to submit individual embedding requests as part of an async batch operation.
  Each request can include metadata for tracking purposes.

  ## Fields

  - `request`: The embedding request (EmbedContentRequest)
  - `metadata`: Optional metadata (map) to track request identity

  ## Examples

      # Simple inlined request
      %InlinedEmbedContentRequest{
        request: %EmbedContentRequest{
          model: "models/gemini-embedding-001",
          content: %Content{parts: [%Part{text: "Hello world"}]}
        }
      }

      # With metadata
      %InlinedEmbedContentRequest{
        request: embed_request,
        metadata: %{"document_id" => "doc-123", "category" => "tech"}
      }
  """

  alias Gemini.Types.Request.EmbedContentRequest

  @enforce_keys [:request]
  defstruct [:request, :metadata]

  @type t :: %__MODULE__{
          request: EmbedContentRequest.t(),
          metadata: map() | nil
        }

  @doc """
  Creates a new inlined embed content request.

  ## Parameters

  - `request`: The EmbedContentRequest to include
  - `opts`: Optional keyword list
    - `:metadata`: Metadata map for tracking

  ## Examples

      InlinedEmbedContentRequest.new(embed_request)

      InlinedEmbedContentRequest.new(embed_request,
        metadata: %{"id" => "123"}
      )
  """
  @spec new(EmbedContentRequest.t(), keyword()) :: t()
  def new(%EmbedContentRequest{} = request, opts \\ []) do
    %__MODULE__{
      request: request,
      metadata: Keyword.get(opts, :metadata)
    }
  end

  @doc """
  Converts the inlined request to API-compatible map format.
  """
  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{} = inlined_request) do
    %{
      "request" => EmbedContentRequest.to_api_map(inlined_request.request)
    }
    |> maybe_put("metadata", inlined_request.metadata)
  end

  # Private helpers

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
