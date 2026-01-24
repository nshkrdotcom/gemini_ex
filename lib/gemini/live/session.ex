defmodule Gemini.Live.Session do
  @moduledoc """
  GenServer managing a Live API WebSocket session.

  Provides a high-level interface for real-time bidirectional communication
  with Gemini models for voice, video, and text interactions.

  ## Usage

      # Start a session
      {:ok, pid} = Session.start_link(
        model: "gemini-2.5-flash-native-audio-preview-12-2025",
        auth: :gemini,
        on_message: fn msg -> IO.inspect(msg) end,
        on_error: fn err -> Logger.error(inspect(err)) end
      )

      # Connect to the Live API
      :ok = Session.connect(pid)

      # Send text content
      :ok = Session.send_client_content(pid, "Hello!")

      # Send realtime audio
      :ok = Session.send_realtime_input(pid, audio: audio_blob)

      # Close when done
      :ok = Session.close(pid)

  ## Callbacks

  - `on_message` - Called for each server message
  - `on_error` - Called on errors
  - `on_close` - Called when session closes
  - `on_tool_call` - Called when model requests tool execution (may return tool responses)
  - `on_transcription` - Called for audio transcriptions
  - `on_voice_activity` - Called for voice activity signals

  ## Session State

  The session tracks:
  - Connection status
  - Setup completion
  - Active tool calls
  - Session resumption handle
  - Usage metadata

  ## Audio Format

  - **Input:** 16-bit PCM, 16kHz, mono
  - **Output:** 16-bit PCM, 24kHz, mono
  """

  use GenServer
  require Logger

  alias Gemini.Client.WebSocket
  alias Gemini.Config
  alias Gemini.Telemetry
  alias Gemini.Types.Live.{ServerMessage, Setup, SetupComplete, ToolCall}

  @type session_status :: :disconnected | :connecting | :setup_pending | :ready | :closing

  @type callback :: (term() -> any())
  @type tool_response :: map()
  @type tool_responses :: [tool_response()]
  @type tool_call_callback_result ::
          :ok
          | {:tool_response, tool_responses()}
          | {:send_tool_response, tool_responses()}
          | tool_responses()
  @type tool_call_callback :: (ToolCall.t() -> tool_call_callback_result())

  @type state :: %{
          websocket: WebSocket.t() | term() | nil,
          websocket_module: module(),
          websocket_opts: keyword(),
          status: session_status(),
          config: map(),
          callbacks: map(),
          pending_setup: Setup.t() | nil,
          session_handle: String.t() | nil,
          usage_metadata: map() | nil,
          owner: pid()
        }

  # Client API

  @doc """
  Starts a new Live session process.

  ## Options

  - `:model` - Required. Model name (e.g., "gemini-2.5-flash-native-audio-preview-12-2025")
  - `:auth` - Auth strategy (`:gemini` or `:vertex_ai`, default: auto-detect)
  - `:project_id` - Required for Vertex AI
  - `:location` - Vertex AI location (default: "us-central1")
  - `:api_version` - Live API version (default: "v1beta")
  - `:generation_config` - Generation configuration
  - `:system_instruction` - System instruction content
  - `:tools` - Tool declarations
  - `:proactivity` - Proactivity configuration (v1alpha)
  - `:enable_affective_dialog` - Enable affective dialog (v1alpha)
  - `:realtime_input_config` - Realtime input configuration
  - `:on_message` - Callback for server messages
  - `:on_error` - Callback for errors
  - `:on_close` - Callback for session close
  - `:on_tool_call` - Callback for tool call requests (may return tool responses)
    - Return `{:tool_response, responses}` or a list of responses to send automatically
  - `:on_tool_call_cancellation` - Callback for tool call cancellation
  - `:on_transcription` - Callback for transcriptions
  - `:on_voice_activity` - Callback for voice activity signals
  - `:on_session_resumption` - Callback for session resumption updates
  - `:on_go_away` - Callback for GoAway notices (impending disconnection)
  - `:session_resumption` - Enable session resumption
  - `:resume_handle` - Handle from previous session to resume
  - `:context_window_compression` - Enable context compression
  - `:websocket_module` - Advanced: override WebSocket client module (useful for testing)
  - `:websocket_opts` - Advanced: extra options passed to WebSocket.connect/2

  ## Returns

  - `{:ok, pid}` - Session started
  - `{:error, reason}` - Start failed

  ## Examples

      {:ok, session} = Session.start_link(
        model: "gemini-2.5-flash-native-audio-preview-12-2025",
        auth: :gemini,
        generation_config: %{response_modalities: ["TEXT"]},
        on_message: fn msg -> IO.inspect(msg) end
      )
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Connects to the Live API and sends setup configuration.

  Must be called after `start_link/1` to establish the WebSocket connection.
  Waits for the setup_complete response before returning.

  ## Returns

  - `:ok` - Connected and setup complete
  - `{:error, reason}` - Connection failed
  """
  @spec connect(GenServer.server()) :: :ok | {:error, term()}
  def connect(session) do
    GenServer.call(session, :connect, 30_000)
  end

  @doc """
  Sends client content (text turns) to the model.

  ## Parameters

  - `session` - Session PID
  - `content` - String or list of turn maps
  - `opts` - Options:
    - `:turn_complete` - Whether this completes the turn (default: true)

  ## Returns

  - `:ok` - Content sent
  - `{:error, reason}` - Send failed

  ## Examples

      # Simple text
      Session.send_client_content(pid, "What is 2+2?")

      # With turn control
      Session.send_client_content(pid, "Part 1", turn_complete: false)
      Session.send_client_content(pid, "Part 2", turn_complete: true)

      # Multi-turn context
      Session.send_client_content(pid, [
        %{role: "user", parts: [%{text: "Hello"}]},
        %{role: "model", parts: [%{text: "Hi!"}]},
        %{role: "user", parts: [%{text: "How are you?"}]}
      ])
  """
  @spec send_client_content(GenServer.server(), String.t() | list(), keyword()) ::
          :ok | {:error, term()}
  def send_client_content(session, content, opts \\ []) do
    GenServer.call(session, {:send_client_content, content, opts})
  end

  @doc """
  Sends realtime input (audio, video, text) to the model.

  ## Parameters

  - `session` - Session PID
  - `opts` - Input options:
    - `:audio` - Audio blob (16-bit PCM, 16kHz mono)
    - `:video` - Video blob
    - `:text` - Text string
    - `:activity_start` - Signal start of user activity
    - `:activity_end` - Signal end of user activity
    - `:audio_stream_end` - Signal audio stream ended

  ## Returns

  - `:ok` - Input sent
  - `{:error, reason}` - Send failed

  ## Examples

      # Send audio chunk
      Session.send_realtime_input(pid, audio: %{data: pcm_data, mime_type: "audio/pcm;rate=16000"})

      # Signal manual activity
      Session.send_realtime_input(pid, activity_start: true)
      Session.send_realtime_input(pid, audio: audio_chunk)
      Session.send_realtime_input(pid, activity_end: true)
  """
  @spec send_realtime_input(GenServer.server(), keyword()) :: :ok | {:error, term()}
  def send_realtime_input(session, opts) do
    GenServer.call(session, {:send_realtime_input, opts})
  end

  @doc """
  Sends tool/function responses to the model.

  ## Parameters

  - `session` - Session PID
  - `responses` - List of function response maps with `:id`, `:name`, and `:response` keys

  ## Returns

  - `:ok` - Response sent
  - `{:error, reason}` - Send failed

  ## Example

      Session.send_tool_response(pid, [
        %{id: "call_123", name: "get_weather", response: %{temp: 72}}
      ])
  """
  @spec send_tool_response(GenServer.server(), list()) :: :ok | {:error, term()}
  def send_tool_response(session, responses) do
    if session == self() or resolve_session_pid(session) == self() do
      GenServer.cast(session, {:send_tool_response, responses})
      :ok
    else
      GenServer.call(session, {:send_tool_response, responses})
    end
  end

  @doc """
  Closes the session gracefully.

  ## Returns

  - `:ok` - Session closed
  """
  @spec close(GenServer.server()) :: :ok
  def close(session) do
    GenServer.call(session, :close)
  end

  @doc """
  Returns the current session status.

  ## Status Values

  - `:disconnected` - Not connected
  - `:connecting` - Connection in progress
  - `:setup_pending` - Connected, waiting for setup_complete
  - `:ready` - Connected and ready for messages
  - `:closing` - Received GoAway, closing soon
  """
  @spec status(GenServer.server()) :: session_status()
  def status(session) do
    GenServer.call(session, :status)
  end

  @doc """
  Returns the session resumption handle (if available).

  The handle can be used to resume a session after disconnection.
  Only available if session_resumption was enabled and the server
  has provided a handle.
  """
  @spec get_session_handle(GenServer.server()) :: String.t() | nil
  def get_session_handle(session) do
    GenServer.call(session, :get_session_handle)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    model = Keyword.fetch!(opts, :model)
    auth = Keyword.get(opts, :auth, detect_auth_strategy())

    state = %{
      websocket: nil,
      status: :disconnected,
      config: %{
        model: model,
        auth: auth,
        project_id: Keyword.get(opts, :project_id),
        location: Keyword.get(opts, :location, "us-central1"),
        generation_config: Keyword.get(opts, :generation_config),
        system_instruction: Keyword.get(opts, :system_instruction),
        tools: Keyword.get(opts, :tools),
        proactivity: Keyword.get(opts, :proactivity),
        enable_affective_dialog: Keyword.get(opts, :enable_affective_dialog),
        realtime_input_config: Keyword.get(opts, :realtime_input_config),
        session_resumption: Keyword.get(opts, :session_resumption),
        context_window_compression: Keyword.get(opts, :context_window_compression),
        input_audio_transcription: Keyword.get(opts, :input_audio_transcription),
        output_audio_transcription: Keyword.get(opts, :output_audio_transcription),
        api_version: Keyword.get(opts, :api_version, "v1beta")
      },
      callbacks: %{
        on_message: Keyword.get(opts, :on_message, &default_callback/1),
        on_error: Keyword.get(opts, :on_error, &default_callback/1),
        on_close: Keyword.get(opts, :on_close, &default_callback/1),
        on_tool_call: Keyword.get(opts, :on_tool_call),
        on_tool_call_cancellation: Keyword.get(opts, :on_tool_call_cancellation),
        on_transcription: Keyword.get(opts, :on_transcription),
        on_voice_activity: Keyword.get(opts, :on_voice_activity),
        on_session_resumption: Keyword.get(opts, :on_session_resumption),
        on_go_away: Keyword.get(opts, :on_go_away)
      },
      pending_setup: nil,
      session_handle: Keyword.get(opts, :resume_handle),
      usage_metadata: nil,
      websocket_module: Keyword.get(opts, :websocket_module, WebSocket),
      websocket_opts: Keyword.get(opts, :websocket_opts, []),
      owner: self()
    }

    emit_telemetry_init(model, auth)
    {:ok, state}
  end

  @impl true
  def handle_call(:connect, _from, %{status: :disconnected} = state) do
    case do_connect(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        emit_telemetry_error(reason)
        invoke_callback(state.callbacks.on_error, reason)
        {:reply, error, state}
    end
  end

  def handle_call(:connect, _from, state) do
    {:reply, {:error, {:already_connected, state.status}}, state}
  end

  def handle_call({:send_client_content, content, opts}, _from, %{status: :ready} = state) do
    message = build_client_content_message(content, opts)

    case state.websocket_module.send(state.websocket, message) do
      :ok ->
        emit_telemetry_message_sent(:client_content, %{model: state.config.model})
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:send_client_content, _, _}, _from, state) do
    {:reply, {:error, {:not_ready, state.status}}, state}
  end

  def handle_call({:send_realtime_input, opts}, _from, %{status: :ready} = state) do
    message = build_realtime_input_message(opts)

    case state.websocket_module.send(state.websocket, message) do
      :ok ->
        emit_telemetry_message_sent(:realtime_input, %{model: state.config.model})
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:send_realtime_input, _}, _from, state) do
    {:reply, {:error, {:not_ready, state.status}}, state}
  end

  def handle_call({:send_tool_response, responses}, _from, state) do
    case do_send_tool_response(state, responses) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call(:close, _from, state) do
    emit_telemetry_close(:user_requested)
    new_state = do_close(state)
    {:reply, :ok, new_state}
  end

  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  def handle_call(:get_session_handle, _from, state) do
    {:reply, state.session_handle, state}
  end

  @impl true
  def handle_cast({:send_tool_response, responses}, state) do
    _ = do_send_tool_response(state, responses)
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, _pid, _ref, {:text, data}}, state) do
    handle_websocket_data(data, state)
  end

  # Live API sends binary frames containing JSON
  def handle_info({:gun_ws, _pid, _ref, {:binary, data}}, state) do
    handle_websocket_data(data, state)
  end

  def handle_info({:gun_ws, _pid, _ref, {:close, code, reason}}, state) do
    Logger.info("Live API WebSocket closed: #{code} - #{reason}")
    emit_telemetry_close(:server_closed)
    invoke_callback(state.callbacks.on_close, {code, reason})
    {:noreply, %{state | status: :disconnected, websocket: nil}}
  end

  def handle_info({:gun_down, _pid, protocol, reason, _}, state)
      when protocol in [:http, :http2] do
    Logger.warning("Live API connection down: #{inspect(reason)}")
    emit_telemetry_error({:connection_down, reason})
    invoke_callback(state.callbacks.on_error, {:connection_down, reason})
    {:noreply, %{state | status: :disconnected}}
  end

  def handle_info(msg, state) do
    Logger.debug("Unhandled Live API message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Helper to handle WebSocket data (text or binary frames)
  defp handle_websocket_data(data, state) do
    case Jason.decode(data) do
      {:ok, message} ->
        new_state = handle_server_message(message, state)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to decode Live API message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    do_close(state)
    :ok
  end

  # Private Functions

  @spec do_connect(state()) :: {:ok, state()} | {:error, term()}
  defp do_connect(state) do
    base_opts = [
      model: state.config.model,
      project_id: state.config.project_id,
      location: state.config.location
    ]

    base_opts =
      if state.config.api_version do
        Keyword.put(base_opts, :api_version, state.config.api_version)
      else
        base_opts
      end

    ws_opts = Keyword.merge(state.websocket_opts, base_opts)

    websocket_module = state.websocket_module

    with {:ok, websocket} <- websocket_module.connect(state.config.auth, ws_opts),
         setup <- build_setup(state.config, state.session_handle),
         :ok <- send_setup(websocket_module, websocket, setup),
         {:ok, updated_state} <-
           wait_for_setup_complete(websocket_module, %{state | websocket: websocket}) do
      emit_telemetry_ready(state.config.model)
      {:ok, updated_state}
    end
  end

  @spec do_close(state()) :: state()
  defp do_close(%{websocket: nil} = state), do: %{state | status: :disconnected}

  defp do_close(%{websocket: ws} = state) do
    state.websocket_module.close(ws)
    %{state | websocket: nil, status: :disconnected}
  end

  @spec send_setup(module(), WebSocket.t() | term(), Setup.t()) :: :ok | {:error, term()}
  defp send_setup(websocket_module, websocket, setup) do
    message = %{"setup" => Setup.to_api(setup)}
    websocket_module.send(websocket, message)
  end

  @spec do_send_tool_response(state(), list()) :: :ok | {:error, term()}
  defp do_send_tool_response(%{status: :ready, websocket: websocket} = state, responses)
       when is_list(responses) and not is_nil(websocket) do
    message = %{
      "toolResponse" => %{
        "functionResponses" => Enum.map(responses, &format_function_response/1)
      }
    }

    case state.websocket_module.send(websocket, message) do
      :ok ->
        emit_telemetry_message_sent(:tool_response, %{
          model: state.config.model,
          response_count: length(responses)
        })

        :ok

      error ->
        error
    end
  end

  defp do_send_tool_response(state, _responses) do
    {:error, {:not_ready, state.status}}
  end

  @spec wait_for_setup_complete(module(), state()) :: {:ok, state()} | {:error, term()}
  defp wait_for_setup_complete(websocket_module, state) do
    state = %{state | status: :setup_pending}

    # Wait for setup_complete message with a timeout
    case websocket_module.receive(state.websocket, 30_000) do
      {:ok, %{"setupComplete" => _} = setup_complete_msg} ->
        # Use handle_server_message to properly invoke callbacks
        new_state = handle_server_message(setup_complete_msg, state)
        {:ok, new_state}

      {:ok, other_message} ->
        # Handle other messages while waiting for setup_complete
        new_state = handle_server_message(other_message, state)

        if new_state.status == :ready do
          {:ok, new_state}
        else
          wait_for_setup_complete(websocket_module, new_state)
        end

      {:error, reason} ->
        {:error, {:setup_failed, reason}}
    end
  end

  @spec build_setup(map(), String.t() | nil) :: Setup.t()
  defp build_setup(config, resume_handle) do
    # Build session resumption config with the resume handle if provided
    session_resumption = build_session_resumption_config(config.session_resumption, resume_handle)

    Setup.new(
      config.model,
      generation_config: config.generation_config,
      system_instruction: config.system_instruction,
      tools: config.tools,
      proactivity: config.proactivity,
      enable_affective_dialog: config.enable_affective_dialog,
      realtime_input_config: config.realtime_input_config,
      session_resumption: session_resumption,
      context_window_compression: config.context_window_compression,
      input_audio_transcription: config.input_audio_transcription,
      output_audio_transcription: config.output_audio_transcription
    )
  end

  # Build session resumption config, merging the resume handle if provided
  @spec build_session_resumption_config(map() | nil, String.t() | nil) :: map() | nil
  defp build_session_resumption_config(nil, nil), do: nil
  defp build_session_resumption_config(nil, handle) when is_binary(handle), do: %{handle: handle}

  defp build_session_resumption_config(config, nil) when is_map(config), do: config

  defp build_session_resumption_config(config, handle)
       when is_map(config) and is_binary(handle) do
    Map.put(config, :handle, handle)
  end

  @spec handle_server_message(map(), state()) :: state()
  defp handle_server_message(%{"setupComplete" => _}, state) do
    Logger.debug("Received setupComplete")
    emit_telemetry_message_received(:setup_complete, %{model: state.config.model})
    parsed = ServerMessage.new(setup_complete: %SetupComplete{})
    invoke_callback(state.callbacks.on_message, parsed)
    %{state | status: :ready}
  end

  defp handle_server_message(%{"serverContent" => content} = msg, state) do
    parsed = ServerMessage.from_api(msg)
    emit_telemetry_message_received(:server_content, %{model: state.config.model})
    invoke_callback(state.callbacks.on_message, parsed)

    # Handle transcriptions
    handle_transcription(content, state)

    # Update usage metadata
    usage = msg["usageMetadata"]
    %{state | usage_metadata: usage || state.usage_metadata}
  end

  defp handle_server_message(%{"toolCall" => _tool_call} = msg, state) do
    parsed = ServerMessage.from_api(msg)
    emit_telemetry_message_received(:tool_call, %{model: state.config.model})
    invoke_callback(state.callbacks.on_message, parsed)

    # Invoke specific tool call callback with parsed ToolCall struct
    if state.callbacks.on_tool_call && parsed.tool_call do
      # Emit telemetry for each function call
      Enum.each(parsed.tool_call.function_calls || [], fn call ->
        emit_telemetry_tool_call(call.id || "unknown", call.name || "unknown")
      end)

      state.callbacks.on_tool_call
      |> invoke_callback_result(parsed.tool_call)
      |> maybe_send_tool_response_from_callback(state)
    end

    state
  end

  defp handle_server_message(%{"toolCallCancellation" => cancellation} = msg, state) do
    parsed = ServerMessage.from_api(msg)
    invoke_callback(state.callbacks.on_message, parsed)

    cancelled_ids = cancellation["ids"] || []
    Logger.warning("Tool calls cancelled: #{inspect(cancelled_ids)}")

    # Invoke specific tool call cancellation callback
    if state.callbacks.on_tool_call_cancellation do
      invoke_callback(state.callbacks.on_tool_call_cancellation, cancelled_ids)
    end

    state
  end

  defp handle_server_message(%{"goAway" => go_away} = msg, state) do
    time_left_ms = parse_time_left(go_away["timeLeft"])

    Logger.warning("GoAway received, #{time_left_ms || "unknown"} ms remaining")
    emit_telemetry_go_away(time_left_ms)
    emit_telemetry_message_received(:go_away, %{model: state.config.model})

    parsed = ServerMessage.from_api(msg)
    invoke_callback(state.callbacks.on_message, parsed)

    # Invoke specific GoAway callback with useful info
    if state.callbacks.on_go_away do
      invoke_callback(state.callbacks.on_go_away, %{
        time_left_ms: time_left_ms,
        handle: state.session_handle
      })
    end

    %{state | status: :closing}
  end

  defp handle_server_message(%{"sessionResumptionUpdate" => update}, state) do
    handle = update["newHandle"]
    resumable = update["resumable"] == true

    Logger.debug("Session resumption update: resumable=#{resumable}, handle=#{handle != nil}")

    # Invoke specific session resumption callback
    if resumable && handle && state.callbacks.on_session_resumption do
      invoke_callback(state.callbacks.on_session_resumption, %{
        handle: handle,
        resumable: true
      })
    end

    %{state | session_handle: handle}
  end

  defp handle_server_message(%{"voiceActivity" => activity} = msg, state) do
    parsed = ServerMessage.from_api(msg)
    invoke_callback(state.callbacks.on_message, parsed)

    if state.callbacks.on_voice_activity do
      invoke_callback(state.callbacks.on_voice_activity, activity)
    end

    state
  end

  defp handle_server_message(msg, state) do
    # Generic handling for any other message
    parsed = ServerMessage.from_api(msg)
    invoke_callback(state.callbacks.on_message, parsed)
    state
  end

  @spec handle_transcription(map(), state()) :: :ok
  defp handle_transcription(content, state) do
    input_trans = content["inputTranscription"]
    output_trans = content["outputTranscription"]

    if input_trans && state.callbacks.on_transcription do
      invoke_callback(state.callbacks.on_transcription, {:input, input_trans})
    end

    if output_trans && state.callbacks.on_transcription do
      invoke_callback(state.callbacks.on_transcription, {:output, output_trans})
    end

    :ok
  end

  @spec build_client_content_message(String.t() | list(), keyword()) :: map()
  defp build_client_content_message(content, opts) when is_binary(content) do
    turn_complete = Keyword.get(opts, :turn_complete, true)

    %{
      "clientContent" => %{
        "turns" => [%{"role" => "user", "parts" => [%{"text" => content}]}],
        "turnComplete" => turn_complete
      }
    }
  end

  defp build_client_content_message(turns, opts) when is_list(turns) do
    turn_complete = Keyword.get(opts, :turn_complete, true)

    # Convert turns to API format if they have atom keys
    formatted_turns = Enum.map(turns, &format_turn/1)

    %{
      "clientContent" => %{
        "turns" => formatted_turns,
        "turnComplete" => turn_complete
      }
    }
  end

  @spec format_turn(map()) :: map()
  defp format_turn(%{role: role, parts: parts}) do
    %{
      "role" => to_string(role),
      "parts" => Enum.map(parts, &format_part/1)
    }
  end

  defp format_turn(%{"role" => _, "parts" => _} = turn), do: turn
  defp format_turn(turn), do: turn

  @spec format_part(map()) :: map()
  defp format_part(%{text: text}), do: %{"text" => text}
  defp format_part(%{"text" => _} = part), do: part
  defp format_part(part), do: part

  @spec build_realtime_input_message(keyword()) :: map()
  defp build_realtime_input_message(opts) do
    input = %{}

    input =
      if audio = Keyword.get(opts, :audio) do
        Map.put(input, "audio", format_blob(audio))
      else
        input
      end

    input =
      if video = Keyword.get(opts, :video) do
        Map.put(input, "video", format_blob(video))
      else
        input
      end

    input =
      if text = Keyword.get(opts, :text) do
        Map.put(input, "text", text)
      else
        input
      end

    input =
      if Keyword.get(opts, :activity_start) do
        Map.put(input, "activityStart", %{})
      else
        input
      end

    input =
      if Keyword.get(opts, :activity_end) do
        Map.put(input, "activityEnd", %{})
      else
        input
      end

    input =
      if Keyword.get(opts, :audio_stream_end) do
        Map.put(input, "audioStreamEnd", true)
      else
        input
      end

    %{"realtimeInput" => input}
  end

  @spec format_blob(map()) :: map()
  defp format_blob(%{data: data, mime_type: mime_type}) do
    encoded = if is_binary(data), do: Base.encode64(data), else: data
    %{"data" => encoded, "mimeType" => mime_type}
  end

  defp format_blob(%{"data" => _, "mimeType" => _} = blob), do: blob
  defp format_blob(blob) when is_map(blob), do: blob

  @spec format_function_response(map()) :: map()
  defp format_function_response(%{id: id, name: name, response: response} = func_resp) do
    base = %{"id" => id, "name" => name, "response" => response}

    # Support for async function calling with scheduling
    scheduling = Map.get(func_resp, :scheduling)

    if scheduling do
      Map.put(base, "scheduling", scheduling_to_api(scheduling))
    else
      base
    end
  end

  defp format_function_response(%{"id" => _, "name" => _, "response" => _} = response),
    do: response

  defp format_function_response(response) when is_map(response), do: response

  # Convert scheduling option to API format
  @spec scheduling_to_api(atom() | String.t()) :: String.t()
  defp scheduling_to_api(:interrupt), do: "INTERRUPT"
  defp scheduling_to_api(:when_idle), do: "WHEN_IDLE"
  defp scheduling_to_api(:silent), do: "SILENT"
  defp scheduling_to_api(s) when is_binary(s), do: s

  # Parse duration string from GoAway timeLeft field (e.g., "30s" -> 30000ms)
  @spec parse_time_left(String.t() | nil) :: non_neg_integer() | nil
  defp parse_time_left(nil), do: nil

  defp parse_time_left(duration) when is_binary(duration) do
    # Handle duration format like "30s" or "30.5s"
    trimmed = String.trim_trailing(duration, "s")

    case Float.parse(trimmed) do
      {seconds, _} -> round(seconds * 1000)
      :error -> nil
    end
  end

  defp parse_time_left(_), do: nil

  @spec invoke_callback(callback() | nil, term()) :: :ok
  defp invoke_callback(nil, _arg), do: :ok

  defp invoke_callback(callback, arg) when is_function(callback, 1) do
    callback.(arg)
    :ok
  rescue
    e ->
      Logger.error("Live session callback error: #{inspect(e)}")
      :ok
  catch
    :exit, reason ->
      Logger.error("Live session callback exit: #{inspect(reason)}")
      :ok
  end

  @spec invoke_callback_result(tool_call_callback() | nil, term()) ::
          {:ok, term()} | {:error, term()}
  defp invoke_callback_result(nil, _arg), do: {:ok, nil}

  defp invoke_callback_result(callback, arg) when is_function(callback, 1) do
    {:ok, callback.(arg)}
  rescue
    e ->
      Logger.error("Live session callback error: #{inspect(e)}")
      {:error, e}
  catch
    :exit, reason ->
      Logger.error("Live session callback exit: #{inspect(reason)}")
      {:error, reason}
  end

  @spec maybe_send_tool_response_from_callback({:ok, term()} | {:error, term()}, state()) :: :ok
  defp maybe_send_tool_response_from_callback({:ok, result}, state) do
    case normalize_tool_responses(result) do
      {:ok, responses} -> _ = do_send_tool_response(state, responses)
      :ignore -> :ok
    end

    :ok
  end

  defp maybe_send_tool_response_from_callback({:error, _reason}, _state), do: :ok

  @spec normalize_tool_responses(term()) :: {:ok, tool_responses()} | :ignore
  defp normalize_tool_responses({:tool_response, responses}) when is_list(responses),
    do: {:ok, responses}

  defp normalize_tool_responses({:send_tool_response, responses}) when is_list(responses),
    do: {:ok, responses}

  defp normalize_tool_responses(responses) when is_list(responses),
    do: {:ok, responses}

  defp normalize_tool_responses(_), do: :ignore

  @spec resolve_session_pid(GenServer.server()) :: pid() | nil
  defp resolve_session_pid(pid) when is_pid(pid), do: pid
  defp resolve_session_pid(name) when is_atom(name), do: Process.whereis(name)
  defp resolve_session_pid(_), do: nil

  @spec default_callback(term()) :: :ok
  defp default_callback(_), do: :ok

  @spec detect_auth_strategy() :: :gemini | :vertex_ai
  defp detect_auth_strategy do
    cond do
      Config.api_key() -> :gemini
      Config.get_auth_config(:vertex_ai)[:project_id] -> :vertex_ai
      true -> :gemini
    end
  end

  # Telemetry Functions

  @spec emit_telemetry_init(String.t(), atom()) :: :ok
  defp emit_telemetry_init(model, auth) do
    Telemetry.execute(
      [:gemini, :live, :session, :init],
      %{system_time: System.system_time()},
      %{model: model, auth: auth}
    )
  end

  @spec emit_telemetry_ready(String.t()) :: :ok
  defp emit_telemetry_ready(model) do
    Telemetry.execute(
      [:gemini, :live, :session, :ready],
      %{system_time: System.system_time()},
      %{model: model}
    )
  end

  @spec emit_telemetry_message_received(atom(), map()) :: :ok
  defp emit_telemetry_message_received(message_type, metadata) do
    Telemetry.execute(
      [:gemini, :live, :session, :message, :received],
      %{system_time: System.system_time()},
      Map.merge(%{message_type: message_type}, metadata)
    )
  end

  @spec emit_telemetry_message_sent(atom(), map()) :: :ok
  defp emit_telemetry_message_sent(message_type, metadata) do
    Telemetry.execute(
      [:gemini, :live, :session, :message, :sent],
      %{system_time: System.system_time()},
      Map.merge(%{message_type: message_type}, metadata)
    )
  end

  @spec emit_telemetry_tool_call(String.t(), String.t()) :: :ok
  defp emit_telemetry_tool_call(call_id, function_name) do
    Telemetry.execute(
      [:gemini, :live, :session, :tool_call],
      %{system_time: System.system_time()},
      %{call_id: call_id, function_name: function_name}
    )
  end

  @spec emit_telemetry_close(atom()) :: :ok
  defp emit_telemetry_close(reason) do
    Telemetry.execute(
      [:gemini, :live, :session, :close],
      %{system_time: System.system_time()},
      %{reason: reason}
    )
  end

  @spec emit_telemetry_error(term()) :: :ok
  defp emit_telemetry_error(error) do
    Telemetry.execute(
      [:gemini, :live, :session, :error],
      %{system_time: System.system_time()},
      %{error: error}
    )
  end

  @spec emit_telemetry_go_away(non_neg_integer() | nil) :: :ok
  defp emit_telemetry_go_away(time_left_ms) do
    Telemetry.execute(
      [:gemini, :live, :session, :go_away],
      %{system_time: System.system_time(), time_left_ms: time_left_ms},
      %{}
    )
  end
end
