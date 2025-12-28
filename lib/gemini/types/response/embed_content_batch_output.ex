defmodule Gemini.Types.Response.EmbedContentBatchOutput do
  @moduledoc """
  Output of an async batch embedding job.

  This is a union type - exactly ONE of the fields will be set.

  ## Union Type - ONE will be set:

  - `responses_file`: File ID containing JSONL responses (for file-based output)
  - `inlined_responses`: Direct inline responses (for inline output)

  ## Fields

  - `responses_file`: GCS file containing batch results
  - `inlined_responses`: Container with inline response data

  ## Examples

      # File-based output
      %EmbedContentBatchOutput{
        responses_file: "gs://bucket/outputs/batch-001-results.jsonl",
        inlined_responses: nil
      }

      # Inline output
      %EmbedContentBatchOutput{
        responses_file: nil,
        inlined_responses: %InlinedEmbedContentResponses{...}
      }
  """

  alias Gemini.Types.Response.InlinedEmbedContentResponses

  defstruct [:responses_file, :inlined_responses]

  @type t :: %__MODULE__{
          responses_file: String.t() | nil,
          inlined_responses: InlinedEmbedContentResponses.t() | nil
        }

  @doc """
  Creates batch output from API response data.

  ## Parameters

  - `data`: Map containing the API response

  ## Examples

      EmbedContentBatchOutput.from_api_response(%{
        "responsesFile" => "gs://bucket/results.jsonl"
      })
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(data) when is_map(data) do
    %__MODULE__{
      responses_file: data["responsesFile"],
      inlined_responses: parse_inlined_responses(data)
    }
  end

  @doc """
  Checks if the output is file-based.

  ## Examples

      EmbedContentBatchOutput.file_based?(output)
      # => true
  """
  @spec file_based?(t()) :: boolean()
  def file_based?(%__MODULE__{responses_file: file}) when is_binary(file), do: true
  def file_based?(_), do: false

  @doc """
  Checks if the output is inline.

  ## Examples

      EmbedContentBatchOutput.inline?(output)
      # => false
  """
  @spec inline?(t()) :: boolean()
  def inline?(%__MODULE__{inlined_responses: %InlinedEmbedContentResponses{}}), do: true
  def inline?(_), do: false

  # Private helpers

  defp parse_inlined_responses(%{"inlinedResponses" => _} = data) do
    InlinedEmbedContentResponses.from_api_response(data)
  end

  defp parse_inlined_responses(_), do: nil
end
