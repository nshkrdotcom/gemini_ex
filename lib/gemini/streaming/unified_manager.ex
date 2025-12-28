defmodule Gemini.Streaming.UnifiedManager do
  @moduledoc """
  Unified streaming manager that supports multiple authentication strategies.

  This manager extends the excellent ManagerV2 functionality with multi-auth support,
  allowing concurrent usage of both Gemini API and Vertex AI authentication strategies
  within the same application.

  Features:
  - All capabilities from ManagerV2 (HTTP streaming, resource management, etc.)
  - Multi-authentication strategy support via MultiAuthCoordinator
  - Per-stream authentication strategy selection
  - Concurrent usage of multiple auth strategies
  """

  use GenServer
  require Logger

  alias Altar.ADM.FunctionCall
  alias Gemini.Auth
  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Chat
  alias Gemini.Client.HTTPStreaming
  alias Gemini.Config
  alias Gemini.RateLimiter
  alias Gemini.Streaming.ToolOrchestrator
  alias Gemini.Types.{Content, Part}

  @type stream_id :: String.t()
  @type subscriber_ref :: {pid(), reference()}
  @type auth_strategy :: :gemini | :vertex_ai

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
          config: keyword(),
          auth_strategy: auth_strategy(),
          release_fn: nil | (atom(), map() | nil -> :ok)
        }

  @type manager_state :: %{
          streams: %{stream_id() => stream_state()},
          stream_counter: non_neg_integer(),
          max_streams: pos_integer(),
          default_timeout: pos_integer()
        }

  # Client API

  @doc """
  Start the unified streaming manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a new stream.

  ## API Variants

  ### New API: start_stream(model, request_body, opts)
  - `model`: The model to use for generation
  - `request_body`: The request body for content generation
  - `opts`: Options including auth strategy and other config

  ### Legacy API: start_stream(contents, opts, subscriber_pid) - ManagerV2 compatibility
  - `contents`: Content to stream (string or list of Content structs)
  - `opts`: Generation options (model, generation_config, etc.)
  - `subscriber_pid`: Process to receive stream events

  ## Options
  - `:auth`: Authentication strategy (`:gemini` or `:vertex_ai`)
  - `:timeout`: Request timeout in milliseconds
  - Other options passed to the streaming request

  ## Examples

      # New API with Gemini auth
      {:ok, stream_id} = UnifiedManager.start_stream(
        Gemini.Config.get_model(:flash_lite_latest),
        %{contents: [%{parts: [%{text: "Hello"}]}]},
        auth: :gemini
      )

      # Legacy API for ManagerV2 compatibility
      {:ok, stream_id} = UnifiedManager.start_stream("Hello", [model: Gemini.Config.get_model(:flash_lite_latest)], self())
  """
  def start_stream(model, request_body, opts \\ [])

  @spec start_stream(String.t(), map(), keyword()) :: {:ok, stream_id()} | {:error, term()}
  def start_stream(model, request_body, opts)
      when is_binary(model) and is_map(request_body) and is_list(opts) do
    GenServer.call(__MODULE__, {:start_stream, model, request_body, opts})
  end

  @spec start_stream(term(), keyword(), pid()) :: {:ok, stream_id()} | {:error, term()}
  def start_stream(contents, opts, subscriber_pid)
      when is_list(opts) and is_pid(subscriber_pid) do
    # Convert to the new API format
    model = Keyword.get(opts, :model, Gemini.Config.default_model())

    # Build request body from contents
    request_body =
      case contents do
        contents when is_binary(contents) ->
          %{contents: [%{parts: [%{text: contents}]}]}

        contents when is_list(contents) ->
          %{contents: contents}

        contents ->
          contents
      end

    # Start the stream with new API
    case start_stream(model, request_body, opts) do
      {:ok, stream_id} ->
        # Auto-subscribe the calling process for compatibility
        case subscribe(stream_id, subscriber_pid) do
          :ok -> {:ok, stream_id}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Subscribe to a stream to receive events.
  """
  @spec subscribe(stream_id(), pid()) :: :ok | {:error, term()}
  def subscribe(stream_id, subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, stream_id, subscriber_pid})
  end

  @doc """
  Unsubscribe from a stream.
  """
  @spec unsubscribe(stream_id(), pid()) :: :ok | {:error, term()}
  def unsubscribe(stream_id, subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:unsubscribe, stream_id, subscriber_pid})
  end

  @doc """
  Stop a stream.
  """
  @spec stop_stream(stream_id()) :: :ok | {:error, term()}
  def stop_stream(stream_id) do
    GenServer.call(__MODULE__, {:stop_stream, stream_id})
  end

  @doc """
  Get the status of a stream.
  """
  @spec stream_status(stream_id()) :: {:ok, atom()} | {:error, term()}
  def stream_status(stream_id) do
    GenServer.call(__MODULE__, {:stream_status, stream_id})
  end

  @doc """
  List all active streams.
  """
  @spec list_streams() :: [stream_id()]
  def list_streams do
    GenServer.call(__MODULE__, :list_streams)
  end

  # Compatibility functions for ManagerV2 API

  @doc """
  Subscribe to stream events (ManagerV2 compatibility).
  """
  @spec subscribe_stream(stream_id(), pid()) :: :ok | {:error, term()}
  def subscribe_stream(stream_id, subscriber_pid \\ self()) do
    subscribe(stream_id, subscriber_pid)
  end

  @doc """
  Get stream information (ManagerV2 compatibility).
  """
  @spec get_stream_info(stream_id()) :: {:ok, map()} | {:error, term()}
  def get_stream_info(stream_id) do
    GenServer.call(__MODULE__, {:get_stream_info, stream_id})
  end

  @doc """
  Get manager statistics (ManagerV2 compatibility).
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    max_streams = Keyword.get(opts, :max_streams, 100)
    default_timeout = Keyword.get(opts, :default_timeout, Config.timeout())

    Logger.info("Unified streaming manager started with max_streams: #{max_streams}")

    state = %{
      streams: %{},
      stream_counter: 0,
      max_streams: max_streams,
      default_timeout: default_timeout
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_stream, model, request_body, opts}, _from, state) do
    if max_streams_reached?(state) do
      {:reply, {:error, :max_streams_reached}, state}
    else
      start_stream_with_opts(model, request_body, opts, state)
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
          try do
            Process.demonitor(monitor_ref, [:flush])
          catch
            :error, :noproc -> :ok
          end

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

        # Demonitor removed references (ignore if already removed)
        Enum.each(demonitor_refs, fn ref ->
          try do
            Process.demonitor(ref, [:flush])
          catch
            :error, :noproc -> :ok
          end
        end)

        updated_stream = %{stream_state | subscribers: updated_subscribers}

        # If no subscribers left, stop the stream
        new_state =
          if updated_subscribers == [] do
            finalize_stream(stream_state, state, :stopped)
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

      stream_state ->
        new_state = finalize_stream(stream_state, state, :stopped)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:stream_status, stream_id}, _from, state) do
    case Map.get(state.streams, stream_id) do
      nil -> {:reply, {:error, :stream_not_found}, state}
      stream_state -> {:reply, {:ok, stream_state.status}, state}
    end
  end

  @impl true
  def handle_call(:list_streams, _from, state) do
    stream_ids = Map.keys(state.streams)
    {:reply, stream_ids, state}
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
          subscribers_count: length(stream_state.subscribers),
          started_at: stream_state.started_at
        }

        {:reply, {:ok, info}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    streams_by_status =
      state.streams
      |> Enum.group_by(fn {_id, stream} -> stream.status end)
      |> Map.new(fn {status, streams} -> {status, length(streams)} end)

    total_subscribers =
      state.streams
      |> Enum.reduce(0, fn {_id, stream}, acc ->
        acc + length(stream.subscribers)
      end)

    stats = %{
      total_streams: map_size(state.streams),
      max_streams: state.max_streams,
      streams_by_status: streams_by_status,
      total_subscribers: total_subscribers
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    # Handle subscriber process death
    {updated_streams, _removed_streams} =
      Enum.reduce(state.streams, {%{}, []}, fn {stream_id, stream_state},
                                               {acc_streams, acc_removed} ->
        {updated_subscribers, _demonitor_refs} =
          remove_subscriber_by_ref(stream_state.subscribers, pid, ref)

        updated_stream = %{stream_state | subscribers: updated_subscribers}

        # If no subscribers left and not the stream process itself, stop the stream
        if updated_subscribers == [] and stream_state.stream_pid != pid do
          new_state = finalize_stream(stream_state, %{state | streams: acc_streams}, :stopped)
          {new_state.streams, [stream_id | acc_removed]}
        else
          {Map.put(acc_streams, stream_id, updated_stream), acc_removed}
        end
      end)

    new_state = %{state | streams: updated_streams}

    if reason not in [:normal, :shutdown] and pid != self() do
      Logger.warning("Process #{inspect(pid)} died with reason: #{inspect(reason)}")
    end

    {:noreply, new_state}
  end

  # Handle streaming events from the HTTP streaming process
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
            last_event_at: DateTime.utc_now()
        }

        # Forward event to all subscribers
        Enum.each(stream_state.subscribers, fn {subscriber_pid, _ref} ->
          send(subscriber_pid, {:stream_event, stream_id, event})
        end)

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
        updated_stream = release_stream_resources(stream_state, :completed)

        # Update status and notify subscribers
        updated_stream = %{updated_stream | status: :completed}

        Enum.each(stream_state.subscribers, fn {subscriber_pid, _ref} ->
          send(subscriber_pid, {:stream_complete, stream_id})
        end)

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
        updated_stream = release_stream_resources(stream_state, :error)

        # Update status and notify subscribers
        updated_stream = %{updated_stream | status: :error, error: error}

        Enum.each(stream_state.subscribers, fn {subscriber_pid, _ref} ->
          send(subscriber_pid, {:stream_error, stream_id, error})
        end)

        new_state = put_in(state.streams[stream_id], updated_stream)
        {:noreply, new_state}
    end
  end

  # Private helper functions

  defp start_stream_with_opts(model, request_body, opts, state) do
    auth_strategy = Keyword.get(opts, :auth, Gemini.Config.current_api_type())

    case validate_auth_strategy(auth_strategy) do
      :ok ->
        init_and_start_stream(model, request_body, opts, auth_strategy, state)

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp init_and_start_stream(model, request_body, opts, auth_strategy, state) do
    stream_id = generate_stream_id(state.stream_counter)

    stream_state = %{
      stream_id: stream_id,
      stream_pid: nil,
      model: model,
      request_body: request_body,
      status: :starting,
      error: nil,
      started_at: DateTime.utc_now(),
      subscribers: [],
      events_count: 0,
      last_event_at: nil,
      config: opts,
      auth_strategy: auth_strategy,
      release_fn: nil
    }

    case start_stream_backend(stream_state, opts) do
      {:ok, stream_pid, release_fn} ->
        updated_stream = %{
          stream_state
          | stream_pid: stream_pid,
            status: :active,
            release_fn: release_fn
        }

        new_state = %{
          state
          | streams: Map.put(state.streams, stream_id, updated_stream),
            stream_counter: state.stream_counter + 1
        }

        {:reply, {:ok, stream_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp start_stream_backend(stream_state, opts) do
    if Keyword.get(opts, :auto_execute_tools, false) do
      start_auto_tool_stream(stream_state)
    else
      start_stream_process(stream_state)
    end
  end

  defp max_streams_reached?(state) do
    map_size(state.streams) >= state.max_streams
  end

  @spec validate_auth_strategy(term()) :: :ok | {:error, String.t()}
  defp validate_auth_strategy(:gemini), do: :ok
  defp validate_auth_strategy(:vertex_ai), do: :ok

  defp validate_auth_strategy(strategy),
    do: {:error, "Invalid auth strategy: #{inspect(strategy)}"}

  @spec generate_stream_id(non_neg_integer()) :: stream_id()
  defp generate_stream_id(counter) do
    timestamp = System.system_time(:microsecond)
    "stream_#{counter}_#{timestamp}"
  end

  @spec start_stream_process(stream_state()) :: {:ok, pid(), function()} | {:error, term()}
  defp start_stream_process(stream_state) do
    start_fn = fn -> stream_request_with_auth(stream_state) end

    with {:ok, {result, release_fn}} <-
           RateLimiter.execute_streaming(
             start_fn,
             stream_state.model,
             stream_state.config
           ) do
      handle_stream_start_result(result, release_fn)
    end
  end

  @spec start_auto_tool_stream(stream_state()) :: {:ok, pid(), function()} | {:error, term()}
  defp start_auto_tool_stream(stream_state) do
    # Convert request body to Chat struct for the orchestrator
    chat = request_body_to_chat(stream_state.request_body, stream_state.config)

    # Start the tool orchestrator
    # Note: The orchestrator will send events to self() (UnifiedManager)
    # which will then forward them to subscribers
    start_fn = fn ->
      ToolOrchestrator.start_link(
        stream_state.stream_id,
        self(),
        chat,
        stream_state.auth_strategy,
        stream_state.config
      )
    end

    with {:ok, {result, release_fn}} <-
           RateLimiter.execute_streaming(
             start_fn,
             stream_state.model,
             stream_state.config
           ) do
      handle_stream_start_result(result, release_fn)
    end
  end

  @spec request_body_to_chat(map(), keyword()) :: Chat.t()
  defp request_body_to_chat(request_body, config) do
    # Extract contents from request body and convert to Content structs
    contents =
      case Map.get(request_body, :contents, []) do
        contents when is_list(contents) ->
          Enum.map(contents, &convert_api_content_to_struct/1)

        _ ->
          []
      end

    # Create chat with history and options
    chat = Chat.new(config)
    %{chat | history: contents}
  end

  @spec convert_api_content_to_struct(map()) :: Content.t()
  defp convert_api_content_to_struct(%{role: role, parts: parts}) do
    converted_parts = Enum.map(parts, &convert_api_part_to_struct/1)
    %Content{role: role, parts: converted_parts}
  end

  @spec convert_api_part_to_struct(map()) :: Part.t()
  defp convert_api_part_to_struct(part) do
    cond do
      Map.has_key?(part, :text) ->
        %Part{text: part.text}

      Map.has_key?(part, :functionCall) ->
        case FunctionCall.new(part.functionCall) do
          {:ok, function_call} ->
            %Part{function_call: function_call}

          {:error, _} ->
            %Part{text: ""}
        end

      Map.has_key?(part, :functionResponse) ->
        # functionResponse parts are stored as raw maps
        part

      true ->
        %Part{text: ""}
    end
  end

  @spec get_streaming_url_and_headers(stream_state(), auth_strategy(), [{String.t(), String.t()}]) ::
          {:ok, String.t(), [{String.t(), String.t()}]} | {:error, term()}
  defp get_streaming_url_and_headers(stream_state, auth_strategy, auth_headers) do
    # Get credentials for URL building (we need to get them again for the URL builder)
    with {:ok, credentials} <-
           MultiAuthCoordinator.get_credentials(auth_strategy, stream_state.config),
         base_url when is_binary(base_url) <- Auth.get_base_url(auth_strategy, credentials) do
      path =
        Auth.build_path(
          auth_strategy,
          stream_state.model,
          "streamGenerateContent",
          credentials
        )

      url = "#{base_url}/#{path}"
      {:ok, url, ensure_content_type_header(auth_headers)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp stream_request_with_auth(stream_state) do
    case MultiAuthCoordinator.coordinate_auth(stream_state.auth_strategy, stream_state.config) do
      {:ok, auth_strategy, headers} ->
        case get_streaming_url_and_headers(stream_state, auth_strategy, headers) do
          {:ok, url, final_headers} ->
            HTTPStreaming.stream_to_process(
              url,
              final_headers,
              stream_state.request_body,
              stream_state.stream_id,
              self()
            )

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "Auth failed: #{reason}"}
    end
  end

  defp handle_stream_start_result({:ok, stream_pid}, release_fn),
    do: {:ok, stream_pid, release_fn}

  defp handle_stream_start_result({:error, reason}, _release_fn), do: {:error, reason}
  defp handle_stream_start_result(other, release_fn), do: {:ok, other, release_fn}

  defp ensure_content_type_header(headers) do
    if List.keyfind(headers, "Content-Type", 0) do
      headers
    else
      [{"Content-Type", "application/json"} | headers]
    end
  end

  defp finalize_stream(stream_state, state, status) do
    stop_stream_process(stream_state.stream_pid)

    _ = release_stream_resources(stream_state, status)

    # Demonitor all subscribers (ignore if already removed)
    Enum.each(stream_state.subscribers, fn {_pid, ref} ->
      try do
        Process.demonitor(ref, [:flush])
      catch
        :error, :noproc -> :ok
      end
    end)

    %{state | streams: Map.delete(state.streams, stream_state.stream_id)}
  end

  defp release_stream_resources(stream_state, status, usage \\ nil) do
    case Map.get(stream_state, :release_fn) do
      nil ->
        stream_state

      release_fn ->
        release_fn.(status, usage)
        %{stream_state | release_fn: nil}
    end
  end

  @spec stop_stream_process(pid() | nil) :: :ok
  defp stop_stream_process(nil), do: :ok

  defp stop_stream_process(stream_pid) when is_pid(stream_pid) do
    if Process.alive?(stream_pid) do
      Process.exit(stream_pid, :shutdown)
    end

    :ok
  end

  @spec subscriber_already_exists?([subscriber_ref()], pid()) :: boolean()
  defp subscriber_already_exists?(subscribers, pid) do
    Enum.any?(subscribers, fn {subscriber_pid, _ref} -> subscriber_pid == pid end)
  end

  @spec remove_subscriber([subscriber_ref()], pid()) :: {[subscriber_ref()], [reference()]}
  defp remove_subscriber(subscribers, target_pid) do
    Enum.reduce(subscribers, {[], []}, fn {pid, ref} = subscriber, {keep, demonitor} ->
      if pid == target_pid do
        {keep, [ref | demonitor]}
      else
        {[subscriber | keep], demonitor}
      end
    end)
  end

  @spec remove_subscriber_by_ref([subscriber_ref()], pid(), reference()) ::
          {[subscriber_ref()], [reference()]}
  defp remove_subscriber_by_ref(subscribers, target_pid, target_ref) do
    Enum.reduce(subscribers, {[], []}, fn {pid, ref} = subscriber, {keep, demonitor} ->
      if pid == target_pid and ref == target_ref do
        {keep, [ref | demonitor]}
      else
        {[subscriber | keep], demonitor}
      end
    end)
  end
end
