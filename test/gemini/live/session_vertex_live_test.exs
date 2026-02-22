defmodule Gemini.Live.SessionVertexLiveTest do
  @moduledoc """
  Live integration tests for Gemini.Live.Session with Vertex AI.

  These tests make actual API calls to the Vertex AI Live API.
  They are tagged with :live_vertex_ai and skipped by default.

  To run these tests, you need either:
  - VERTEX_PROJECT_ID and VERTEX_SERVICE_ACCOUNT environment variables
  - Or VERTEX_PROJECT_ID and VERTEX_ACCESS_TOKEN environment variables
  - Or VERTEX_PROJECT_ID and GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable

  Example:

      RUN_BILLED_VERTEX_LIVE_TESTS=1 VERTEX_PROJECT_ID=your-project VERTEX_SERVICE_ACCOUNT=/path/to/key.json mix test --only live_vertex_ai
  """

  use ExUnit.Case, async: false

  alias Gemini.Live.Session

  @moduletag :live_vertex_ai

  @live_model "gemini-2.5-flash-native-audio-preview-12-2025"
  @run_billed_live_tests System.get_env("RUN_BILLED_VERTEX_LIVE_TESTS") in [
                           "1",
                           "true",
                           "TRUE",
                           "yes",
                           "YES"
                         ]
  @project_id System.get_env("VERTEX_PROJECT_ID")
  @has_auth Enum.any?(
              [
                System.get_env("VERTEX_SERVICE_ACCOUNT"),
                System.get_env("VERTEX_ACCESS_TOKEN"),
                System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
              ],
              fn value -> is_binary(value) and value != "" end
            )

  if not @run_billed_live_tests do
    @moduletag skip: "Set RUN_BILLED_VERTEX_LIVE_TESTS=1 to run billed Vertex live tests"
  end

  if is_nil(@project_id) or @project_id == "" do
    @moduletag skip: "VERTEX_PROJECT_ID required"
  end

  if not @has_auth do
    @moduletag skip:
                 "One of VERTEX_SERVICE_ACCOUNT, VERTEX_ACCESS_TOKEN, GOOGLE_APPLICATION_CREDENTIALS_JSON required"
  end

  setup do
    {:ok, project_id: System.fetch_env!("VERTEX_PROJECT_ID")}
  end

  describe "Vertex AI connection" do
    if System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") in [nil, ""] do
      @tag :adc_json
      @tag skip: "GOOGLE_APPLICATION_CREDENTIALS_JSON not set"
      @tag :live_vertex_ai
      test "connects using ADC JSON env credentials", _context do
        :ok
      end
    else
      @tag :adc_json
      @tag :live_vertex_ai
      test "connects using ADC JSON env credentials", %{project_id: project_id} do
        test_pid = self()
        {:ok, session} = start_vertex_session(test_pid, project_id)
        assert :ok = Session.connect(session)
        assert Session.status(session) == :ready
        Session.close(session)
      end
    end

    @tag :live_vertex_ai
    test "connects with service account", %{project_id: project_id} do
      test_pid = self()
      {:ok, session} = start_vertex_session(test_pid, project_id)
      assert :ok = Session.connect(session)
      assert Session.status(session) == :ready
      Session.close(session)
    end

    @tag :live_vertex_ai
    test "sends text and receives response", %{project_id: project_id} do
      test_pid = self()
      {:ok, session} = start_vertex_session(test_pid, project_id)
      assert :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 10_000
      :ok = Session.send_client_content(session, "Say hello in one word")
      assert_receive {:msg, %{server_content: content}}, 15_000
      assert content != nil
      Session.close(session)
    end

    @tag :live_vertex_ai
    test "returns error without project_id" do
      result =
        case Session.start_link(model: @live_model, auth: :vertex_ai) do
          {:ok, pid} ->
            connect_result = Session.connect(pid)
            GenServer.stop(pid)
            connect_result

          error ->
            error
        end

      assert {:error, :project_id_required_for_vertex_ai} = result
    end

    @tag :live_vertex_ai
    test "handles different locations", %{project_id: project_id} do
      # Test with a different location (if available)
      test_pid = self()
      {:ok, session} = start_vertex_session(test_pid, project_id)
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

      assert :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 10_000
      :ok = Session.send_client_content(session, "Tell me a joke")
      assert_receive {:msg, %{server_content: _}}, 15_000
      Session.close(session)
    end
  end

  defp start_vertex_session(test_pid, project_id) do
    Session.start_link(
      model: @live_model,
      auth: :vertex_ai,
      project_id: project_id,
      location: "us-central1",
      generation_config: %{response_modalities: ["TEXT"]},
      on_message: fn msg -> send(test_pid, {:msg, msg}) end
    )
  end
end
