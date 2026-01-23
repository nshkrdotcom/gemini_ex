defmodule Gemini.Live.SessionVertexLiveTest do
  @moduledoc """
  Live integration tests for Gemini.Live.Session with Vertex AI.

  These tests make actual API calls to the Vertex AI Live API.
  They are tagged with :live_vertex_ai and skipped by default.

  To run these tests, you need either:
  - VERTEX_PROJECT_ID and VERTEX_SERVICE_ACCOUNT environment variables
  - Or VERTEX_PROJECT_ID and VERTEX_ACCESS_TOKEN environment variables

  Example:

      VERTEX_PROJECT_ID=your-project VERTEX_SERVICE_ACCOUNT=/path/to/key.json mix test --only live_vertex_ai
  """

  use ExUnit.Case, async: false

  alias Gemini.Live.Session

  @moduletag :live_vertex_ai

  @live_model "gemini-2.5-flash-native-audio-preview-12-2025"

  setup do
    project_id = System.get_env("VERTEX_PROJECT_ID")
    has_auth = System.get_env("VERTEX_SERVICE_ACCOUNT") || System.get_env("VERTEX_ACCESS_TOKEN")

    unless project_id && has_auth do
      {:skip, "VERTEX_PROJECT_ID and VERTEX_SERVICE_ACCOUNT (or VERTEX_ACCESS_TOKEN) required"}
    else
      {:ok, project_id: project_id}
    end
  end

  describe "Vertex AI connection" do
    @tag :live_vertex_ai
    test "connects with service account", %{project_id: project_id} do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :vertex_ai,
          project_id: project_id,
          location: "us-central1",
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      assert :ok = Session.connect(session)
      assert Session.status(session) == :ready

      Session.close(session)
    end

    @tag :live_vertex_ai
    test "sends text and receives response", %{project_id: project_id} do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :vertex_ai,
          project_id: project_id,
          location: "us-central1",
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 10_000

      :ok = Session.send_client_content(session, "Say hello in one word")
      assert_receive {:msg, %{server_content: content}}, 15_000
      assert content != nil

      Session.close(session)
    end

    @tag :live_vertex_ai
    test "returns error without project_id" do
      assert {:error, :project_id_required_for_vertex_ai} =
               Session.start_link(
                 model: @live_model,
                 auth: :vertex_ai
               )
               |> case do
        {:ok, pid} ->
          result = Session.connect(pid)
          GenServer.stop(pid)
          result

        error ->
          error
      end
    end

    @tag :live_vertex_ai
    test "handles different locations", %{project_id: project_id} do
      # Test with a different location (if available)
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :vertex_ai,
          project_id: project_id,
          location: "us-central1",
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      assert :ok = Session.connect(session)
      assert Session.status(session) == :ready

      Session.close(session)
    end
  end

  describe "Vertex AI with system instruction" do
    @tag :live_vertex_ai
    test "respects system instruction", %{project_id: project_id} do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :vertex_ai,
          project_id: project_id,
          location: "us-central1",
          generation_config: %{response_modalities: ["TEXT"]},
          system_instruction:
            "You are a helpful assistant that always starts responses with 'Certainly!'",
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 10_000

      :ok = Session.send_client_content(session, "Tell me a joke")
      assert_receive {:msg, %{server_content: _}}, 15_000

      Session.close(session)
    end
  end
end
