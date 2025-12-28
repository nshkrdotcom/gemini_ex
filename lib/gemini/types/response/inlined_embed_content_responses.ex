defmodule Gemini.Types.Response.InlinedEmbedContentResponses do
  @moduledoc """
  Container for all responses in an inline batch.

  Contains a list of InlinedEmbedContentResponse structs, each representing
  the result of one request from the batch.

  ## Fields

  - `inlined_responses`: List of InlinedEmbedContentResponse structs

  ## Examples

      %InlinedEmbedContentResponses{
        inlined_responses: [
          %InlinedEmbedContentResponse{response: ..., error: nil},
          %InlinedEmbedContentResponse{response: nil, error: ...}
        ]
      }
  """

  alias Gemini.Types.Response.{EmbedContentResponse, InlinedEmbedContentResponse}

  @enforce_keys [:inlined_responses]
  defstruct [:inlined_responses]

  @type t :: %__MODULE__{
          inlined_responses: [InlinedEmbedContentResponse.t()]
        }

  @doc """
  Creates an inlined responses container from API response data.

  ## Parameters

  - `data`: Map containing the API response with inlined responses

  ## Examples

      InlinedEmbedContentResponses.from_api_response(%{
        "inlinedResponses" => [
          %{"response" => %{"embedding" => ...}},
          %{"error" => %{"code" => 400}}
        ]
      })
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(%{"inlinedResponses" => responses}) when is_list(responses) do
    inlined_responses = Enum.map(responses, &InlinedEmbedContentResponse.from_api_response/1)

    %__MODULE__{inlined_responses: inlined_responses}
  end

  @doc """
  Extracts all successful responses from the container.

  ## Returns

  List of EmbedContentResponse structs

  ## Examples

      successful = InlinedEmbedContentResponses.successful_responses(responses)
      # => [%EmbedContentResponse{...}, %EmbedContentResponse{...}]
  """
  @spec successful_responses(t()) :: [EmbedContentResponse.t()]
  def successful_responses(%__MODULE__{inlined_responses: responses}) do
    responses
    |> Enum.filter(&InlinedEmbedContentResponse.success?/1)
    |> Enum.map(& &1.response)
  end

  @doc """
  Extracts all failed responses with their indices and error details.

  ## Returns

  List of tuples: `{index, error_map}`

  ## Examples

      failures = InlinedEmbedContentResponses.failed_responses(responses)
      # => [{2, %{"code" => 400, "message" => "Invalid"}}, ...]
  """
  @spec failed_responses(t()) :: [{integer(), map()}]
  def failed_responses(%__MODULE__{inlined_responses: responses}) do
    responses
    |> Enum.with_index()
    |> Enum.filter(fn {response, _idx} -> InlinedEmbedContentResponse.error?(response) end)
    |> Enum.map(fn {response, idx} -> {idx, response.error} end)
  end
end
