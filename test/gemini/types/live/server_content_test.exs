defmodule Gemini.Types.Live.ServerContentTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.ServerContent

  describe "from_api/1" do
    test "parses Vertex turn completion reason enum" do
      content =
        ServerContent.from_api(%{
          "turnComplete" => true,
          "turnCompleteReason" => "NEED_MORE_INPUT"
        })

      assert content.turn_complete == true
      assert content.turn_complete_reason == :need_more_input
    end
  end

  describe "to_api/1" do
    test "serializes turn completion reason enum" do
      content =
        ServerContent.new(
          turn_complete: true,
          turn_complete_reason: :response_rejected
        )

      assert %{
               "turnComplete" => true,
               "turnCompleteReason" => "RESPONSE_REJECTED"
             } = ServerContent.to_api(content)
    end
  end

  describe "extract_text/1" do
    test "falls back to output transcription when model turn has no text parts" do
      content =
        ServerContent.new(
          model_turn: %{
            parts: [%{inline_data: %{data: "AAA=", mime_type: "audio/pcm;rate=24000"}}]
          },
          output_transcription: %{text: "Hello from transcript"}
        )

      assert ServerContent.extract_text(content) == "Hello from transcript"
    end
  end
end
