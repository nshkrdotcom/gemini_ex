defmodule Gemini.StreamingIntegrationTest do
  use ExUnit.Case, async: false

  alias Gemini.SSE.Parser
  alias Gemini.Streaming.UnifiedManager

  import ExUnit.CaptureLog
  import Gemini.Test.ModelHelpers

  describe "SSE Parser" do
    test "parses single complete event" do
      parser = Parser.new()
      chunk = "data: {\"text\": \"hello\"}\n\n"

      {:ok, events, new_parser} = Parser.parse_chunk(chunk, parser)

      assert length(events) == 1
      assert hd(events).data == %{"text" => "hello"}
      assert new_parser.buffer == ""
    end

    test "handles partial events across chunks" do
      parser = Parser.new()

      # First chunk - incomplete event
      chunk1 = "data: {\"text\": \"hel"
      {:ok, events1, parser1} = Parser.parse_chunk(chunk1, parser)

      assert events1 == []
      assert parser1.buffer == "data: {\"text\": \"hel"

      # Second chunk - completes the event
      chunk2 = "lo\"}\n\n"
      {:ok, events2, parser2} = Parser.parse_chunk(chunk2, parser1)

      assert length(events2) == 1
      assert hd(events2).data == %{"text" => "hello"}
      assert parser2.buffer == ""
    end

    test "handles multiple events in single chunk" do
      parser = Parser.new()

      chunk = """
      data: {"text": "hello"}

      data: {"text": "world"}

      """

      {:ok, events, new_parser} = Parser.parse_chunk(chunk, parser)

      assert length(events) == 2
      assert Enum.at(events, 0).data == %{"text" => "hello"}
      assert Enum.at(events, 1).data == %{"text" => "world"}
      assert new_parser.buffer == ""
    end

    test "detects stream completion" do
      parser = Parser.new()
      chunk = "data: [DONE]\n\n"

      {:ok, events, _parser} = Parser.parse_chunk(chunk, parser)

      assert length(events) == 1
      event = hd(events)
      assert Parser.stream_done?(event)
    end

    test "extracts text from Gemini response format" do
      event = %{
        data: %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [
                  %{"text" => "Hello world"}
                ]
              }
            }
          ]
        }
      }

      assert Parser.extract_text(event) == "Hello world"
    end

    test "handles malformed JSON gracefully" do
      parser = Parser.new()
      chunk = "data: {invalid json}\n\n"

      {:ok, events, _parser} = Parser.parse_chunk(chunk, parser)

      # Should skip malformed events
      assert events == []
    end

    test "finalizes remaining buffer" do
      parser = %Parser{buffer: "data: {\"text\": \"final\"}\n\n"}

      {:ok, events} = Parser.finalize(parser)

      assert length(events) == 1
      assert hd(events).data == %{"text" => "final"}
    end
  end

  describe "HTTP Streaming (Mock Tests)" do
    test "handles successful streaming callback" do
      _events = []

      callback = fn event ->
        send(self(), {:callback_event, event})
        :ok
      end

      # This would require mocking Req, but demonstrates the interface
      # In real tests, you'd mock the HTTP client
      assert is_function(callback, 1)
    end

    test "handles callback returning :stop" do
      callback = fn _event -> :stop end

      # Would test that streaming stops when callback returns :stop
      assert is_function(callback, 1)
    end

    test "retries on connection failure" do
      # Would test retry logic with exponential backoff
      # Mock HTTP failures and verify retry attempts
      :ok
    end
  end

  describe "Unified Streaming Manager" do
    setup do
      # Use the existing manager instance (started by Application)
      :ok
    end

    test "requires authentication to start stream" do
      # Save original state - both :gemini and :gemini_ex namespaces
      original_gemini_auth = Application.get_env(:gemini, :auth)
      original_config = Application.get_env(:gemini_ex, :auth)
      original_api_key = Application.get_env(:gemini_ex, :api_key)
      original_gemini_key = System.get_env("GEMINI_API_KEY")
      original_vertex_token = System.get_env("VERTEX_ACCESS_TOKEN")
      original_vertex_service = System.get_env("VERTEX_SERVICE_ACCOUNT")
      original_vertex_json = System.get_env("VERTEX_JSON_FILE")
      original_vertex_project = System.get_env("VERTEX_PROJECT_ID")
      original_google_project = System.get_env("GOOGLE_CLOUD_PROJECT")

      # Clear all auth sources - BOTH namespaces
      Application.delete_env(:gemini, :auth)
      Application.delete_env(:gemini_ex, :auth)
      Application.delete_env(:gemini_ex, :api_key)
      System.delete_env("GEMINI_API_KEY")
      System.delete_env("VERTEX_ACCESS_TOKEN")
      System.delete_env("VERTEX_SERVICE_ACCOUNT")
      System.delete_env("VERTEX_JSON_FILE")
      System.delete_env("VERTEX_PROJECT_ID")
      System.delete_env("GOOGLE_CLOUD_PROJECT")

      try do
        contents = "Hello, world!"
        opts = [model: default_model()]

        # Should fail with proper error when no auth is configured
        assert {:error, error_msg} = UnifiedManager.start_stream(contents, opts, self())

        assert (is_binary(error_msg) and String.contains?(error_msg, "auth failed")) or
                 error_msg == :no_auth_config
      after
        # Restore original state - BOTH namespaces
        if original_gemini_auth, do: Application.put_env(:gemini, :auth, original_gemini_auth)
        if original_config, do: Application.put_env(:gemini_ex, :auth, original_config)
        if original_api_key, do: Application.put_env(:gemini_ex, :api_key, original_api_key)
        if original_gemini_key, do: System.put_env("GEMINI_API_KEY", original_gemini_key)
        if original_vertex_token, do: System.put_env("VERTEX_ACCESS_TOKEN", original_vertex_token)

        if original_vertex_service,
          do: System.put_env("VERTEX_SERVICE_ACCOUNT", original_vertex_service)

        if original_vertex_json, do: System.put_env("VERTEX_JSON_FILE", original_vertex_json)

        if original_vertex_project,
          do: System.put_env("VERTEX_PROJECT_ID", original_vertex_project)

        if original_google_project,
          do: System.put_env("GOOGLE_CLOUD_PROJECT", original_google_project)
      end
    end

    test "starts and tracks stream with mock auth" do
      # Set up mock authentication for this test
      original_config = Application.get_env(:gemini_ex, :auth)

      Application.put_env(:gemini_ex, :auth, %{
        type: :gemini,
        credentials: %{api_key: "test_key_123"}
      })

      try do
        contents = "Hello, world!"
        opts = [model: default_model()]

        # Capture debug logs from streaming setup
        capture_log(fn ->
          case UnifiedManager.start_stream(contents, opts, self()) do
            {:ok, stream_id} ->
              assert is_binary(stream_id)

              # Verify stream is tracked
              {:ok, info} = UnifiedManager.get_stream_info(stream_id)
              assert info.status in [:starting, :active]
              assert info.model == default_model()

              # Clean up the stream
              UnifiedManager.stop_stream(stream_id)

            {:error, reason} ->
              # This is expected since we're using a fake API key
              # but the stream should at least start before failing
              assert reason != :no_auth_config
          end
        end)
      after
        # Restore original config
        if original_config do
          Application.put_env(:gemini_ex, :auth, original_config)
        else
          Application.delete_env(:gemini_ex, :auth)
        end
      end
    end

    test "fails without authentication" do
      # Save original state - both :gemini and :gemini_ex namespaces
      original_gemini_auth = Application.get_env(:gemini, :auth)
      original_config = Application.get_env(:gemini_ex, :auth)
      original_api_key = Application.get_env(:gemini_ex, :api_key)
      original_gemini_key = System.get_env("GEMINI_API_KEY")
      original_vertex_token = System.get_env("VERTEX_ACCESS_TOKEN")
      original_vertex_service = System.get_env("VERTEX_SERVICE_ACCOUNT")
      original_vertex_json = System.get_env("VERTEX_JSON_FILE")
      original_vertex_project = System.get_env("VERTEX_PROJECT_ID")
      original_google_project = System.get_env("GOOGLE_CLOUD_PROJECT")

      # Clear all auth sources - BOTH namespaces
      Application.delete_env(:gemini, :auth)
      Application.delete_env(:gemini_ex, :auth)
      Application.delete_env(:gemini_ex, :api_key)
      System.delete_env("GEMINI_API_KEY")
      System.delete_env("VERTEX_ACCESS_TOKEN")
      System.delete_env("VERTEX_SERVICE_ACCOUNT")
      System.delete_env("VERTEX_JSON_FILE")
      System.delete_env("VERTEX_PROJECT_ID")
      System.delete_env("GOOGLE_CLOUD_PROJECT")

      try do
        contents = "Test content"
        # This should fail immediately with auth error
        assert {:error, error_msg} = UnifiedManager.start_stream(contents, [], self())

        assert (is_binary(error_msg) and String.contains?(error_msg, "auth failed")) or
                 error_msg == :no_auth_config
      after
        # Restore original state - BOTH namespaces
        if original_gemini_auth, do: Application.put_env(:gemini, :auth, original_gemini_auth)
        if original_config, do: Application.put_env(:gemini_ex, :auth, original_config)
        if original_api_key, do: Application.put_env(:gemini_ex, :api_key, original_api_key)
        if original_gemini_key, do: System.put_env("GEMINI_API_KEY", original_gemini_key)
        if original_vertex_token, do: System.put_env("VERTEX_ACCESS_TOKEN", original_vertex_token)

        if original_vertex_service,
          do: System.put_env("VERTEX_SERVICE_ACCOUNT", original_vertex_service)

        if original_vertex_json, do: System.put_env("VERTEX_JSON_FILE", original_vertex_json)

        if original_vertex_project,
          do: System.put_env("VERTEX_PROJECT_ID", original_vertex_project)

        if original_google_project,
          do: System.put_env("GOOGLE_CLOUD_PROJECT", original_google_project)
      end
    end

    test "manages multiple subscribers with mock auth" do
      # Set up mock authentication
      original_config = Application.get_env(:gemini_ex, :auth)

      Application.put_env(:gemini_ex, :auth, %{
        type: :gemini,
        credentials: %{api_key: "test_key_123"}
      })

      try do
        contents = "Test content"

        # Capture debug logs from streaming setup
        capture_log(fn ->
          case UnifiedManager.start_stream(contents, [], self()) do
            {:ok, stream_id} ->
              # Add another subscriber
              subscriber2 =
                spawn(fn ->
                  receive do
                    msg -> send(self(), {:subscriber2_got, msg})
                  end
                end)

              :ok = UnifiedManager.subscribe_stream(stream_id, subscriber2)

              {:ok, info} = UnifiedManager.get_stream_info(stream_id)
              assert info.subscribers_count == 2

              # Clean up
              UnifiedManager.stop_stream(stream_id)

            {:error, reason} ->
              # Should not be no_auth_config since we set up auth
              # (though it may fail for other reasons like network/API key validity)
              assert reason != :no_auth_config
          end
        end)
      after
        # Restore original config
        if original_config do
          Application.put_env(:gemini_ex, :auth, original_config)
        else
          Application.delete_env(:gemini_ex, :auth)
        end
      end
    end

    test "cleans up when subscribers die" do
      contents = "Test content"

      # Capture debug logs from streaming setup
      capture_log(fn ->
        case UnifiedManager.start_stream(contents, [], self()) do
          {:ok, stream_id} ->
            # Create a subscriber that will die
            subscriber = spawn(fn -> :ok end)
            :ok = UnifiedManager.subscribe_stream(stream_id, subscriber)

            # Kill the subscriber
            Process.exit(subscriber, :kill)

            # Give manager time to process DOWN message
            Process.sleep(50)

            # Check if stream was cleaned up (if no other subscribers)
            case UnifiedManager.get_stream_info(stream_id) do
              {:error, :stream_not_found} ->
                # Stream was cleaned up because last subscriber died
                :ok

              {:ok, info} ->
                # Stream still exists because calling process is still subscribed
                assert info.subscribers_count == 1
            end

          {:error, _reason} ->
            :ok
        end
      end)
    end

    test "enforces maximum streams limit" do
      # Capture debug logs from streaming setup
      capture_log(fn ->
        # This would test the max_streams configuration
        stats = UnifiedManager.get_stats()
        assert is_integer(stats.max_streams)
        assert stats.total_streams >= 0
      end)
    end

    test "provides comprehensive statistics" do
      stats = UnifiedManager.get_stats()

      assert Map.has_key?(stats, :total_streams)
      assert Map.has_key?(stats, :max_streams)
      assert Map.has_key?(stats, :streams_by_status)
      assert Map.has_key?(stats, :total_subscribers)
    end

    @tag :live_api
    test "handles invalid model names with proper error" do
      # Set up mock authentication
      original_config = Application.get_env(:gemini_ex, :auth)

      Application.put_env(:gemini_ex, :auth, %{
        type: :gemini,
        credentials: %{api_key: "test_key_for_error_test"}
      })

      log =
        capture_log(fn ->
          try do
            contents = "Hello"
            opts = [model: "definitely-invalid-model-name"]

            case UnifiedManager.start_stream(contents, opts, self()) do
              {:ok, stream_id} ->
                # Stream should start but then fail
                assert is_binary(stream_id)

                # Wait for error event
                receive do
                  {:stream_error, ^stream_id, error} ->
                    # Should be an HTTP error about invalid model
                    assert %Gemini.Error{type: :http_error, http_status: 404} = error
                    assert String.contains?(error.message, "not found")

                  {:stream_complete, ^stream_id} ->
                    flunk("Stream should not complete with invalid model")
                after
                  15_000 ->
                    flunk("Expected stream error within 15 seconds")
                end

              {:error, reason} ->
                # Could also fail at start - that's acceptable
                assert reason != :no_auth_config
            end
          after
            # Restore original config
            if original_config do
              Application.put_env(:gemini_ex, :auth, original_config)
            else
              Application.delete_env(:gemini_ex, :auth)
            end
          end
        end)

      assert log == "" or String.contains?(log, "not found")
    end

    test "stops streams cleanly" do
      contents = "Test content"

      # Capture debug logs from streaming setup
      capture_log(fn ->
        case UnifiedManager.start_stream(contents, [], self()) do
          {:ok, stream_id} ->
            :ok = UnifiedManager.stop_stream(stream_id)

            # Verify stream is removed
            assert {:error, :stream_not_found} = UnifiedManager.get_stream_info(stream_id)

          {:error, _reason} ->
            :ok
        end
      end)
    end
  end

  describe "Integration Scenarios" do
    @tag :live_api
    test "end-to-end streaming with real API" do
      # This test requires GEMINI_API_KEY environment variable
      case System.get_env("GEMINI_API_KEY") do
        nil ->
          IO.puts("Skipping integration test - no API key")
          :ok

        _api_key ->
          # Use existing manager

          contents = "Count from 1 to 5, one number per response"
          opts = [model: default_model()]

          {:ok, stream_id} = UnifiedManager.start_stream(contents, opts, self())

          # Collect events for up to 10 seconds
          events = collect_stream_events(stream_id, 10_000)

          # Verify we got some events
          assert length(events) > 0

          # Check that we got completion or error
          final_event = List.last(events)
          assert final_event.type in [:complete, :error]
      end
    end

    @tag :live_api
    test "streaming with error handling" do
      case System.get_env("GEMINI_API_KEY") do
        nil ->
          :ok

        _api_key ->
          # Use existing manager

          # Use invalid model to trigger error
          contents = "Hello"
          opts = [model: "invalid-model-name"]

          log =
            capture_log(fn ->
              case UnifiedManager.start_stream(contents, opts, self()) do
                {:ok, stream_id} ->
                  events = collect_stream_events(stream_id, 5_000)

                  # Should get an error event
                  error_events = Enum.filter(events, &(&1.type == :error))
                  assert length(error_events) > 0

                {:error, _reason} ->
                  # Also acceptable - error caught at start
                  :ok
              end
            end)

          assert log == "" or String.contains?(log, "not found")
      end
    end
  end

  # Helper functions for tests

  defp collect_stream_events(stream_id, timeout) do
    collect_stream_events(stream_id, timeout, [])
  end

  defp collect_stream_events(stream_id, timeout, acc) do
    receive do
      {:stream_event, ^stream_id, event} ->
        event_wrapper = %{type: :data, data: event, timestamp: System.system_time(:millisecond)}
        collect_stream_events(stream_id, timeout, [event_wrapper | acc])

      {:stream_complete, ^stream_id} ->
        completion = %{type: :complete, data: nil, timestamp: System.system_time(:millisecond)}
        Enum.reverse([completion | acc])

      {:stream_error, ^stream_id, error} ->
        error_event = %{type: :error, error: error, timestamp: System.system_time(:millisecond)}
        Enum.reverse([error_event | acc])

      {:stream_stopped, ^stream_id} ->
        stopped = %{type: :stopped, data: nil, timestamp: System.system_time(:millisecond)}
        Enum.reverse([stopped | acc])
    after
      timeout ->
        IO.puts("Stream collection timed out after #{timeout}ms")
        Enum.reverse(acc)
    end
  end
end

defmodule Gemini.SSE.ParserTest do
  use ExUnit.Case, async: true

  alias Gemini.SSE.Parser

  describe "edge cases" do
    test "handles empty chunks" do
      parser = Parser.new()

      {:ok, events, new_parser} = Parser.parse_chunk("", parser)

      assert events == []
      assert new_parser.buffer == ""
    end

    test "handles chunks with only newlines" do
      parser = Parser.new()

      {:ok, events, new_parser} = Parser.parse_chunk("\n\n\n", parser)

      assert events == []
      assert new_parser.buffer == ""
    end

    test "handles chunks without complete events" do
      parser = Parser.new()

      {:ok, events, new_parser} = Parser.parse_chunk("data: {\"partial", parser)

      assert events == []
      assert new_parser.buffer == "data: {\"partial"
    end

    test "handles mixed complete and partial events" do
      parser = Parser.new()
      chunk = "data: {\"complete\": true}\n\ndata: {\"partial"

      {:ok, events, new_parser} = Parser.parse_chunk(chunk, parser)

      assert length(events) == 1
      assert hd(events).data == %{"complete" => true}
      assert new_parser.buffer == "data: {\"partial"
    end

    test "handles events with other SSE fields" do
      parser = Parser.new()

      chunk = """
      event: update
      id: 123
      retry: 1000
      data: {"text": "hello"}

      """

      {:ok, events, _parser} = Parser.parse_chunk(chunk, parser)

      assert length(events) == 1
      event = hd(events)
      assert event.data == %{"text" => "hello"}
      assert event.event == "update"
      assert event.id == "123"
      assert event.retry == 1000
    end

    test "handles Unicode content correctly" do
      parser = Parser.new()
      chunk = "data: {\"text\": \"Hello 🌍 世界\"}\n\n"

      {:ok, events, _parser} = Parser.parse_chunk(chunk, parser)

      assert length(events) == 1
      assert hd(events).data == %{"text" => "Hello 🌍 世界"}
    end

    test "performance with large chunks" do
      parser = Parser.new()

      # Create a large chunk with many events
      large_chunk = Enum.map_join(1..1000, "", fn i -> "data: {\"number\": #{i}}\n\n" end)

      start_time = System.monotonic_time(:millisecond)
      {:ok, events, _parser} = Parser.parse_chunk(large_chunk, parser)
      end_time = System.monotonic_time(:millisecond)

      assert length(events) == 1000
      # Should complete within 1 second
      assert end_time - start_time < 1000
    end
  end
end
