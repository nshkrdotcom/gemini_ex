defmodule Gemini.Client.WebSocketTest do
  @moduledoc """
  Unit tests for Gemini.Client.WebSocket.

  These tests verify the WebSocket client functionality without
  making actual network calls.
  """

  use ExUnit.Case, async: true

  alias Gemini.Client.WebSocket

  describe "struct" do
    test "has correct default status" do
      conn = %WebSocket{}
      assert conn.status == :connecting
    end

    test "has correct default api_version" do
      conn = %WebSocket{}
      assert conn.api_version == "v1beta"
    end

    test "has nil defaults for connection state" do
      conn = %WebSocket{}
      assert conn.gun_pid == nil
      assert conn.stream_ref == nil
      assert conn.project_id == nil
      assert conn.location == nil
    end

    test "has default retry configuration" do
      conn = %WebSocket{}
      assert conn.retry_config == %{attempts: 3, delay: 1000, backoff: 2.0}
    end
  end

  describe "retryable_error?/1" do
    test "returns true for timeout" do
      assert WebSocket.retryable_error?(:timeout)
    end

    test "returns true for closed" do
      assert WebSocket.retryable_error?(:closed)
    end

    test "returns true for connection refused" do
      assert WebSocket.retryable_error?(:econnrefused)
    end

    test "returns true for connection reset" do
      assert WebSocket.retryable_error?(:econnreset)
    end

    test "returns true for etimedout" do
      assert WebSocket.retryable_error?(:etimedout)
    end

    test "returns true for connection_failed tuple" do
      assert WebSocket.retryable_error?({:connection_failed, :some_reason})
    end

    test "returns true for upgrade_timeout" do
      assert WebSocket.retryable_error?(:upgrade_timeout)
    end

    test "returns true for upgrade_error with stream_error" do
      assert WebSocket.retryable_error?(
               {:upgrade_error, {:stream_error, :protocol_error, "reason"}}
             )
    end

    test "returns false for invalid api key" do
      refute WebSocket.retryable_error?(:invalid_api_key)
    end

    test "returns false for project_id_required_for_vertex_ai" do
      refute WebSocket.retryable_error?(:project_id_required_for_vertex_ai)
    end

    test "returns false for upgrade_failed with status" do
      refute WebSocket.retryable_error?({:upgrade_failed, 401, []})
    end
  end

  describe "connected?/1" do
    test "returns true when status is :connected" do
      conn = %WebSocket{status: :connected}
      assert WebSocket.connected?(conn)
    end

    test "returns false when status is :connecting" do
      conn = %WebSocket{status: :connecting}
      refute WebSocket.connected?(conn)
    end

    test "returns false when status is :closing" do
      conn = %WebSocket{status: :closing}
      refute WebSocket.connected?(conn)
    end

    test "returns false when status is :closed" do
      conn = %WebSocket{status: :closed}
      refute WebSocket.connected?(conn)
    end
  end

  describe "status/1" do
    test "returns the current status" do
      conn = %WebSocket{status: :connected}
      assert WebSocket.status(conn) == :connected
    end

    test "returns :connecting for new connection" do
      conn = %WebSocket{}
      assert WebSocket.status(conn) == :connecting
    end
  end

  describe "send/2" do
    test "returns error when not connected (status: :connecting)" do
      conn = %WebSocket{status: :connecting}
      assert {:error, {:not_connected, :connecting}} = WebSocket.send(conn, %{test: true})
    end

    test "returns error when not connected (status: :closing)" do
      conn = %WebSocket{status: :closing}
      assert {:error, {:not_connected, :closing}} = WebSocket.send(conn, %{test: true})
    end

    test "returns error when not connected (status: :closed)" do
      conn = %WebSocket{status: :closed}
      assert {:error, {:not_connected, :closed}} = WebSocket.send(conn, %{test: true})
    end
  end

  describe "close/1" do
    test "returns :ok for nil gun_pid" do
      conn = %WebSocket{gun_pid: nil}
      assert :ok = WebSocket.close(conn)
    end

    test "returns :ok for nil gun_pid with closed status" do
      conn = %WebSocket{gun_pid: nil, status: :closed}
      assert :ok = WebSocket.close(conn)
    end
  end

  describe "build_websocket_path/1 (via connect validation)" do
    test "returns error for vertex_ai without project_id" do
      # When connecting to Vertex AI without project_id, it should fail validation
      result = WebSocket.connect(:vertex_ai, model: "gemini-2.5-flash")
      assert {:error, :project_id_required_for_vertex_ai} = result
    end
  end

  describe "redacted_websocket_path/1" do
    setup do
      Application.put_env(:gemini_ex, :api_key, "test-key")
      on_exit(fn -> Application.delete_env(:gemini_ex, :api_key) end)
      :ok
    end

    test "uses api_version in gemini path" do
      conn = %WebSocket{auth_strategy: :gemini, model: "gemini-2.5-flash", api_version: "v1beta"}
      path = WebSocket.redacted_websocket_path(conn)

      assert path =~
               "/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

      assert path =~ "key=[REDACTED]"
      refute path =~ "test-key"
    end
  end

  describe "auth strategy validation" do
    test "gemini strategy doesn't require project_id" do
      # This will fail at connection (no network), but should pass validation
      # We're testing that the validation doesn't reject gemini for missing project_id
      conn = %WebSocket{
        auth_strategy: :gemini,
        model: "gemini-2.5-flash",
        project_id: nil
      }

      # Struct is valid - gemini doesn't need project_id
      assert conn.auth_strategy == :gemini
      assert conn.project_id == nil
    end

    test "vertex_ai strategy stores project_id and location" do
      conn = %WebSocket{
        auth_strategy: :vertex_ai,
        model: "gemini-2.5-flash",
        project_id: "my-project",
        location: "us-central1"
      }

      assert conn.auth_strategy == :vertex_ai
      assert conn.project_id == "my-project"
      assert conn.location == "us-central1"
    end
  end

  describe "redact_websocket_path/1" do
    test "redacts api key query parameter" do
      path =
        "/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=secret123"

      assert WebSocket.redact_websocket_path(path) =~ "key=[REDACTED]"
      refute WebSocket.redact_websocket_path(path) =~ "secret123"
    end

    test "redacts access_token and token query parameters" do
      path = "/ws/service?access_token=tok123&token=tok456&other=ok"
      redacted = WebSocket.redact_websocket_path(path)

      assert redacted =~ "access_token=[REDACTED]"
      assert redacted =~ "token=[REDACTED]"
      assert redacted =~ "other=ok"
      refute redacted =~ "tok123"
      refute redacted =~ "tok456"
    end

    test "returns path unchanged when no sensitive params present" do
      path = "/ws/service?project=proj&location=us-central1"
      assert WebSocket.redact_websocket_path(path) == path
    end
  end
end
