defmodule Gemini.Types.Request.EmbedContentRequest do
  @moduledoc """
  Request structure for embedding content using Gemini embedding models.

  Represents a request to generate text embeddings from input content.
  Embeddings are numerical representations of text that enable use cases
  such as clustering, similarity measurement, and information retrieval.

  ## Fields

  - `model`: The embedding model to use (e.g., "gemini-embedding-001", "gemini-embedding-exp-03-07")
  - `content`: The content to embed (only text parts will be processed)
  - `task_type`: Optional task type for optimized embeddings
  - `title`: Optional title for retrieval documents
  - `output_dimensionality`: Optional dimension reduction for embeddings

  ## Examples

      # Simple embedding request
      %EmbedContentRequest{
        model: "models/gemini-embedding-001",
        content: %Content{
          parts: [%Part{text: "What is the meaning of life?"}]
        }
      }

      # With task type and dimensionality
      %EmbedContentRequest{
        model: "models/gemini-embedding-001",
        content: %Content{
          parts: [%Part{text: "Document text here"}]
        },
        task_type: :retrieval_document,
        title: "Important Document",
        output_dimensionality: 256
      }
  """

  alias Gemini.Types.Content

  @enforce_keys [:model, :content]
  defstruct [:model, :content, :task_type, :title, :output_dimensionality]

  @type task_type ::
          :task_type_unspecified
          | :retrieval_query
          | :retrieval_document
          | :semantic_similarity
          | :classification
          | :clustering
          | :question_answering
          | :fact_verification
          | :code_retrieval_query

  @type t :: %__MODULE__{
          model: String.t(),
          content: Content.t(),
          task_type: task_type() | nil,
          title: String.t() | nil,
          output_dimensionality: pos_integer() | nil
        }

  @doc """
  Creates a new embedding request from text content.

  ## Parameters

  - `text`: The text to embed
  - `opts`: Optional keyword list of options
    - `:model`: Model to use (default: "gemini-embedding-001")
    - `:task_type`: Task type for optimized embeddings
    - `:title`: Title for retrieval documents
    - `:output_dimensionality`: Dimension reduction

  ## Examples

      EmbedContentRequest.new("What is AI?")

      EmbedContentRequest.new("Document content",
        task_type: :retrieval_document,
        title: "AI Overview",
        output_dimensionality: 256
      )
  """
  @spec new(String.t(), keyword()) :: t()
  def new(text, opts \\ []) when is_binary(text) do
    model = Keyword.get(opts, :model, "gemini-embedding-001")

    content = %Content{
      role: "user",
      parts: [%Gemini.Types.Part{text: text}]
    }

    %__MODULE__{
      model: "models/#{model}",
      content: content,
      task_type: Keyword.get(opts, :task_type),
      title: Keyword.get(opts, :title),
      output_dimensionality: Keyword.get(opts, :output_dimensionality)
    }
  end

  @doc """
  Converts the request struct to API-compatible map format.

  Converts snake_case field names to camelCase as required by the Gemini API.
  """
  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{} = request) do
    %{
      "model" => request.model,
      "content" => content_to_map(request.content)
    }
    |> maybe_put("taskType", task_type_to_string(request.task_type))
    |> maybe_put("title", request.title)
    |> maybe_put("outputDimensionality", request.output_dimensionality)
  end

  # Private helpers

  defp content_to_map(%Content{parts: parts}) do
    %{
      "parts" => Enum.map(parts, &part_to_map/1)
    }
  end

  defp part_to_map(%{text: text}), do: %{"text" => text}
  defp part_to_map(part), do: part

  defp task_type_to_string(nil), do: nil
  defp task_type_to_string(:task_type_unspecified), do: "TASK_TYPE_UNSPECIFIED"
  defp task_type_to_string(:retrieval_query), do: "RETRIEVAL_QUERY"
  defp task_type_to_string(:retrieval_document), do: "RETRIEVAL_DOCUMENT"
  defp task_type_to_string(:semantic_similarity), do: "SEMANTIC_SIMILARITY"
  defp task_type_to_string(:classification), do: "CLASSIFICATION"
  defp task_type_to_string(:clustering), do: "CLUSTERING"
  defp task_type_to_string(:question_answering), do: "QUESTION_ANSWERING"
  defp task_type_to_string(:fact_verification), do: "FACT_VERIFICATION"
  defp task_type_to_string(:code_retrieval_query), do: "CODE_RETRIEVAL_QUERY"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
