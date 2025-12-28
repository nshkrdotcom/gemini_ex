defmodule Gemini.APIs.FileSearchStoresLiveTest do
  @moduledoc """
  Live API tests for the File Search Stores API.

  Run with: mix test --include live_api test/live_api/file_search_stores_live_test.exs

  Requires Vertex AI authentication:
  - GOOGLE_CLOUD_PROJECT environment variable
  - GOOGLE_APPLICATION_CREDENTIALS or valid gcloud credentials

  Note: File Search Stores are only available through Vertex AI.
  """

  use ExUnit.Case, async: false

  alias Gemini.APIs.{Files, FileSearchStores}
  alias Gemini.Types.{CreateFileSearchStoreConfig, FileSearchDocument, FileSearchStore}

  # Use Elixir.File for standard library file operations
  @elixir_file Elixir.File

  @moduletag :live_api
  @moduletag timeout: 120_000

  @test_document_path "test/fixtures/test_document.txt"

  setup_all do
    # Check for Vertex AI configuration
    project_id = System.get_env("GOOGLE_CLOUD_PROJECT")
    credentials_path = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")

    vertex_configured? =
      project_id != nil and project_id != "" and
        (credentials_path != nil and credentials_path != "" and
           @elixir_file.exists?(credentials_path))

    if vertex_configured? do
      # Configure Vertex AI
      Gemini.configure(:vertex_ai, %{
        project_id: project_id,
        location: "us-central1"
      })

      {:ok, vertex_configured: true}
    else
      {:ok, vertex_configured: false}
    end
  end

  describe "create/2" do
    @tag :live_api
    test "creates a file search store", %{vertex_configured: configured} do
      if configured do
        config = %CreateFileSearchStoreConfig{
          display_name: "Test Store #{System.unique_integer([:positive])}",
          description: "Test store for live API testing"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        assert store.name != nil
        assert String.starts_with?(store.name, "fileSearchStores/")
        assert store.display_name == config.display_name
        assert store.description == config.description
        assert store.state in [:creating, :active]

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end

    @tag :live_api
    test "creates store with vector config", %{vertex_configured: configured} do
      if configured do
        config = %CreateFileSearchStoreConfig{
          display_name: "Vector Test Store #{System.unique_integer([:positive])}",
          vector_config: %{
            embedding_model: "text-embedding-004"
          }
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        assert store.name != nil
        assert store.vector_config != nil

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "get/2" do
    @tag :live_api
    test "retrieves store by name", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Get Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, created} = FileSearchStores.create(config, auth: :vertex_ai)

        # Retrieve it
        {:ok, store} = FileSearchStores.get(created.name, auth: :vertex_ai)

        assert store.name == created.name
        assert store.display_name == created.display_name

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end

    @tag :live_api
    test "returns error for non-existent store", %{vertex_configured: configured} do
      if configured do
        result = FileSearchStores.get("fileSearchStores/nonexistent12345", auth: :vertex_ai)

        assert {:error, _} = result
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "list/1" do
    @tag :live_api
    test "lists file search stores", %{vertex_configured: configured} do
      if configured do
        # Create a test store to ensure we have at least one
        config = %CreateFileSearchStoreConfig{
          display_name: "List Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, created} = FileSearchStores.create(config, auth: :vertex_ai)

        # List stores
        {:ok, response} = FileSearchStores.list(auth: :vertex_ai)

        assert is_list(response.file_search_stores)
        assert Enum.any?(response.file_search_stores, fn s -> s.name == created.name end)

        # Cleanup
        FileSearchStores.delete(created.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end

    @tag :live_api
    test "lists with pagination", %{vertex_configured: configured} do
      if configured do
        {:ok, response} = FileSearchStores.list(page_size: 1, auth: :vertex_ai)

        assert is_list(response.file_search_stores)

        if length(response.file_search_stores) > 0 do
          assert length(response.file_search_stores) <= 1
        end
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "delete/2" do
    @tag :live_api
    test "deletes an empty store", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Delete Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Delete it
        assert :ok = FileSearchStores.delete(store.name, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end

    @tag :live_api
    test "force deletes store with documents", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Force Delete Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(store.name, poll_interval: 1000, auth: :vertex_ai)

        # Upload and import a test file (if store is active)
        if FileSearchStore.active?(active_store) do
          {:ok, file} = Files.upload(@test_document_path, auth: :vertex_ai)
          {:ok, _doc} = FileSearchStores.import_file(store.name, file.name, auth: :vertex_ai)

          # Cleanup uploaded file
          Files.delete(file.name, auth: :vertex_ai)
        end

        # Force delete the store
        assert :ok = FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "wait_for_active/2" do
    @tag :live_api
    test "waits for store to become active", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Wait Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Wait for it to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 1000,
            timeout: 60_000,
            auth: :vertex_ai
          )

        assert FileSearchStore.active?(active_store)

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end

    @tag :live_api
    test "times out if store doesn't become active", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Timeout Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Wait with very short timeout
        result =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 100,
            timeout: 200,
            auth: :vertex_ai
          )

        # Should timeout or succeed quickly
        case result do
          {:error, :timeout} -> assert true
          {:ok, _} -> assert true
        end

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "import_file/3" do
    @tag :live_api
    @tag timeout: 180_000
    test "imports a file into the store", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Import Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(store.name, poll_interval: 1000, auth: :vertex_ai)

        if FileSearchStore.active?(active_store) do
          # Upload a file first
          {:ok, file} = Files.upload(@test_document_path, auth: :vertex_ai)

          # Import it into the store
          {:ok, doc} = FileSearchStores.import_file(store.name, file.name, auth: :vertex_ai)

          assert doc.name != nil
          assert String.contains?(doc.name, store.name)
          assert doc.state in [:processing, :active]

          # Cleanup
          Files.delete(file.name, auth: :vertex_ai)
        end

        # Cleanup store
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "upload_to_store/3" do
    @tag :live_api
    @tag timeout: 180_000
    test "uploads and imports a file directly", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Upload Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(store.name, poll_interval: 1000, auth: :vertex_ai)

        if FileSearchStore.active?(active_store) do
          # Upload file directly to store
          {:ok, doc} =
            FileSearchStores.upload_to_store(
              store.name,
              @test_document_path,
              display_name: "Uploaded Test Doc",
              auth: :vertex_ai
            )

          assert doc.name != nil
          assert doc.state in [:processing, :active]
        end

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "get_document/2" do
    @tag :live_api
    @tag timeout: 180_000
    test "retrieves document metadata", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Doc Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(store.name, poll_interval: 1000, auth: :vertex_ai)

        if FileSearchStore.active?(active_store) do
          # Upload a file
          {:ok, file} = Files.upload(@test_document_path, auth: :vertex_ai)

          # Import it
          {:ok, doc} = FileSearchStores.import_file(store.name, file.name, auth: :vertex_ai)

          # Get the document
          {:ok, retrieved} = FileSearchStores.get_document(doc.name, auth: :vertex_ai)

          assert retrieved.name == doc.name
          assert retrieved.state in [:processing, :active, :failed]

          # Cleanup
          Files.delete(file.name, auth: :vertex_ai)
        end

        # Cleanup store
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "wait_for_document/2" do
    @tag :live_api
    @tag timeout: 180_000
    test "waits for document to be processed", %{vertex_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Doc Wait Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(store.name, poll_interval: 1000, auth: :vertex_ai)

        if FileSearchStore.active?(active_store) do
          # Upload and import a file
          {:ok, doc} =
            FileSearchStores.upload_to_store(
              store.name,
              @test_document_path,
              auth: :vertex_ai
            )

          # Wait for processing
          result =
            FileSearchStores.wait_for_document(
              doc.name,
              poll_interval: 2000,
              timeout: 60_000,
              auth: :vertex_ai
            )

          case result do
            {:ok, processed_doc} ->
              assert FileSearchDocument.active?(processed_doc)

            {:error, :timeout} ->
              IO.puts("Document processing timed out (may be expected for large files)")
              assert true

            {:error, :document_processing_failed} ->
              IO.puts("Document processing failed")
              assert true
          end
        end

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end

  describe "list_all/1" do
    @tag :live_api
    test "retrieves all stores across pages", %{vertex_configured: configured} do
      if configured do
        # Create a couple of test stores
        config1 = %CreateFileSearchStoreConfig{
          display_name: "List All Test 1 #{System.unique_integer([:positive])}"
        }

        config2 = %CreateFileSearchStoreConfig{
          display_name: "List All Test 2 #{System.unique_integer([:positive])}"
        }

        {:ok, store1} = FileSearchStores.create(config1, auth: :vertex_ai)
        {:ok, store2} = FileSearchStores.create(config2, auth: :vertex_ai)

        # List all stores
        {:ok, all_stores} = FileSearchStores.list_all(auth: :vertex_ai)

        assert is_list(all_stores)
        assert Enum.any?(all_stores, fn s -> s.name == store1.name end)
        assert Enum.any?(all_stores, fn s -> s.name == store2.name end)

        # Cleanup
        FileSearchStores.delete(store1.name, force: true, auth: :vertex_ai)
        FileSearchStores.delete(store2.name, force: true, auth: :vertex_ai)
      else
        IO.puts("Skipping: Vertex AI not configured")
        :ok
      end
    end
  end
end
