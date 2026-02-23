defmodule Gemini.ModelRegistryTest do
  use ExUnit.Case, async: true

  alias Gemini.ModelRegistry

  describe "get/1" do
    test "resolves canonical model code" do
      assert %{key: :gemini_3_1_pro_preview, code: "gemini-3.1-pro-preview"} =
               ModelRegistry.get("gemini-3.1-pro-preview")
    end

    test "resolves project-scoped resource names with endpoint suffixes" do
      model_name =
        "projects/test/locations/us-central1/publishers/google/models/gemini-2.5-flash-native-audio-preview-12-2025:bidiGenerateContent"

      assert %{key: :gemini_2_5_flash_native_audio_preview_12_2025} =
               ModelRegistry.get(model_name)
    end
  end

  describe "capability helpers" do
    test "supports?/3 returns capability state match" do
      assert ModelRegistry.supports?("gemini-3.1-pro-preview", :thinking)
      refute ModelRegistry.supports?("gemini-3.1-pro-preview", :live_api)
      assert ModelRegistry.supports?("gemini-2.0-flash", :thinking, :experimental)
    end

    test "with_capability/2 returns matching model codes" do
      supported_live_models = ModelRegistry.with_capability(:live_api, :supported)

      assert "gemini-2.5-flash-native-audio-preview-12-2025" in supported_live_models
      refute "gemini-3.1-pro-preview" in supported_live_models
    end
  end

  describe "live_candidates/2" do
    test "returns ordered live candidates for text and audio" do
      text_candidates = ModelRegistry.live_candidates(:text)
      audio_candidates = ModelRegistry.live_candidates(:audio)

      assert hd(text_candidates) == "gemini-2.5-flash-native-audio-preview-12-2025"
      assert hd(audio_candidates) == "gemini-2.5-flash-native-audio-preview-12-2025"
      assert "gemini-2.5-flash-native-audio-preview-09-2025" in text_candidates
      assert "gemini-2.5-flash-native-audio-latest" in audio_candidates
    end
  end
end
