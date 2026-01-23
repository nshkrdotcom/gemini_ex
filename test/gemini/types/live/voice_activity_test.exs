defmodule Gemini.Types.Live.VoiceActivityTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.VoiceActivity

  describe "new/1" do
    test "creates voice activity with start of speech" do
      va = VoiceActivity.new(vad_signal_type: :start_of_speech)
      assert va.vad_signal_type == :start_of_speech
    end

    test "creates voice activity with end of speech" do
      va = VoiceActivity.new(vad_signal_type: :end_of_speech)
      assert va.vad_signal_type == :end_of_speech
    end

    test "creates empty voice activity" do
      va = VoiceActivity.new()
      assert va.vad_signal_type == nil
    end
  end

  describe "to_api/1" do
    test "converts start_of_speech to API format" do
      va = VoiceActivity.new(vad_signal_type: :start_of_speech)
      api_format = VoiceActivity.to_api(va)

      assert api_format["vadSignalType"] == "START_OF_SPEECH"
    end

    test "converts end_of_speech to API format" do
      va = VoiceActivity.new(vad_signal_type: :end_of_speech)
      api_format = VoiceActivity.to_api(va)

      assert api_format["vadSignalType"] == "END_OF_SPEECH"
    end

    test "handles nil input" do
      assert VoiceActivity.to_api(nil) == nil
    end
  end

  describe "from_api/1" do
    test "parses START_OF_SPEECH" do
      api_data = %{"vadSignalType" => "START_OF_SPEECH"}
      va = VoiceActivity.from_api(api_data)

      assert va.vad_signal_type == :start_of_speech
    end

    test "parses END_OF_SPEECH" do
      api_data = %{"vadSignalType" => "END_OF_SPEECH"}
      va = VoiceActivity.from_api(api_data)

      assert va.vad_signal_type == :end_of_speech
    end

    test "handles nil input" do
      assert VoiceActivity.from_api(nil) == nil
    end
  end
end
