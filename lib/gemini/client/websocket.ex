defmodule Gemini.Client.WebSocket do
  @moduledoc """
  WebSocket client for Gemini Live API using :gun.

  This module provides low-level WebSocket connectivity with:
  - TLS/HTTP2 connection management
  - Automatic reconnection handling with configurable retry logic
  - Message framing and parsing
  - Auth strategy integration (Gemini API / Vertex AI)
  - Comprehensive telemetry integration

  ## Usage

  Typically used through `Gemini.Live.Session` rather than directly.

      {:ok, conn} = WebSocket.connect(:gemini, model: "gemini-2.5-flash")
      :ok = WebSocket.send(conn, %{setup: setup_config})
      {:ok, message} = WebSocket.receive(conn)
      :ok = WebSocket.close(conn)

  ## Connection Options

  - `:model` - Required. Model name for the Live API
  - `:project_id` - Required for Vertex AI
  - `:location` - Vertex AI location (default: "us-central1")
  - `:api_version` - API version (default: "v1beta")
  - `:timeout` - Connection timeout in ms (default: 30000)
  - `:retry_attempts` - Number of retry attempts for transient failures (default: 3)
  - `:retry_delay` - Initial delay between retries in ms (default: 1000)
  - `:retry_backoff` - Backoff multiplier for retries (default: 2.0)

  ## Connection State

  The connection struct tracks:
  - Gun connection PID
  - Stream reference
  - Authentication strategy
  - Connection status

  ## Endpoints

  - **Gemini API**: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=API_KEY`
  - **Vertex AI**: `wss://{location}-aiplatform.googleapis.com/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent?project=...&location=...`

  ## Telemetry Events

  This module emits the following telemetry events:

  - `[:gemini, :live, :websocket, :connect, :start]` - Connection attempt started
  - `[:gemini, :live, :websocket, :connect, :stop]` - Connection established
  - `[:gemini, :live, :websocket, :connect, :exception]` - Connection failed
  - `[:gemini, :live, :websocket, :send]` - Message sent
  - `[:gemini, :live, :websocket, :receive]` - Message received
  - `[:gemini, :live, :websocket, :close]` - Connection closed
  - `[:gemini, :live, :websocket, :retry]` - Retry attempt
  """

  require Logger

  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Config
  alias Gemini.Telemetry

  @type auth_strategy :: :gemini | :vertex_ai
  @type connection_status :: :connecting | :connected | :closing | :closed

  @type t :: %__MODULE__{
          gun_pid: pid() | nil,
          stream_ref: reference() | nil,
          auth_strategy: auth_strategy() | nil,
          status: connection_status(),
          model: String.t() | nil,
          project_id: String.t() | nil,
          location: String.t() | nil,
          api_version: String.t(),
          retry_config: retry_config()
        }

  @type retry_config :: %{
          attempts: non_neg_integer(),
          delay: non_neg_integer(),
          backoff: float()
        }

  @type connection_error ::
          :project_id_required_for_vertex_ai
          | :no_api_key
          | {:open_failed, term()}
          | {:connection_failed, term()}
          | {:upgrade_failed, integer(), list()}
          | {:upgrade_error, term()}
          | :upgrade_timeout
          | {:max_retries_exceeded, term()}

  @enforce_keys []
  defstruct [
    :gun_pid,
    :stream_ref,
    :auth_strategy,
    :model,
    :project_id,
    :location,
    status: :connecting,
    api_version: "v1beta",
    retry_config: %{attempts: 3, delay: 1000, backoff: 2.0}
  ]

  # Gemini API endpoint - v1beta is the default Live API version.
  # Use v1alpha for native audio extras (affective dialog, proactivity, thinking).
  @gemini_host "generativelanguage.googleapis.com"

  # Vertex AI Live endpoint (v1)
  @vertex_path "/ws/google.cloud.aiplatform.v1.LlmBidiService/BidiGenerateContent"

  # Connection timeouts
  @connect_timeout 30_000
  @upgrade_timeout 10_000

  # Default retry configuration
  @default_retry_attempts 3
  @default_retry_delay 1_000
  @default_retry_backoff 2.0

  # Retryable error types
  @retryable_errors [:timeout, :closed, :econnrefused, :econnreset, :etimedout]

  @redact_query_params ~w(key access_token token)

  # Build gun options at runtime to avoid compile-time function capture issue
  # WebSocket connections require HTTP/1.1 for the upgrade handshake
  @spec gun_opts() :: map()
  defp gun_opts do
    %{
      protocols: [:http],
      transport: :tls,
      tls_opts: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    }
  end

  @doc """
  Establishes a WebSocket connection to the Live API.

  ## Parameters

  - `auth_strategy` - `:gemini` or `:vertex_ai`
  - `opts` - Connection options:
    - `:model` - Required. Model name
    - `:project_id` - Required for Vertex AI
    - `:location` - Vertex AI location (default: "us-central1")
    - `:api_version` - Gemini API version for `:gemini` connections (default: "v1beta")
    - `:timeout` - Connection timeout in ms (default: 30000)
    - `:retry_attempts` - Number of retry attempts (default: 3)
    - `:retry_delay` - Initial retry delay in ms (default: 1000)
    - `:retry_backoff` - Backoff multiplier (default: 2.0)

  ## Returns

  - `{:ok, connection}` - Successfully connected
  - `{:error, reason}` - Connection failed

  ## Examples

      {:ok, conn} = WebSocket.connect(:gemini, model: "gemini-2.5-flash-native-audio-preview-12-2025")

      {:ok, conn} = WebSocket.connect(:vertex_ai,
        model: "gemini-2.5-flash-native-audio-preview-12-2025",
        project_id: "my-project",
        location: "us-central1"
      )

      # With custom retry configuration
      {:ok, conn} = WebSocket.connect(:gemini,
        model: "gemini-2.5-flash",
        retry_attempts: 5,
        retry_delay: 2000,
        retry_backoff: 1.5
      )
  """
  @spec connect(auth_strategy(), keyword()) :: {:ok, t()} | {:error, connection_error()}
  def connect(auth_strategy, opts \\ []) do
    start_time = System.monotonic_time()
    model = Keyword.fetch!(opts, :model)
    project_id = Keyword.get(opts, :project_id)
    location = Keyword.get(opts, :location, "us-central1")
    api_version = Keyword.get(opts, :api_version, "v1beta")
    timeout = Keyword.get(opts, :timeout, @connect_timeout)

    retry_config = %{
      attempts: Keyword.get(opts, :retry_attempts, @default_retry_attempts),
      delay: Keyword.get(opts, :retry_delay, @default_retry_delay),
      backoff: Keyword.get(opts, :retry_backoff, @default_retry_backoff)
    }

    conn = %__MODULE__{
      auth_strategy: auth_strategy,
      model: model,
      project_id: project_id,
      location: location,
      api_version: api_version,
      retry_config: retry_config
    }

    # Emit telemetry start event
    emit_connect_start(conn)

    result =
      with {:ok, conn} <- validate_config(conn) do
        connect_with_retry(conn, timeout, retry_config.attempts, retry_config.delay)
      end

    # Emit telemetry stop/exception event
    case result do
      {:ok, conn} ->
        emit_connect_stop(conn, start_time)
        {:ok, conn}

      {:error, reason} ->
        emit_connect_exception(conn, reason, start_time)
        {:error, reason}
    end
  end

  @doc """
  Sends a message over the WebSocket connection.

  The message should be a map that will be JSON-encoded.

  ## Parameters

  - `conn` - The WebSocket connection struct
  - `message` - A map to be JSON-encoded and sent

  ## Returns

  - `:ok` - Message sent successfully
  - `{:error, reason}` - Send failed

  ## Example

      :ok = WebSocket.send(conn, %{
        "clientContent" => %{
          "turns" => [%{"role" => "user", "parts" => [%{"text" => "Hello"}]}],
          "turnComplete" => true
        }
      })
  """
  @spec send(t(), map()) :: :ok | {:error, term()}
  def send(%__MODULE__{status: :connected, gun_pid: pid, stream_ref: ref} = conn, message)
      when is_map(message) do
    json = Jason.encode!(message)
    :gun.ws_send(pid, ref, {:text, json})
    emit_send(conn, message, byte_size(json))
    :ok
  catch
    :error, reason -> {:error, reason}
  end

  def send(%__MODULE__{status: status}, _message) do
    {:error, {:not_connected, status}}
  end

  @doc """
  Receives the next message from the WebSocket connection.

  This is a blocking call that waits for the next message.

  ## Parameters

  - `conn` - The connection struct
  - `timeout` - Timeout in milliseconds (default: 60000)

  ## Returns

  - `{:ok, message}` - Received and parsed JSON message
  - `{:error, :timeout}` - No message received within timeout
  - `{:error, :closed}` - Connection closed
  - `{:error, reason}` - Other error
  """
  @spec receive(t(), timeout()) :: {:ok, map()} | {:error, term()}
  def receive(%__MODULE__{gun_pid: pid, stream_ref: ref} = conn, timeout \\ 60_000) do
    start_time = System.monotonic_time()

    result =
      receive do
        {:gun_ws, ^pid, ^ref, {:text, data}} ->
          case Jason.decode(data) do
            {:ok, message} -> {:ok, message}
            {:error, _} = error -> error
          end

        # Live API sends binary frames containing JSON
        {:gun_ws, ^pid, ^ref, {:binary, data}} ->
          case Jason.decode(data) do
            {:ok, message} -> {:ok, message}
            {:error, _} = error -> error
          end

        {:gun_ws, ^pid, ^ref, {:close, code, reason}} ->
          Logger.debug("WebSocket closed: code=#{code}, reason=#{reason}")
          {:error, {:closed, code, reason}}

        {:gun_down, ^pid, :http2, reason, _} ->
          Logger.warning("Gun connection down: #{inspect(reason)}")
          {:error, {:connection_down, reason}}

        {:gun_error, ^pid, ^ref, reason} ->
          Logger.error("WebSocket error: #{inspect(reason)}")
          {:error, reason}

        {:gun_error, ^pid, reason} ->
          Logger.error("Gun error: #{inspect(reason)}")
          {:error, reason}
      after
        timeout ->
          {:error, :timeout}
      end

    # Emit telemetry for received message
    case result do
      {:ok, message} ->
        emit_receive(conn, message, start_time)

      _ ->
        :ok
    end

    result
  catch
    :exit, reason ->
      {:error, {:exit, reason}}
  end

  @doc """
  Receives all available messages without blocking.

  Returns a list of messages that are immediately available.
  """
  @spec receive_all(t()) :: [map()]
  def receive_all(%__MODULE__{} = conn) do
    receive_all(conn, [])
  end

  defp receive_all(conn, acc) do
    case __MODULE__.receive(conn, 0) do
      {:ok, message} -> receive_all(conn, [message | acc])
      {:error, :timeout} -> Enum.reverse(acc)
      {:error, _} -> Enum.reverse(acc)
    end
  end

  @doc """
  Closes the WebSocket connection gracefully.

  ## Parameters

  - `conn` - The WebSocket connection struct

  ## Returns

  - `:ok` - Always returns :ok
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{gun_pid: nil} = conn) do
    emit_close(conn, :already_closed)
    :ok
  end

  def close(%__MODULE__{gun_pid: pid, stream_ref: ref, status: :connected} = conn) do
    :gun.ws_send(pid, ref, :close)
    :gun.close(pid)
    emit_close(conn, :graceful)
    :ok
  end

  def close(%__MODULE__{gun_pid: pid} = conn) do
    :gun.close(pid)
    emit_close(conn, :forced)
    :ok
  end

  @doc """
  Returns the current connection status.
  """
  @spec status(t()) :: connection_status()
  def status(%__MODULE__{status: status}), do: status

  @doc """
  Checks if the connection is active.
  """
  @spec connected?(t()) :: boolean()
  def connected?(%__MODULE__{status: :connected}), do: true
  def connected?(_), do: false

  @doc """
  Checks if an error is retryable.

  Returns true if the error is a transient failure that might succeed on retry.

  ## Parameters

  - `error` - The error to check

  ## Returns

  - `true` if the error is retryable
  - `false` otherwise
  """
  @spec retryable_error?(term()) :: boolean()
  def retryable_error?(:timeout), do: true
  def retryable_error?(:closed), do: true
  def retryable_error?(:econnrefused), do: true
  def retryable_error?(:econnreset), do: true
  def retryable_error?(:etimedout), do: true
  def retryable_error?({:connection_failed, _}), do: true
  def retryable_error?({:open_failed, reason}) when reason in @retryable_errors, do: true
  def retryable_error?({:upgrade_error, {:stream_error, _, _}}), do: true
  def retryable_error?(:upgrade_timeout), do: true
  def retryable_error?(_), do: false

  # Private Functions

  @spec validate_config(t()) :: {:ok, t()} | {:error, atom()}
  defp validate_config(%__MODULE__{auth_strategy: :vertex_ai, project_id: nil}) do
    {:error, :project_id_required_for_vertex_ai}
  end

  defp validate_config(conn), do: {:ok, conn}

  @spec connect_with_retry(t(), timeout(), non_neg_integer(), non_neg_integer()) ::
          {:ok, t()} | {:error, connection_error()}
  defp connect_with_retry(conn, timeout, attempts_remaining, current_delay) do
    case do_connect(conn, timeout) do
      {:ok, connected_conn} ->
        {:ok, connected_conn}

      {:error, reason} when attempts_remaining > 0 ->
        if retryable_error?(reason) do
          Logger.warning(
            "WebSocket connection failed (#{inspect(reason)}), " <>
              "retrying in #{current_delay}ms (#{attempts_remaining} attempts remaining)"
          )

          emit_retry(conn, reason, attempts_remaining, current_delay)
          Process.sleep(current_delay)

          next_delay = round(current_delay * conn.retry_config.backoff)
          connect_with_retry(conn, timeout, attempts_remaining - 1, next_delay)
        else
          # Non-retryable error
          Logger.error("WebSocket connection failed with non-retryable error: #{inspect(reason)}")
          {:error, reason}
        end

      {:error, reason} ->
        # No more retries
        Logger.error("WebSocket connection failed after all retries: #{inspect(reason)}")
        {:error, {:max_retries_exceeded, reason}}
    end
  end

  @spec do_connect(t(), timeout()) :: {:ok, t()} | {:error, term()}
  defp do_connect(conn, timeout) do
    with {:ok, conn} <- open_connection(conn, timeout),
         {:ok, conn} <- upgrade_to_websocket(conn) do
      {:ok, %{conn | status: :connected}}
    end
  end

  @spec open_connection(t(), timeout()) :: {:ok, t()} | {:error, term()}
  defp open_connection(%__MODULE__{auth_strategy: :gemini} = conn, timeout) do
    Logger.debug("Opening connection to Gemini API Live endpoint")
    do_open_connection(conn, @gemini_host, 443, timeout)
  end

  defp open_connection(%__MODULE__{auth_strategy: :vertex_ai, location: location} = conn, timeout) do
    host = "#{location}-aiplatform.googleapis.com"
    Logger.debug("Opening connection to Vertex AI Live endpoint: #{host}")
    do_open_connection(conn, host, 443, timeout)
  end

  @spec do_open_connection(t(), String.t(), pos_integer(), timeout()) ::
          {:ok, t()} | {:error, term()}
  defp do_open_connection(conn, host, port, timeout) do
    case :gun.open(String.to_charlist(host), port, gun_opts()) do
      {:ok, pid} ->
        case :gun.await_up(pid, timeout) do
          {:ok, protocol} when protocol in [:http, :http2] ->
            Logger.debug("Gun connection established with #{protocol}")
            {:ok, %{conn | gun_pid: pid}}

          {:error, reason} ->
            :gun.close(pid)
            {:error, {:connection_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:open_failed, reason}}
    end
  end

  @spec upgrade_to_websocket(t()) :: {:ok, t()} | {:error, term()}
  defp upgrade_to_websocket(%__MODULE__{} = conn) do
    path = build_websocket_path(conn)
    headers = build_upgrade_headers(conn)

    Logger.debug("Upgrading to WebSocket: #{redact_websocket_path(path)}")

    stream_ref = :gun.ws_upgrade(conn.gun_pid, path, headers, %{})

    receive do
      {:gun_upgrade, _pid, ^stream_ref, ["websocket"], _headers} ->
        Logger.debug("WebSocket upgrade successful")
        {:ok, %{conn | stream_ref: stream_ref}}

      {:gun_response, _pid, ^stream_ref, :fin, status, resp_headers} ->
        Logger.error("WebSocket upgrade failed: status=#{status}")
        {:error, {:upgrade_failed, status, resp_headers}}

      {:gun_error, _pid, ^stream_ref, reason} ->
        Logger.error("WebSocket upgrade error: #{inspect(reason)}")
        {:error, {:upgrade_error, reason}}
    after
      @upgrade_timeout ->
        {:error, :upgrade_timeout}
    end
  end

  @spec build_websocket_path(t()) :: String.t()
  defp build_websocket_path(%__MODULE__{auth_strategy: :gemini} = conn) do
    case get_auth_params(conn) do
      {:ok, %{api_key: api_key}} ->
        "#{gemini_path(conn.api_version)}?key=#{api_key}"

      {:error, _} ->
        # Fallback - will fail at server
        gemini_path(conn.api_version)
    end
  end

  defp build_websocket_path(%__MODULE__{auth_strategy: :vertex_ai}) do
    @vertex_path
  end

  @doc false
  @spec redact_websocket_path(String.t()) :: String.t()
  def redact_websocket_path(path) when is_binary(path) do
    Enum.reduce(@redact_query_params, path, &redact_query_param/2)
  end

  @doc false
  @spec redacted_websocket_path(t()) :: String.t()
  def redacted_websocket_path(%__MODULE__{} = conn) do
    conn
    |> build_websocket_path()
    |> redact_websocket_path()
  end

  defp redact_query_param(param, path) do
    regex = Regex.compile!("([?&]#{Regex.escape(param)}=)[^&]+", "i")
    Regex.replace(regex, path, "\\1[REDACTED]")
  end

  defp gemini_path(api_version) when is_binary(api_version) do
    "/ws/google.ai.generativelanguage.#{api_version}.GenerativeService.BidiGenerateContent"
  end

  @spec build_upgrade_headers(t()) :: [{String.t(), String.t()}]
  defp build_upgrade_headers(%__MODULE__{auth_strategy: :gemini}) do
    [
      {"content-type", "application/json"}
    ]
  end

  defp build_upgrade_headers(%__MODULE__{auth_strategy: :vertex_ai} = conn) do
    case get_vertex_token(conn) do
      {:ok, token} ->
        [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ]

      {:error, _} ->
        [{"content-type", "application/json"}]
    end
  end

  @spec get_auth_params(t()) :: {:ok, map()} | {:error, term()}
  defp get_auth_params(%__MODULE__{auth_strategy: :gemini}) do
    case Config.api_key() do
      nil -> {:error, :no_api_key}
      key -> {:ok, %{api_key: key}}
    end
  end

  @spec get_vertex_token(t()) :: {:ok, String.t()} | {:error, term()}
  defp get_vertex_token(conn) do
    case get_vertex_credentials(conn) do
      {:ok, %{access_token: token}} when is_binary(token) ->
        {:ok, token}

      {:ok, creds} ->
        extract_token_from_auth(creds)

      error ->
        error
    end
  end

  @spec extract_token_from_auth(map()) :: {:ok, String.t()} | {:error, term()}
  defp extract_token_from_auth(creds) do
    case Gemini.Auth.build_headers(:vertex_ai, creds) do
      {:ok, headers} ->
        extract_bearer_token(headers)

      error ->
        error
    end
  end

  @spec extract_bearer_token([{String.t(), String.t()}]) :: {:ok, String.t()} | {:error, term()}
  defp extract_bearer_token(headers) do
    case List.keyfind(headers, "Authorization", 0) do
      {_, "Bearer " <> token} -> {:ok, token}
      _ -> {:error, :no_token_in_headers}
    end
  end

  @spec get_vertex_credentials(t()) :: {:ok, map()} | {:error, term()}
  defp get_vertex_credentials(conn) do
    opts = [
      project_id: conn.project_id,
      location: conn.location
    ]

    MultiAuthCoordinator.get_credentials(:vertex_ai, opts)
  end

  # Telemetry helpers

  @spec emit_connect_start(t()) :: :ok
  defp emit_connect_start(conn) do
    Telemetry.execute(
      [:gemini, :live, :websocket, :connect, :start],
      %{system_time: System.system_time()},
      %{
        auth_strategy: conn.auth_strategy,
        model: conn.model,
        location: conn.location
      }
    )
  end

  @spec emit_connect_stop(t(), integer()) :: :ok
  defp emit_connect_stop(conn, start_time) do
    duration = Telemetry.calculate_duration(start_time)

    Telemetry.execute(
      [:gemini, :live, :websocket, :connect, :stop],
      %{duration: duration},
      %{
        auth_strategy: conn.auth_strategy,
        model: conn.model,
        location: conn.location,
        status: :connected
      }
    )
  end

  @spec emit_connect_exception(t(), term(), integer()) :: :ok
  defp emit_connect_exception(conn, reason, start_time) do
    duration = Telemetry.calculate_duration(start_time)

    Telemetry.execute(
      [:gemini, :live, :websocket, :connect, :exception],
      %{duration: duration},
      %{
        auth_strategy: conn.auth_strategy,
        model: conn.model,
        location: conn.location,
        error: reason
      }
    )
  end

  @spec emit_send(t(), map(), non_neg_integer()) :: :ok
  defp emit_send(conn, message, size) do
    Telemetry.execute(
      [:gemini, :live, :websocket, :send],
      %{size: size},
      %{
        auth_strategy: conn.auth_strategy,
        model: conn.model,
        message_type: detect_message_type(message)
      }
    )
  end

  @spec emit_receive(t(), map(), integer()) :: :ok
  defp emit_receive(conn, message, start_time) do
    duration = Telemetry.calculate_duration(start_time)

    Telemetry.execute(
      [:gemini, :live, :websocket, :receive],
      %{duration: duration},
      %{
        auth_strategy: conn.auth_strategy,
        model: conn.model,
        message_type: detect_message_type(message)
      }
    )
  end

  @spec emit_close(t(), atom()) :: :ok
  defp emit_close(conn, reason) do
    Telemetry.execute(
      [:gemini, :live, :websocket, :close],
      %{},
      %{
        auth_strategy: conn.auth_strategy,
        model: conn.model,
        close_reason: reason
      }
    )
  end

  @spec emit_retry(t(), term(), non_neg_integer(), non_neg_integer()) :: :ok
  defp emit_retry(conn, error, attempts_remaining, delay) do
    Telemetry.execute(
      [:gemini, :live, :websocket, :retry],
      %{delay: delay, attempts_remaining: attempts_remaining},
      %{
        auth_strategy: conn.auth_strategy,
        model: conn.model,
        error: error
      }
    )
  end

  # Key mappings for message type detection: {string_key, atom_key, type}
  @message_type_keys [
    {"setup", :setup, :setup},
    {"setupComplete", :setup_complete, :setup_complete},
    {"clientContent", :client_content, :client_content},
    {"serverContent", :server_content, :server_content},
    {"realtimeInput", :realtime_input, :realtime_input},
    {"toolCall", :tool_call, :tool_call},
    {"toolResponse", :tool_response, :tool_response},
    {"goAway", :go_away, :go_away}
  ]

  @spec detect_message_type(map()) :: atom()
  defp detect_message_type(message) when is_map(message) do
    Enum.find_value(@message_type_keys, :unknown, fn {string_key, atom_key, type} ->
      if Map.has_key?(message, string_key) or Map.has_key?(message, atom_key) do
        type
      end
    end)
  end
end
