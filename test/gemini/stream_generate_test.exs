defmodule Gemini.StreamGenerateTest do
  use ExUnit.Case, async: false

  setup do
    :meck.new(Gemini.APIs.Coordinator, [:non_strict])

    :meck.expect(Gemini.APIs.Coordinator, :stream_generate_content, fn _contents, _opts ->
      {:ok, "stream_test"}
    end)

    :meck.expect(Gemini.APIs.Coordinator, :subscribe_stream, fn "stream_test", _pid ->
      :ok
    end)

    on_exit(fn ->
      :meck.unload()
    end)

    :ok
  end

  test "stream_generate returns collected responses on complete" do
    Process.send_after(
      self(),
      {:stream_event, "stream_test", %{type: :data, data: %{"text" => "hello"}}},
      5
    )

    Process.send_after(self(), {:stream_complete, "stream_test"}, 10)

    assert {:ok, [%{"text" => "hello"}]} =
             Gemini.stream_generate("hello", stream_timeout: 100)
  end

  test "stream_generate stops stream when collection times out" do
    test_pid = self()

    :meck.expect(Gemini.APIs.Coordinator, :stop_stream, fn "stream_test" ->
      send(test_pid, :stream_stopped)
      :ok
    end)

    assert {:error, "Stream timeout"} =
             Gemini.stream_generate("hello", stream_timeout: 10)

    assert_receive :stream_stopped, 100
  end
end
