defmodule Gemini.Client.WebSocket.Transport do
  @moduledoc false

  use WebSockex

  @type state :: %{owner: pid(), connection_ref: reference()}

  @spec start(
          String.t(),
          [{String.t(), String.t()}],
          pid(),
          reference(),
          timeout(),
          timeout()
        ) ::
          {:ok, pid()} | {:error, term()}
  def start(url, headers, owner, connection_ref, connect_timeout, upgrade_timeout) do
    uri = URI.parse(url)

    case WebSockex.Conn.new(url,
           extra_headers: headers,
           socket_connect_timeout: connect_timeout,
           socket_recv_timeout: upgrade_timeout,
           ssl_options: tls_options(uri)
         ) do
      %WebSockex.Conn{} = connection ->
        WebSockex.start(connection, __MODULE__, %{
          owner: owner,
          connection_ref: connection_ref
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec close(pid()) :: :ok
  def close(pid), do: WebSockex.cast(pid, :close)

  @impl WebSockex
  def handle_frame({type, payload}, state) when type in [:text, :binary] do
    send(state.owner, {:gemini_websocket, self(), state.connection_ref, {type, payload}})
    {:ok, state}
  end

  @impl WebSockex
  def handle_cast(:close, state), do: {:close, state}

  @impl WebSockex
  def handle_disconnect(%{reason: reason}, state) do
    send(
      state.owner,
      {:gemini_websocket, self(), state.connection_ref, normalize_disconnect(reason)}
    )

    {:ok, state}
  end

  defp tls_options(%URI{scheme: "wss", host: host}) do
    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  defp tls_options(_uri), do: []

  defp normalize_disconnect({:remote, :normal}), do: {:close, 1000, ""}
  defp normalize_disconnect({:remote, code, reason}), do: {:close, code, reason}
  defp normalize_disconnect({:remote, :closed}), do: {:connection_down, :closed}
  defp normalize_disconnect({:error, reason}), do: {:connection_down, reason}
  defp normalize_disconnect(reason), do: {:connection_down, reason}
end
