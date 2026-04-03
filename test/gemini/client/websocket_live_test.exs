defmodule Gemini.Client.WebSocketLiveTest do
  @moduledoc """
  Live integration tests for Gemini.Client.WebSocket.

  These tests make actual API calls to test WebSocket connectivity.
  They are tagged with :live_gemini or :live_vertex_ai and skipped by default.

  To run these tests:

      GEMINI_API_KEY=your_api_key mix test --only live_gemini
      RUN_BILLED_VERTEX_LIVE_TESTS=1 VERTEX_PROJECT_ID=your-project VERTEX_SERVICE_ACCOUNT=/path/to/key.json mix test --only live_vertex_ai
  """

  use ExUnit.Case, async: false

  alias Gemini.Client.WebSocket
  alias Gemini.Live.Models
  alias Gemini.Test.LiveHelpers
  alias Gemini.Types.Live.Setup

  @has_gemini_api_key System.get_env("GEMINI_API_KEY") not in [nil, ""]
  @run_billed_vertex_live_tests System.get_env("RUN_BILLED_VERTEX_LIVE_TESTS") in [
                                  "1",
                                  "true",
                                  "TRUE",
                                  "yes",
                                  "YES"
                                ]
  @vertex_project_id System.get_env("VERTEX_PROJECT_ID")
  @has_vertex_auth Enum.any?(
                     [
                       System.get_env("VERTEX_SERVICE_ACCOUNT"),
                       System.get_env("VERTEX_ACCESS_TOKEN"),
                       System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
                     ],
                     fn value -> is_binary(value) and value != "" end
                   )

  describe "connect/2 with Gemini API" do
    @describetag :live_gemini

    if not @has_gemini_api_key do
      @describetag skip: "GEMINI_API_KEY required"
    end

    test "establishes connection successfully" do
      live_model = Models.resolve(:audio)

      {:ok, conn} =
        WebSocket.connect(:gemini,
          model: live_model
        )

      assert WebSocket.connected?(conn)
      assert conn.auth_strategy == :gemini
      WebSocket.close(conn)
    end

    test "can send and receive setup message" do
      live_model = Models.resolve(:audio)

      setup =
        Setup.new(live_model,
          generation_config: %{response_modalities: ["AUDIO"]},
          output_audio_transcription: %{}
        )

      setup_msg = %{"setup" => Setup.to_api(setup)}

      case receive_setup_message(:gemini, [model: live_model], setup_msg, 2) do
        {:ok, response} ->
          assert Map.has_key?(response, "setupComplete")

        {:skip, reason} ->
          IO.puts("\nSkipping Gemini WebSocket setup test: #{reason}")
          assert true
      end
    end
  end

  describe "connect/2 with Vertex AI live connection" do
    @describetag :live_vertex_ai

    if not @run_billed_vertex_live_tests do
      @describetag skip: "Set RUN_BILLED_VERTEX_LIVE_TESTS=1 to run billed Vertex live tests"
    end

    if is_nil(@vertex_project_id) or @vertex_project_id == "" do
      @describetag skip: "VERTEX_PROJECT_ID required"
    end

    if not @has_vertex_auth do
      @describetag skip:
                     "One of VERTEX_SERVICE_ACCOUNT, VERTEX_ACCESS_TOKEN, GOOGLE_APPLICATION_CREDENTIALS_JSON required"
    end

    @tag :live_vertex_ai
    test "establishes connection successfully" do
      live_model = Models.default(:audio)
      project_id = System.fetch_env!("VERTEX_PROJECT_ID")

      {:ok, conn} =
        WebSocket.connect(:vertex_ai,
          model: live_model,
          project_id: project_id,
          location: "us-central1"
        )

      assert WebSocket.connected?(conn)
      assert conn.auth_strategy == :vertex_ai
      WebSocket.close(conn)
    end
  end

  describe "connect/2 with Vertex AI validation" do
    @tag :live_vertex_ai
    test "returns error without project_id" do
      live_model = Models.default(:audio)

      assert {:error, :project_id_required_for_vertex_ai} =
               WebSocket.connect(:vertex_ai, model: live_model)
    end
  end

  describe "close/1" do
    @describetag :live_gemini

    if not @has_gemini_api_key do
      @describetag skip: "GEMINI_API_KEY required"
    end

    test "closes connection gracefully" do
      live_model = Models.resolve(:audio)

      {:ok, conn} =
        WebSocket.connect(:gemini,
          model: live_model
        )

      assert WebSocket.connected?(conn)
      assert :ok = WebSocket.close(conn)
    end
  end

  defp receive_setup_message(auth, opts, setup_msg, attempts_left) when attempts_left > 0 do
    {:ok, conn} = WebSocket.connect(auth, opts)

    assert :ok = WebSocket.send(conn, setup_msg)

    case WebSocket.receive(conn, 10_000) do
      {:ok, response} ->
        WebSocket.close(conn)
        {:ok, response}

      {:error, reason} ->
        maybe_close(conn)

        case LiveHelpers.skippable_websocket_close?(reason) do
          :transient_backend_error when attempts_left > 1 ->
            Process.sleep(1_000)
            receive_setup_message(auth, opts, setup_msg, attempts_left - 1)

          :transient_backend_error ->
            flunk(
              "Gemini Live setup repeatedly returned transient-looking upstream error for the same config: #{inspect(reason)}"
            )

          :quota_exceeded ->
            {:skip, "Gemini Live setup hit quota or rate limiting: #{inspect(reason)}"}

          false ->
            flunk("WebSocket setup failed: #{inspect(reason)}")
        end
    end
  end

  defp maybe_close(conn) do
    _ = WebSocket.close(conn)
    :ok
  end
end
