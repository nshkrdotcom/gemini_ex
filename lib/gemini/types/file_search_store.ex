defmodule Gemini.Types.FileSearchStore do
  @moduledoc """
  Type definitions for File Search Stores (semantic search stores).

  File Search Stores enable semantic search over uploaded documents using
  vector embeddings. They are part of the RAG (Retrieval-Augmented Generation)
  system and are only available through Vertex AI.

  ## Store States

  Stores go through several states during their lifecycle:

  - `:state_unspecified` - Initial/unknown state
  - `:creating` - Store is being created
  - `:active` - Store is ready to use
  - `:deleting` - Store is being deleted
  - `:failed` - Store creation/operation failed

  ## Example

      # Create a file search store
      config = %CreateFileSearchStoreConfig{
        display_name: "Product Documentation",
        description: "Technical documentation for our products"
      }
      {:ok, store} = Gemini.APIs.FileSearchStores.create(config)

      # Check store state
      case store.state do
        :active -> IO.puts("Store ready: \#{store.name}")
        :creating -> IO.puts("Still creating...")
        :failed -> IO.puts("Failed to create store")
      end

      # Import files
      {:ok, _doc} = Gemini.APIs.FileSearchStores.import_file(
        store.name,
        "files/uploaded-doc-id"
      )
  """

  use TypedStruct

  @typedoc """
  File search store state enumeration.

  - `:state_unspecified` - Initial/unknown state
  - `:creating` - Store is being created
  - `:active` - Store is ready for operations
  - `:deleting` - Store is being deleted
  - `:failed` - Operation failed
  """
  @type file_search_store_state ::
          :state_unspecified
          | :creating
          | :active
          | :deleting
          | :failed

  @typedoc """
  Vector embedding configuration for the store.
  """
  @type vector_config :: %{
          optional(:embedding_model) => String.t(),
          optional(:dimensions) => pos_integer()
        }

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Represents a File Search Store for semantic search.

    ## Fields

    - `name` - Resource name (format: "fileSearchStores/{store_id}")
    - `display_name` - Human-readable name
    - `description` - Store description
    - `state` - Current state
    - `create_time` - Creation timestamp (ISO 8601)
    - `update_time` - Last update timestamp (ISO 8601)
    - `document_count` - Number of documents in the store
    - `total_size_bytes` - Total size of all documents
    - `vector_config` - Vector embedding configuration
    """

    field(:name, String.t())
    field(:display_name, String.t())
    field(:description, String.t())
    field(:state, file_search_store_state())
    field(:create_time, String.t())
    field(:update_time, String.t())
    field(:document_count, integer())
    field(:total_size_bytes, integer())
    field(:vector_config, vector_config())
  end

  @doc """
  Creates a FileSearchStore from API response.

  ## Parameters

  - `response` - Map from API response with string keys

  ## Examples

      response = %{
        "name" => "fileSearchStores/abc123",
        "displayName" => "My Store",
        "state" => "ACTIVE",
        "documentCount" => 42
      }
      store = FileSearchStore.from_api_response(response)
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
  @spec parse_state(String.t() | nil) :: file_search_store_state() | nil
  def parse_state("STATE_UNSPECIFIED"), do: :state_unspecified
  def parse_state("CREATING"), do: :creating
  def parse_state("ACTIVE"), do: :active
  def parse_state("DELETING"), do: :deleting
  def parse_state("FAILED"), do: :failed
  def parse_state(nil), do: nil
  def parse_state(_), do: :state_unspecified

  @doc """
  Converts state atom to API string format.
  """
  @spec state_to_api(file_search_store_state()) :: String.t()
  def state_to_api(:state_unspecified), do: "STATE_UNSPECIFIED"
  def state_to_api(:creating), do: "CREATING"
  def state_to_api(:active), do: "ACTIVE"
  def state_to_api(:deleting), do: "DELETING"
  def state_to_api(:failed), do: "FAILED"

  @doc """
  Checks if the store is active and ready to use.
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{state: :active}), do: true
  def active?(_), do: false

  @doc """
  Checks if the store is still being created.
  """
  @spec creating?(t()) :: boolean()
  def creating?(%__MODULE__{state: :creating}), do: true
  def creating?(_), do: false

  @doc """
  Checks if the store operation failed.
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{state: :failed}), do: true
  def failed?(_), do: false

  @doc """
  Extracts the store ID from the full resource name.

  ## Examples

      store = %FileSearchStore{name: "fileSearchStores/abc123"}
      FileSearchStore.get_id(store)
      # => "abc123"
  """
  @spec get_id(t()) :: String.t() | nil
  def get_id(%__MODULE__{name: nil}), do: nil

  def get_id(%__MODULE__{name: name}) do
    case String.split(name, "/") do
      ["fileSearchStores", id] -> id
      _ -> name
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
end

defmodule Gemini.Types.CreateFileSearchStoreConfig do
  @moduledoc """
  Configuration for creating a new File Search Store.

  ## Example

      config = %CreateFileSearchStoreConfig{
        display_name: "Product Documentation",
        description: "Technical docs for all our products",
        vector_config: %{
          embedding_model: "text-embedding-004",
          dimensions: 768
        }
      }

      {:ok, store} = Gemini.APIs.FileSearchStores.create(config)
  """

  use TypedStruct

  alias Gemini.Types.FileSearchStore

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Configuration for creating a file search store.

    ## Fields

    - `display_name` - Human-readable name for the store
    - `description` - Description of the store's purpose
    - `vector_config` - Optional vector embedding configuration
    """

    field(:display_name, String.t())
    field(:description, String.t())
    field(:vector_config, FileSearchStore.vector_config())
  end

  @doc """
  Converts the config to API request format.
  """
  @spec to_api_request(t()) :: map()
  def to_api_request(%__MODULE__{} = config) do
    %{}
    |> put_if_present("displayName", config.display_name)
    |> put_if_present("description", config.description)
    |> put_if_present("vectorConfig", config.vector_config)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, value) when value == %{}, do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.ListFileSearchStoresResponse do
  @moduledoc """
  Response type for listing file search stores.
  """

  use TypedStruct

  alias Gemini.Types.FileSearchStore

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response from listing file search stores.

    - `file_search_stores` - List of FileSearchStore structs
    - `next_page_token` - Token for fetching next page (nil if no more pages)
    """
    field(:file_search_stores, [FileSearchStore.t()], default: [])
    field(:next_page_token, String.t())
  end

  @doc """
  Creates a ListFileSearchStoresResponse from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    stores =
      (response["fileSearchStores"] || [])
      |> Enum.map(&FileSearchStore.from_api_response/1)

    %__MODULE__{
      file_search_stores: stores,
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

defmodule Gemini.Types.FileSearchDocument do
  @moduledoc """
  Represents a document within a File Search Store.

  This is similar to the regular Document type but specific to file search stores.
  Documents are created when files are imported into the store.
  """

  use TypedStruct

  @typedoc """
  Document state in the file search store.
  """
  @type document_state ::
          :state_unspecified
          | :processing
          | :active
          | :failed

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    A document in a file search store.

    ## Fields

    - `name` - Resource name (e.g., "fileSearchStores/abc/documents/xyz")
    - `display_name` - Human-readable name
    - `state` - Processing state
    - `create_time` - When the document was created
    - `update_time` - Last update timestamp
    - `size_bytes` - Document size in bytes
    - `mime_type` - MIME type of the document
    - `chunk_count` - Number of chunks for indexing
    - `error` - Error details if processing failed
    """

    field(:name, String.t())
    field(:display_name, String.t())
    field(:state, document_state())
    field(:create_time, String.t())
    field(:update_time, String.t())
    field(:size_bytes, integer())
    field(:mime_type, String.t())
    field(:chunk_count, integer())
    field(:error, map())
  end

  @doc """
  Creates a FileSearchDocument from API response.
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
      mime_type: response["mimeType"],
      chunk_count: response["chunkCount"],
      error: response["error"]
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
  Checks if the document is active.
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{state: :active}), do: true
  def active?(_), do: false

  defp parse_integer(nil), do: nil
  defp parse_integer(val) when is_integer(val), do: val

  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
end
