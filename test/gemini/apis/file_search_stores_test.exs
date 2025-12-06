defmodule Gemini.APIs.FileSearchStoresTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{
    FileSearchStore,
    CreateFileSearchStoreConfig,
    ListFileSearchStoresResponse,
    FileSearchDocument
  }

  describe "FileSearchStore type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "fileSearchStores/store123",
        "displayName" => "Product Documentation",
        "description" => "All product docs",
        "state" => "ACTIVE",
        "createTime" => "2025-12-05T10:00:00Z",
        "updateTime" => "2025-12-05T10:05:00Z",
        "documentCount" => 42,
        "totalSizeBytes" => "1048576",
        "vectorConfig" => %{
          "embeddingModel" => "text-embedding-004",
          "dimensions" => 768
        }
      }

      store = FileSearchStore.from_api_response(response)

      assert store.name == "fileSearchStores/store123"
      assert store.display_name == "Product Documentation"
      assert store.description == "All product docs"
      assert store.state == :active
      assert store.create_time == "2025-12-05T10:00:00Z"
      assert store.update_time == "2025-12-05T10:05:00Z"
      assert store.document_count == 42
      assert store.total_size_bytes == 1_048_576
      assert store.vector_config["embeddingModel"] == "text-embedding-004"
    end

    test "from_api_response/1 parses creating state" do
      response = %{
        "name" => "fileSearchStores/store123",
        "state" => "CREATING"
      }

      store = FileSearchStore.from_api_response(response)
      assert store.state == :creating
    end

    test "from_api_response/1 parses failed state" do
      response = %{
        "name" => "fileSearchStores/store123",
        "state" => "FAILED"
      }

      store = FileSearchStore.from_api_response(response)
      assert store.state == :failed
    end

    test "from_api_response/1 handles integer totalSizeBytes" do
      response = %{
        "name" => "fileSearchStores/store123",
        "totalSizeBytes" => 2048
      }

      store = FileSearchStore.from_api_response(response)
      assert store.total_size_bytes == 2048
    end

    test "from_api_response/1 handles missing optional fields" do
      response = %{
        "name" => "fileSearchStores/store123"
      }

      store = FileSearchStore.from_api_response(response)
      assert store.name == "fileSearchStores/store123"
      assert store.display_name == nil
      assert store.description == nil
      assert store.vector_config == nil
    end
  end

  describe "FileSearchStore state helpers" do
    test "active?/1 returns true for active stores" do
      assert FileSearchStore.active?(%FileSearchStore{state: :active})
      refute FileSearchStore.active?(%FileSearchStore{state: :creating})
    end

    test "creating?/1 returns true for creating stores" do
      assert FileSearchStore.creating?(%FileSearchStore{state: :creating})
      refute FileSearchStore.creating?(%FileSearchStore{state: :active})
    end

    test "failed?/1 returns true for failed stores" do
      assert FileSearchStore.failed?(%FileSearchStore{state: :failed})
      refute FileSearchStore.failed?(%FileSearchStore{state: :active})
    end
  end

  describe "FileSearchStore.get_id/1" do
    test "extracts store ID from full name" do
      store = %FileSearchStore{name: "fileSearchStores/store123"}
      assert FileSearchStore.get_id(store) == "store123"
    end

    test "returns nil for nil name" do
      store = %FileSearchStore{name: nil}
      assert FileSearchStore.get_id(store) == nil
    end

    test "returns full name for non-standard format" do
      store = %FileSearchStore{name: "custom/path"}
      assert FileSearchStore.get_id(store) == "custom/path"
    end
  end

  describe "FileSearchStore state conversion" do
    test "parse_state/1 handles all states" do
      assert FileSearchStore.parse_state("STATE_UNSPECIFIED") == :state_unspecified
      assert FileSearchStore.parse_state("CREATING") == :creating
      assert FileSearchStore.parse_state("ACTIVE") == :active
      assert FileSearchStore.parse_state("DELETING") == :deleting
      assert FileSearchStore.parse_state("FAILED") == :failed
      assert FileSearchStore.parse_state(nil) == nil
      assert FileSearchStore.parse_state("UNKNOWN") == :state_unspecified
    end

    test "state_to_api/1 converts atoms to strings" do
      assert FileSearchStore.state_to_api(:state_unspecified) == "STATE_UNSPECIFIED"
      assert FileSearchStore.state_to_api(:creating) == "CREATING"
      assert FileSearchStore.state_to_api(:active) == "ACTIVE"
      assert FileSearchStore.state_to_api(:deleting) == "DELETING"
      assert FileSearchStore.state_to_api(:failed) == "FAILED"
    end
  end

  describe "CreateFileSearchStoreConfig" do
    test "to_api_request/1 converts config to API format" do
      config = %CreateFileSearchStoreConfig{
        display_name: "Test Store",
        description: "Test description",
        vector_config: %{
          embedding_model: "text-embedding-004",
          dimensions: 768
        }
      }

      request = CreateFileSearchStoreConfig.to_api_request(config)

      assert request["displayName"] == "Test Store"
      assert request["description"] == "Test description"
      assert request["vectorConfig"][:embedding_model] == "text-embedding-004"
      assert request["vectorConfig"][:dimensions] == 768
    end

    test "to_api_request/1 omits nil fields" do
      config = %CreateFileSearchStoreConfig{
        display_name: "Test Store",
        description: nil,
        vector_config: nil
      }

      request = CreateFileSearchStoreConfig.to_api_request(config)

      assert request["displayName"] == "Test Store"
      refute Map.has_key?(request, "description")
      refute Map.has_key?(request, "vectorConfig")
    end
  end

  describe "ListFileSearchStoresResponse" do
    test "from_api_response/1 parses stores list" do
      response = %{
        "fileSearchStores" => [
          %{"name" => "fileSearchStores/s1", "state" => "ACTIVE"},
          %{"name" => "fileSearchStores/s2", "state" => "CREATING"}
        ],
        "nextPageToken" => "token123"
      }

      result = ListFileSearchStoresResponse.from_api_response(response)

      assert length(result.file_search_stores) == 2
      assert result.next_page_token == "token123"
      assert ListFileSearchStoresResponse.has_more_pages?(result)
    end

    test "from_api_response/1 handles empty response" do
      response = %{}
      result = ListFileSearchStoresResponse.from_api_response(response)

      assert result.file_search_stores == []
      assert result.next_page_token == nil
      refute ListFileSearchStoresResponse.has_more_pages?(result)
    end

    test "from_api_response/1 handles no next page" do
      response = %{
        "fileSearchStores" => [
          %{"name" => "fileSearchStores/s1", "state" => "ACTIVE"}
        ]
      }

      result = ListFileSearchStoresResponse.from_api_response(response)

      assert length(result.file_search_stores) == 1
      refute ListFileSearchStoresResponse.has_more_pages?(result)
    end

    test "has_more_pages?/1 returns false for empty token" do
      result = %ListFileSearchStoresResponse{next_page_token: ""}
      refute ListFileSearchStoresResponse.has_more_pages?(result)
    end
  end

  describe "FileSearchDocument type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "fileSearchStores/s1/documents/d1",
        "displayName" => "Document 1",
        "state" => "ACTIVE",
        "createTime" => "2025-12-05T10:00:00Z",
        "updateTime" => "2025-12-05T10:05:00Z",
        "sizeBytes" => "2048",
        "mimeType" => "application/pdf",
        "chunkCount" => 10,
        "error" => %{
          "code" => 500,
          "message" => "Error message"
        }
      }

      doc = FileSearchDocument.from_api_response(response)

      assert doc.name == "fileSearchStores/s1/documents/d1"
      assert doc.display_name == "Document 1"
      assert doc.state == :active
      assert doc.create_time == "2025-12-05T10:00:00Z"
      assert doc.update_time == "2025-12-05T10:05:00Z"
      assert doc.size_bytes == 2048
      assert doc.mime_type == "application/pdf"
      assert doc.chunk_count == 10
      assert doc.error["code"] == 500
    end

    test "from_api_response/1 parses processing state" do
      response = %{
        "name" => "fileSearchStores/s1/documents/d1",
        "state" => "PROCESSING"
      }

      doc = FileSearchDocument.from_api_response(response)
      assert doc.state == :processing
    end

    test "from_api_response/1 parses failed state" do
      response = %{
        "name" => "fileSearchStores/s1/documents/d1",
        "state" => "FAILED"
      }

      doc = FileSearchDocument.from_api_response(response)
      assert doc.state == :failed
    end

    test "from_api_response/1 handles integer sizeBytes" do
      response = %{
        "name" => "fileSearchStores/s1/documents/d1",
        "sizeBytes" => 4096
      }

      doc = FileSearchDocument.from_api_response(response)
      assert doc.size_bytes == 4096
    end
  end

  describe "FileSearchDocument state helpers" do
    test "active?/1 returns true for active documents" do
      assert FileSearchDocument.active?(%FileSearchDocument{state: :active})
      refute FileSearchDocument.active?(%FileSearchDocument{state: :processing})
    end
  end

  describe "FileSearchDocument state conversion" do
    test "parse_state/1 handles all states" do
      assert FileSearchDocument.parse_state("STATE_UNSPECIFIED") == :state_unspecified
      assert FileSearchDocument.parse_state("PROCESSING") == :processing
      assert FileSearchDocument.parse_state("ACTIVE") == :active
      assert FileSearchDocument.parse_state("FAILED") == :failed
      assert FileSearchDocument.parse_state(nil) == nil
      assert FileSearchDocument.parse_state("UNKNOWN") == :state_unspecified
    end
  end
end
