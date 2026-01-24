defmodule Gemini.Streaming.ToolOrchestratorTest do
  use ExUnit.Case, async: false

  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Chat
  alias Gemini.Streaming.ToolOrchestrator

  setup do
    :meck.new(Gemini.Auth.MultiAuthCoordinator, [:non_strict])
    :meck.new(Gemini.Client.HTTPStreaming, [:non_strict])
    :meck.new(Gemini.Tools, [:non_strict])

    on_exit(fn ->
      :meck.unload()
    end)

    :ok
  end

  test "tool execution failures are reported without crashing the orchestrator" do
    :meck.expect(MultiAuthCoordinator, :coordinate_auth, fn _strategy, _config ->
      {:ok, :gemini, []}
    end)

    :meck.expect(MultiAuthCoordinator, :get_credentials, fn _strategy, _config ->
      {:ok, %{project_id: "test", location: "us-central1"}}
    end)

    stream_pid =
      spawn(fn ->
        receive do
          _msg -> :ok
        end
      end)

    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     _stream_id,
                                                                     _target_pid ->
      {:ok, stream_pid}
    end)

    :meck.expect(Gemini.Tools, :execute_calls, fn _calls ->
      raise "boom"
    end)

    {:ok, pid} =
      ToolOrchestrator.start_link(
        "stream_1",
        self(),
        Chat.new(),
        :gemini,
        model: "models/test"
      )

    ref = Process.monitor(pid)

    event = %{
      type: :data,
      data: %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{"functionCall" => %{"name" => "tool", "args" => %{}}}
              ]
            }
          }
        ]
      }
    }

    send(pid, {:stream_event, "stream_1", event})

    assert_receive {:stream_error, "stream_1", error}, 1_000
    assert String.contains?(error, "Tool execution failed")

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
  end
end
