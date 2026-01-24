defmodule Gemini.Client.HTTPStreamingTest do
  use ExUnit.Case, async: false

  alias Gemini.Client.HTTPStreaming
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    %{bypass: bypass}
  end

  test "stream_to_process starts stream tasks under the task supervisor", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/stream", fn conn ->
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
end
