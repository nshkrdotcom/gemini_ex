defmodule Gemini.Types.SpeechConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{PrebuiltVoiceConfig, SpeechConfig, VoiceConfig}

  describe "to_api/1" do
    test "serializes language and voice" do
      config = %SpeechConfig{
        language_code: "en-US",
        voice_config: %VoiceConfig{
          prebuilt_voice_config: %PrebuiltVoiceConfig{voice_name: "Puck"}
        }
      }

      assert SpeechConfig.to_api(config) == %{
               "languageCode" => "en-US",
               "voiceConfig" => %{
                 "prebuiltVoiceConfig" => %{"voiceName" => "Puck"}
               }
             }
    end
  end

  describe "from_api/1" do
    test "parses nested voice config" do
      payload = %{
        "languageCode" => "fr-FR",
        "voiceConfig" => %{
          "prebuiltVoiceConfig" => %{"voiceName" => "Aoede"}
        }
      }

      assert %SpeechConfig{
               language_code: "fr-FR",
               voice_config: %VoiceConfig{
                 prebuilt_voice_config: %PrebuiltVoiceConfig{voice_name: "Aoede"}
               }
             } = SpeechConfig.from_api(payload)
    end
  end
end
