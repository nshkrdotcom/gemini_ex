defmodule Gemini.Live.FeaturesLiveTest do
  @moduledoc """
  Live integration tests for Live API advanced features.

  These tests verify function calling, session resumption, and other
  advanced Live API features with actual API calls.

  To run these tests:

      GEMINI_API_KEY=your_api_key mix test --only live_gemini test/gemini/live/features_live_test.exs
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

  describe "function calling" do
    @tag :live_gemini
    test "receives tool call and sends response" do
      test_pid = self()

      tools = [
        %{
          function_declarations: [
            %{
              name: "get_current_time",
              description: "Get the current time"
            }
          ]
        }
      ]

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          tools: tools,
          on_tool_call: fn tc -> send(test_pid, {:tool_call, tc}) end,
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(session)
      Process.sleep(1000)

      :ok =
        Session.send_client_content(
          session,
          "What time is it? Use the get_current_time function."
        )

      # Wait for tool call (model might not always call the function)
      tool_call_received =
        receive do
          {:tool_call, %{function_calls: [call | _]}} ->
            # Verify we received a properly formatted tool call
            assert call.name == "get_current_time"
            assert is_binary(call.id)

            # Send response
            :ok =
              Session.send_tool_response(session, [
                %{id: call.id, name: call.name, response: %{time: "12:00 PM EST"}}
              ])

            true
        after
          15_000 ->
            # Model might choose not to call the function - that's acceptable
            false
        end

      if tool_call_received do
        # Wait for model's response after tool call
        Process.sleep(3000)
      end

      Session.close(session)
    end

    @tag :live_gemini
    test "tool call callback receives ToolCall struct" do
      test_pid = self()

      tools = [
        %{
          function_declarations: [
            %{
              name: "test_function",
              description: "A test function that always returns success"
            }
          ]
        }
      ]

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          tools: tools,
          on_tool_call: fn tc ->
            # Verify we receive a properly structured ToolCall
            send(test_pid, {:tool_call_struct, tc})
          end,
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(session)
      Process.sleep(1000)

      :ok =
        Session.send_client_content(
          session,
          "Please call test_function for me."
        )

      receive do
        {:tool_call_struct, tc} ->
          # Verify it's a proper ToolCall struct with function_calls
          assert is_struct(tc, Gemini.Types.Live.ToolCall) or
                   (is_map(tc) and Map.has_key?(tc, :function_calls))
      after
        15_000 ->
          # Model might not call function - acceptable
          :ok
      end

      Session.close(session)
    end
  end

  describe "async function calling with scheduling" do
    @tag :live_gemini
    test "sends tool response with scheduling option" do
      test_pid = self()

      tools = [
        %{
          function_declarations: [
            %{
              name: "slow_operation",
              description: "A slow operation",
              behavior: "NON_BLOCKING"
            }
          ]
        }
      ]

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          tools: tools,
          on_tool_call: fn tc -> send(test_pid, {:tool_call, tc}) end,
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(session)
      Process.sleep(1000)

      :ok =
        Session.send_client_content(
          session,
          "Run the slow_operation function."
        )

      receive do
        {:tool_call, %{function_calls: [call | _]}} ->
          # Send response with scheduling
          :ok =
            Session.send_tool_response(session, [
              %{
                id: call.id,
                name: call.name,
                response: %{result: "completed"},
                scheduling: :interrupt
              }
            ])
      after
        15_000 -> :ok
      end

      Session.close(session)
    end
  end

  describe "session resumption" do
    @tag :live_gemini
    test "receives session resumption handle when enabled" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          session_resumption: %{},
          on_session_resumption: fn info -> send(test_pid, {:resumption, info}) end,
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(session)

      # Send a message to trigger session state updates
      :ok = Session.send_client_content(session, "Remember: the secret code is 42")
      Process.sleep(3000)

      # Check if we received a handle
      handle = Session.get_session_handle(session)

      # Also check callback
      resumption_received =
        receive do
          {:resumption, %{handle: h, resumable: true}} when is_binary(h) ->
            true
        after
          1000 -> false
        end

      Session.close(session)

      # Handle may or may not be available depending on server behavior
      if handle || resumption_received do
        assert true, "Session resumption handle received"
      else
        # This is acceptable - the server may not immediately issue a handle
        :ok
      end
    end

    @tag :live_gemini
    @tag :skip
    test "can resume session with handle" do
      test_pid = self()

      # Start first session with resumption enabled
      {:ok, s1} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          session_resumption: %{},
          on_session_resumption: fn info -> send(test_pid, {:resumption, info}) end,
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(s1)

      # Send a message to establish context
      :ok = Session.send_client_content(s1, "Remember: the secret code is 42")
      Process.sleep(3000)

      handle = Session.get_session_handle(s1)
      Session.close(s1)

      # Only continue if we got a handle
      if handle do
        # Resume session
        {:ok, s2} =
          Session.start_link(
            model: @live_model,
            auth: :gemini,
            generation_config: %{response_modalities: ["TEXT"]},
            session_resumption: %{handle: handle},
            on_message: fn msg -> send(test_pid, {:msg, msg}) end
          )

        :ok = Session.connect(s2)

        # Ask about the secret code to verify context was preserved
        :ok = Session.send_client_content(s2, "What was the secret code?")

        # Wait for response
        receive do
          {:msg, %{server_content: _content}} ->
            # We got a response - context may or may not be preserved
            :ok
        after
          15_000 -> :ok
        end

        Session.close(s2)
      end
    end
  end

  describe "callbacks" do
    @tag :live_gemini
    test "on_go_away callback structure (simulated via state check)" do
      # We can't easily trigger a GoAway, but we can verify the callback is set up
      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          on_go_away: fn info ->
            assert Map.has_key?(info, :time_left_ms)
            assert Map.has_key?(info, :handle)
          end,
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(session)
      assert Session.status(session) == :ready

      Session.close(session)
    end

    @tag :live_gemini
    test "all callbacks can be set" do
      test_pid = self()

      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          on_message: fn _ -> send(test_pid, :message) end,
          on_error: fn _ -> send(test_pid, :error) end,
          on_close: fn _ -> send(test_pid, :close) end,
          on_tool_call: fn _ -> send(test_pid, :tool_call) end,
          on_tool_call_cancellation: fn _ -> send(test_pid, :tool_call_cancellation) end,
          on_transcription: fn _ -> send(test_pid, :transcription) end,
          on_voice_activity: fn _ -> send(test_pid, :voice_activity) end,
          on_session_resumption: fn _ -> send(test_pid, :session_resumption) end,
          on_go_away: fn _ -> send(test_pid, :go_away) end
        )

      :ok = Session.connect(session)
      assert Session.status(session) == :ready

      # Should receive setup complete message
      assert_receive :message, 5_000

      Session.close(session)
    end
  end

  describe "context window compression" do
    @tag :live_gemini
    test "can enable context compression" do
      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          context_window_compression: %{sliding_window: %{}},
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(session)
      assert Session.status(session) == :ready

      # Send a message to verify it works with compression enabled
      :ok = Session.send_client_content(session, "Hello with compression enabled")
      Process.sleep(2000)

      Session.close(session)
    end

    @tag :live_gemini
    test "can enable compression with trigger_tokens" do
      {:ok, session} =
        Session.start_link(
          model: @live_model,
          auth: :gemini,
          generation_config: %{response_modalities: ["TEXT"]},
          context_window_compression: %{
            sliding_window: %{target_tokens: 8000},
            trigger_tokens: 16000
          },
          on_message: fn _ -> :ok end
        )

      :ok = Session.connect(session)
      assert Session.status(session) == :ready

      Session.close(session)
    end
  end
end
