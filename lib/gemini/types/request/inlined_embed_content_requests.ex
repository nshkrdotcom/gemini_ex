defmodule Gemini.Types.Request.InlinedEmbedContentRequests do
  @moduledoc """
  Container for multiple inlined embedding requests in a batch.

  Wraps a list of InlinedEmbedContentRequest structs for submission
  as part of an async batch embedding job.

  ## Fields

  - `requests`: List of InlinedEmbedContentRequest structs

  ## Examples

      %InlinedEmbedContentRequests{
        requests: [
          %InlinedEmbedContentRequest{request: embed_req1},
          %InlinedEmbedContentRequest{request: embed_req2}
        ]
      }
  """

  alias Gemini.Types.Request.InlinedEmbedContentRequest

  @enforce_keys [:requests]
  defstruct [:requests]

  @type t :: %__MODULE__{
          requests: [InlinedEmbedContentRequest.t()]
        }

  @doc """
  Creates a new container for inlined requests.

  ## Parameters

  - `requests`: List of InlinedEmbedContentRequest structs

  ## Examples

      InlinedEmbedContentRequests.new([req1, req2, req3])
  """
  @spec new([InlinedEmbedContentRequest.t()]) :: t()
  def new(requests) when is_list(requests) do
    %__MODULE__{requests: requests}
  end

  @doc """
  Converts the inlined requests container to API-compatible map format.
  """
  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{requests: requests}) do
    %{
      "requests" => Enum.map(requests, &InlinedEmbedContentRequest.to_api_map/1)
    }
  end
end
