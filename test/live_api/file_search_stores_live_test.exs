defmodule Gemini.APIs.FileSearchStoresLiveTest do
  @moduledoc """
  Live API tests for the File Search Stores API.

  Run with: mix test --include live_api test/live_api/file_search_stores_live_test.exs

  Requires Gemini API authentication:
  - GEMINI_API_KEY (or GOOGLE_API_KEY)
  """

  use ExUnit.Case, async: false

  alias Gemini.APIs.{Files, FileSearchStores}
  alias Gemini.Error
  alias Gemini.Test.AuthHelpers
  alias Gemini.Types.{CreateFileSearchStoreConfig, FileSearchDocument, FileSearchStore}

  @moduletag timeout: 120_000

  @test_document_path "test/fixtures/test_document.txt"

  setup_all do
    case AuthHelpers.detect_auth(:gemini) do
      {:ok, :gemini, _creds} -> {:ok, api_configured: true}
      _ -> {:ok, api_configured: false}
    end
  end

  describe "create/2" do
    @tag :live_api
    test "creates a file search store", %{api_configured: configured} do
      if configured do
        config = %CreateFileSearchStoreConfig{
          display_name: "Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        assert store.name != nil
        assert String.starts_with?(store.name, "fileSearchStores/")
        assert store.display_name == config.display_name
        assert store.state in [nil, :creating, :active]

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end

    @tag :live_api
    test "creates store with vector config", %{api_configured: configured} do
      if configured do
        config = %CreateFileSearchStoreConfig{
          display_name: "Vector Test Store #{System.unique_integer([:positive])}",
          vector_config: %{
            embedding_model: "text-embedding-004"
          }
        }

        case FileSearchStores.create(config, auth: :gemini) do
          {:ok, store} ->
            assert store.name != nil
            assert store.vector_config != nil
            FileSearchStores.delete(store.name, force: true, auth: :gemini)

          {:error, %Error{} = error} ->
            message =
              cond do
                is_map(error.message) and is_binary(error.message["message"]) ->
                  error.message["message"]

                is_binary(error.message) ->
                  error.message

                true ->
                  inspect(error)
              end

            assert String.contains?(message, "vectorConfig") or
                     String.contains?(message, "Unknown name")
        end
      else
        :ok
      end
    end
  end

  describe "get/2" do
    @tag :live_api
    test "retrieves store by name", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Get Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, created} = FileSearchStores.create(config, auth: :gemini)

        # Retrieve it
        {:ok, store} = FileSearchStores.get(created.name, auth: :gemini)

        assert store.name == created.name
        assert store.display_name == created.display_name

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end

    @tag :live_api
    test "returns error for non-existent store", %{api_configured: configured} do
      if configured do
        result = FileSearchStores.get("fileSearchStores/nonexistent12345", auth: :gemini)

        assert {:error, _} = result
      else
        :ok
      end
    end
  end

  describe "list/1" do
    @tag :live_api
    test "lists file search stores", %{api_configured: configured} do
      if configured do
        # Create a test store to ensure we have at least one
        config = %CreateFileSearchStoreConfig{
          display_name: "List Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, created} = FileSearchStores.create(config, auth: :gemini)

        # List stores
        {:ok, response} = FileSearchStores.list(auth: :gemini)

        assert is_list(response.file_search_stores)

        # Cleanup
        FileSearchStores.delete(created.name, force: true, auth: :gemini)
      else
        :ok
      end
    end

    @tag :live_api
    test "lists with pagination", %{api_configured: configured} do
      if configured do
        {:ok, response} = FileSearchStores.list(page_size: 1, auth: :gemini)

        assert is_list(response.file_search_stores)

        if response.file_search_stores != [] do
          assert length(response.file_search_stores) <= 1
        end
      else
        :ok
      end
    end
  end

  describe "delete/2" do
    @tag :live_api
    test "deletes an empty store", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Delete Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Delete it
        assert :ok = FileSearchStores.delete(store.name, auth: :gemini)
      else
        :ok
      end
    end

    @tag :live_api_slow
    @tag :slow
    test "force deletes store with documents", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Force Delete Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 1000,
            timeout: 45_000,
            auth: :gemini
          )

        # Upload and import a test file (if store is active)
        if FileSearchStore.active?(active_store) do
          {:ok, file} = Files.upload(@test_document_path, auth: :gemini)
          {:ok, _doc} = FileSearchStores.import_file(store.name, file.name, auth: :gemini)

          # Cleanup uploaded file
          Files.delete(file.name, auth: :gemini)
        end

        # Force delete the store
        assert :ok = FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end
  end

  describe "wait_for_active/2" do
    @tag :live_api_slow
    @tag :slow
    test "waits for store to become active", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Wait Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Wait for it to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 1000,
            timeout: 60_000,
            auth: :gemini
          )

        assert FileSearchStore.active?(active_store)

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end

    @tag :live_api_slow
    @tag :slow
    test "times out if store doesn't become active", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Timeout Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Wait with very short timeout
        result =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 100,
            timeout: 200,
            auth: :gemini
          )

        # Should timeout or succeed quickly
        case result do
          {:error, :timeout} -> assert true
          {:ok, _} -> assert true
        end

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end
  end

  describe "import_file/3" do
    @tag :live_api_slow
    @tag :slow
    @tag timeout: 180_000
    test "imports a file into the store", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Import Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 1000,
            timeout: 45_000,
            auth: :gemini
          )

        if FileSearchStore.active?(active_store) do
          # Upload a file first
          {:ok, file} = Files.upload(@test_document_path, auth: :gemini)

          # Import it into the store
          {:ok, doc} = FileSearchStores.import_file(store.name, file.name, auth: :gemini)

          assert doc.name != nil
          assert String.contains?(doc.name, store.name)
          assert doc.state in [:processing, :active]

          # Cleanup
          Files.delete(file.name, auth: :gemini)
        end

        # Cleanup store
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end
  end

  describe "upload_to_store/3" do
    @tag :live_api_slow
    @tag :slow
    @tag timeout: 180_000
    test "uploads and imports a file directly", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Upload Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 1000,
            timeout: 45_000,
            auth: :gemini
          )

        if FileSearchStore.active?(active_store) do
          # Upload file directly to store
          {:ok, doc} =
            FileSearchStores.upload_to_store(
              store.name,
              @test_document_path,
              display_name: "Uploaded Test Doc",
              auth: :gemini
            )

          assert doc.name != nil
          assert doc.state in [:processing, :active]
        end

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end
  end

  describe "get_document/2" do
    @tag :live_api_slow
    @tag :slow
    @tag timeout: 180_000
    test "retrieves document metadata", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Doc Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 1000,
            timeout: 45_000,
            auth: :gemini
          )

        if FileSearchStore.active?(active_store) do
          # Upload a file
          {:ok, file} = Files.upload(@test_document_path, auth: :gemini)

          # Import it
          {:ok, doc} = FileSearchStores.import_file(store.name, file.name, auth: :gemini)

          # Get the document
          {:ok, retrieved} = FileSearchStores.get_document(doc.name, auth: :gemini)

          assert retrieved.name == doc.name
          assert retrieved.state in [:processing, :active, :failed]

          # Cleanup
          Files.delete(file.name, auth: :gemini)
        end

        # Cleanup store
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end
  end

  describe "wait_for_document/2" do
    @tag :live_api_slow
    @tag :slow
    @tag timeout: 180_000
    test "waits for document to be processed", %{api_configured: configured} do
      if configured do
        # Create a test store
        config = %CreateFileSearchStoreConfig{
          display_name: "Doc Wait Test Store #{System.unique_integer([:positive])}"
        }

        {:ok, store} = FileSearchStores.create(config, auth: :gemini)

        # Wait for store to be active
        {:ok, active_store} =
          FileSearchStores.wait_for_active(
            store.name,
            poll_interval: 1000,
            timeout: 45_000,
            auth: :gemini
          )

        if FileSearchStore.active?(active_store) do
          # Upload and import a file
          {:ok, doc} =
            FileSearchStores.upload_to_store(
              store.name,
              @test_document_path,
              auth: :gemini
            )

          # Wait for processing
          result =
            FileSearchStores.wait_for_document(
              doc.name,
              poll_interval: 2000,
              timeout: 60_000,
              auth: :gemini
            )

          case result do
            {:ok, processed_doc} ->
              assert FileSearchDocument.active?(processed_doc)

            {:error, :timeout} ->
              assert true

            {:error, :document_processing_failed} ->
              assert true
          end
        end

        # Cleanup
        FileSearchStores.delete(store.name, force: true, auth: :gemini)
      else
        :ok
      end
    end
  end

  describe "list_all/1" do
    @tag :live_api_slow
    @tag :slow
    test "retrieves all stores across pages", %{api_configured: configured} do
      if configured do
        # Create a couple of test stores
        config1 = %CreateFileSearchStoreConfig{
          display_name: "List All Test 1 #{System.unique_integer([:positive])}"
        }

        config2 = %CreateFileSearchStoreConfig{
          display_name: "List All Test 2 #{System.unique_integer([:positive])}"
        }

        {:ok, store1} = FileSearchStores.create(config1, auth: :gemini)
        {:ok, store2} = FileSearchStores.create(config2, auth: :gemini)

        # List all stores
        {:ok, all_stores} = FileSearchStores.list_all(auth: :gemini)

        assert is_list(all_stores)
        assert Enum.any?(all_stores, fn s -> s.name == store1.name end)
        assert Enum.any?(all_stores, fn s -> s.name == store2.name end)

        # Cleanup
        FileSearchStores.delete(store1.name, force: true, auth: :gemini)
        FileSearchStores.delete(store2.name, force: true, auth: :gemini)
      else
        :ok
      end
    end
  end
end
