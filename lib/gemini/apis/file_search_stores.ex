defmodule Gemini.APIs.FileSearchStores do
  @moduledoc """
  File Search Stores API for semantic search and RAG (Retrieval-Augmented Generation).

  File Search Stores enable semantic search over documents using vector embeddings.
  They are part of the Vertex AI RAG system and provide powerful document search
  capabilities for grounding generation responses.

  **Note:** This API is only available through Vertex AI authentication.

  ## Overview

  The File Search Stores API allows you to:
  - Create stores for organizing searchable documents
  - Import files into stores for indexing
  - Upload files directly to stores
  - List and manage stores
  - Delete stores when no longer needed

  ## Workflow

  1. **Create a Store**: Set up a semantic search store
  2. **Import Files**: Add documents to the store
  3. **Wait for Processing**: Documents are indexed asynchronously
  4. **Use in Generation**: Reference the store for grounded responses

  ## Example: Basic Store Creation

      alias Gemini.APIs.FileSearchStores
      alias Gemini.Types.CreateFileSearchStoreConfig

      # Create a store
      config = %CreateFileSearchStoreConfig{
        display_name: "Product Documentation",
        description: "Technical documentation for all products"
      }

      {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)
      IO.puts("Created: \#{store.name}")

      # Wait for store to be active
      {:ok, ready_store} = FileSearchStores.wait_for_active(store.name)

      # Import a file that was already uploaded
      {:ok, doc} = FileSearchStores.import_file(
        store.name,
        "files/abc123"
      )

  ## Example: Upload and Import

      # Upload a file directly to the store
      {:ok, doc} = FileSearchStores.upload_to_store(
        store.name,
        "/path/to/document.pdf",
        display_name: "Product Manual"
      )

      # Wait for document to be processed
      {:ok, ready_doc} = FileSearchStores.wait_for_document(doc.name)

  ## Example: List and Cleanup

      # List all stores
      {:ok, response} = FileSearchStores.list()

      Enum.each(response.file_search_stores, fn store ->
        IO.puts("\#{store.display_name}: \#{store.document_count} docs")
      end)

      # Delete a store (requires force: true if it has documents)
      :ok = FileSearchStores.delete("fileSearchStores/abc123", force: true)

  ## Grounding with File Search

  Once documents are indexed, use the store for grounding in generation:

      {:ok, response} = Gemini.generate_content(
        "What are the safety features?",
        tools: [
          %{file_search_stores: ["fileSearchStores/abc123"]}
        ]
      )

  ## Best Practices

  1. **Descriptive Names**: Use clear display names for stores
  2. **Wait for Processing**: Always wait for documents to reach `:active` state
  3. **Batch Imports**: Import multiple files before using the store
  4. **Monitor Size**: Check `document_count` and `total_size_bytes`
  5. **Clean Up**: Delete stores when no longer needed to avoid costs
  """

  alias Gemini.Client.HTTP

  alias Gemini.Types.{
    FileSearchStore,
    CreateFileSearchStoreConfig,
    ListFileSearchStoresResponse,
    FileSearchDocument
  }

  @type create_opts :: [
          {:auth, :gemini | :vertex_ai}
        ]

  @type store_opts :: [
          {:auth, :gemini | :vertex_ai}
        ]

  @type list_opts :: [
          {:page_size, pos_integer()}
          | {:page_token, String.t()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type delete_opts :: [
          {:force, boolean()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type import_opts :: [
          {:auth, :gemini | :vertex_ai}
        ]

  @type upload_opts :: [
          {:display_name, String.t()}
          | {:mime_type, String.t()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type wait_opts :: [
          {:poll_interval, pos_integer()}
          | {:timeout, pos_integer()}
          | {:on_status, (FileSearchStore.t() -> any())}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type wait_doc_opts :: [
          {:poll_interval, pos_integer()}
          | {:timeout, pos_integer()}
          | {:on_status, (FileSearchDocument.t() -> any())}
          | {:auth, :gemini | :vertex_ai}
        ]

  @doc """
  Create a new file search store.

  Creates a semantic search store for organizing and searching documents.
  The store will be in `:creating` state initially and will transition to
  `:active` once ready.

  ## Parameters

  - `config` - CreateFileSearchStoreConfig struct with store configuration
  - `opts` - Options (must include `auth: :vertex_ai`)

  ## Examples

      config = %CreateFileSearchStoreConfig{
        display_name: "Product Docs",
        description: "All product documentation"
      }

      {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

      # Wait for it to be active
      {:ok, active_store} = FileSearchStores.wait_for_active(store.name)
  """
  @spec create(CreateFileSearchStoreConfig.t(), create_opts()) ::
          {:ok, FileSearchStore.t()} | {:error, term()}
  def create(%CreateFileSearchStoreConfig{} = config, opts \\ []) do
    path = "fileSearchStores"
    body = CreateFileSearchStoreConfig.to_api_request(config)

    case HTTP.post(path, body, opts) do
      {:ok, response} -> {:ok, FileSearchStore.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get a file search store by name.

  ## Parameters

  - `name` - Store resource name (e.g., "fileSearchStores/abc123")
  - `opts` - Options

  ## Examples

      {:ok, store} = FileSearchStores.get("fileSearchStores/abc123")
      IO.puts("State: \#{store.state}")
      IO.puts("Documents: \#{store.document_count}")
      IO.puts("Size: \#{store.total_size_bytes} bytes")
  """
  @spec get(String.t(), store_opts()) :: {:ok, FileSearchStore.t()} | {:error, term()}
  def get(name, opts \\ []) do
    path = normalize_store_path(name)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, FileSearchStore.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete a file search store.

  By default, stores with documents cannot be deleted. Use `force: true` to
  delete a store and all its documents.

  ## Parameters

  - `name` - Store resource name
  - `opts` - Delete options

  ## Options

  - `:force` - Delete even if store contains documents (default: false)
  - `:auth` - Authentication strategy

  ## Examples

      # Delete empty store
      :ok = FileSearchStores.delete("fileSearchStores/abc123")

      # Force delete store with documents
      :ok = FileSearchStores.delete(
        "fileSearchStores/abc123",
        force: true
      )
  """
  @spec delete(String.t(), delete_opts()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    path = build_delete_path(name, opts)

    case HTTP.delete(path, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List file search stores.

  ## Parameters

  - `opts` - List options

  ## Options

  - `:page_size` - Number of stores per page (default: 100)
  - `:page_token` - Token from previous response for pagination
  - `:auth` - Authentication strategy

  ## Examples

      # List all stores
      {:ok, response} = FileSearchStores.list()

      Enum.each(response.file_search_stores, fn store ->
        IO.puts("\#{store.display_name}: \#{store.state}")
      end)

      # With pagination
      {:ok, page1} = FileSearchStores.list(page_size: 10)
      if ListFileSearchStoresResponse.has_more_pages?(page1) do
        {:ok, page2} = FileSearchStores.list(
          page_token: page1.next_page_token
        )
      end
  """
  @spec list(list_opts()) :: {:ok, ListFileSearchStoresResponse.t()} | {:error, term()}
  def list(opts \\ []) do
    path = build_list_path(opts)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, ListFileSearchStoresResponse.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all file search stores across all pages.

  Automatically handles pagination to retrieve all stores.

  ## Parameters

  - `opts` - Options

  ## Examples

      {:ok, all_stores} = FileSearchStores.list_all()
      active = Enum.filter(all_stores, &FileSearchStore.active?/1)
      IO.puts("Active stores: \#{length(active)}")
  """
  @spec list_all(list_opts()) :: {:ok, [FileSearchStore.t()]} | {:error, term()}
  def list_all(opts \\ []) do
    collect_all_stores(opts, [])
  end

  @doc """
  Import an already uploaded file into the store.

  The file must have been previously uploaded using the Files API.
  This creates a document in the store that will be indexed for search.

  ## Parameters

  - `store_name` - Store resource name
  - `file_name` - File resource name (e.g., "files/abc123")
  - `opts` - Options

  ## Examples

      # Upload a file first
      {:ok, file} = Gemini.upload_file("/path/to/doc.pdf")

      # Import it into the store
      {:ok, doc} = FileSearchStores.import_file(
        "fileSearchStores/abc123",
        file.name
      )

      # Wait for processing
      {:ok, ready_doc} = FileSearchStores.wait_for_document(doc.name)
  """
  @spec import_file(String.t(), String.t(), import_opts()) ::
          {:ok, FileSearchDocument.t()} | {:error, term()}
  def import_file(store_name, file_name, opts \\ []) do
    path = "#{normalize_store_path(store_name)}:import"
    body = %{"file" => normalize_file_path(file_name)}

    case HTTP.post(path, body, opts) do
      {:ok, response} -> {:ok, FileSearchDocument.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Upload a file directly to the store.

  This is a convenience method that uploads a file and imports it into the
  store in a single operation.

  ## Parameters

  - `store_name` - Store resource name
  - `file_path` - Path to local file
  - `opts` - Upload options

  ## Options

  - `:display_name` - Human-readable name for the document
  - `:mime_type` - MIME type (auto-detected if not provided)
  - `:auth` - Authentication strategy

  ## Examples

      {:ok, doc} = FileSearchStores.upload_to_store(
        "fileSearchStores/abc123",
        "/path/to/document.pdf",
        display_name: "Product Manual v2.0"
      )

      IO.puts("Uploaded: \#{doc.name}")
  """
  @spec upload_to_store(String.t(), String.t(), upload_opts()) ::
          {:ok, FileSearchDocument.t()} | {:error, term()}
  def upload_to_store(store_name, file_path, opts \\ []) do
    # First upload the file
    upload_opts = Keyword.take(opts, [:display_name, :mime_type, :auth])

    with {:ok, file} <- Gemini.APIs.Files.upload(file_path, upload_opts),
         {:ok, doc} <- import_file(store_name, file.name, opts) do
      {:ok, doc}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Wait for a store to become active.

  Polls the store status until it reaches `:active` or `:failed` state.

  ## Parameters

  - `name` - Store resource name
  - `opts` - Wait options

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 2000)
  - `:timeout` - Maximum wait time in milliseconds (default: 300000 = 5 min)
  - `:on_status` - Callback for status updates `fn(FileSearchStore.t()) -> any()`
  - `:auth` - Authentication strategy

  ## Examples

      {:ok, store} = FileSearchStores.wait_for_active(
        "fileSearchStores/abc123",
        poll_interval: 5000,
        on_status: fn s -> IO.puts("State: \#{s.state}") end
      )

      if FileSearchStore.active?(store) do
        IO.puts("Store ready!")
      end
  """
  @spec wait_for_active(String.t(), wait_opts()) ::
          {:ok, FileSearchStore.t()} | {:error, term()}
  def wait_for_active(name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 2000)
    timeout = Keyword.get(opts, :timeout, 300_000)
    on_status = Keyword.get(opts, :on_status)
    store_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)
    do_wait_for_active(name, store_opts, poll_interval, timeout, start_time, on_status)
  end

  @doc """
  Wait for a document to finish processing.

  Polls the document status until it reaches `:active` or `:failed` state.

  ## Parameters

  - `document_name` - Document resource name
  - `opts` - Wait options

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 2000)
  - `:timeout` - Maximum wait time in milliseconds (default: 300000 = 5 min)
  - `:on_status` - Callback for status updates
  - `:auth` - Authentication strategy

  ## Examples

      {:ok, doc} = FileSearchStores.wait_for_document(
        "fileSearchStores/abc/documents/xyz",
        on_status: fn d -> IO.puts("Chunks: \#{d.chunk_count}") end
      )
  """
  @spec wait_for_document(String.t(), wait_doc_opts()) ::
          {:ok, FileSearchDocument.t()} | {:error, term()}
  def wait_for_document(document_name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 2000)
    timeout = Keyword.get(opts, :timeout, 300_000)
    on_status = Keyword.get(opts, :on_status)
    doc_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)
    do_wait_for_document(document_name, doc_opts, poll_interval, timeout, start_time, on_status)
  end

  @doc """
  Get a document from a file search store.

  ## Parameters

  - `document_name` - Document resource name
  - `opts` - Options

  ## Examples

      {:ok, doc} = FileSearchStores.get_document(
        "fileSearchStores/abc/documents/xyz"
      )
      IO.puts("State: \#{doc.state}")
  """
  @spec get_document(String.t(), store_opts()) ::
          {:ok, FileSearchDocument.t()} | {:error, term()}
  def get_document(document_name, opts \\ []) do
    path = normalize_document_path(document_name)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, FileSearchDocument.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Functions

  defp normalize_store_path(name) do
    if String.starts_with?(name, "fileSearchStores/") do
      name
    else
      "fileSearchStores/#{name}"
    end
  end

  defp normalize_file_path(name) do
    if String.starts_with?(name, "files/") do
      name
    else
      "files/#{name}"
    end
  end

  defp normalize_document_path(name) do
    cond do
      String.starts_with?(name, "fileSearchStores/") -> name
      String.contains?(name, "/documents/") -> name
      true -> name
    end
  end

  defp build_delete_path(name, opts) do
    base = normalize_store_path(name)

    if Keyword.get(opts, :force, false) do
      "#{base}?force=true"
    else
      base
    end
  end

  defp build_list_path(opts) do
    base = "fileSearchStores"
    query_params = []

    query_params =
      case Keyword.get(opts, :page_size) do
        nil -> query_params
        size -> [{"pageSize", size} | query_params]
      end

    query_params =
      case Keyword.get(opts, :page_token) do
        nil -> query_params
        token -> [{"pageToken", token} | query_params]
      end

    case query_params do
      [] ->
        base

      params ->
        query_string =
          params
          |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
          |> Enum.join("&")

        "#{base}?#{query_string}"
    end
  end

  defp collect_all_stores(opts, acc) do
    case list(opts) do
      {:ok, response} ->
        new_acc = acc ++ response.file_search_stores

        if ListFileSearchStoresResponse.has_more_pages?(response) do
          new_opts = Keyword.put(opts, :page_token, response.next_page_token)
          collect_all_stores(new_opts, new_acc)
        else
          {:ok, new_acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_wait_for_active(name, opts, poll_interval, timeout, start_time, on_status) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed >= timeout do
      {:error, :timeout}
    else
      case get(name, opts) do
        {:ok, store} ->
          if on_status, do: on_status.(store)

          case store.state do
            :active ->
              {:ok, store}

            :failed ->
              {:error, :store_creation_failed}

            _ ->
              Process.sleep(poll_interval)
              do_wait_for_active(name, opts, poll_interval, timeout, start_time, on_status)
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp do_wait_for_document(document_name, opts, poll_interval, timeout, start_time, on_status) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed >= timeout do
      {:error, :timeout}
    else
      case get_document(document_name, opts) do
        {:ok, doc} ->
          if on_status, do: on_status.(doc)

          case doc.state do
            :active ->
              {:ok, doc}

            :failed ->
              {:error, :document_processing_failed}

            _ ->
              Process.sleep(poll_interval)

              do_wait_for_document(
                document_name,
                opts,
                poll_interval,
                timeout,
                start_time,
                on_status
              )
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
