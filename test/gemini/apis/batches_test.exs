defmodule Gemini.APIs.BatchesTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{BatchJob, ListBatchJobsResponse}

  describe "BatchJob type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "batches/abc123",
        "displayName" => "Test Batch",
        "state" => "JOB_STATE_RUNNING",
        "model" => "gemini-2.0-flash",
        "src" => %{
          "fileName" => "files/input123"
        },
        "dest" => %{
          "fileName" => "files/output123"
        },
        "createTime" => "2025-12-05T10:00:00Z",
        "updateTime" => "2025-12-05T10:05:00Z"
      }

      batch = BatchJob.from_api_response(response)

      assert batch.name == "batches/abc123"
      assert batch.display_name == "Test Batch"
      assert batch.state == :running
      assert batch.model == "gemini-2.0-flash"
      assert batch.src[:file_name] == "files/input123"
      assert batch.dest[:file_name] == "files/output123"
    end

    test "from_api_response/1 parses queued state" do
      response = %{"name" => "batches/abc", "state" => "JOB_STATE_QUEUED"}
      batch = BatchJob.from_api_response(response)
      assert batch.state == :queued
    end

    test "from_api_response/1 parses succeeded state" do
      response = %{"name" => "batches/abc", "state" => "JOB_STATE_SUCCEEDED"}
      batch = BatchJob.from_api_response(response)
      assert batch.state == :succeeded
    end

    test "from_api_response/1 parses failed state with error" do
      response = %{
        "name" => "batches/abc",
        "state" => "JOB_STATE_FAILED",
        "error" => %{
          "code" => 500,
          "message" => "Internal error",
          "details" => ["Detail 1"]
        }
      }

      batch = BatchJob.from_api_response(response)
      assert batch.state == :failed
      assert batch.error.code == 500
      assert batch.error.message == "Internal error"
    end

    test "from_api_response/1 parses completion stats" do
      response = %{
        "name" => "batches/abc",
        "state" => "JOB_STATE_SUCCEEDED",
        "completionStats" => %{
          "totalCount" => 100,
          "successCount" => 95,
          "failureCount" => 5
        }
      }

      batch = BatchJob.from_api_response(response)
      assert batch.completion_stats[:total_count] == 100
      assert batch.completion_stats[:success_count] == 95
      assert batch.completion_stats[:failure_count] == 5
    end

    test "from_api_response/1 handles GCS source" do
      response = %{
        "name" => "batches/abc",
        "src" => %{
          "gcsUri" => ["gs://bucket/input.jsonl"],
          "format" => "jsonl"
        }
      }

      batch = BatchJob.from_api_response(response)
      assert batch.src[:gcs_uri] == ["gs://bucket/input.jsonl"]
      assert batch.src[:format] == "jsonl"
    end

    test "from_api_response/1 handles BigQuery destination" do
      response = %{
        "name" => "batches/abc",
        "dest" => %{
          "bigqueryUri" => "bq://project.dataset.table"
        }
      }

      batch = BatchJob.from_api_response(response)
      assert batch.dest[:bigquery_uri] == "bq://project.dataset.table"
    end

    test "from_api_response/1 handles inlined requests" do
      response = %{
        "name" => "batches/abc",
        "src" => %{
          "inlinedRequests" => [
            %{"contents" => [%{"parts" => [%{"text" => "Hello"}]}]},
            %{"contents" => [%{"parts" => [%{"text" => "World"}]}]}
          ]
        }
      }

      batch = BatchJob.from_api_response(response)
      assert length(batch.src[:inlined_requests]) == 2
    end

    test "from_api_response/1 handles Gemini API simple states" do
      response = %{"name" => "batches/abc", "state" => "ACTIVE"}
      batch = BatchJob.from_api_response(response)
      assert batch.state == :running

      response = %{"name" => "batches/abc", "state" => "COMPLETED"}
      batch = BatchJob.from_api_response(response)
      assert batch.state == :succeeded
    end
  end

  describe "BatchJob state helpers" do
    test "complete?/1 returns true for terminal states" do
      assert BatchJob.complete?(%BatchJob{state: :succeeded})
      assert BatchJob.complete?(%BatchJob{state: :failed})
      assert BatchJob.complete?(%BatchJob{state: :cancelled})
      assert BatchJob.complete?(%BatchJob{state: :expired})
      assert BatchJob.complete?(%BatchJob{state: :partially_succeeded})
    end

    test "complete?/1 returns false for non-terminal states" do
      refute BatchJob.complete?(%BatchJob{state: :queued})
      refute BatchJob.complete?(%BatchJob{state: :pending})
      refute BatchJob.complete?(%BatchJob{state: :running})
    end

    test "succeeded?/1 returns true only for succeeded state" do
      assert BatchJob.succeeded?(%BatchJob{state: :succeeded})
      refute BatchJob.succeeded?(%BatchJob{state: :failed})
      refute BatchJob.succeeded?(%BatchJob{state: :running})
    end

    test "failed?/1 returns true only for failed state" do
      assert BatchJob.failed?(%BatchJob{state: :failed})
      refute BatchJob.failed?(%BatchJob{state: :succeeded})
      refute BatchJob.failed?(%BatchJob{state: :running})
    end

    test "running?/1 returns true for active states" do
      assert BatchJob.running?(%BatchJob{state: :queued})
      assert BatchJob.running?(%BatchJob{state: :pending})
      assert BatchJob.running?(%BatchJob{state: :running})
      refute BatchJob.running?(%BatchJob{state: :succeeded})
    end

    test "cancelled?/1 returns true only for cancelled state" do
      assert BatchJob.cancelled?(%BatchJob{state: :cancelled})
      refute BatchJob.cancelled?(%BatchJob{state: :succeeded})
    end
  end

  describe "BatchJob.get_progress/1" do
    test "calculates progress from completion stats" do
      batch = %BatchJob{
        completion_stats: %{
          total_count: 100,
          success_count: 50,
          failure_count: 10
        }
      }

      assert BatchJob.get_progress(batch) == 60.0
    end

    test "returns nil when no stats" do
      batch = %BatchJob{completion_stats: nil}
      assert BatchJob.get_progress(batch) == nil
    end

    test "returns nil when total is zero" do
      batch = %BatchJob{
        completion_stats: %{total_count: 0, success_count: 0, failure_count: 0}
      }

      assert BatchJob.get_progress(batch) == nil
    end
  end

  describe "BatchJob.get_id/1" do
    test "extracts ID from Gemini API format" do
      batch = %BatchJob{name: "batches/abc123"}
      assert BatchJob.get_id(batch) == "abc123"
    end

    test "extracts ID from Vertex AI format" do
      batch = %BatchJob{name: "batchPredictionJobs/12345"}
      assert BatchJob.get_id(batch) == "12345"
    end

    test "returns nil for nil name" do
      batch = %BatchJob{name: nil}
      assert BatchJob.get_id(batch) == nil
    end
  end

  describe "ListBatchJobsResponse" do
    test "from_api_response/1 parses batch jobs list" do
      response = %{
        "batchJobs" => [
          %{"name" => "batches/1", "state" => "JOB_STATE_RUNNING"},
          %{"name" => "batches/2", "state" => "JOB_STATE_SUCCEEDED"}
        ],
        "nextPageToken" => "token123"
      }

      result = ListBatchJobsResponse.from_api_response(response)

      assert length(result.batch_jobs) == 2
      assert result.next_page_token == "token123"
      assert ListBatchJobsResponse.has_more_pages?(result)
    end

    test "from_api_response/1 handles Vertex AI format" do
      response = %{
        "batchPredictionJobs" => [
          %{"name" => "batchPredictionJobs/1", "state" => "JOB_STATE_RUNNING"}
        ]
      }

      result = ListBatchJobsResponse.from_api_response(response)
      assert length(result.batch_jobs) == 1
    end

    test "from_api_response/1 handles empty response" do
      response = %{}

      result = ListBatchJobsResponse.from_api_response(response)

      assert result.batch_jobs == []
      assert result.next_page_token == nil
      refute ListBatchJobsResponse.has_more_pages?(result)
    end
  end
end
