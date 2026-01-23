defmodule Gemini.Types.Live.ServerMessageTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.{
    GoAway,
    ServerContent,
    ServerMessage,
    SetupComplete,
    ToolCall
  }

  describe "new/1" do
    test "creates empty server message" do
      msg = ServerMessage.new()
      assert msg.setup_complete == nil
      assert msg.server_content == nil
      assert msg.tool_call == nil
    end

    test "creates server message with setup_complete" do
      msg = ServerMessage.new(setup_complete: %SetupComplete{session_id: "sess_123"})
      assert msg.setup_complete.session_id == "sess_123"
    end

    test "creates server message with server_content" do
      msg =
        ServerMessage.new(
          server_content: %ServerContent{
            model_turn: %{role: "model", parts: [%{text: "Hello!"}]},
            turn_complete: true
          }
        )

      assert msg.server_content.turn_complete == true
    end
  end

  describe "to_api/1" do
    test "converts setup_complete message to API format" do
      msg = ServerMessage.new(setup_complete: %SetupComplete{session_id: "sess_123"})
      api_format = ServerMessage.to_api(msg)

      assert api_format["setupComplete"]["sessionId"] == "sess_123"
    end

    test "converts server_content message to API format" do
      msg =
        ServerMessage.new(
          server_content: %ServerContent{
            model_turn: %{role: "model", parts: [%{text: "Hello!"}]},
            turn_complete: true
          }
        )

      api_format = ServerMessage.to_api(msg)

      assert api_format["serverContent"]["turnComplete"] == true
    end

    test "excludes nil fields" do
      msg = ServerMessage.new(setup_complete: %SetupComplete{})
      api_format = ServerMessage.to_api(msg)

      refute Map.has_key?(api_format, "serverContent")
      refute Map.has_key?(api_format, "toolCall")
    end

    test "handles nil input" do
      assert ServerMessage.to_api(nil) == nil
    end
  end

  describe "from_api/1" do
    test "parses setup_complete message" do
      api_data = %{
        "setupComplete" => %{"sessionId" => "sess_123"}
      }

      msg = ServerMessage.from_api(api_data)

      assert msg.setup_complete.session_id == "sess_123"
    end

    test "parses server_content message" do
      api_data = %{
        "serverContent" => %{
          "modelTurn" => %{
            "role" => "model",
            "parts" => [%{"text" => "Hello!"}]
          },
          "turnComplete" => true
        }
      }

      msg = ServerMessage.from_api(api_data)

      assert msg.server_content.turn_complete == true
      assert msg.server_content.model_turn.role == "model"
    end

    test "parses tool_call message" do
      api_data = %{
        "toolCall" => %{
          "functionCalls" => [
            %{"id" => "call_1", "name" => "get_weather", "args" => %{"location" => "Seattle"}}
          ]
        }
      }

      msg = ServerMessage.from_api(api_data)

      assert length(msg.tool_call.function_calls) == 1
      assert hd(msg.tool_call.function_calls).name == "get_weather"
    end

    test "parses go_away message" do
      api_data = %{
        "goAway" => %{"timeLeft" => "30s"}
      }

      msg = ServerMessage.from_api(api_data)

      assert msg.go_away.time_left == "30s"
    end

    test "parses with usage_metadata" do
      api_data = %{
        "serverContent" => %{"turnComplete" => true},
        "usageMetadata" => %{
          "promptTokenCount" => 100,
          "responseTokenCount" => 50,
          "totalTokenCount" => 150
        }
      }

      msg = ServerMessage.from_api(api_data)

      assert msg.server_content.turn_complete == true
      assert msg.usage_metadata.prompt_token_count == 100
      assert msg.usage_metadata.total_token_count == 150
    end

    test "handles nil input" do
      assert ServerMessage.from_api(nil) == nil
    end
  end

  describe "message_type/1" do
    test "returns :setup_complete for setup complete message" do
      msg = ServerMessage.new(setup_complete: %SetupComplete{})
      assert ServerMessage.message_type(msg) == :setup_complete
    end

    test "returns :server_content for server content message" do
      msg = ServerMessage.new(server_content: %ServerContent{})
      assert ServerMessage.message_type(msg) == :server_content
    end

    test "returns :tool_call for tool call message" do
      msg = ServerMessage.new(tool_call: %ToolCall{})
      assert ServerMessage.message_type(msg) == :tool_call
    end

    test "returns :go_away for go away message" do
      msg = ServerMessage.new(go_away: %GoAway{})
      assert ServerMessage.message_type(msg) == :go_away
    end

    test "returns nil for empty message" do
      msg = ServerMessage.new()
      assert ServerMessage.message_type(msg) == nil
    end
  end

  describe "setup_complete?/1" do
    test "returns true for setup complete message" do
      msg = ServerMessage.new(setup_complete: %SetupComplete{})
      assert ServerMessage.setup_complete?(msg) == true
    end

    test "returns false for other messages" do
      msg = ServerMessage.new(server_content: %ServerContent{})
      assert ServerMessage.setup_complete?(msg) == false
    end
  end

  describe "turn_complete?/1" do
    test "returns true when turn is complete" do
      msg = ServerMessage.new(server_content: %ServerContent{turn_complete: true})
      assert ServerMessage.turn_complete?(msg) == true
    end

    test "returns false when turn is not complete" do
      msg = ServerMessage.new(server_content: %ServerContent{turn_complete: false})
      assert ServerMessage.turn_complete?(msg) == false
    end

    test "returns false for non-server_content messages" do
      msg = ServerMessage.new(setup_complete: %SetupComplete{})
      assert ServerMessage.turn_complete?(msg) == false
    end
  end

  describe "interrupted?/1" do
    test "returns true when interrupted" do
      msg = ServerMessage.new(server_content: %ServerContent{interrupted: true})
      assert ServerMessage.interrupted?(msg) == true
    end

    test "returns false when not interrupted" do
      msg = ServerMessage.new(server_content: %ServerContent{interrupted: false})
      assert ServerMessage.interrupted?(msg) == false
    end
  end

  describe "extract_text/1" do
    test "extracts text from server content" do
      msg =
        ServerMessage.new(
          server_content: %ServerContent{
            model_turn: %{role: "model", parts: [%{text: "Hello!"}, %{text: " World!"}]}
          }
        )

      assert ServerMessage.extract_text(msg) == "Hello! World!"
    end

    test "returns nil for non-server_content messages" do
      msg = ServerMessage.new(setup_complete: %SetupComplete{})
      assert ServerMessage.extract_text(msg) == nil
    end
  end
end
