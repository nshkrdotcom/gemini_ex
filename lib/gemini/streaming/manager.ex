defmodule Gemini.Streaming.Manager do
  @moduledoc """
  GenServer for managing streaming connections and state.

  This GenServer handles:
  - Managing multiple concurrent streaming sessions
  - Buffering and parsing Server-Sent Events
  - Maintaining connection state and metadata
  - Automatic reconnection and error recovery
  """

  use GenServer
  require Logger

  alias Gemini.Client.HTTP

  @type stream_id :: String.t()
  @type stream_state :: %{
          stream_id: stream_id(),
          pid: pid(),
          auth_type: atom(),
          credentials: map(),
          model: String.t(),
          endpoint: String.t(),
          request_body: map(),
          buffer: String.t(),
          status: :active | :completed | :error,
          error: term() | nil,
          events: [map()],
          subscribers: [pid()]
        }

  @type state :: %{
          streams: %{stream_id() => stream_state()},
          stream_counter: non_neg_integer()
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a new streaming session.

  Returns a stream ID that can be used to subscribe to events.
  """
  def start_stream(auth_type, credentials, model, endpoint, request_body, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:start_stream, auth_type, credentials, model, endpoint, request_body, opts}
    )
  end

  @doc """
  Start a new streaming session with contents and options.
  (Alternative signature for compatibility)
  """
  def start_stream(contents, opts, subscriber_pid) when is_list(contents) do
    GenServer.call(__MODULE__, {:start_stream_simple, contents, opts, subscriber_pid})
  end

  @doc """
  Subscribe to events from a streaming session.
  """
  def subscribe(stream_id, subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber_pid})
  end

  @doc """
  Subscribe to events from a streaming session.
  (Alias for subscribe/2)
  """
  def subscribe_stream(stream_id, subscriber_pid \\ self()) do
    subscribe(stream_id, subscriber_pid)
  end

  @doc """
  Unsubscribe from a streaming session.
  """
  def unsubscribe(stream_id, subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:unsubscribe, stream_id, subscriber_pid})
  end

  @doc """
  Get the current status of a stream.
  """
  def get_stream_status(stream_id) do
    GenServer.call(__MODULE__, {:get_stream_status, stream_id})
  end

  @doc """
  Stop a streaming session.
  """
  def stop_stream(stream_id) do
    GenServer.call(__MODULE__, {:stop_stream, stream_id})
  end

  @doc """
  List all active streams.
  """
  def list_streams do
    GenServer.call(__MODULE__, :list_streams)
  end

  @doc """
  Get information about a specific stream.
  """
  def get_stream_info(stream_id) do
    GenServer.call(__MODULE__, {:get_stream_info, stream_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      streams: %{},
      stream_counter: 0,
      # Track monitors: %{monitor_ref => {stream_id, pid}}
      monitors: %{},
      # Track recently added subscribers: %{pid => timestamp}
      recent_subscribers: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(
        {:start_stream, auth_type, credentials, model, endpoint, request_body, _opts},
        {caller_pid, _ref},
        state
      ) do
    stream_id = generate_stream_id(state.stream_counter)

    stream_state = %{
      stream_id: stream_id,
      pid: caller_pid,
      auth_type: auth_type,
      credentials: credentials,
      model: model,
      endpoint: endpoint,
      request_body: request_body,
      buffer: "",
      status: :active,
      error: nil,
      events: [],
      subscribers: [caller_pid]
    }

    # Start the actual streaming request
    case start_http_stream(stream_state) do
      {:ok, _} ->
        new_state = %{
          state
          | streams: Map.put(state.streams, stream_id, stream_state),
            stream_counter: state.stream_counter + 1
        }

        {:reply, {:ok, stream_id}, new_state}
    end
  end

  @impl true
  def handle_call({:subscribe, stream_id, subscriber_pid}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      stream_state ->
        # Check if already subscribed
        if subscriber_pid in stream_state.subscribers do
          {:reply, :ok, state}
        else
          # Always add the subscriber first
          updated_stream = %{
            stream_state
            | subscribers: [subscriber_pid | stream_state.subscribers]
          }

          # Monitor the subscriber process
          monitor_ref = Process.monitor(subscriber_pid)

          # Track this as a recent subscriber to prevent immediate removal
          current_time = System.monotonic_time(:millisecond)
          new_recent_subscribers = Map.put(state.recent_subscribers, subscriber_pid, current_time)

          new_monitors = Map.put(state.monitors, monitor_ref, {stream_id, subscriber_pid})

          new_state = %{
            state
            | streams: Map.put(state.streams, stream_id, updated_stream),
              monitors: new_monitors,
              recent_subscribers: new_recent_subscribers
          }

          {:reply, :ok, new_state}
        end
    end
  end

  @impl true
  def handle_call({:unsubscribe, stream_id, subscriber_pid}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      stream_state ->
        updated_stream = %{
          stream_state
          | subscribers: List.delete(stream_state.subscribers, subscriber_pid)
        }

        # Find and remove the monitor for this subscriber
        {monitor_to_remove, new_monitors} =
          Enum.reduce(state.monitors, {nil, %{}}, fn {ref, {sid, pid}}, {remove_ref, acc} ->
            if sid == stream_id and pid == subscriber_pid do
              {ref, acc}
            else
              {remove_ref, Map.put(acc, ref, {sid, pid})}
            end
          end)

        # Demonitor if we found a monitor
        if monitor_to_remove do
          Process.demonitor(monitor_to_remove, [:flush])
        end

        new_state = %{
          state
          | streams: Map.put(state.streams, stream_id, updated_stream),
            monitors: new_monitors
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_stream_status, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:error, :stream_not_found}, state}
      stream_state -> {:reply, {:ok, stream_state.status}, state}
    end
  end

  @impl true
  def handle_call({:stop_stream, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      stream_state ->
        # Notify subscribers that stream is stopping
        notify_subscribers(stream_state, {:stream_stopped, stream_id})

        new_state = %{state | streams: Map.delete(state.streams, stream_id)}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:list_streams, _from, state) do
    stream_ids = Map.keys(state.streams)
    {:reply, stream_ids, state}
  end

  @impl true
  def handle_call({:start_stream_simple, contents, opts, subscriber_pid}, _from, state) do
    stream_id = generate_stream_id(state.stream_counter)

    # Monitor the initial subscriber
    monitor_ref = Process.monitor(subscriber_pid)

    stream_state = %{
      stream_id: stream_id,
      pid: subscriber_pid,
      contents: contents,
      opts: opts,
      status: :active,
      error: nil,
      events: [],
      subscribers: [subscriber_pid]
    }

    new_monitors = Map.put(state.monitors, monitor_ref, {stream_id, subscriber_pid})

    new_state = %{
      state
      | streams: Map.put(state.streams, stream_id, stream_state),
        stream_counter: state.stream_counter + 1,
        monitors: new_monitors
    }

    {:reply, {:ok, stream_id}, new_state}
  end

  @impl true
  def handle_call({:get_stream_info, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:error, :stream_not_found}, state}
      stream_state -> {:reply, {:ok, stream_state}, state}
    end
  end

  @impl true
  def handle_info({:stream_event, stream_id, event}, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:noreply, state}

      stream_state ->
        updated_stream = %{stream_state | events: [event | stream_state.events]}
        new_state = %{state | streams: Map.put(state.streams, stream_id, updated_stream)}

        # Notify all subscribers
        notify_subscribers(updated_stream, {:stream_event, stream_id, event})

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:stream_error, stream_id, error}, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:noreply, state}

      stream_state ->
        updated_stream = %{stream_state | status: :error, error: error}
        new_state = %{state | streams: Map.put(state.streams, stream_id, updated_stream)}

        # Notify all subscribers
        notify_subscribers(updated_stream, {:stream_error, stream_id, error})

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:stream_complete, stream_id}, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:noreply, state}

      stream_state ->
        updated_stream = %{stream_state | status: :completed}
        new_state = %{state | streams: Map.put(state.streams, stream_id, updated_stream)}

        # Notify all subscribers
        notify_subscribers(updated_stream, {:stream_complete, stream_id})

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    case Map.get(state.monitors, monitor_ref) do
      nil ->
        # Monitor not found, ignore
        {:noreply, state}

      {stream_id, dead_pid} ->
        # Check if this was a recently added subscriber (within last 50ms)
        current_time = System.monotonic_time(:millisecond)

        recently_added =
          case Map.get(state.recent_subscribers, dead_pid) do
            nil -> false
            add_time -> current_time - add_time < 50
          end

        if recently_added do
          # Don't remove recently added subscribers immediately to prevent race conditions
          {:noreply, state}
        else
          # Remove the monitor and recent subscriber tracking
          new_monitors = Map.delete(state.monitors, monitor_ref)
          new_recent_subscribers = Map.delete(state.recent_subscribers, dead_pid)

          case Map.get(state.streams, stream_id) do
            nil ->
              # Stream doesn't exist anymore, just remove the monitor
              {:noreply,
               %{state | monitors: new_monitors, recent_subscribers: new_recent_subscribers}}

            stream_state ->
              # Remove the dead process from subscribers
              updated_subscribers = List.delete(stream_state.subscribers, dead_pid)

              if Enum.empty?(updated_subscribers) do
                # No more subscribers, remove the stream entirely
                new_streams = Map.delete(state.streams, stream_id)

                {:noreply,
                 %{
                   state
                   | streams: new_streams,
                     monitors: new_monitors,
                     recent_subscribers: new_recent_subscribers
                 }}
              else
                # Update stream with remaining subscribers
                updated_stream = %{stream_state | subscribers: updated_subscribers}
                new_streams = Map.put(state.streams, stream_id, updated_stream)

                {:noreply,
                 %{
                   state
                   | streams: new_streams,
                     monitors: new_monitors,
                     recent_subscribers: new_recent_subscribers
                 }}
              end
          end
        end
    end
  end

  # Private Functions

  defp generate_stream_id(_counter) do
    # Generate a 32-character hex string using crypto random bytes
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp start_http_stream(stream_state) do
    # Build the authenticated request using the auth strategy
    base_url = Gemini.Auth.get_base_url(stream_state.auth_type, stream_state.credentials)

    path =
      Gemini.Auth.build_path(
        stream_state.auth_type,
        stream_state.model,
        stream_state.endpoint,
        stream_state.credentials
      )

    case Gemini.Auth.build_headers(stream_state.auth_type, stream_state.credentials) do
      {:ok, headers} ->
        full_url = "#{base_url}/#{path}?alt=sse"

        # Start the HTTP stream in a separate process
        manager_pid = self()
        stream_id = stream_state.stream_id

        spawn_link(fn ->
          case HTTP.stream_post_raw(full_url, stream_state.request_body, headers) do
            {:ok, events} ->
              Enum.each(events, fn event ->
                send(manager_pid, {:stream_event, stream_id, event})
              end)

              send(manager_pid, {:stream_complete, stream_id})

            {:error, error} ->
              send(manager_pid, {:stream_error, stream_id, error})
          end
        end)

        {:ok, :started}

      {:error, reason} ->
        {:error, {:auth_failed, reason}}
    end
  end

  defp notify_subscribers(stream_state, message) do
    Enum.each(stream_state.subscribers, fn pid ->
      send(pid, message)
    end)
  end
end
