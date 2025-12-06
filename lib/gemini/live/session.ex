defmodule Gemini.Live.Session do
  @moduledoc """
  GenServer for managing WebSocket connections to the Gemini Live API.

  The Live API provides bidirectional streaming communication with Gemini models,
  supporting real-time text, audio, and video interactions.

  ## Features

  - WebSocket-based real-time communication
  - Automatic reconnection with exponential backoff
  - Message queuing during connection setup
  - Callback-based event handling
  - Graceful connection lifecycle management

  ## Usage

      # Start a session
      {:ok, session} = LiveSession.start_link(
        model: "gemini-2.0-flash-exp",
        generation_config: %{temperature: 0.8},
        on_message: fn message -> IO.inspect(message, label: "Received") end
      )

      # Connect to the Live API
      :ok = LiveSession.connect(session)

      # Send a text message
      :ok = LiveSession.send(session, "Hello, how are you?")

      # Send client content with tools
      :ok = LiveSession.send_client_content(session, [
        %{role: "user", parts: [%{text: "What's the weather?"}]}
      ])

      # Send tool response
      :ok = LiveSession.send_tool_response(session, [
        %{name: "get_weather", response: %{temperature: 72, condition: "sunny"}}
      ])

      # Close the session
      :ok = LiveSession.close(session)

  ## Callbacks

  The session supports several callbacks for handling events:

  - `:on_message` - Called when a message is received from the server
  - `:on_connect` - Called when successfully connected
  - `:on_disconnect` - Called when disconnected
  - `:on_error` - Called when an error occurs

  ## Example with Callbacks

      LiveSession.start_link(
        model: "gemini-2.0-flash-exp",
        on_message: fn message ->
          case message do
            %{server_content: content} ->
              IO.puts("Model: \#{inspect(content)}")
            %{tool_call: calls} ->
              IO.puts("Function calls: \#{inspect(calls)}")
            _ ->
              IO.puts("Other: \#{inspect(message)}")
          end
        end,
        on_connect: fn -> IO.puts("Connected!") end,
        on_error: fn error -> IO.puts("Error: \#{inspect(error)}") end
      )
  """

  use GenServer
  require Logger

  alias Gemini.Live.Message
  alias Gemini.Live.Message.{ClientMessage, LiveClientSetup, ClientContent, ToolResponse}
  alias Gemini.Config
  alias Gemini.Auth.MultiAuthCoordinator

  @type session :: pid() | atom()
  @type message :: String.t() | map()
  @type callback :: (term() -> any())

  @default_reconnect_delay 1000
  @max_reconnect_delay 30_000
  @ping_interval 30_000

  defstruct [
    :conn_pid,
    :stream_ref,
    :model,
    :config,
    :auth_strategy,
    :websocket_url,
    :auth_headers,
    :on_message,
    :on_connect,
    :on_disconnect,
    :on_error,
    :message_queue,
    :reconnect_delay,
    :reconnect_timer,
    :ping_timer,
    :setup_sent,
    :setup_complete,
    status: :disconnected
  ]

  @type t :: %__MODULE__{
          conn_pid: pid() | nil,
          stream_ref: reference() | nil,
          model: String.t(),
          config: map(),
          auth_strategy: :gemini | :vertex_ai,
          websocket_url: String.t() | nil,
          auth_headers: [{String.t(), String.t()}] | nil,
          on_message: callback() | nil,
          on_connect: callback() | nil,
          on_disconnect: callback() | nil,
          on_error: callback() | nil,
          message_queue: [map()],
          reconnect_delay: non_neg_integer(),
          reconnect_timer: reference() | nil,
          ping_timer: reference() | nil,
          setup_sent: boolean(),
          setup_complete: boolean(),
          status: :disconnected | :connecting | :connected | :error
        }

  # Client API

  @doc """
  Start a Live API session.

  ## Options

  - `:model` - Model to use (required)
  - `:auth` - Authentication strategy (`:gemini` or `:vertex_ai`, auto-detected if not provided)
  - `:generation_config` - Generation configuration
  - `:system_instruction` - System instruction
  - `:tools` - Available tools/functions
  - `:tool_config` - Tool configuration
  - `:on_message` - Callback when message received
  - `:on_connect` - Callback when connected
  - `:on_disconnect` - Callback when disconnected
  - `:on_error` - Callback when error occurs
  - `:name` - Optional name for the GenServer

  ## Examples

      {:ok, session} = LiveSession.start_link(
        model: "gemini-2.0-flash-exp",
        on_message: &handle_message/1
      )
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  @doc """
  Connect to the Live API WebSocket endpoint.

  This must be called after start_link to establish the connection.

  ## Examples

      {:ok, session} = LiveSession.start_link(model: "gemini-2.0-flash-exp")
      :ok = LiveSession.connect(session)
  """
  @spec connect(session()) :: :ok | {:error, term()}
  def connect(session) do
    GenServer.call(session, :connect)
  end

  @doc """
  Send a text message to the model.

  ## Examples

      :ok = LiveSession.send(session, "What is the weather today?")
  """
  @spec send(session(), String.t()) :: :ok | {:error, term()}
  def send(session, text) when is_binary(text) do
    content = %ClientContent{
      turns: [%{role: "user", parts: [%{text: text}]}],
      turn_complete: true
    }

    send_client_content(session, content)
  end

  @doc """
  Send client content (turns) to the model.

  ## Parameters

  - `session` - Session PID or name
  - `turns` - List of content turns or ClientContent struct
  - `turn_complete` - Whether the turn is complete (default: true)

  ## Examples

      # Send simple content
      :ok = LiveSession.send_client_content(session, [
        %{role: "user", parts: [%{text: "Hello"}]}
      ])

      # Send ClientContent struct
      content = %ClientContent{
        turns: [...],
        turn_complete: true
      }
      :ok = LiveSession.send_client_content(session, content)
  """
  @spec send_client_content(session(), [map()] | ClientContent.t(), boolean()) ::
          :ok | {:error, term()}
  def send_client_content(session, turns, turn_complete \\ true)

  def send_client_content(session, %ClientContent{} = content, _turn_complete) do
    message = %ClientMessage{client_content: content}
    GenServer.call(session, {:send_message, message})
  end

  def send_client_content(session, turns, turn_complete) when is_list(turns) do
    content = %ClientContent{
      turns: turns,
      turn_complete: turn_complete
    }

    send_client_content(session, content)
  end

  @doc """
  Send real-time input (audio/video) to the model.

  ## Parameters

  - `session` - Session PID or name
  - `media_chunks` - List of media chunks
  - `opts` - Additional options

  ## Examples

      # Send audio chunk
      :ok = LiveSession.send_realtime_input(session, [
        %{data: audio_data, mime_type: "audio/pcm"}
      ])
  """
  @spec send_realtime_input(session(), [map()], keyword()) :: :ok | {:error, term()}
  def send_realtime_input(session, media_chunks, _opts \\ []) when is_list(media_chunks) do
    message = %ClientMessage{
      realtime_input: %Message.RealtimeInput{media_chunks: media_chunks}
    }

    GenServer.call(session, {:send_message, message})
  end

  @doc """
  Send tool/function response to the model.

  ## Parameters

  - `session` - Session PID or name
  - `function_responses` - List of function responses
  - `opts` - Additional options

  ## Examples

      :ok = LiveSession.send_tool_response(session, [
        %{
          name: "get_weather",
          response: %{temperature: 72, condition: "sunny"}
        }
      ])
  """
  @spec send_tool_response(session(), [map()], keyword()) :: :ok | {:error, term()}
  def send_tool_response(session, function_responses, _opts \\ [])
      when is_list(function_responses) do
    message = %ClientMessage{
      tool_response: %ToolResponse{function_responses: function_responses}
    }

    GenServer.call(session, {:send_message, message})
  end

  @doc """
  Close the Live API session.

  ## Examples

      :ok = LiveSession.close(session)
  """
  @spec close(session()) :: :ok
  def close(session) do
    GenServer.stop(session, :normal)
  end

  @doc """
  Get the current status of the session.

  Returns one of: `:disconnected`, `:connecting`, `:connected`, `:error`

  ## Examples

      status = LiveSession.status(session)
      # => :connected
  """
  @spec status(session()) :: atom()
  def status(session) do
    GenServer.call(session, :status)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    model = Keyword.fetch!(opts, :model)
    auth_strategy = Keyword.get(opts, :auth, Config.current_api_type())

    state = %__MODULE__{
      model: model,
      config: opts,
      auth_strategy: auth_strategy,
      on_message: Keyword.get(opts, :on_message),
      on_connect: Keyword.get(opts, :on_connect),
      on_disconnect: Keyword.get(opts, :on_disconnect),
      on_error: Keyword.get(opts, :on_error),
      message_queue: [],
      reconnect_delay: @default_reconnect_delay,
      setup_sent: false,
      setup_complete: false,
      status: :disconnected
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:connect, _from, state) do
    case do_connect(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, _reason} = error ->
        {:reply, error, %{state | status: :error}}
    end
  end

  @impl true
  def handle_call({:send_message, message}, _from, state) do
    case state.status do
      :connected when state.setup_complete ->
        case send_websocket_message(state, message) do
          :ok ->
            {:reply, :ok, state}

          {:error, reason} = error ->
            Logger.error("Failed to send message: #{inspect(reason)}")
            {:reply, error, state}
        end

      status when status in [:connecting, :connected] ->
        # Queue message until setup is complete
        new_state = %{state | message_queue: state.message_queue ++ [message]}
        {:reply, :ok, new_state}

      _ ->
        {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_info({:gun_up, conn_pid, _protocol}, %{conn_pid: conn_pid} = state) do
    Logger.debug("Gun connection established")
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:gun_upgrade, conn_pid, stream_ref, ["websocket"], _headers},
        %{conn_pid: conn_pid, stream_ref: stream_ref} = state
      ) do
    Logger.info("WebSocket upgrade successful")

    # Send setup message
    setup_message = build_setup_message(state)

    case send_websocket_message(state, setup_message) do
      :ok ->
        # Start ping timer
        ping_timer = Process.send_after(self(), :send_ping, @ping_interval)

        new_state = %{
          state
          | status: :connected,
            setup_sent: true,
            ping_timer: ping_timer
        }

        invoke_callback(state.on_connect, nil)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to send setup message: #{inspect(reason)}")
        invoke_callback(state.on_error, reason)
        {:noreply, schedule_reconnect(state)}
    end
  end

  @impl true
  def handle_info(
        {:gun_ws, conn_pid, stream_ref, {:text, text}},
        %{
          conn_pid: conn_pid,
          stream_ref: stream_ref
        } = state
      ) do
    case Message.from_json(text) do
      {:ok, message} ->
        handle_server_message(message, state)

      {:error, reason} ->
        Logger.error("Failed to parse WebSocket message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:gun_ws, conn_pid, stream_ref, {:close, code, reason}},
        %{
          conn_pid: conn_pid,
          stream_ref: stream_ref
        } = state
      ) do
    Logger.warning("WebSocket closed: code=#{code}, reason=#{inspect(reason)}")
    invoke_callback(state.on_disconnect, {code, reason})

    {:noreply, schedule_reconnect(state)}
  end

  @impl true
  def handle_info({:gun_down, conn_pid, _protocol, reason, _}, %{conn_pid: conn_pid} = state) do
    Logger.warning("Gun connection down: #{inspect(reason)}")
    invoke_callback(state.on_disconnect, reason)

    {:noreply, schedule_reconnect(state)}
  end

  @impl true
  def handle_info({:gun_error, conn_pid, reason}, %{conn_pid: conn_pid} = state) do
    Logger.error("Gun error: #{inspect(reason)}")
    invoke_callback(state.on_error, reason)

    {:noreply, schedule_reconnect(state)}
  end

  @impl true
  def handle_info(
        {:gun_error, conn_pid, stream_ref, reason},
        %{
          conn_pid: conn_pid,
          stream_ref: stream_ref
        } = state
      ) do
    Logger.error("Gun stream error: #{inspect(reason)}")
    invoke_callback(state.on_error, reason)

    {:noreply, state}
  end

  @impl true
  def handle_info(:send_ping, state) do
    if state.status == :connected do
      :gun.ws_send(state.conn_pid, state.stream_ref, :ping)
    end

    ping_timer = Process.send_after(self(), :send_ping, @ping_interval)
    {:noreply, %{state | ping_timer: ping_timer}}
  end

  @impl true
  def handle_info(:reconnect, state) do
    Logger.info("Attempting to reconnect...")

    case do_connect(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, schedule_reconnect(state)}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up timers
    if state.reconnect_timer, do: Process.cancel_timer(state.reconnect_timer)
    if state.ping_timer, do: Process.cancel_timer(state.ping_timer)

    # Close connection
    if state.conn_pid do
      :gun.close(state.conn_pid)
    end

    :ok
  end

  # Private Functions

  defp do_connect(state) do
    with {:ok, url, headers} <- build_websocket_url_and_headers(state),
         {:ok, conn_pid, stream_ref} <- connect_websocket(url, headers) do
      new_state = %{
        state
        | conn_pid: conn_pid,
          stream_ref: stream_ref,
          websocket_url: url,
          auth_headers: headers,
          status: :connecting,
          reconnect_delay: @default_reconnect_delay
      }

      {:ok, new_state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to connect: #{inspect(reason)}")
        invoke_callback(state.on_error, reason)
        error
    end
  end

  defp build_websocket_url_and_headers(state) do
    case MultiAuthCoordinator.coordinate_auth(state.auth_strategy, Enum.into(state.config, %{})) do
      {:ok, auth_strategy, headers} ->
        url = build_live_api_url(state.model, auth_strategy, state.config)
        {:ok, url, headers}

      {:error, reason} ->
        {:error, "Authentication failed: #{inspect(reason)}"}
    end
  end

  defp build_live_api_url(_model, :gemini, config) do
    api_key = Config.api_key() || Keyword.get(config, :api_key)

    "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=#{api_key}"
  end

  defp build_live_api_url(_model, :vertex_ai, config) do
    vertex_config = Config.get_auth_config(:vertex_ai)
    project_id = Keyword.get(config, :project_id) || Map.get(vertex_config, :project_id)

    location =
      Keyword.get(config, :location, "us-central1") ||
        Map.get(vertex_config, :location, "us-central1")

    "wss://#{location}-aiplatform.googleapis.com/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent?project=#{project_id}&location=#{location}"
  end

  defp connect_websocket(url, headers) do
    uri = URI.parse(url)
    port = uri.port || 443
    host = String.to_charlist(uri.host)

    # Build path with query string
    path =
      if uri.query do
        "#{uri.path}?#{uri.query}"
      else
        uri.path
      end

    # Convert headers to gun format
    gun_headers =
      Enum.map(headers, fn {k, v} ->
        {String.to_charlist(k), String.to_charlist(v)}
      end)

    with {:ok, conn_pid} <- :gun.open(host, port, %{protocols: [:http], transport: :tls}),
         {:ok, _protocol} <- :gun.await_up(conn_pid),
         stream_ref <- :gun.ws_upgrade(conn_pid, path, gun_headers) do
      {:ok, conn_pid, stream_ref}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_setup_message(state) do
    setup = %LiveClientSetup{
      model: state.model,
      generation_config: Keyword.get(state.config, :generation_config),
      system_instruction: Keyword.get(state.config, :system_instruction),
      tools: Keyword.get(state.config, :tools),
      tool_config: Keyword.get(state.config, :tool_config)
    }

    %ClientMessage{setup: setup}
  end

  defp send_websocket_message(state, %ClientMessage{} = message) do
    case Message.to_json(message) do
      {:ok, json} ->
        :gun.ws_send(state.conn_pid, state.stream_ref, {:text, json})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_server_message(message, state) do
    # Invoke callback
    invoke_callback(state.on_message, message)

    # Handle specific message types
    new_state =
      cond do
        message.setup_complete ->
          Logger.info("Setup complete")
          # Flush queued messages
          flush_message_queue(%{state | setup_complete: true})

        message.server_content ->
          state

        message.tool_call ->
          state

        message.tool_call_cancellation ->
          state

        true ->
          state
      end

    {:noreply, new_state}
  end

  defp flush_message_queue(state) do
    Enum.each(state.message_queue, fn message ->
      send_websocket_message(state, message)
    end)

    %{state | message_queue: []}
  end

  defp schedule_reconnect(state) do
    # Cancel existing timer if any
    if state.reconnect_timer do
      Process.cancel_timer(state.reconnect_timer)
    end

    # Cancel ping timer
    if state.ping_timer do
      Process.cancel_timer(state.ping_timer)
    end

    # Close existing connection
    if state.conn_pid do
      :gun.close(state.conn_pid)
    end

    # Calculate next delay with exponential backoff
    next_delay = min(state.reconnect_delay * 2, @max_reconnect_delay)

    # Schedule reconnect
    timer = Process.send_after(self(), :reconnect, state.reconnect_delay)

    %{
      state
      | status: :disconnected,
        conn_pid: nil,
        stream_ref: nil,
        setup_sent: false,
        setup_complete: false,
        reconnect_timer: timer,
        reconnect_delay: next_delay,
        ping_timer: nil
    }
  end

  defp invoke_callback(nil, _arg), do: :ok

  defp invoke_callback(callback, _arg) when is_function(callback, 0) do
    try do
      callback.()
    rescue
      e -> Logger.error("Callback error: #{inspect(e)}")
    end
  end

  defp invoke_callback(callback, arg) when is_function(callback, 1) do
    try do
      callback.(arg)
    rescue
      e -> Logger.error("Callback error: #{inspect(e)}")
    end
  end
end
