defmodule Gemini.Types.Request.InputEmbedContentConfig do
  @moduledoc """
  Input configuration for async batch embedding.

  Specifies where to read batch embedding requests from. This is a union type -
  exactly ONE of the fields must be set.

  ## Union Type - Choose ONE:

  - `file_name`: Google Cloud Storage URI (e.g., "gs://bucket/inputs.jsonl")
  - `requests`: InlinedEmbedContentRequests for inline processing

  Per spec: Cannot specify both. One must be nil.

  ## Examples

      # File-based input
      InputEmbedContentConfig.new_from_file("gs://my-bucket/embeddings/batch-001.jsonl")

      # Inline requests
      InputEmbedContentConfig.new_from_requests(inlined_requests)
  """

  alias Gemini.Types.Request.InlinedEmbedContentRequests

  defstruct [:file_name, :requests]

  @type t :: %__MODULE__{
          file_name: String.t() | nil,
          requests: InlinedEmbedContentRequests.t() | nil
        }

  @doc """
  Creates input config from a Google Cloud Storage file.

  ## Parameters

  - `file_name`: GCS URI (e.g., "gs://bucket/inputs.jsonl")

  ## Examples

      InputEmbedContentConfig.new_from_file("gs://my-bucket/batch.jsonl")
  """
  @spec new_from_file(String.t()) :: t()
  def new_from_file(file_name) when is_binary(file_name) do
    %__MODULE__{
      file_name: file_name,
      requests: nil
    }
  end

  @doc """
  Creates input config from inline requests.

  ## Parameters

  - `requests`: InlinedEmbedContentRequests container

  ## Examples

      InputEmbedContentConfig.new_from_requests(inlined_requests)
  """
  @spec new_from_requests(InlinedEmbedContentRequests.t()) :: t()
  def new_from_requests(%InlinedEmbedContentRequests{} = requests) do
    %__MODULE__{
      file_name: nil,
      requests: requests
    }
  end

  @doc """
  Converts the input config to API-compatible map format.

  For file-based: {"fileName": "gs://..."}
  For inline: {"requests": {"requests": [...]}}
  """
  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{file_name: file_name, requests: nil}) when is_binary(file_name) do
    %{"fileName" => file_name}
  end

  def to_api_map(%__MODULE__{file_name: nil, requests: %InlinedEmbedContentRequests{} = requests}) do
    # Wrap the InlinedEmbedContentRequests in a "requests" key
    %{"requests" => InlinedEmbedContentRequests.to_api_map(requests)}
  end

  @doc """
  Validates that exactly one input source is specified.

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid

  ## Examples

      InputEmbedContentConfig.validate(config)
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{file_name: nil, requests: nil}) do
    {:error, "Must specify either file_name or requests"}
  end

  def validate(%__MODULE__{file_name: file_name, requests: requests})
      when not is_nil(file_name) and not is_nil(requests) do
    {:error, "Cannot specify both file_name and requests"}
  end

  def validate(%__MODULE__{file_name: file_name}) when is_binary(file_name) do
    if String.starts_with?(file_name, "gs://") do
      :ok
    else
      {:error, "file_name must be a Google Cloud Storage URI (gs://...)"}
    end
  end

  def validate(%__MODULE__{requests: %InlinedEmbedContentRequests{}}), do: :ok

  def validate(_), do: {:error, "Invalid input config"}
end
