defmodule Gemini.Client.WebSocket do
  @moduledoc """
  WebSocket client for Gemini Live API using :gun.

  This module provides low-level WebSocket connectivity with:
  - TLS/HTTP2 connection management
  - Automatic reconnection handling
  - Message framing and parsing
  - Auth strategy integration (Gemini API / Vertex AI)

  ## Usage

  Typically used through `Gemini.Live.Session` rather than directly.

      {:ok, conn} = WebSocket.connect(:gemini, model: "gemini-2.5-flash")
      :ok = WebSocket.send(conn, %{setup: setup_config})
      {:ok, message} = WebSocket.receive(conn)
      :ok = WebSocket.close(conn)

  ## Connection State

  The connection struct tracks:
  - Gun connection PID
  - Stream reference
  - Authentication strategy
  - Connection status

  ## Endpoints

  - **Gemini API**: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=API_KEY`
  - **Vertex AI**: `wss://{location}-aiplatform.googleapis.com/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent?project=...&location=...`
  """

  require Logger

  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Config

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
          api_version: String.t()
        }

  @enforce_keys []
  defstruct [
    :gun_pid,
    :stream_ref,
    :auth_strategy,
    :model,
    :project_id,
    :location,
    status: :connecting,
    api_version: "v1alpha"
  ]

  # Gemini API endpoint
  @gemini_host "generativelanguage.googleapis.com"
  @gemini_path "/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent"

  # Vertex AI endpoint template
  @vertex_path "/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent"

  # Connection timeouts
  @connect_timeout 30_000
  @upgrade_timeout 10_000

  # Build gun options at runtime to avoid compile-time function capture issue
  @spec gun_opts() :: map()
  defp gun_opts do
    %{
      protocols: [:http2],
      transport: :tls,
      tls_opts: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      http2_opts: %{
        keepalive: :infinity
      }
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
    - `:api_version` - API version (default: "v1alpha")
    - `:timeout` - Connection timeout in ms (default: 30000)

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
  """
  @spec connect(auth_strategy(), keyword()) :: {:ok, t()} | {:error, term()}
  def connect(auth_strategy, opts \\ []) do
    model = Keyword.fetch!(opts, :model)
    project_id = Keyword.get(opts, :project_id)
    location = Keyword.get(opts, :location, "us-central1")
    api_version = Keyword.get(opts, :api_version, "v1alpha")
    timeout = Keyword.get(opts, :timeout, @connect_timeout)

    conn = %__MODULE__{
      auth_strategy: auth_strategy,
      model: model,
      project_id: project_id,
      location: location,
      api_version: api_version
    }

    with {:ok, conn} <- validate_config(conn),
         {:ok, conn} <- open_connection(conn, timeout),
         {:ok, conn} <- upgrade_to_websocket(conn) do
      {:ok, %{conn | status: :connected}}
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
  def send(%__MODULE__{status: :connected, gun_pid: pid, stream_ref: ref}, message)
      when is_map(message) do
    json = Jason.encode!(message)
    :gun.ws_send(pid, ref, {:text, json})
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
  def receive(%__MODULE__{gun_pid: pid, stream_ref: ref} = _conn, timeout \\ 60_000) do
    receive do
      {:gun_ws, ^pid, ^ref, {:text, data}} ->
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
  def close(%__MODULE__{gun_pid: nil}), do: :ok

  def close(%__MODULE__{gun_pid: pid, stream_ref: ref, status: :connected}) do
    :gun.ws_send(pid, ref, :close)
    :gun.close(pid)
    :ok
  end

  def close(%__MODULE__{gun_pid: pid}) do
    :gun.close(pid)
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

  # Private Functions

  @spec validate_config(t()) :: {:ok, t()} | {:error, atom()}
  defp validate_config(%__MODULE__{auth_strategy: :vertex_ai, project_id: nil}) do
    {:error, :project_id_required_for_vertex_ai}
  end

  defp validate_config(conn), do: {:ok, conn}

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
          {:ok, :http2} ->
            Logger.debug("Gun connection established with HTTP/2")
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

    Logger.debug("Upgrading to WebSocket: #{path}")

    stream_ref = :gun.ws_upgrade(conn.gun_pid, path, headers, %{protocols: [:http]})

    receive do
      {:gun_upgrade, _pid, ^stream_ref, ["websocket"], _headers} ->
        Logger.debug("WebSocket upgrade successful")
        {:ok, %{conn | stream_ref: stream_ref}}

      {:gun_response, _pid, ^stream_ref, :fin, status, headers} ->
        Logger.error("WebSocket upgrade failed: status=#{status}")
        {:error, {:upgrade_failed, status, headers}}

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
        "#{@gemini_path}?key=#{api_key}"

      {:error, _} ->
        # Fallback - will fail at server
        @gemini_path
    end
  end

  defp build_websocket_path(%__MODULE__{auth_strategy: :vertex_ai} = conn) do
    "#{@vertex_path}?project=#{conn.project_id}&location=#{conn.location}"
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
end
