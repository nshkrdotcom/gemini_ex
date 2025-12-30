defmodule Gemini.Types.Request.EmbedContentRequest do
  @moduledoc """
  Request structure for embedding content using Gemini embedding models.

  Represents a request to generate text embeddings from input content.
  Embeddings are numerical representations of text that enable use cases
  such as clustering, similarity measurement, and information retrieval.

  ## API Differences

  This module handles the differences between Gemini API and Vertex AI embedding models:

  - **Gemini API** (`gemini-embedding-001`): Uses `taskType` parameter
  - **Vertex AI** (`embeddinggemma`): Uses prompt prefixes like "task: search result | query: "

  The `new/2` function automatically detects the model type and formats accordingly.

  ## Fields

  - `model`: The embedding model to use (e.g., "gemini-embedding-001" or "embeddinggemma")
  - `content`: The content to embed (only text parts will be processed)
  - `task_type`: Optional task type for optimized embeddings
  - `title`: Optional title for retrieval documents
  - `output_dimensionality`: Optional dimension reduction for embeddings

  ## Examples

      # Simple embedding request (auto-detects model from auth)
      EmbedContentRequest.new("What is the meaning of life?")

      # With task type - automatically formats for model type
      EmbedContentRequest.new("Document text here",
        task_type: :retrieval_document,
        title: "Important Document",
        output_dimensionality: 256
      )

      # For EmbeddingGemma, the text becomes:
      # "title: Important Document | text: Document text here"
  """

  alias Gemini.Config
  alias Gemini.Types.Content

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

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

  Automatically handles model-specific formatting:
  - For Gemini embedding models: Uses taskType parameter
  - For EmbeddingGemma: Prepends prompt prefix to text content

  ## Parameters

  - `text`: The text to embed
  - `opts`: Optional keyword list of options
    - `:model`: Model to use (default: auto-detected based on auth)
    - `:task_type`: Task type for optimized embeddings
    - `:title`: Title for retrieval documents (required for EmbeddingGemma with :retrieval_document)
    - `:output_dimensionality`: Dimension reduction

  ## Examples

      # Basic usage (auto-detects model)
      EmbedContentRequest.new("What is AI?")

      # With task type (works with both APIs)
      EmbedContentRequest.new("Document content",
        task_type: :retrieval_document,
        title: "AI Overview"
      )

      # Explicit model selection
      EmbedContentRequest.new("Query text",
        model: "embeddinggemma",
        task_type: :retrieval_query
      )
      # Text becomes: "task: search result | query: Query text"
  """
  @spec new(String.t(), keyword()) :: t()
  def new(text, opts \\ []) when is_binary(text) do
    model = Keyword.get(opts, :model, Config.default_embedding_model())
    task_type = Keyword.get(opts, :task_type)
    title = Keyword.get(opts, :title)

    # Format text based on model type
    formatted_text = format_text_for_model(text, model, task_type, title)

    content = %Content{
      role: "user",
      parts: [%Gemini.Types.Part{text: formatted_text}]
    }

    %__MODULE__{
      model: "models/#{model}",
      content: content,
      # Only store task_type for models that use the parameter
      task_type: if(Config.uses_prompt_prefix?(model), do: nil, else: task_type),
      title: if(Config.uses_prompt_prefix?(model), do: nil, else: title),
      output_dimensionality: Keyword.get(opts, :output_dimensionality)
    }
  end

  @doc """
  Creates an embedding request with explicit API type specification.

  Use this when you need to force a specific API's embedding model regardless
  of the current authentication configuration.

  ## Parameters

  - `text`: The text to embed
  - `api_type`: `:gemini` or `:vertex_ai`
  - `opts`: Same options as `new/2`

  ## Examples

      # Force Gemini API embedding model
      EmbedContentRequest.new_for_api("Query", :gemini, task_type: :retrieval_query)

      # Force Vertex AI embedding model
      EmbedContentRequest.new_for_api("Document", :vertex_ai, task_type: :retrieval_document)
  """
  @spec new_for_api(String.t(), :gemini | :vertex_ai, keyword()) :: t()
  def new_for_api(text, api_type, opts \\ []) when is_binary(text) do
    model = Config.default_embedding_model_for(api_type)
    new(text, Keyword.put(opts, :model, model))
  end

  @doc """
  Converts the request struct to API-compatible map format.

  Converts snake_case field names to camelCase as required by the Gemini API.
  For EmbeddingGemma models, the task type is already embedded in the text content.
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

  @doc """
  Format text with the appropriate prompt prefix for EmbeddingGemma models.

  This is exposed for cases where you need to manually format text for
  EmbeddingGemma without going through the full request creation.

  ## Parameters

  - `text`: The original text
  - `task_type`: Task type atom
  - `opts`: Options including `:title` for retrieval_document

  ## Examples

      format_for_embedding_gemma("My query", :retrieval_query)
      #=> "task: search result | query: My query"

      format_for_embedding_gemma("My document", :retrieval_document, title: "Title")
      #=> "title: Title | text: My document"
  """
  @spec format_for_embedding_gemma(String.t(), task_type() | nil, keyword()) :: String.t()
  def format_for_embedding_gemma(text, task_type, opts \\ []) do
    prefix = Config.embedding_prompt_prefix(task_type || :retrieval_query, opts)
    prefix <> text
  end

  # Private helpers

  # Format text based on whether the model uses prompt prefixes
  defp format_text_for_model(text, model, task_type, title) do
    if Config.uses_prompt_prefix?(model) do
      # EmbeddingGemma - prepend prompt prefix
      opts = if title, do: [title: title], else: []
      format_for_embedding_gemma(text, task_type, opts)
    else
      # Gemini embedding - text stays as-is, task_type goes in parameter
      text
    end
  end

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
end
