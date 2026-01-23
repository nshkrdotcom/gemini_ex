defmodule Gemini.Types.Interactions.FileSearchCallContentTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Interactions.{Content, FileSearchCallContent}

  describe "from_api/1" do
    test "parses file_search_call content" do
      data = %{
        "type" => "file_search_call",
        "id" => "call_123"
      }

      content = FileSearchCallContent.from_api(data)

      assert content.type == "file_search_call"
      assert content.id == "call_123"
    end

    test "handles missing id" do
      data = %{
        "type" => "file_search_call"
      }

      content = FileSearchCallContent.from_api(data)

      assert content.type == "file_search_call"
      assert content.id == nil
    end

    test "defaults type when missing" do
      data = %{"id" => "call_456"}

      content = FileSearchCallContent.from_api(data)

      assert content.type == "file_search_call"
      assert content.id == "call_456"
    end

    test "returns nil for nil input" do
      assert FileSearchCallContent.from_api(nil) == nil
    end

    test "passes through existing struct" do
      original = %FileSearchCallContent{type: "file_search_call", id: "id1"}
      result = FileSearchCallContent.from_api(original)

      assert result == original
    end
  end

  describe "to_api/1" do
    test "converts to API format" do
      content = %FileSearchCallContent{
        type: "file_search_call",
        id: "call_789"
      }

      api = FileSearchCallContent.to_api(content)

      assert api["type"] == "file_search_call"
      assert api["id"] == "call_789"
    end

    test "excludes nil id" do
      content = %FileSearchCallContent{type: "file_search_call", id: nil}

      api = FileSearchCallContent.to_api(content)

      assert api["type"] == "file_search_call"
      refute Map.has_key?(api, "id")
    end

    test "returns nil for nil input" do
      assert FileSearchCallContent.to_api(nil) == nil
    end

    test "passes through plain maps" do
      map = %{"type" => "file_search_call", "id" => "abc"}
      result = FileSearchCallContent.to_api(map)

      assert result == map
    end
  end

  describe "Content union integration" do
    test "Content.from_api handles file_search_call type" do
      data = %{
        "type" => "file_search_call",
        "id" => "integrated_call"
      }

      content = Content.from_api(data)

      assert %FileSearchCallContent{} = content
      assert content.id == "integrated_call"
    end

    test "Content.to_api handles FileSearchCallContent struct" do
      content = %FileSearchCallContent{
        type: "file_search_call",
        id: "to_api_test"
      }

      api = Content.to_api(content)

      assert api["type"] == "file_search_call"
      assert api["id"] == "to_api_test"
    end
  end
end
