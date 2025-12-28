defmodule Gemini.Streaming.ManagerV2 do
  @moduledoc """
  Improved GenServer for managing streaming connections and state.

  Features:
  - Proper HTTP streaming with persistent connections
  - Resource management and cleanup
  - Subscriber pattern with backpressure
  - Error handling and automatic retries
  - Stream lifecycle management
  """

  use GenServer
  require Logger

  alias Gemini.Auth
  alias Gemini.Client.HTTPStreaming
  alias Gemini.Config
  alias Gemini.Generate

  @type stream_id :: String.t()
  @type subscriber_ref :: {pid(), reference()}

  @type stream_state :: %{
          stream_id: stream_id(),
          stream_pid: pid() | nil,
          model: String.t(),
          request_body: map(),
          status: :starting | :active | :completed | :error | :stopped,
          error: term() | nil,
          started_at: DateTime.t(),
          subscribers: [subscriber_ref()],
          events_count: non_neg_integer(),
          last_event_at: DateTime.t() | nil,
          config: keyword()
        }

  @type manager_state :: %{
          streams: %{stream_id() => stream_state()},
          stream_counter: non_neg_integer(),
          max_streams: pos_integer(),
          default_timeout: pos_integer(),
          cleanup_delay_ms: pos_integer()
        }

  # Client API

  @doc """
  Start the streaming manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a new streaming session.

  ## Parameters
  - `contents` - Content to stream (string or list of Content structs)
  - `opts` - Generation options (model, generation_config, etc.)
  - `subscriber_pid` - Process to receive stream events (default: calling process)

  ## Returns
  - `{:ok, stream_id}` - Stream started successfully
  - `{:error, reason}` - Failed to start stream

  ## Events sent to subscriber:
  - `{:stream_event, stream_id, event_data}` - New event received
  - `{:stream_complete, stream_id}` - Stream completed successfully
  - `{:stream_error, stream_id, error}` - Stream failed with error
  """
  @spec start_stream(term(), keyword(), pid()) :: {:ok, stream_id()} | {:error, term()}
  def start_stream(contents, opts \\ [], subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:start_stream, contents, opts, subscriber_pid})
  end

  @doc """
  Subscribe to events from an existing stream.
  """
  @spec subscribe_stream(stream_id(), pid()) :: :ok | {:error, term()}
  def subscribe_stream(stream_id, subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber_pid})
  end

  @doc """
  Unsubscribe from a stream.
  """
  @spec unsubscribe_stream(stream_id(), pid()) :: :ok | {:error, term()}
  def unsubscribe_stream(stream_id, subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:unsubscribe, stream_id, subscriber_pid})
  end

  @doc """
  Stop a streaming session.
  """
  @spec stop_stream(stream_id()) :: :ok | {:error, term()}
  def stop_stream(stream_id) do
    GenServer.call(__MODULE__, {:stop_stream, stream_id})
  end

  @doc """
  Get information about a stream.
  """
  @spec get_stream_info(stream_id()) :: {:ok, map()} | {:error, term()}
  def get_stream_info(stream_id) do
    GenServer.call(__MODULE__, {:get_stream_info, stream_id})
  end

  @doc """
  List all active streams.
  """
  @spec list_streams() :: [stream_id()]
  def list_streams do
    GenServer.call(__MODULE__, :list_streams)
  end

  @doc """
  Get manager statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    max_streams = Keyword.get(opts, :max_streams, 100)
    default_timeout = Keyword.get(opts, :default_timeout, Config.timeout())
    cleanup_delay_ms = Keyword.get(opts, :cleanup_delay_ms, default_cleanup_delay_ms())

    state = %{
      streams: %{},
      stream_counter: 0,
      max_streams: max_streams,
      default_timeout: default_timeout,
      cleanup_delay_ms: cleanup_delay_ms
    }

    Logger.info("Streaming manager started with max_streams: #{state.max_streams}")
    {:ok, state}
  end

  @impl true
  def handle_call({:start_stream, contents, opts, subscriber_pid}, _from, state) do
    if map_size(state.streams) >= state.max_streams do
      {:reply, {:error, :max_streams_exceeded}, state}
    else
      case create_stream(contents, opts, subscriber_pid, state) do
        {:ok, stream_id, new_state} ->
          {:reply, {:ok, stream_id}, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call({:subscribe, stream_id, subscriber_pid}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      stream_state ->
        # Create monitor reference for the subscriber
        monitor_ref = Process.monitor(subscriber_pid)
        subscriber_ref = {subscriber_pid, monitor_ref}

        # Check if already subscribed
        if subscriber_already_exists?(stream_state.subscribers, subscriber_pid) do
          # Demonitor the new reference since subscriber already exists
          Process.demonitor(monitor_ref, [:flush])
          {:reply, :ok, state}
        else
          updated_stream = %{
            stream_state
            | subscribers: [subscriber_ref | stream_state.subscribers]
          }

          new_state = put_in(state.streams[stream_id], updated_stream)
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
        {updated_subscribers, demonitor_refs} =
          remove_subscriber(stream_state.subscribers, subscriber_pid)

        # Demonitor removed references
        Enum.each(demonitor_refs, &Process.demonitor(&1, [:flush]))

        updated_stream = %{stream_state | subscribers: updated_subscribers}

        # If no subscribers left, stop the stream
        new_state =
          if Enum.empty?(updated_subscribers) do
            stop_stream_internal(stream_id, state)
          else
            put_in(state.streams[stream_id], updated_stream)
          end

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:stop_stream, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      _stream_state ->
        new_state = stop_stream_internal(stream_id, state)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_stream_info, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:reply, {:error, :stream_not_found}, state}

      stream_state ->
        info = %{
          stream_id: stream_state.stream_id,
          status: stream_state.status,
          model: stream_state.model,
          started_at: stream_state.started_at,
          events_count: stream_state.events_count,
          last_event_at: stream_state.last_event_at,
          subscribers_count: length(stream_state.subscribers),
          error: stream_state.error
        }

        {:reply, {:ok, info}, state}
    end
  end

  @impl true
  def handle_call(:list_streams, _from, state) do
    stream_ids = Map.keys(state.streams)
    {:reply, stream_ids, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_streams: map_size(state.streams),
      max_streams: state.max_streams,
      streams_by_status: count_streams_by_status(state.streams),
      total_subscribers: count_total_subscribers(state.streams)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:stream_event, stream_id, event}, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        Logger.warning("Received event for unknown stream: #{stream_id}")
        {:noreply, state}

      stream_state ->
        # Update stream state
        updated_stream = %{
          stream_state
          | events_count: stream_state.events_count + 1,
            last_event_at: DateTime.utc_now(),
            status: :active
        }

        # Notify all subscribers
        notify_subscribers(updated_stream.subscribers, {:stream_event, stream_id, event})

        new_state = put_in(state.streams[stream_id], updated_stream)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:stream_complete, stream_id}, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:noreply, state}

      stream_state ->
        Logger.info("Stream completed: #{stream_id}")

        # Update status
        updated_stream = %{stream_state | status: :completed}

        # Notify subscribers
        notify_subscribers(updated_stream.subscribers, {:stream_complete, stream_id})

        # Clean up after a delay
        Process.send_after(self(), {:cleanup_stream, stream_id}, state.cleanup_delay_ms)

        new_state = put_in(state.streams[stream_id], updated_stream)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:stream_error, stream_id, error}, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        {:noreply, state}

      stream_state ->
        Logger.error("Stream error: #{stream_id} - #{inspect(error)}")

        # Update status
        updated_stream = %{
          stream_state
          | status: :error,
            error: error
        }

        # Notify subscribers
        notify_subscribers(updated_stream.subscribers, {:stream_error, stream_id, error})

        new_state = put_in(state.streams[stream_id], updated_stream)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:cleanup_stream, stream_id}, state) do
    case Map.get(state.streams, stream_id) do
      %{status: status} when status in [:completed, :error, :stopped] ->
        Logger.debug("Cleaning up completed stream: #{stream_id}")
        new_state = %{state | streams: Map.delete(state.streams, stream_id)}
        {:noreply, new_state}

      _ ->
        # Stream still active, don't clean up
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, state) do
    # Find and remove the dead subscriber
    new_streams =
      Enum.reduce(state.streams, state.streams, fn {stream_id, stream_state}, acc ->
        case remove_subscriber_by_ref(stream_state.subscribers, pid, monitor_ref) do
          {[], _} ->
            # No subscribers left, stop the stream
            Logger.debug("Last subscriber died for stream #{stream_id}, stopping stream")
            stop_stream_if_exists(stream_id, stream_state)
            Map.delete(acc, stream_id)

          {updated_subscribers, _} ->
            updated_stream = %{stream_state | subscribers: updated_subscribers}
            Map.put(acc, stream_id, updated_stream)
        end
      end)

    new_state = %{state | streams: new_streams}
    {:noreply, new_state}
  end

  # Private helper functions

  @spec create_stream(term(), keyword(), pid(), manager_state()) ::
          {:ok, stream_id(), manager_state()} | {:error, term()}
  defp create_stream(contents, opts, subscriber_pid, state) do
    # Generate unique stream ID
    stream_id = generate_stream_id(state.stream_counter)

    # Get authentication configuration
    auth_config = Config.auth_config()

    if is_nil(auth_config) do
      throw({:error, :no_auth_config})
    end

    # Build request
    model = Keyword.get(opts, :model, Config.default_model())
    request_body = Generate.build_generate_request(contents, opts)

    # Build streaming URL
    base_url = Auth.get_base_url(auth_config.type, auth_config.credentials)

    path =
      Auth.build_path(auth_config.type, model, "streamGenerateContent", auth_config.credentials)

    case Auth.build_headers(auth_config.type, auth_config.credentials) do
      {:error, reason} ->
        throw({:error, {:auth_failed, reason}})

      {:ok, headers} ->
        full_url = "#{base_url}/#{path}"

        # Create monitor for initial subscriber
        monitor_ref = Process.monitor(subscriber_pid)
        subscriber_ref = {subscriber_pid, monitor_ref}

        # Initialize stream state
        stream_state = %{
          stream_id: stream_id,
          stream_pid: nil,
          model: model,
          request_body: request_body,
          status: :starting,
          error: nil,
          started_at: DateTime.utc_now(),
          subscribers: [subscriber_ref],
          events_count: 0,
          last_event_at: nil,
          config: opts
        }

        # Start HTTP streaming
        stream_opts = [
          timeout: Keyword.get(opts, :timeout, state.default_timeout),
          max_retries: Keyword.get(opts, :max_retries, 3)
        ]

        {:ok, stream_pid} =
          HTTPStreaming.stream_to_process(
            full_url,
            headers,
            request_body,
            stream_id,
            self(),
            stream_opts
          )

        updated_stream = %{stream_state | stream_pid: stream_pid, status: :active}

        new_state = %{
          state
          | streams: Map.put(state.streams, stream_id, updated_stream),
            stream_counter: state.stream_counter + 1
        }

        Logger.info("Started stream #{stream_id} for model #{model}")
        {:ok, stream_id, new_state}
    end
  rescue
    error -> {:error, {:create_stream_error, error}}
  catch
    {:error, reason} -> {:error, reason}
  end

  @spec generate_stream_id(non_neg_integer()) :: stream_id()
  defp generate_stream_id(counter) do
    # Generate a unique ID combining timestamp, counter, and random bytes
    timestamp = System.system_time(:millisecond)
    random_part = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    "stream_#{timestamp}_#{counter}_#{random_part}"
  end

  @spec subscriber_already_exists?([subscriber_ref()], pid()) :: boolean()
  defp subscriber_already_exists?(subscribers, pid) do
    Enum.any?(subscribers, fn {subscriber_pid, _ref} -> subscriber_pid == pid end)
  end

  @spec remove_subscriber([subscriber_ref()], pid()) :: {[subscriber_ref()], [reference()]}
  defp remove_subscriber(subscribers, pid_to_remove) do
    {remaining, removed} =
      Enum.split_with(subscribers, fn {subscriber_pid, _ref} ->
        subscriber_pid != pid_to_remove
      end)

    removed_refs = Enum.map(removed, fn {_pid, ref} -> ref end)
    {remaining, removed_refs}
  end

  @spec remove_subscriber_by_ref([subscriber_ref()], pid(), reference()) ::
          {[subscriber_ref()], [reference()]}
  defp remove_subscriber_by_ref(subscribers, pid, monitor_ref) do
    {remaining, removed} =
      Enum.split_with(subscribers, fn {subscriber_pid, ref} ->
        not (subscriber_pid == pid and ref == monitor_ref)
      end)

    removed_refs = Enum.map(removed, fn {_pid, ref} -> ref end)
    {remaining, removed_refs}
  end

  @spec notify_subscribers([subscriber_ref()], term()) :: :ok
  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn {pid, _ref} ->
      send(pid, message)
    end)
  end

  @spec stop_stream_internal(stream_id(), manager_state()) :: manager_state()
  defp stop_stream_internal(stream_id, state) do
    case Map.get(state.streams, stream_id) do
      nil ->
        state

      stream_state ->
        # Stop the streaming process if it exists
        if stream_state.stream_pid && Process.alive?(stream_state.stream_pid) do
          Process.exit(stream_state.stream_pid, :shutdown)
        end

        # Notify subscribers
        notify_subscribers(stream_state.subscribers, {:stream_stopped, stream_id})

        # Clean up monitors
        Enum.each(stream_state.subscribers, fn {_pid, ref} ->
          Process.demonitor(ref, [:flush])
        end)

        Logger.info("Stopped stream: #{stream_id}")

        # Remove from state
        %{state | streams: Map.delete(state.streams, stream_id)}
    end
  end

  @spec stop_stream_if_exists(stream_id(), stream_state()) :: :ok
  defp stop_stream_if_exists(_stream_id, stream_state) do
    if stream_state.stream_pid && Process.alive?(stream_state.stream_pid) do
      Process.exit(stream_state.stream_pid, :shutdown)
    end

    :ok
  end

  @spec count_streams_by_status(%{stream_id() => stream_state()}) :: map()
  defp count_streams_by_status(streams) do
    Enum.reduce(streams, %{}, fn {_id, stream}, acc ->
      status = stream.status
      Map.update(acc, status, 1, &(&1 + 1))
    end)
  end

  @spec count_total_subscribers(%{stream_id() => stream_state()}) :: non_neg_integer()
  defp count_total_subscribers(streams) do
    Enum.reduce(streams, 0, fn {_id, stream}, acc ->
      acc + length(stream.subscribers)
    end)
  end

  defp default_cleanup_delay_ms do
    streaming_config = Application.get_env(:gemini_ex, :streaming, [])
    Keyword.get(streaming_config, :cleanup_delay_ms, 5_000)
  end
end
