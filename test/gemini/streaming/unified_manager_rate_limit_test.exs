defmodule Gemini.Streaming.UnifiedManagerRateLimitTest do
  use ExUnit.Case, async: false

  import Gemini.Test.ModelHelpers

  alias Gemini.RateLimiter
  alias Gemini.Streaming.UnifiedManager

  setup do
    RateLimiter.reset_all()

    :meck.new(Gemini.Auth.MultiAuthCoordinator, [:non_strict])
    :meck.new(Gemini.Client.HTTPStreaming, [:non_strict])

    :meck.expect(Gemini.Auth.MultiAuthCoordinator, :coordinate_auth, fn _strategy, _config ->
      {:ok, :gemini, []}
    end)

    :meck.expect(Gemini.Auth.MultiAuthCoordinator, :get_credentials, fn _strategy, _config ->
      {:ok, %{project_id: "test", location: "us"}}
    end)

    on_exit(fn ->
      :meck.unload()
    end)

    :ok
  end

  test "streaming respects concurrency gate in non_blocking mode" do
    test_pid = self()

    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     stream_id,
                                                                     manager_pid ->
      pid =
        spawn(fn ->
          send(test_pid, {:stream_started, stream_id, manager_pid, self()})

          receive do
            :finish ->
              send(manager_pid, {:stream_complete, stream_id})
          end
        end)

      {:ok, pid}
    end)

    model = default_model()

    {:ok, stream_id} =
      UnifiedManager.start_stream("hello", [model: model, max_concurrency_per_model: 1], self())

    assert_receive {:stream_started, ^stream_id, _manager_pid, stream_pid}

    result =
      UnifiedManager.start_stream(
        "world",
        [model: model, max_concurrency_per_model: 1, non_blocking: true],
        self()
      )

    assert {:error, {:rate_limited, nil, %{reason: :no_permit_available}}} = result

    send(stream_pid, :finish)
    assert_receive {:stream_complete, ^stream_id}

    {:ok, _stream_id2} =
      UnifiedManager.start_stream(
        "again",
        [model: model, max_concurrency_per_model: 1, non_blocking: true],
        self()
      )

    assert :meck.num_calls(Gemini.Client.HTTPStreaming, :stream_to_process, :_) >= 2
  end

  test "streaming enforces token budget preflight" do
    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     _stream_id,
                                                                     _manager_pid ->
      flunk("stream_to_process should not be called when over budget")
    end)

    model = default_model()

    assert {:error, {:rate_limited, _retry_at, %{reason: :over_budget}}} =
             UnifiedManager.start_stream(model, %{contents: [%{parts: [%{text: "too big"}]}]},
               token_budget_per_window: 5,
               estimated_input_tokens: 10,
               non_blocking: true
             )
  end

  test "concurrency permit released on manual stop" do
    test_pid = self()

    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     stream_id,
                                                                     _manager_pid ->
      pid =
        spawn(fn ->
          send(test_pid, {:stream_started, stream_id, self()})

          receive do
            :finish -> :ok
          end
        end)

      {:ok, pid}
    end)

    model = default_model()

    {:ok, stream_id} =
      UnifiedManager.start_stream("hello", [model: model, max_concurrency_per_model: 1], self())

    assert_receive {:stream_started, ^stream_id, stream_pid}

    :ok = UnifiedManager.stop_stream(stream_id)
    refute Process.alive?(stream_pid)

    {:ok, _new_stream} =
      UnifiedManager.start_stream(
        "next",
        [model: model, max_concurrency_per_model: 1, non_blocking: true],
        self()
      )
  end
end
