defmodule Gemini.APIs.Documents do
  @moduledoc """
  Documents API for RAG (Retrieval-Augmented Generation) document management.

  Documents are stored in RAG stores and used for semantic search and
  context augmentation in generation requests.

  ## Overview

  The Documents API allows you to:
  - List documents in a RAG store
  - Get document metadata
  - Delete documents

  ## Example Workflow

      # List documents in a store
      {:ok, response} = Gemini.APIs.Documents.list("ragStores/my-store")

      Enum.each(response.documents, fn doc ->
        IO.puts("\#{doc.name}: \#{doc.state}")
      end)

      # Get specific document
      {:ok, doc} = Gemini.APIs.Documents.get("ragStores/my-store/documents/doc123")

      if Document.active?(doc) do
        IO.puts("Document ready: \#{doc.chunk_count} chunks")
      end

      # Delete document
      :ok = Gemini.APIs.Documents.delete("ragStores/my-store/documents/doc123")

  ## RAG Store Integration

  Documents are typically created by uploading files to a RAG store
  via the FileSearchStores API. This API focuses on document management
  after creation.
  """

  alias Gemini.Client.HTTP
  alias Gemini.Types.{Document, ListDocumentsResponse}

  @type list_opts :: [
          {:page_size, pos_integer()}
          | {:page_token, String.t()}
          | {:filter, String.t()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type document_opts :: [{:auth, :gemini | :vertex_ai}]

  @type wait_opts :: [
          {:poll_interval, pos_integer()}
          | {:timeout, pos_integer()}
          | {:on_status, (Document.t() -> any())}
          | {:auth, :gemini | :vertex_ai}
        ]

  @doc """
  Get a document by name.

  ## Parameters

  - `name` - Document resource name (e.g., "ragStores/abc/documents/xyz")
  - `opts` - Options

  ## Examples

      {:ok, doc} = Gemini.APIs.Documents.get("ragStores/my-store/documents/doc123")
      IO.puts("State: \#{doc.state}")
      IO.puts("Size: \#{doc.size_bytes} bytes")
      IO.puts("Chunks: \#{doc.chunk_count}")
  """
  @spec get(String.t(), document_opts()) :: {:ok, Document.t()} | {:error, term()}
  def get(name, opts \\ []) do
    path = normalize_document_path(name)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, Document.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List documents in a RAG store.

  ## Parameters

  - `store_name` - RAG store resource name (e.g., "ragStores/abc")
  - `opts` - List options

  ## Options

  - `:page_size` - Number of documents per page (default: 100)
  - `:page_token` - Token from previous response for pagination
  - `:filter` - Filter expression
  - `:auth` - Authentication strategy

  ## Examples

      # List all documents
      {:ok, response} = Gemini.APIs.Documents.list("ragStores/my-store")

      Enum.each(response.documents, fn doc ->
        IO.puts("\#{doc.display_name}: \#{doc.state}")
      end)

      # With pagination
      {:ok, page1} = Gemini.APIs.Documents.list("ragStores/my-store", page_size: 10)
      if ListDocumentsResponse.has_more_pages?(page1) do
        {:ok, page2} = Gemini.APIs.Documents.list("ragStores/my-store",
          page_token: page1.next_page_token
        )
      end
  """
  @spec list(String.t(), list_opts()) :: {:ok, ListDocumentsResponse.t()} | {:error, term()}
  def list(store_name, opts \\ []) do
    path = build_list_path(store_name, opts)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, ListDocumentsResponse.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all documents across all pages.

  Automatically handles pagination to retrieve all documents.

  ## Parameters

  - `store_name` - RAG store resource name
  - `opts` - Options

  ## Examples

      {:ok, all_docs} = Gemini.APIs.Documents.list_all("ragStores/my-store")
      active = Enum.filter(all_docs, &Document.active?/1)
      IO.puts("Active documents: \#{length(active)}")
  """
  @spec list_all(String.t(), list_opts()) :: {:ok, [Document.t()]} | {:error, term()}
  def list_all(store_name, opts \\ []) do
    collect_all_documents(store_name, opts, [])
  end

  @doc """
  Delete a document from a RAG store.

  ## Parameters

  - `name` - Document resource name
  - `opts` - Options

  ## Examples

      :ok = Gemini.APIs.Documents.delete("ragStores/my-store/documents/doc123")
  """
  @spec delete(String.t(), document_opts()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    path = normalize_document_path(name)

    case HTTP.delete(path, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Wait for a document to finish processing.

  Polls the document status until it reaches `:active` or `:failed` state.

  ## Parameters

  - `name` - Document resource name
  - `opts` - Wait options

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 2000)
  - `:timeout` - Maximum wait time in milliseconds (default: 300000 = 5 min)
  - `:on_status` - Callback for status updates `fn(Document.t()) -> any()`

  ## Examples

      {:ok, doc} = Gemini.APIs.Documents.wait_for_processing(
        "ragStores/my-store/documents/doc123",
        poll_interval: 5000,
        on_status: fn d -> IO.puts("State: \#{d.state}") end
      )

      if Document.active?(doc) do
        IO.puts("Document ready with \#{doc.chunk_count} chunks")
      end
  """
  @spec wait_for_processing(String.t(), wait_opts()) ::
          {:ok, Document.t()} | {:error, term()}
  def wait_for_processing(name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 2000)
    timeout = Keyword.get(opts, :timeout, 300_000)
    on_status = Keyword.get(opts, :on_status)
    doc_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)
    do_wait_for_processing(name, doc_opts, poll_interval, timeout, start_time, on_status)
  end

  # Private Functions

  defp normalize_document_path(name) do
    cond do
      String.starts_with?(name, "ragStores/") -> name
      String.contains?(name, "/documents/") -> name
      true -> name
    end
  end

  defp build_list_path(store_name, opts) do
    base =
      if String.starts_with?(store_name, "ragStores/") do
        "#{store_name}/documents"
      else
        "ragStores/#{store_name}/documents"
      end

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

    query_params =
      case Keyword.get(opts, :filter) do
        nil -> query_params
        filter -> [{"filter", filter} | query_params]
      end

    case query_params do
      [] -> base
      params -> base <> "?" <> URI.encode_query(params)
    end
  end

  defp collect_all_documents(store_name, opts, acc) do
    case list(store_name, opts) do
      {:ok, %{documents: docs, next_page_token: nil}} ->
        {:ok, acc ++ docs}

      {:ok, %{documents: docs, next_page_token: token}} ->
        collect_all_documents(store_name, Keyword.put(opts, :page_token, token), acc ++ docs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_wait_for_processing(name, opts, poll_interval, timeout, start_time, on_status) do
    case get(name, opts) do
      {:ok, doc} ->
        if on_status, do: on_status.(doc)

        case doc.state do
          :active ->
            {:ok, doc}

          :failed ->
            {:error, {:document_processing_failed, doc.error}}

          :processing ->
            elapsed = System.monotonic_time(:millisecond) - start_time

            if elapsed >= timeout do
              {:error, :timeout}
            else
              Process.sleep(poll_interval)

              do_wait_for_processing(
                name,
                opts,
                poll_interval,
                timeout,
                start_time,
                on_status
              )
            end

          _ ->
            {:error, {:unknown_state, doc.state}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

defmodule Gemini.APIs.RagStores do
  @moduledoc """
  RAG Stores API for managing file search stores.

  RAG (Retrieval-Augmented Generation) stores contain documents that
  can be searched semantically and used for context augmentation.

  ## Overview

  The RAG Stores API allows you to:
  - Create and manage RAG stores
  - List stores
  - Delete stores

  ## Example Workflow

      # List stores
      {:ok, response} = Gemini.APIs.RagStores.list()

      Enum.each(response.rag_stores, fn store ->
        IO.puts("\#{store.display_name}: \#{store.document_count} documents")
      end)

      # Get specific store
      {:ok, store} = Gemini.APIs.RagStores.get("ragStores/my-store")

      # Delete store
      :ok = Gemini.APIs.RagStores.delete("ragStores/my-store")
  """

  alias Gemini.Client.HTTP
  alias Gemini.Types.{RagStore, ListRagStoresResponse}

  @type list_opts :: [
          {:page_size, pos_integer()}
          | {:page_token, String.t()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type store_opts :: [{:auth, :gemini | :vertex_ai}]

  @type create_opts :: [
          {:display_name, String.t()}
          | {:description, String.t()}
          | {:vector_config, map()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @doc """
  Get a RAG store by name.

  ## Parameters

  - `name` - Store resource name (e.g., "ragStores/abc123")
  - `opts` - Options

  ## Examples

      {:ok, store} = Gemini.APIs.RagStores.get("ragStores/my-store")
      IO.puts("Documents: \#{store.document_count}")
      IO.puts("Size: \#{store.total_size_bytes} bytes")
  """
  @spec get(String.t(), store_opts()) :: {:ok, RagStore.t()} | {:error, term()}
  def get(name, opts \\ []) do
    path = normalize_store_path(name)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, RagStore.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all RAG stores.

  ## Parameters

  - `opts` - List options

  ## Options

  - `:page_size` - Number of stores per page (default: 100)
  - `:page_token` - Token from previous response for pagination
  - `:auth` - Authentication strategy

  ## Examples

      {:ok, response} = Gemini.APIs.RagStores.list()

      Enum.each(response.rag_stores, fn store ->
        IO.puts("\#{store.display_name}: \#{store.state}")
      end)
  """
  @spec list(list_opts()) :: {:ok, ListRagStoresResponse.t()} | {:error, term()}
  def list(opts \\ []) do
    path = build_list_path(opts)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, ListRagStoresResponse.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all RAG stores across all pages.

  ## Examples

      {:ok, all_stores} = Gemini.APIs.RagStores.list_all()
      active = Enum.filter(all_stores, &RagStore.active?/1)
  """
  @spec list_all(list_opts()) :: {:ok, [RagStore.t()]} | {:error, term()}
  def list_all(opts \\ []) do
    collect_all_stores(opts, [])
  end

  @doc """
  Create a new RAG store.

  ## Parameters

  - `opts` - Creation options

  ## Options

  - `:display_name` - Human-readable name (required)
  - `:description` - Store description
  - `:vector_config` - Vector embedding configuration
  - `:auth` - Authentication strategy

  ## Examples

      {:ok, store} = Gemini.APIs.RagStores.create(
        display_name: "My Knowledge Base",
        description: "Documents for customer support"
      )
  """
  @spec create(create_opts()) :: {:ok, RagStore.t()} | {:error, term()}
  def create(opts) do
    request_body =
      %{}
      |> maybe_put(:displayName, Keyword.get(opts, :display_name))
      |> maybe_put(:description, Keyword.get(opts, :description))
      |> maybe_put(:vectorConfig, Keyword.get(opts, :vector_config))

    case HTTP.post("ragStores", request_body, opts) do
      {:ok, response} -> {:ok, RagStore.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete a RAG store.

  ## Parameters

  - `name` - Store resource name
  - `opts` - Options

  ## Examples

      :ok = Gemini.APIs.RagStores.delete("ragStores/my-store")
  """
  @spec delete(String.t(), store_opts()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    path = normalize_store_path(name)

    case HTTP.delete(path, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Functions

  defp normalize_store_path("ragStores/" <> _ = name), do: name
  defp normalize_store_path(name), do: "ragStores/#{name}"

  defp build_list_path(opts) do
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
      [] -> "ragStores"
      params -> "ragStores?" <> URI.encode_query(params)
    end
  end

  defp collect_all_stores(opts, acc) do
    case list(opts) do
      {:ok, %{rag_stores: stores, next_page_token: nil}} ->
        {:ok, acc ++ stores}

      {:ok, %{rag_stores: stores, next_page_token: token}} ->
        collect_all_stores(Keyword.put(opts, :page_token, token), acc ++ stores)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
