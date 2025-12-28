defmodule Gemini.ThoughtSignaturesTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Chat
  alias Gemini.Types.Part
  alias Gemini.Types.Response.GenerateContentResponse

  describe "Part.with_thought_signature/2" do
    test "adds thought signature to a text part" do
      part = Part.text("Hello")
      signature = "sig_abc123"

      result = Part.with_thought_signature(part, signature)

      assert result.text == "Hello"
      assert result.thought_signature == "sig_abc123"
    end

    test "adds thought signature to an inline data part" do
      part = Part.inline_data("base64data", "image/jpeg")
      signature = "sig_xyz789"

      result = Part.with_thought_signature(part, signature)

      assert result.inline_data != nil
      assert result.thought_signature == "sig_xyz789"
    end
  end

  describe "Gemini.extract_thought_signatures/1" do
    test "extracts thought signatures from response with signatures" do
      response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [
                %{text: "Hello", thought_signature: "sig_part1"},
                %{text: "World", thought_signature: "sig_part2"}
              ]
            }
          }
        ]
      }

      signatures = Gemini.extract_thought_signatures(response)

      assert signatures == ["sig_part1", "sig_part2"]
    end

    test "returns empty list when no signatures present" do
      response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [
                %{text: "Hello"},
                %{text: "World"}
              ]
            }
          }
        ]
      }

      signatures = Gemini.extract_thought_signatures(response)

      assert signatures == []
    end

    test "handles nil response gracefully" do
      assert Gemini.extract_thought_signatures(nil) == []
    end

    test "handles empty candidates" do
      response = %GenerateContentResponse{candidates: []}
      assert Gemini.extract_thought_signatures(response) == []
    end
  end

  describe "Chat thought signature handling" do
    test "new chat starts without signatures" do
      chat = Chat.new()
      assert chat.history == []
      assert Map.get(chat, :last_signatures, []) == [] or is_nil(Map.get(chat, :last_signatures))
    end

    test "add_model_response_with_signatures stores signatures" do
      chat = Chat.new()

      # Simulate a model response with signatures
      response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [
                %{text: "I can help with that.", thought_signature: "sig_model_1"}
              ]
            }
          }
        ]
      }

      updated_chat = Chat.add_model_response(chat, response)

      assert updated_chat.last_signatures == ["sig_model_1"]
    end

    test "next user message includes echoed signatures" do
      chat = Chat.new()

      # Add a model response with signatures
      model_response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [
                %{text: "Here's my answer.", thought_signature: "sig_to_echo"}
              ]
            }
          }
        ]
      }

      chat = Chat.add_model_response(chat, model_response)

      # Add a user follow-up - should include echoed signature
      chat = Chat.add_turn(chat, "user", "What about this?")

      # The last user message should have the signature attached
      last_content = List.last(chat.history)
      assert last_content.role == "user"

      # Check that signature was echoed in the parts
      first_part = hd(last_content.parts)

      assert first_part.thought_signature == "sig_to_echo" or
               Map.get(first_part, :thought_signature) == "sig_to_echo"
    end
  end

  describe "Part serialization includes thought_signature" do
    test "Jason encodes thought_signature" do
      part = %Part{text: "Hello", thought_signature: "sig_123"}

      encoded = Jason.encode!(part)
      decoded = Jason.decode!(encoded)

      assert decoded["thought_signature"] == "sig_123"
    end

    test "thought_signature is included in API format via coordinator" do
      part = %Part{text: "Hello", thought_signature: "sig_456"}

      # Use the coordinator's internal formatting function via a test helper
      api_format = Coordinator.__test_format_part__(part)

      assert api_format[:thoughtSignature] == "sig_456"
      assert api_format[:text] == "Hello"
    end

    test "media_resolution is included in API format" do
      part = Part.inline_data_with_resolution("base64data", "image/jpeg", :high)

      api_format = Coordinator.__test_format_part__(part)

      assert api_format[:mediaResolution] == "MEDIA_RESOLUTION_HIGH"
    end
  end
end
