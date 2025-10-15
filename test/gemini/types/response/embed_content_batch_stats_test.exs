defmodule Gemini.Types.Response.EmbedContentBatchStatsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.EmbedContentBatchStats

  describe "from_api_response/1" do
    test "parses complete stats from API" do
      api_response = %{
        "requestCount" => "100",
        "successfulRequestCount" => "75",
        "failedRequestCount" => "5",
        "pendingRequestCount" => "20"
      }

      stats = EmbedContentBatchStats.from_api_response(api_response)

      assert stats.request_count == 100
      assert stats.successful_request_count == 75
      assert stats.failed_request_count == 5
      assert stats.pending_request_count == 20
    end

    test "handles string integer conversion" do
      # API returns strings, we convert to integers
      api_response = %{"requestCount" => "42"}
      stats = EmbedContentBatchStats.from_api_response(api_response)

      assert stats.request_count == 42
      assert is_integer(stats.request_count)
    end

    test "handles missing optional fields" do
      api_response = %{"requestCount" => "50"}
      stats = EmbedContentBatchStats.from_api_response(api_response)

      assert stats.request_count == 50
      assert stats.successful_request_count == nil
      assert stats.failed_request_count == nil
      assert stats.pending_request_count == nil
    end

    test "parses partial completion stats" do
      api_response = %{
        "requestCount" => "200",
        "successfulRequestCount" => "100",
        "pendingRequestCount" => "100"
      }

      stats = EmbedContentBatchStats.from_api_response(api_response)

      assert stats.request_count == 200
      assert stats.successful_request_count == 100
      assert stats.failed_request_count == nil
      assert stats.pending_request_count == 100
    end

    test "handles integer values from API" do
      # Some APIs might return integers directly
      api_response = %{
        "requestCount" => 75,
        "successfulRequestCount" => 50,
        "failedRequestCount" => 25
      }

      stats = EmbedContentBatchStats.from_api_response(api_response)

      assert stats.request_count == 75
      assert stats.successful_request_count == 50
      assert stats.failed_request_count == 25
    end
  end

  describe "progress_percentage/1" do
    test "calculates completion percentage" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 75,
        failed_request_count: 5,
        pending_request_count: 20
      }

      # (75 + 5) / 100 * 100 = 80%
      assert EmbedContentBatchStats.progress_percentage(stats) == 80.0
    end

    test "returns 0 for new batch with no completed requests" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 0,
        failed_request_count: 0,
        pending_request_count: 100
      }

      assert EmbedContentBatchStats.progress_percentage(stats) == 0.0
    end

    test "returns 100 for completed batch" do
      stats = %EmbedContentBatchStats{
        request_count: 50,
        successful_request_count: 50,
        failed_request_count: 0,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.progress_percentage(stats) == 100.0
    end

    test "handles batch with some failures" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 80,
        failed_request_count: 20,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.progress_percentage(stats) == 100.0
    end

    test "handles partial progress with nil counts" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 30,
        failed_request_count: nil,
        pending_request_count: nil
      }

      # 30 / 100 * 100 = 30%
      assert EmbedContentBatchStats.progress_percentage(stats) == 30.0
    end

    test "handles nil successful and failed counts as zero" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: nil,
        failed_request_count: nil,
        pending_request_count: 100
      }

      assert EmbedContentBatchStats.progress_percentage(stats) == 0.0
    end

    test "returns accurate decimal percentages" do
      stats = %EmbedContentBatchStats{
        request_count: 3,
        successful_request_count: 1,
        failed_request_count: 0,
        pending_request_count: 2
      }

      # 1 / 3 * 100 = 33.333...
      percentage = EmbedContentBatchStats.progress_percentage(stats)
      assert_in_delta percentage, 33.33, 0.01
    end
  end

  describe "is_complete?/1" do
    test "returns true when no pending requests" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 95,
        failed_request_count: 5,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.is_complete?(stats) == true
    end

    test "returns false when pending requests remain" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 50,
        failed_request_count: 0,
        pending_request_count: 50
      }

      assert EmbedContentBatchStats.is_complete?(stats) == false
    end

    test "returns false when pending count is nil" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 50,
        failed_request_count: 0,
        pending_request_count: nil
      }

      # If we don't know pending count, assume not complete
      assert EmbedContentBatchStats.is_complete?(stats) == false
    end

    test "returns true when pending count is explicitly zero" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 100,
        failed_request_count: 0,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.is_complete?(stats) == true
    end

    test "returns true for batch with all failures completed" do
      stats = %EmbedContentBatchStats{
        request_count: 10,
        successful_request_count: 0,
        failed_request_count: 10,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.is_complete?(stats) == true
    end
  end

  describe "struct enforcement" do
    test "allows creation with only request_count" do
      stats = %EmbedContentBatchStats{request_count: 100}

      assert stats.request_count == 100
      assert stats.successful_request_count == nil
      assert stats.failed_request_count == nil
      assert stats.pending_request_count == nil
    end
  end

  describe "success_rate/1" do
    test "calculates success rate when all completed" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 80,
        failed_request_count: 20,
        pending_request_count: 0
      }

      # 80 / 100 * 100 = 80%
      assert EmbedContentBatchStats.success_rate(stats) == 80.0
    end

    test "returns 0 when no successful requests" do
      stats = %EmbedContentBatchStats{
        request_count: 50,
        successful_request_count: 0,
        failed_request_count: 50,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.success_rate(stats) == 0.0
    end

    test "returns 100 when all requests successful" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 100,
        failed_request_count: 0,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.success_rate(stats) == 100.0
    end

    test "handles nil successful count as zero" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: nil,
        failed_request_count: 10,
        pending_request_count: 90
      }

      assert EmbedContentBatchStats.success_rate(stats) == 0.0
    end
  end

  describe "failure_rate/1" do
    test "calculates failure rate" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 80,
        failed_request_count: 20,
        pending_request_count: 0
      }

      # 20 / 100 * 100 = 20%
      assert EmbedContentBatchStats.failure_rate(stats) == 20.0
    end

    test "returns 0 when no failures" do
      stats = %EmbedContentBatchStats{
        request_count: 50,
        successful_request_count: 50,
        failed_request_count: 0,
        pending_request_count: 0
      }

      assert EmbedContentBatchStats.failure_rate(stats) == 0.0
    end

    test "handles nil failed count as zero" do
      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 50,
        failed_request_count: nil,
        pending_request_count: 50
      }

      assert EmbedContentBatchStats.failure_rate(stats) == 0.0
    end
  end
end
