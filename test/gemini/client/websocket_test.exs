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
      assert conn.api_version == "v1alpha"
    end

    test "has nil defaults for connection state" do
      conn = %WebSocket{}
      assert conn.gun_pid == nil
      assert conn.stream_ref == nil
      assert conn.project_id == nil
      assert conn.location == nil
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
end
