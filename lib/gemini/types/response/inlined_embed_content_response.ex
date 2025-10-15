defmodule Gemini.Types.Response.InlinedEmbedContentResponse do
  @moduledoc """
  Response for a single request within an async batch.

  This is a union type - exactly ONE of `response` or `error` will be set.

  ## Union Type - ONE will be set:

  - `response`: Successful EmbedContentResponse
  - `error`: Error status if request failed

  ## Fields

  - `metadata`: Optional metadata from the request
  - `response`: Successful embedding response (if successful)
  - `error`: Error details (if failed)

  ## Examples

      # Successful response
      %InlinedEmbedContentResponse{
        metadata: %{"id" => "123"},
        response: %EmbedContentResponse{...},
        error: nil
      }

      # Failed response
      %InlinedEmbedContentResponse{
        metadata: %{"id" => "456"},
        response: nil,
        error: %{"code" => 400, "message" => "Invalid input"}
      }
  """

  alias Gemini.Types.Response.EmbedContentResponse

  defstruct [:metadata, :response, :error]

  @type t :: %__MODULE__{
          metadata: map() | nil,
          response: EmbedContentResponse.t() | nil,
          error: map() | nil
        }

  @doc """
  Creates an inlined response from API response data.

  ## Parameters

  - `data`: Map containing the API response

  ## Examples

      InlinedEmbedContentResponse.from_api_response(%{
        "metadata" => %{"id" => "123"},
        "response" => %{"embedding" => %{"values" => [...]}}
      })
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(data) when is_map(data) do
    %__MODULE__{
      metadata: data["metadata"],
      response: parse_response(data["response"]),
      error: data["error"]
    }
  end

  @doc """
  Checks if the inlined response is successful.

  ## Examples

      InlinedEmbedContentResponse.is_success?(response)
      # => true
  """
  @spec is_success?(t()) :: boolean()
  def is_success?(%__MODULE__{response: %EmbedContentResponse{}, error: nil}), do: true
  def is_success?(_), do: false

  @doc """
  Checks if the inlined response is an error.

  ## Examples

      InlinedEmbedContentResponse.is_error?(response)
      # => false
  """
  @spec is_error?(t()) :: boolean()
  def is_error?(%__MODULE__{response: nil, error: error}) when is_map(error), do: true
  def is_error?(_), do: false

  # Private helpers

  defp parse_response(nil), do: nil

  defp parse_response(response_data) when is_map(response_data) do
    EmbedContentResponse.from_api_response(response_data)
  end
end
