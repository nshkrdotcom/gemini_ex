defmodule Gemini.APIs.OperationsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{Operation, ListOperationsResponse}

  describe "Operation type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "operations/abc123",
        "done" => false,
        "metadata" => %{
          "@type" => "type.googleapis.com/some.type",
          "progress" => 50
        }
      }

      op = Operation.from_api_response(response)

      assert op.name == "operations/abc123"
      assert op.done == false
      assert op.metadata["progress"] == 50
      assert op.error == nil
      assert op.response == nil
    end

    test "from_api_response/1 parses completed successful operation" do
      response = %{
        "name" => "operations/abc123",
        "done" => true,
        "response" => %{
          "result" => "success",
          "data" => %{"value" => 42}
        }
      }

      op = Operation.from_api_response(response)

      assert op.done == true
      assert op.response["result"] == "success"
      assert op.error == nil
    end

    test "from_api_response/1 parses failed operation" do
      response = %{
        "name" => "operations/abc123",
        "done" => true,
        "error" => %{
          "code" => 400,
          "message" => "Invalid input",
          "details" => [%{"reason" => "BAD_REQUEST"}]
        }
      }

      op = Operation.from_api_response(response)

      assert op.done == true
      assert op.error.code == 400
      assert op.error.message == "Invalid input"
      assert length(op.error.details) == 1
      assert op.response == nil
    end

    test "from_api_response/1 handles missing done field" do
      response = %{"name" => "operations/abc123"}

      op = Operation.from_api_response(response)

      assert op.done == false
    end
  end

  describe "Operation state helpers" do
    test "complete?/1 returns true for done operations" do
      op = %Operation{done: true}
      assert Operation.complete?(op)
    end

    test "complete?/1 returns false for running operations" do
      op = %Operation{done: false}
      refute Operation.complete?(op)
    end

    test "succeeded?/1 returns true for successful completion" do
      op = %Operation{done: true, error: nil, response: %{"result" => "ok"}}
      assert Operation.succeeded?(op)
    end

    test "succeeded?/1 returns false for failed operation" do
      op = %Operation{done: true, error: %{message: "failed"}}
      refute Operation.succeeded?(op)
    end

    test "succeeded?/1 returns false for running operation" do
      op = %Operation{done: false}
      refute Operation.succeeded?(op)
    end

    test "failed?/1 returns true for failed operation" do
      op = %Operation{done: true, error: %{message: "failed"}}
      assert Operation.failed?(op)
    end

    test "failed?/1 returns false for successful operation" do
      op = %Operation{done: true, error: nil}
      refute Operation.failed?(op)
    end

    test "failed?/1 returns false for running operation" do
      op = %Operation{done: false}
      refute Operation.failed?(op)
    end

    test "running?/1 returns true for running operation" do
      op = %Operation{done: false}
      assert Operation.running?(op)
    end

    test "running?/1 returns false for completed operation" do
      op = %Operation{done: true}
      refute Operation.running?(op)
    end
  end

  describe "Operation.get_progress/1" do
    test "returns progress from metadata" do
      op = %Operation{metadata: %{"progress" => 75}}
      assert Operation.get_progress(op) == 75
    end

    test "returns progressPercent from metadata" do
      op = %Operation{metadata: %{"progressPercent" => 50}}
      assert Operation.get_progress(op) == 50
    end

    test "returns completionPercentage from metadata" do
      op = %Operation{metadata: %{"completionPercentage" => 25.5}}
      assert Operation.get_progress(op) == 25.5
    end

    test "returns nil when no progress info" do
      op = %Operation{metadata: %{"other" => "field"}}
      assert Operation.get_progress(op) == nil
    end

    test "returns nil when metadata is nil" do
      op = %Operation{metadata: nil}
      assert Operation.get_progress(op) == nil
    end
  end

  describe "Operation.get_id/1" do
    test "extracts ID from name" do
      op = %Operation{name: "operations/abc123"}
      assert Operation.get_id(op) == "abc123"
    end

    test "returns nil for nil name" do
      op = %Operation{name: nil}
      assert Operation.get_id(op) == nil
    end

    test "returns full name for non-standard format" do
      op = %Operation{name: "custom/path/abc"}
      assert Operation.get_id(op) == "custom/path/abc"
    end
  end

  describe "ListOperationsResponse" do
    test "from_api_response/1 parses operations list" do
      response = %{
        "operations" => [
          %{"name" => "operations/1", "done" => false},
          %{"name" => "operations/2", "done" => true}
        ],
        "nextPageToken" => "token123"
      }

      result = ListOperationsResponse.from_api_response(response)

      assert length(result.operations) == 2
      assert result.next_page_token == "token123"
      assert ListOperationsResponse.has_more_pages?(result)
    end

    test "from_api_response/1 handles empty response" do
      response = %{}

      result = ListOperationsResponse.from_api_response(response)

      assert result.operations == []
      assert result.next_page_token == nil
      refute ListOperationsResponse.has_more_pages?(result)
    end

    test "has_more_pages?/1 returns false for nil or empty token" do
      refute ListOperationsResponse.has_more_pages?(%ListOperationsResponse{next_page_token: nil})
      refute ListOperationsResponse.has_more_pages?(%ListOperationsResponse{next_page_token: ""})
    end
  end
end
