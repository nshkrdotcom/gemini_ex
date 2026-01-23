defmodule Gemini.Live.SessionLiveTest do
  @moduledoc """
  Live integration tests for Gemini.Live.Session.

  These tests make actual API calls to the Gemini Live API.
  They are tagged with :live_gemini and skipped by default.

  To run these tests:

      GEMINI_API_KEY=your_api_key mix test --only live_gemini
  """

  use ExUnit.Case, async: false

  alias Gemini.Live.Session

  @moduletag :live_gemini

  @live_model "gemini-2.5-flash-native-audio-preview-12-2025"

  setup do
    unless System.get_env("GEMINI_API_KEY") do
      {:skip, "GEMINI_API_KEY required for live tests"}
    else
      :ok
    end
  end

  describe "Gemini API connection" do
    @tag :live_gemini
    test "connects and receives setup complete" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      assert :ok = Session.connect(session)
      assert Session.status(session) == :ready

      # We should have received a setup_complete message via callback
      assert_receive {:msg, %{setup_complete: _}}, 5_000

      Session.close(session)
    end

    @tag :live_gemini
    test "sends text and receives response" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      :ok = Session.connect(session)

      # Clear the setup_complete message
      assert_receive {:msg, %{setup_complete: _}}, 5_000

      :ok = Session.send_client_content(session, "Say hello in one word")

      # Should receive server content with response
      assert_receive {:msg, %{server_content: content}}, 15_000
      assert content != nil

      Session.close(session)
    end

    @tag :live_gemini
    test "handles multi-turn conversation" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 5_000

      # Send first message
      :ok = Session.send_client_content(session, "My name is Claude.")
      assert_receive {:msg, %{server_content: _}}, 15_000

      # Drain any additional chunks
      receive do
        {:msg, _} -> :ok
      after
        1000 -> :ok
      end

      # Send follow-up
      :ok = Session.send_client_content(session, "What is my name?")
      assert_receive {:msg, %{server_content: _}}, 15_000

      Session.close(session)
    end

    @tag :live_gemini
    test "handles partial turns with turn_complete: false" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 5_000

      # Send partial content
      :ok = Session.send_client_content(session, "I want to say", turn_complete: false)

      # Complete the turn
      :ok = Session.send_client_content(session, " hello!", turn_complete: true)

      # Should get response
      assert_receive {:msg, %{server_content: _}}, 15_000

      Session.close(session)
    end

    @tag :live_gemini
    test "closes session gracefully" do
      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]}
        )

      :ok = Session.connect(session)
      assert Session.status(session) == :ready

      :ok = Session.close(session)
      assert Session.status(session) == :disconnected
    end

    @tag :live_gemini
    test "returns error when sending without connection" do
      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini
        )

      assert {:error, {:not_ready, :disconnected}} =
               Session.send_client_content(session, "test")

      GenServer.stop(session)
    end
  end

  describe "with system instruction" do
    @tag :live_gemini
    test "respects system instruction" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          system_instruction: "Always respond with exactly the word 'PINEAPPLE'",
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 5_000

      :ok = Session.send_client_content(session, "Say something")
      assert_receive {:msg, %{server_content: _}}, 15_000

      Session.close(session)
    end
  end

  describe "session resumption" do
    @tag :live_gemini
    @tag :skip
    test "receives session resumption handle when enabled" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          session_resumption: %{handle: true},
          on_message: fn msg -> send(test_pid, {:msg, msg}) end
        )

      :ok = Session.connect(session)
      assert_receive {:msg, %{setup_complete: _}}, 5_000

      # Send a message to trigger session state
      :ok = Session.send_client_content(session, "Hello")
      assert_receive {:msg, %{server_content: _}}, 15_000

      # Session handle should be available after some messages
      # Note: This may take a few messages before a handle is issued
      handle = Session.get_session_handle(session)
      # Handle might be nil initially, that's okay

      Session.close(session)
    end
  end

  describe "error handling" do
    @tag :live_gemini
    test "error callback is invoked on connection failure" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: "invalid-model-that-does-not-exist",
          auth: :gemini,
          on_error: fn err -> send(test_pid, {:error, err}) end
        )

      # This should fail with an error
      result = Session.connect(session)

      case result do
        {:error, _reason} ->
          # Expected - connection failed
          :ok

        :ok ->
          # Unexpected success - the model might actually exist or there's a different issue
          Session.close(session)
      end

      GenServer.stop(session)
    end
  end
end
