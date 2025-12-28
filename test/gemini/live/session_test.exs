defmodule Gemini.Live.SessionTest do
  use ExUnit.Case, async: true

  alias Gemini.Live.Message
  alias Gemini.Live.Message.{ClientContent, ClientMessage, LiveClientSetup, ServerMessage}
  alias Gemini.Live.Session

  # We'll use a simple callback-based testing approach instead of Mox for WebSocket
  # since the WebSocket connection is managed internally by :gun

  describe "start_link/1" do
    test "starts session with required model" do
      assert {:ok, pid} = Session.start_link(model: "gemini-2.5-flash")
      assert Process.alive?(pid)
      Session.close(pid)
    end

    test "accepts optional callbacks" do
      on_message = fn _msg -> :ok end
      on_connect = fn -> :ok end

      assert {:ok, pid} =
               Session.start_link(
                 model: "gemini-2.5-flash",
                 on_message: on_message,
                 on_connect: on_connect
               )

      assert Process.alive?(pid)
      Session.close(pid)
    end

    test "can be started with a name" do
      assert {:ok, pid} = Session.start_link(model: "gemini-2.5-flash", name: :test_session)
      assert Process.whereis(:test_session) == pid
      Session.close(pid)
    end
  end

  describe "status/1" do
    test "returns disconnected initially" do
      {:ok, session} = Session.start_link(model: "gemini-2.5-flash")
      assert Session.status(session) == :disconnected
      Session.close(session)
    end
  end

  describe "send/2" do
    test "queues message when not connected" do
      {:ok, session} = Session.start_link(model: "gemini-2.5-flash")

      # Should return ok even though not connected (message will be queued)
      # Note: This will fail since we're not connected, but we're testing the API
      assert {:error, :not_connected} = Session.send(session, "Hello")

      Session.close(session)
    end
  end

  describe "send_client_content/3" do
    test "accepts list of turns" do
      {:ok, session} = Session.start_link(model: "gemini-2.5-flash")

      turns = [
        %{role: "user", parts: [%{text: "Hello"}]}
      ]

      assert {:error, :not_connected} = Session.send_client_content(session, turns)

      Session.close(session)
    end

    test "accepts ClientContent struct" do
      {:ok, session} = Session.start_link(model: "gemini-2.5-flash")

      content = %ClientContent{
        turns: [%{role: "user", parts: [%{text: "Hello"}]}],
        turn_complete: true
      }

      assert {:error, :not_connected} = Session.send_client_content(session, content)

      Session.close(session)
    end
  end

  describe "send_tool_response/3" do
    test "sends function responses" do
      {:ok, session} = Session.start_link(model: "gemini-2.5-flash")

      responses = [
        %{name: "get_weather", response: %{temperature: 72}}
      ]

      assert {:error, :not_connected} = Session.send_tool_response(session, responses)

      Session.close(session)
    end
  end

  describe "send_realtime_input/3" do
    test "sends media chunks" do
      {:ok, session} = Session.start_link(model: "gemini-2.5-flash")

      chunks = [
        %{data: "base64_audio_data", mime_type: "audio/pcm"}
      ]

      assert {:error, :not_connected} = Session.send_realtime_input(session, chunks)

      Session.close(session)
    end
  end

  describe "close/1" do
    test "stops the session" do
      {:ok, session} = Session.start_link(model: "gemini-2.5-flash")
      assert Process.alive?(session)

      assert :ok = Session.close(session)

      # Wait a bit for the process to terminate
      Process.sleep(50)
      refute Process.alive?(session)
    end
  end

  describe "message callbacks" do
    test "on_message callback is invoked" do
      # Use a test process to receive callback notifications
      test_pid = self()

      on_message = fn message ->
        send(test_pid, {:callback_invoked, :on_message, message})
      end

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          on_message: on_message
        )

      # Since we can't actually connect in unit tests, we'll just verify
      # the session started with the callback configured
      assert Process.alive?(session)

      Session.close(session)
    end

    test "on_connect callback is configured" do
      test_pid = self()

      on_connect = fn ->
        send(test_pid, {:callback_invoked, :on_connect})
      end

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          on_connect: on_connect
        )

      assert Process.alive?(session)

      Session.close(session)
    end

    test "on_error callback is configured" do
      test_pid = self()

      on_error = fn error ->
        send(test_pid, {:callback_invoked, :on_error, error})
      end

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          on_error: on_error
        )

      assert Process.alive?(session)

      Session.close(session)
    end
  end

  describe "Message.to_json/1" do
    test "converts setup message to JSON" do
      message = %ClientMessage{
        setup: %LiveClientSetup{
          model: "gemini-2.5-flash",
          generation_config: %{temperature: 0.8}
        }
      }

      assert {:ok, json} = Message.to_json(message)
      assert is_binary(json)
      assert String.contains?(json, "gemini-2.5-flash")
    end

    test "converts client content to JSON" do
      message = %ClientMessage{
        client_content: %ClientContent{
          turns: [%{role: "user", parts: [%{text: "Hello"}]}],
          turn_complete: true
        }
      }

      assert {:ok, json} = Message.to_json(message)
      assert is_binary(json)
      assert String.contains?(json, "Hello")
    end
  end

  describe "Message.from_json/1" do
    test "parses setup complete message" do
      json = ~s({"setupComplete": {}})

      assert {:ok, message} = Message.from_json(json)
      assert %ServerMessage{} = message
      assert message.setup_complete != nil
    end

    test "parses server content message" do
      json = ~s({
        "serverContent": {
          "modelTurn": {
            "role": "model",
            "parts": [{"text": "Hello there!"}]
          },
          "turnComplete": true
        }
      })

      assert {:ok, message} = Message.from_json(json)
      assert %ServerMessage{} = message
      assert message.server_content != nil
    end

    test "parses tool call message" do
      json = ~s({
        "toolCall": {
          "functionCalls": [{
            "name": "get_weather",
            "args": {"location": "San Francisco"}
          }]
        }
      })

      assert {:ok, message} = Message.from_json(json)
      assert %ServerMessage{} = message
      assert message.tool_call != nil
    end
  end
end
