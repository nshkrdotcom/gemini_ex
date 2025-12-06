defmodule Gemini.Types.Document do
  @moduledoc """
  Type definitions for RAG document management.

  Documents are stored in RAG stores and used for semantic search and
  retrieval-augmented generation (RAG) workflows.

  ## Document Lifecycle

  1. Upload a file to a RAG store
  2. Document is created with metadata
  3. Document is indexed for search
  4. Use in generation with grounding

  ## Example

      # List documents in a store
      {:ok, response} = Gemini.APIs.Documents.list("ragStores/my-store")

      # Get document metadata
      {:ok, doc} = Gemini.APIs.Documents.get("ragStores/my-store/documents/doc123")

      # Delete when no longer needed
      :ok = Gemini.APIs.Documents.delete(doc.name)
  """

  use TypedStruct

  @typedoc """
  Document state enumeration.
  """
  @type document_state ::
          :state_unspecified
          | :processing
          | :active
          | :failed

  @typedoc """
  Document metadata for custom properties.
  """
  @type document_metadata :: %{optional(String.t()) => String.t()}

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Represents a document in a RAG store.

    ## Fields

    - `name` - Resource name (e.g., "ragStores/abc/documents/xyz")
    - `display_name` - Human-readable name
    - `state` - Processing state
    - `create_time` - When the document was created
    - `update_time` - Last update timestamp
    - `size_bytes` - Document size in bytes
    - `source_uri` - Original source URI (if applicable)
    - `mime_type` - MIME type of the document
    - `metadata` - Custom metadata key-value pairs
    - `error` - Error details if processing failed
    - `chunk_count` - Number of chunks the document was split into
    """

    field(:name, String.t())
    field(:display_name, String.t())
    field(:state, document_state())
    field(:create_time, String.t())
    field(:update_time, String.t())
    field(:size_bytes, integer())
    field(:source_uri, String.t())
    field(:mime_type, String.t())
    field(:metadata, document_metadata())
    field(:error, map())
    field(:chunk_count, integer())
  end

  @doc """
  Creates a Document from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    %__MODULE__{
      name: response["name"],
      display_name: response["displayName"],
      state: parse_state(response["state"]),
      create_time: response["createTime"],
      update_time: response["updateTime"],
      size_bytes: parse_integer(response["sizeBytes"]),
      source_uri: response["sourceUri"],
      mime_type: response["mimeType"],
      metadata: response["metadata"],
      error: parse_error(response["error"]),
      chunk_count: response["chunkCount"]
    }
  end

  @doc """
  Parses document state from API string.
  """
  @spec parse_state(String.t() | nil) :: document_state() | nil
  def parse_state("STATE_UNSPECIFIED"), do: :state_unspecified
  def parse_state("PROCESSING"), do: :processing
  def parse_state("ACTIVE"), do: :active
  def parse_state("FAILED"), do: :failed
  def parse_state(nil), do: nil
  def parse_state(_), do: :state_unspecified

  @doc """
  Converts state atom to API string.
  """
  @spec state_to_api(document_state()) :: String.t()
  def state_to_api(:state_unspecified), do: "STATE_UNSPECIFIED"
  def state_to_api(:processing), do: "PROCESSING"
  def state_to_api(:active), do: "ACTIVE"
  def state_to_api(:failed), do: "FAILED"

  @doc """
  Checks if the document is ready for use.
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{state: :active}), do: true
  def active?(_), do: false

  @doc """
  Checks if the document is still processing.
  """
  @spec processing?(t()) :: boolean()
  def processing?(%__MODULE__{state: :processing}), do: true
  def processing?(_), do: false

  @doc """
  Checks if the document processing failed.
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{state: :failed}), do: true
  def failed?(_), do: false

  @doc """
  Extracts the document ID from the full resource name.
  """
  @spec get_id(t()) :: String.t() | nil
  def get_id(%__MODULE__{name: nil}), do: nil

  def get_id(%__MODULE__{name: name}) do
    case String.split(name, "/") do
      ["ragStores", _store_id, "documents", doc_id] -> doc_id
      _ -> name
    end
  end

  @doc """
  Extracts the store ID from the document's full resource name.
  """
  @spec get_store_id(t()) :: String.t() | nil
  def get_store_id(%__MODULE__{name: nil}), do: nil

  def get_store_id(%__MODULE__{name: name}) do
    case String.split(name, "/") do
      ["ragStores", store_id, "documents", _doc_id] -> store_id
      _ -> nil
    end
  end

  # Private helpers

  defp parse_integer(nil), do: nil
  defp parse_integer(val) when is_integer(val), do: val

  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_error(nil), do: nil

  defp parse_error(error) when is_map(error) do
    %{
      code: error["code"],
      message: error["message"],
      details: error["details"]
    }
  end
end

defmodule Gemini.Types.ListDocumentsResponse do
  @moduledoc """
  Response type for listing documents in a RAG store.
  """

  use TypedStruct

  alias Gemini.Types.Document

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response from listing documents.
    """
    field(:documents, [Document.t()], default: [])
    field(:next_page_token, String.t())
  end

  @doc """
  Creates a ListDocumentsResponse from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    docs =
      (response["documents"] || [])
      |> Enum.map(&Document.from_api_response/1)

    %__MODULE__{
      documents: docs,
      next_page_token: response["nextPageToken"]
    }
  end

  @doc """
  Checks if there are more pages available.
  """
  @spec has_more_pages?(t()) :: boolean()
  def has_more_pages?(%__MODULE__{next_page_token: nil}), do: false
  def has_more_pages?(%__MODULE__{next_page_token: ""}), do: false
  def has_more_pages?(%__MODULE__{next_page_token: _}), do: true
end

defmodule Gemini.Types.RagStore do
  @moduledoc """
  Type definitions for RAG stores (FileSearchStores).

  RAG stores contain documents that can be searched semantically
  and used for retrieval-augmented generation.
  """

  use TypedStruct

  @typedoc """
  RAG store state enumeration.
  """
  @type store_state ::
          :state_unspecified
          | :creating
          | :active
          | :deleting
          | :failed

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Represents a RAG store.

    ## Fields

    - `name` - Resource name (e.g., "ragStores/abc123")
    - `display_name` - Human-readable name
    - `description` - Store description
    - `state` - Current state
    - `create_time` - When the store was created
    - `update_time` - Last update timestamp
    - `document_count` - Number of documents in the store
    - `total_size_bytes` - Total size of all documents
    - `vector_config` - Vector embedding configuration
    """

    field(:name, String.t())
    field(:display_name, String.t())
    field(:description, String.t())
    field(:state, store_state())
    field(:create_time, String.t())
    field(:update_time, String.t())
    field(:document_count, integer())
    field(:total_size_bytes, integer())
    field(:vector_config, map())
  end

  @doc """
  Creates a RagStore from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    %__MODULE__{
      name: response["name"],
      display_name: response["displayName"],
      description: response["description"],
      state: parse_state(response["state"]),
      create_time: response["createTime"],
      update_time: response["updateTime"],
      document_count: response["documentCount"],
      total_size_bytes: parse_integer(response["totalSizeBytes"]),
      vector_config: response["vectorConfig"]
    }
  end

  @doc """
  Parses store state from API string.
  """
  @spec parse_state(String.t() | nil) :: store_state() | nil
  def parse_state("STATE_UNSPECIFIED"), do: :state_unspecified
  def parse_state("CREATING"), do: :creating
  def parse_state("ACTIVE"), do: :active
  def parse_state("DELETING"), do: :deleting
  def parse_state("FAILED"), do: :failed
  def parse_state(nil), do: nil
  def parse_state(_), do: :state_unspecified

  @doc """
  Checks if the store is active.
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{state: :active}), do: true
  def active?(_), do: false

  @doc """
  Extracts the store ID from the full name.
  """
  @spec get_id(t()) :: String.t() | nil
  def get_id(%__MODULE__{name: nil}), do: nil

  def get_id(%__MODULE__{name: name}) do
    case String.split(name, "/") do
      ["ragStores", id] -> id
      _ -> name
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(val) when is_integer(val), do: val

  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
end

defmodule Gemini.Types.ListRagStoresResponse do
  @moduledoc """
  Response type for listing RAG stores.
  """

  use TypedStruct

  alias Gemini.Types.RagStore

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response from listing RAG stores.
    """
    field(:rag_stores, [RagStore.t()], default: [])
    field(:next_page_token, String.t())
  end

  @doc """
  Creates a ListRagStoresResponse from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    stores =
      (response["ragStores"] || response["fileSearchStores"] || [])
      |> Enum.map(&RagStore.from_api_response/1)

    %__MODULE__{
      rag_stores: stores,
      next_page_token: response["nextPageToken"]
    }
  end

  @doc """
  Checks if there are more pages available.
  """
  @spec has_more_pages?(t()) :: boolean()
  def has_more_pages?(%__MODULE__{next_page_token: nil}), do: false
  def has_more_pages?(%__MODULE__{next_page_token: ""}), do: false
  def has_more_pages?(%__MODULE__{next_page_token: _}), do: true
end
