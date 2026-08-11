defmodule Gemini.Client.HTTPStreamingTest do
  use ExUnit.Case, async: false

  alias Gemini.Client.HTTPStreaming
  alias Plug.Conn

  setup do
    bypass = Gemini.TestHTTPServer.open()
    %{bypass: bypass}
  end

  test "stream_to_process starts stream tasks under the task supervisor", %{bypass: bypass} do
    Gemini.TestHTTPServer.expect_once(bypass, "POST", "/stream", fn conn ->
      conn =
        conn
        |> Conn.put_resp_content_type("text/event-stream")
        |> Conn.send_chunked(200)

      Process.sleep(200)
      {:ok, conn} = Conn.chunk(conn, "data: [DONE]\n\n")
      conn
    end)

    task_supervisor = Process.whereis(Gemini.TaskSupervisor)
    assert is_pid(task_supervisor)

    {:ok, pid} =
      HTTPStreaming.stream_to_process(
        "http://localhost:#{bypass.port}/stream",
        [],
        %{},
        "stream_test",
        self(),
        add_sse_params: false,
        max_retries: 0,
        timeout: 1_000,
        connect_timeout: 1_000
      )

    children = Supervisor.which_children(task_supervisor)

    assert Enum.any?(children, fn {_id, child_pid, _type, _modules} ->
             child_pid == pid
           end)

    assert_receive {:stream_complete, "stream_test"}, 1_000
  end

  test "governed stream errors redact credential material from callbacks results and telemetry",
       %{
         bypass: bypass
       } do
    sentinel = "stream-error-secret-never-visible"
    test_pid = self()
    handler_id = "stream-error-redaction-#{System.unique_integer([:positive])}"
    original_telemetry = Application.get_env(:gemini_ex, :telemetry_enabled)
    Application.put_env(:gemini_ex, :telemetry_enabled, true)

    :telemetry.attach_many(
      handler_id,
      [
        [:gemini, :stream, :start],
        [:gemini, :stream, :error],
        [:gemini, :stream, :exception]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:stream_error_telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)

      case original_telemetry do
        nil -> Application.delete_env(:gemini_ex, :telemetry_enabled)
        value -> Application.put_env(:gemini_ex, :telemetry_enabled, value)
      end
    end)

    Gemini.TestHTTPServer.expect_once(bypass, "POST", "/stream", fn conn ->
      conn = Conn.fetch_query_params(conn)
      assert conn.query_params["key"] == sentinel

      Conn.resp(
        conn,
        400,
        Jason.encode!(%{"error" => %{"message" => "provider echoed #{sentinel}"}})
      )
    end)

    callback = fn event ->
      send(test_pid, {:governed_stream_callback, event})
      :ok
    end

    result =
      HTTPStreaming.stream_sse(
        "http://localhost:#{bypass.port}/stream?key=#{sentinel}",
        [],
        %{},
        callback,
        add_sse_params: false,
        max_retries: 0,
        timeout: 1_000,
        model: "gemini-2.5-flash",
        credential_query_names: ["key"],
        redaction_values: [sentinel],
        governed_context: %{provider_account_ref: "account://google/gemini/test"}
      )

    assert_receive {:governed_stream_callback, callback_event}

    assert_receive {:stream_error_telemetry, [:gemini, :stream, :error], _,
                    provider_error_metadata}

    assert_receive {:stream_error_telemetry, [:gemini, :stream, :exception], _, error_metadata}

    for surface <- [result, callback_event, provider_error_metadata, error_metadata] do
      refute inspect(surface) =~ sentinel
    end

    assert inspect(result) =~ "[REDACTED]"
    assert provider_error_metadata.reason.http_status == 400
    assert error_metadata.url =~ "key=[REDACTED]"

    assert error_metadata.governed_context.provider_account_ref ==
             "account://google/gemini/test"
  end
end
