defmodule Gemini.Types.Live.SetupTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{GenerationConfig, MediaResolution}

  alias Gemini.Types.Live.{
    AudioTranscriptionConfig,
    ContextWindowCompression,
    ProactivityConfig,
    RealtimeInputConfig,
    SessionResumptionConfig,
    Setup,
    SlidingWindow
  }

  describe "new/2" do
    test "creates setup with required model" do
      setup = Setup.new("models/gemini-live-2.5-flash-preview")
      assert setup.model == "models/gemini-live-2.5-flash-preview"
    end

    test "creates setup with generation config" do
      setup =
        Setup.new("models/gemini-live-2.5-flash-preview",
          generation_config: %{response_modalities: [:audio], temperature: 0.7}
        )

      assert setup.model == "models/gemini-live-2.5-flash-preview"
      assert setup.generation_config.response_modalities == [:audio]
      assert setup.generation_config.temperature == 0.7
    end

    test "creates setup with system instruction" do
      setup =
        Setup.new("models/gemini-live-2.5-flash-preview",
          system_instruction: %{parts: [%{text: "Be helpful"}]}
        )

      assert setup.system_instruction.parts == [%{text: "Be helpful"}]
    end

    test "creates setup with all options" do
      setup =
        Setup.new("models/gemini-live-2.5-flash-preview",
          generation_config: %{response_modalities: [:audio]},
          system_instruction: %{parts: [%{text: "Be helpful"}]},
          tools: [%{function_declarations: []}],
          realtime_input_config: %RealtimeInputConfig{activity_handling: :no_interruption},
          session_resumption: %SessionResumptionConfig{transparent: true},
          context_window_compression: %ContextWindowCompression{
            trigger_tokens: 16_000,
            sliding_window: %SlidingWindow{target_tokens: 8000}
          },
          input_audio_transcription: %AudioTranscriptionConfig{},
          output_audio_transcription: %AudioTranscriptionConfig{},
          proactivity: %ProactivityConfig{proactive_audio: true},
          enable_affective_dialog: true
        )

      assert setup.model == "models/gemini-live-2.5-flash-preview"
      assert setup.realtime_input_config.activity_handling == :no_interruption
      assert setup.session_resumption.transparent == true
      assert setup.context_window_compression.trigger_tokens == 16_000
      assert setup.input_audio_transcription == %AudioTranscriptionConfig{}
      assert setup.proactivity.proactive_audio == true
      assert setup.enable_affective_dialog == true
    end

    test "applies model prefix for Vertex model resource names" do
      setup =
        Setup.new("gemini-live-2.5-flash-preview",
          model_prefix: "projects/test-project/locations/us-central1/publishers/google/"
        )

      assert setup.model ==
               "projects/test-project/locations/us-central1/publishers/google/models/gemini-live-2.5-flash-preview"
    end

    test "does not duplicate prefix for already fully qualified Vertex model names" do
      full_model =
        "projects/test-project/locations/us-central1/publishers/google/models/gemini-live-2.5-flash-preview"

      setup =
        Setup.new(full_model,
          model_prefix: "projects/test-project/locations/us-central1/publishers/google/"
        )

      assert setup.model == full_model
    end

    test "adds project/location prefix for publisher-scoped Vertex model names" do
      setup =
        Setup.new("publishers/google/models/gemini-live-2.5-flash",
          model_prefix: "projects/test-project/locations/us-central1/publishers/google/"
        )

      assert setup.model ==
               "projects/test-project/locations/us-central1/publishers/google/models/gemini-live-2.5-flash"
    end
  end

  describe "to_api/1" do
    test "converts to camelCase JSON-compatible map" do
      setup =
        Setup.new("models/gemini-live-2.5-flash-preview",
          generation_config: %{response_modalities: [:audio], temperature: 0.7}
        )

      api_format = Setup.to_api(setup)

      assert api_format["model"] == "models/gemini-live-2.5-flash-preview"
      assert api_format["generationConfig"]["responseModalities"] == ["AUDIO"]
      assert api_format["generationConfig"]["temperature"] == 0.7
    end

    test "excludes nil fields" do
      setup = Setup.new("models/gemini-live-2.5-flash-preview")
      api_format = Setup.to_api(setup)

      assert api_format["model"] == "models/gemini-live-2.5-flash-preview"
      refute Map.has_key?(api_format, "generationConfig")
      refute Map.has_key?(api_format, "tools")
      refute Map.has_key?(api_format, "systemInstruction")
    end

    test "converts system instruction correctly" do
      setup =
        Setup.new("models/gemini-live-2.5-flash-preview",
          system_instruction: %{parts: [%{text: "Be helpful"}]}
        )

      api_format = Setup.to_api(setup)

      assert api_format["systemInstruction"]["parts"] == [%{"text" => "Be helpful"}]
    end

    test "converts speech config correctly" do
      setup =
        Setup.new("models/gemini-live-2.5-flash-preview",
          generation_config: %{
            response_modalities: [:audio],
            speech_config: %{
              voice_config: %{
                prebuilt_voice_config: %{voice_name: "Puck"}
              }
            }
          }
        )

      api_format = Setup.to_api(setup)

      assert api_format["generationConfig"]["responseModalities"] == ["AUDIO"]

      assert api_format["generationConfig"]["speechConfig"]["voiceConfig"][
               "prebuiltVoiceConfig"
             ]["voiceName"] == "Puck"
    end

    test "includes affective dialog and thinking/media resolution in setup" do
      generation_config =
        GenerationConfig.new(
          response_modalities: [:audio],
          thinking_config: %GenerationConfig.ThinkingConfig{
            thinking_budget: 0,
            include_thoughts: true
          },
          media_resolution: :media_resolution_low
        )

      setup =
        Setup.new("models/gemini-2.5-flash-native-audio-preview-12-2025",
          generation_config: generation_config,
          enable_affective_dialog: true
        )

      api_format = Setup.to_api(setup)

      assert api_format["enableAffectiveDialog"] == true
      assert api_format["generationConfig"]["thinkingConfig"]["thinkingBudget"] == 0
      assert api_format["generationConfig"]["thinkingConfig"]["includeThoughts"] == true

      assert api_format["generationConfig"]["mediaResolution"] ==
               MediaResolution.to_api(:media_resolution_low)
    end

    test "handles nil input" do
      assert Setup.to_api(nil) == nil
    end
  end

  describe "from_api/1" do
    test "parses API response" do
      api_data = %{
        "model" => "models/gemini-live-2.5-flash-preview",
        "generationConfig" => %{
          "responseModalities" => ["AUDIO"],
          "temperature" => 0.7,
          "thinkingConfig" => %{
            "thinkingBudget" => 0,
            "includeThoughts" => true
          },
          "mediaResolution" => "MEDIA_RESOLUTION_LOW"
        },
        "systemInstruction" => %{
          "parts" => [%{"text" => "Be helpful"}]
        }
      }

      setup = Setup.from_api(api_data)

      assert setup.model == "models/gemini-live-2.5-flash-preview"
      assert setup.generation_config.response_modalities == [:audio]
      assert setup.generation_config.temperature == 0.7
      assert setup.generation_config.thinking_config.thinking_budget == 0
      assert setup.generation_config.thinking_config.include_thoughts == true
      assert setup.generation_config.media_resolution == :media_resolution_low
      assert setup.system_instruction.parts == [%{"text" => "Be helpful"}]
    end

    test "handles nil input" do
      assert Setup.from_api(nil) == nil
    end
  end
end
