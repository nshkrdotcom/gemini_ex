defmodule Gemini.Streaming.ManagerTest do
  use ExUnit.Case, async: false

  alias Gemini.Streaming.Manager

  setup do
    # Start a fresh manager for each test
    if Process.whereis(Manager) do
      GenServer.stop(Manager)
    end

    # Wait a bit for the process to stop
    :timer.sleep(10)

    case start_supervised({Manager, []}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  describe "start_stream/3" do
    test "creates new stream and returns stream_id" do
      contents = ["Hello, world!"]
      opts = [model: "gemini-flash-lite-latest"]

      assert {:ok, stream_id} = Manager.start_stream(contents, opts, self())
      assert is_binary(stream_id)
      # UUID without hyphens
      assert String.length(stream_id) == 32
    end

    test "each stream gets unique stream_id" do
      contents = ["Hello"]
      opts = []

      {:ok, stream_id1} = Manager.start_stream(contents, opts, self())
      {:ok, stream_id2} = Manager.start_stream(contents, opts, self())

      assert stream_id1 != stream_id2
    end

    test "stores stream state correctly" do
      contents = ["Test content"]
      opts = [model: "gemini-flash-lite-latest"]

      {:ok, stream_id} = Manager.start_stream(contents, opts, self())

      # Verify stream exists in state
      state = :sys.get_state(Manager)
      assert Map.has_key?(state.streams, stream_id)

      stream_info = state.streams[stream_id]
      assert stream_info.contents == contents
      assert stream_info.opts == opts
      assert stream_info.subscribers == [self()]
    end
  end

  describe "subscribe_stream/2" do
    test "adds subscriber to existing stream" do
      contents = ["Hello"]
      opts = []

      {:ok, stream_id} = Manager.start_stream(contents, opts, self())

      new_subscriber = spawn(fn -> :ok end)
      assert :ok = Manager.subscribe_stream(stream_id, new_subscriber)

      # Verify subscriber was added
      state = :sys.get_state(Manager)
      stream_info = state.streams[stream_id]
      assert self() in stream_info.subscribers
      assert new_subscriber in stream_info.subscribers
    end

    test "returns error for non-existent stream" do
      fake_stream_id = "non-existent-stream-id"

      assert {:error, :stream_not_found} = Manager.subscribe_stream(fake_stream_id, self())
    end

    test "does not duplicate subscribers" do
      contents = ["Hello"]
      opts = []

      {:ok, stream_id} = Manager.start_stream(contents, opts, self())

      # Subscribe the same process twice
      assert :ok = Manager.subscribe_stream(stream_id, self())
      assert :ok = Manager.subscribe_stream(stream_id, self())

      # Verify only one instance of subscriber
      state = :sys.get_state(Manager)
      stream_info = state.streams[stream_id]
      subscriber_count = Enum.count(stream_info.subscribers, &(&1 == self()))
      assert subscriber_count == 1
    end
  end

  describe "stop_stream/1" do
    test "removes stream from state" do
      contents = ["Hello"]
      opts = []

      {:ok, stream_id} = Manager.start_stream(contents, opts, self())

      # Verify stream exists
      state = :sys.get_state(Manager)
      assert Map.has_key?(state.streams, stream_id)

      # Stop stream
      assert :ok = Manager.stop_stream(stream_id)

      # Verify stream is removed
      new_state = :sys.get_state(Manager)
      refute Map.has_key?(new_state.streams, stream_id)
    end

    test "returns error for non-existent stream" do
      fake_stream_id = "non-existent-stream-id"

      assert {:error, :stream_not_found} = Manager.stop_stream(fake_stream_id)
    end
  end

  describe "list_streams/0" do
    test "returns empty list when no streams" do
      assert Manager.list_streams() == []
    end

    test "returns list of active streams" do
      contents = ["Hello"]
      opts = []

      {:ok, stream_id1} = Manager.start_stream(contents, opts, self())
      {:ok, stream_id2} = Manager.start_stream(contents, opts, self())

      streams = Manager.list_streams()
      assert length(streams) == 2
      assert stream_id1 in streams
      assert stream_id2 in streams
    end

    test "list updates when streams are stopped" do
      contents = ["Hello"]
      opts = []

      {:ok, stream_id1} = Manager.start_stream(contents, opts, self())
      {:ok, stream_id2} = Manager.start_stream(contents, opts, self())

      assert length(Manager.list_streams()) == 2

      Manager.stop_stream(stream_id1)

      streams = Manager.list_streams()
      assert length(streams) == 1
      assert stream_id2 in streams
      refute stream_id1 in streams
    end
  end

  describe "get_stream_info/1" do
    test "returns stream information for existing stream" do
      contents = ["Test content"]
      opts = [model: "gemini-flash-lite-latest"]

      {:ok, stream_id} = Manager.start_stream(contents, opts, self())

      assert {:ok, info} = Manager.get_stream_info(stream_id)
      assert info.contents == contents
      assert info.opts == opts
      assert info.subscribers == [self()]
      assert info.status == :active
    end

    test "returns error for non-existent stream" do
      fake_stream_id = "non-existent-stream-id"

      assert {:error, :stream_not_found} = Manager.get_stream_info(fake_stream_id)
    end
  end

  describe "process cleanup" do
    test "removes stream when subscriber process dies" do
      contents = ["Hello"]
      opts = []

      # Create a temporary process as subscriber
      subscriber =
        spawn(fn ->
          receive do
            :stop -> :ok
          after
            100 -> :ok
          end
        end)

      {:ok, stream_id} = Manager.start_stream(contents, opts, subscriber)

      # Verify stream exists
      assert {:ok, _info} = Manager.get_stream_info(stream_id)

      # Kill the subscriber process
      Process.exit(subscriber, :kill)

      # Give the manager time to process the DOWN message
      Process.sleep(50)

      # Verify stream is cleaned up
      assert {:error, :stream_not_found} = Manager.get_stream_info(stream_id)
    end
  end
end
