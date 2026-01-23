defmodule Gemini.Client.WebSocketLiveTest do
  @moduledoc """
  Live integration tests for Gemini.Client.WebSocket.

  These tests make actual API calls to test WebSocket connectivity.
  They are tagged with :live_gemini or :live_vertex_ai and skipped by default.

  To run these tests:

      GEMINI_API_KEY=your_api_key mix test --only live_gemini
      VERTEX_PROJECT_ID=your-project VERTEX_SERVICE_ACCOUNT=/path/to/key.json mix test --only live_vertex_ai
  """

  use ExUnit.Case, async: false

  alias Gemini.Client.WebSocket

  @live_model "gemini-2.5-flash-native-audio-preview-12-2025"

  describe "connect/2 with Gemini API" do
    @tag :live_gemini
    test "establishes connection successfully" do
      unless System.get_env("GEMINI_API_KEY") do
        {:skip, "GEMINI_API_KEY required"}
      end

      {:ok, conn} =
        WebSocket.connect(:gemini,
          model: @live_model
        )

      assert WebSocket.connected?(conn)
      assert conn.auth_strategy == :gemini
      WebSocket.close(conn)
    end

    @tag :live_gemini
    test "can send and receive setup message" do
      unless System.get_env("GEMINI_API_KEY") do
        {:skip, "GEMINI_API_KEY required"}
      end

      {:ok, conn} =
        WebSocket.connect(:gemini,
          model: @live_model
        )

      # Send setup message
      setup_msg = %{
        "setup" => %{
          "model" => @live_model,
          "generationConfig" => %{
            "responseModalities" => ["TEXT"]
          }
        }
      }

      assert :ok = WebSocket.send(conn, setup_msg)

      # Should receive setupComplete
      {:ok, response} = WebSocket.receive(conn, 10_000)
      assert Map.has_key?(response, "setupComplete")

      WebSocket.close(conn)
    end
  end

  describe "connect/2 with Vertex AI" do
    @tag :live_vertex_ai
    test "establishes connection successfully" do
      project_id = System.get_env("VERTEX_PROJECT_ID")
      has_auth = System.get_env("VERTEX_SERVICE_ACCOUNT") || System.get_env("VERTEX_ACCESS_TOKEN")

      unless project_id && has_auth do
        {:skip, "VERTEX_PROJECT_ID and credentials required"}
      end

      {:ok, conn} =
        WebSocket.connect(:vertex_ai,
          model: @live_model,
          project_id: project_id,
          location: "us-central1"
        )

      assert WebSocket.connected?(conn)
      assert conn.auth_strategy == :vertex_ai
      WebSocket.close(conn)
    end

    @tag :live_vertex_ai
    test "returns error without project_id" do
      assert {:error, :project_id_required_for_vertex_ai} =
               WebSocket.connect(:vertex_ai, model: @live_model)
    end
  end

  describe "close/1" do
    @tag :live_gemini
    test "closes connection gracefully" do
      unless System.get_env("GEMINI_API_KEY") do
        {:skip, "GEMINI_API_KEY required"}
      end

      {:ok, conn} =
        WebSocket.connect(:gemini,
          model: @live_model
        )

      assert WebSocket.connected?(conn)
      assert :ok = WebSocket.close(conn)
    end
  end
end
