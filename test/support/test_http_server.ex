defmodule Gemini.TestHTTPServer do
  @moduledoc false

  defstruct [:port, :server, :expectations]

  @type t :: %__MODULE__{port: :inet.port_number(), server: pid(), expectations: pid()}
  @type handler :: (Plug.Conn.t() -> Plug.Conn.t())

  @spec open() :: t()
  def open do
    {:ok, expectations} =
      Agent.start(fn -> %{routes: %{}, unexpected: nil, handler_error: nil} end)

    {:ok, server} =
      Bandit.start_link(
        plug: {__MODULE__.Handler, expectations},
        port: 0,
        ip: {127, 0, 0, 1},
        startup_log: false
      )

    Process.unlink(server)
    {:ok, {_address, port}} = ThousandIsland.listener_info(server)

    test_server = %__MODULE__{port: port, server: server, expectations: expectations}

    ExUnit.Callbacks.on_exit({__MODULE__, expectations}, fn ->
      verify_and_stop(test_server)
    end)

    test_server
  end

  @spec expect(t(), handler()) :: :ok
  def expect(server, handler), do: register(server, :any, :any, :once_or_more, handler)

  @spec expect(t(), String.t(), String.t(), handler()) :: :ok
  def expect(server, method, path, handler) do
    register(server, method, path, :once_or_more, handler)
  end

  @spec expect_once(t(), handler()) :: :ok
  def expect_once(server, handler), do: register(server, :any, :any, :once, handler)

  @spec expect_once(t(), String.t(), String.t(), handler()) :: :ok
  def expect_once(server, method, path, handler) do
    register(server, method, path, :once, handler)
  end

  @doc false
  def dispatch(expectations, method, path) do
    Agent.get_and_update(expectations, fn state ->
      route = matching_route(state.routes, method, path)

      case Map.get(state.routes, route) do
        nil ->
          {{:error, {:unexpected, method, path}}, %{state | unexpected: {method, path}}}

        %{expected: :once, calls: calls} = expectation when calls > 0 ->
          routes = put_in(state.routes[route], %{expectation | calls: calls + 1})
          {{:error, {:too_many, method, path}}, %{state | routes: routes}}

        expectation ->
          routes = put_in(state.routes[route], %{expectation | calls: expectation.calls + 1})
          {{:ok, route, expectation.handler}, %{state | routes: routes}}
      end
    end)
  end

  @doc false
  def record_handler_error(expectations, kind, reason, stacktrace) do
    Agent.update(expectations, fn state ->
      %{state | handler_error: state.handler_error || {kind, reason, stacktrace}}
    end)
  end

  defp register(%__MODULE__{expectations: expectations}, method, path, expected, handler)
       when is_function(handler, 1) do
    route = {method, path}

    Agent.update(expectations, fn state ->
      put_in(state.routes[route], %{expected: expected, calls: 0, handler: handler})
    end)
  end

  defp matching_route(routes, method, path) do
    cond do
      Map.has_key?(routes, {method, path}) -> {method, path}
      Map.has_key?(routes, {:any, :any}) -> {:any, :any}
      true -> nil
    end
  end

  defp verify_and_stop(%__MODULE__{} = server) do
    result = Agent.get(server.expectations, &verification_result/1)

    if Process.alive?(server.server), do: Supervisor.stop(server.server)
    if Process.alive?(server.expectations), do: Agent.stop(server.expectations)

    case result do
      :ok -> :ok
      {:raise, kind, reason, stacktrace} -> :erlang.raise(kind, reason, stacktrace)
      {:error, message} -> raise ExUnit.AssertionError, message
    end
  end

  defp verification_result(%{handler_error: {kind, reason, stacktrace}}) do
    {:raise, kind, reason, stacktrace}
  end

  defp verification_result(%{unexpected: {method, path}}) do
    {:error, "test HTTP server got an unexpected request at #{method} #{path}"}
  end

  defp verification_result(%{routes: routes}) do
    Enum.find_value(routes, :ok, fn
      {{method, path}, %{expected: :once, calls: calls}} when calls != 1 ->
        {:error, "expected exactly one request at #{route_name(method, path)}, got #{calls}"}

      {{method, path}, %{expected: :once_or_more, calls: 0}} ->
        {:error, "expected at least one request at #{route_name(method, path)}, got none"}

      _route ->
        nil
    end)
  end

  defp route_name(:any, :any), do: "any route"
  defp route_name(method, path), do: "#{method} #{path}"

  defmodule Handler do
    @moduledoc false

    @behaviour Plug

    alias Gemini.TestHTTPServer
    alias Plug.Conn

    @impl Plug
    def init(expectations), do: expectations

    @impl Plug
    def call(conn, expectations) do
      conn = Conn.fetch_query_params(conn)

      case TestHTTPServer.dispatch(expectations, conn.method, conn.request_path) do
        {:ok, _route, handler} ->
          invoke_handler(conn, expectations, handler)

        {:error, reason} ->
          Conn.send_resp(conn, 500, "test server expectation error: #{reason}")
      end
    end

    defp invoke_handler(conn, expectations, handler) do
      handler.(conn)
    catch
      kind, reason ->
        TestHTTPServer.record_handler_error(
          expectations,
          kind,
          reason,
          __STACKTRACE__
        )

        Conn.send_resp(conn, 500, "test server handler failed")
    end
  end
end
