defmodule Gemini.APIs.DocumentsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{Document, ListDocumentsResponse, RagStore, ListRagStoresResponse}

  describe "Document type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "ragStores/store123/documents/doc456",
        "displayName" => "Test Document",
        "state" => "ACTIVE",
        "createTime" => "2025-12-05T10:00:00Z",
        "updateTime" => "2025-12-05T10:05:00Z",
        "sizeBytes" => "1024",
        "sourceUri" => "gs://bucket/path/to/file.pdf",
        "mimeType" => "application/pdf",
        "metadata" => %{"key" => "value"},
        "chunkCount" => 42
      }

      doc = Document.from_api_response(response)

      assert doc.name == "ragStores/store123/documents/doc456"
      assert doc.display_name == "Test Document"
      assert doc.state == :active
      assert doc.size_bytes == 1024
      assert doc.source_uri == "gs://bucket/path/to/file.pdf"
      assert doc.mime_type == "application/pdf"
      assert doc.metadata["key"] == "value"
      assert doc.chunk_count == 42
    end

    test "from_api_response/1 parses processing state" do
      response = %{"name" => "ragStores/s/documents/d", "state" => "PROCESSING"}
      doc = Document.from_api_response(response)
      assert doc.state == :processing
    end

    test "from_api_response/1 parses failed state with error" do
      response = %{
        "name" => "ragStores/s/documents/d",
        "state" => "FAILED",
        "error" => %{
          "code" => 500,
          "message" => "Processing failed",
          "details" => ["Detail 1"]
        }
      }

      doc = Document.from_api_response(response)
      assert doc.state == :failed
      assert doc.error.code == 500
      assert doc.error.message == "Processing failed"
    end

    test "from_api_response/1 handles integer sizeBytes" do
      response = %{"name" => "ragStores/s/documents/d", "sizeBytes" => 2048}
      doc = Document.from_api_response(response)
      assert doc.size_bytes == 2048
    end
  end

  describe "Document state helpers" do
    test "active?/1 returns true for active documents" do
      assert Document.active?(%Document{state: :active})
      refute Document.active?(%Document{state: :processing})
    end

    test "processing?/1 returns true for processing documents" do
      assert Document.processing?(%Document{state: :processing})
      refute Document.processing?(%Document{state: :active})
    end

    test "failed?/1 returns true for failed documents" do
      assert Document.failed?(%Document{state: :failed})
      refute Document.failed?(%Document{state: :active})
    end
  end

  describe "Document.get_id/1" do
    test "extracts document ID from full name" do
      doc = %Document{name: "ragStores/store123/documents/doc456"}
      assert Document.get_id(doc) == "doc456"
    end

    test "returns nil for nil name" do
      doc = %Document{name: nil}
      assert Document.get_id(doc) == nil
    end

    test "returns full name for non-standard format" do
      doc = %Document{name: "custom/path"}
      assert Document.get_id(doc) == "custom/path"
    end
  end

  describe "Document.get_store_id/1" do
    test "extracts store ID from document name" do
      doc = %Document{name: "ragStores/store123/documents/doc456"}
      assert Document.get_store_id(doc) == "store123"
    end

    test "returns nil for nil name" do
      doc = %Document{name: nil}
      assert Document.get_store_id(doc) == nil
    end

    test "returns nil for non-standard format" do
      doc = %Document{name: "custom/path"}
      assert Document.get_store_id(doc) == nil
    end
  end

  describe "Document state conversion" do
    test "parse_state/1 handles all states" do
      assert Document.parse_state("STATE_UNSPECIFIED") == :state_unspecified
      assert Document.parse_state("PROCESSING") == :processing
      assert Document.parse_state("ACTIVE") == :active
      assert Document.parse_state("FAILED") == :failed
      assert Document.parse_state(nil) == nil
      assert Document.parse_state("UNKNOWN") == :state_unspecified
    end

    test "state_to_api/1 converts atoms to strings" do
      assert Document.state_to_api(:state_unspecified) == "STATE_UNSPECIFIED"
      assert Document.state_to_api(:processing) == "PROCESSING"
      assert Document.state_to_api(:active) == "ACTIVE"
      assert Document.state_to_api(:failed) == "FAILED"
    end
  end

  describe "ListDocumentsResponse" do
    test "from_api_response/1 parses documents list" do
      response = %{
        "documents" => [
          %{"name" => "ragStores/s/documents/d1", "state" => "ACTIVE"},
          %{"name" => "ragStores/s/documents/d2", "state" => "PROCESSING"}
        ],
        "nextPageToken" => "token123"
      }

      result = ListDocumentsResponse.from_api_response(response)

      assert length(result.documents) == 2
      assert result.next_page_token == "token123"
      assert ListDocumentsResponse.has_more_pages?(result)
    end

    test "from_api_response/1 handles empty response" do
      response = %{}

      result = ListDocumentsResponse.from_api_response(response)

      assert result.documents == []
      assert result.next_page_token == nil
      refute ListDocumentsResponse.has_more_pages?(result)
    end

    test "has_more_pages?/1 returns false for nil or empty token" do
      refute ListDocumentsResponse.has_more_pages?(%ListDocumentsResponse{next_page_token: nil})
      refute ListDocumentsResponse.has_more_pages?(%ListDocumentsResponse{next_page_token: ""})
    end
  end

  describe "RagStore type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "ragStores/store123",
        "displayName" => "My Store",
        "description" => "A test store",
        "state" => "ACTIVE",
        "createTime" => "2025-12-05T10:00:00Z",
        "updateTime" => "2025-12-05T10:05:00Z",
        "documentCount" => 100,
        "totalSizeBytes" => "1048576",
        "vectorConfig" => %{"dimension" => 768}
      }

      store = RagStore.from_api_response(response)

      assert store.name == "ragStores/store123"
      assert store.display_name == "My Store"
      assert store.description == "A test store"
      assert store.state == :active
      assert store.document_count == 100
      assert store.total_size_bytes == 1_048_576
      assert store.vector_config["dimension"] == 768
    end

    test "from_api_response/1 handles all states" do
      assert RagStore.parse_state("STATE_UNSPECIFIED") == :state_unspecified
      assert RagStore.parse_state("CREATING") == :creating
      assert RagStore.parse_state("ACTIVE") == :active
      assert RagStore.parse_state("DELETING") == :deleting
      assert RagStore.parse_state("FAILED") == :failed
      assert RagStore.parse_state(nil) == nil
    end
  end

  describe "RagStore state helpers" do
    test "active?/1 returns true for active stores" do
      assert RagStore.active?(%RagStore{state: :active})
      refute RagStore.active?(%RagStore{state: :creating})
    end
  end

  describe "RagStore.get_id/1" do
    test "extracts store ID from name" do
      store = %RagStore{name: "ragStores/store123"}
      assert RagStore.get_id(store) == "store123"
    end

    test "returns nil for nil name" do
      store = %RagStore{name: nil}
      assert RagStore.get_id(store) == nil
    end
  end

  describe "ListRagStoresResponse" do
    test "from_api_response/1 parses stores list" do
      response = %{
        "ragStores" => [
          %{"name" => "ragStores/s1", "state" => "ACTIVE"},
          %{"name" => "ragStores/s2", "state" => "CREATING"}
        ],
        "nextPageToken" => "token123"
      }

      result = ListRagStoresResponse.from_api_response(response)

      assert length(result.rag_stores) == 2
      assert result.next_page_token == "token123"
      assert ListRagStoresResponse.has_more_pages?(result)
    end

    test "from_api_response/1 handles fileSearchStores key" do
      response = %{
        "fileSearchStores" => [
          %{"name" => "ragStores/s1", "state" => "ACTIVE"}
        ]
      }

      result = ListRagStoresResponse.from_api_response(response)
      assert length(result.rag_stores) == 1
    end

    test "from_api_response/1 handles empty response" do
      response = %{}

      result = ListRagStoresResponse.from_api_response(response)

      assert result.rag_stores == []
      assert result.next_page_token == nil
      refute ListRagStoresResponse.has_more_pages?(result)
    end
  end
end
