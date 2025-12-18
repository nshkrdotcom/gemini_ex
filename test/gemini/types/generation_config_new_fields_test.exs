defmodule Gemini.Types.GenerationConfigNewFieldsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{GenerationConfig, SpeechConfig}

  describe "new fields on struct" do
    test "sets seed and response_modalities" do
      config = GenerationConfig.new(seed: 123, response_modalities: [:text, :audio])

      assert config.seed == 123
      assert config.response_modalities == [:text, :audio]
    end

    test "accepts response_json_schema" do
      schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
      config = GenerationConfig.new(response_json_schema: schema)

      assert config.response_json_schema == schema
    end

    test "accepts speech_config and media_resolution" do
      speech = %SpeechConfig{language_code: "en-US"}

      config =
        GenerationConfig.new(speech_config: speech, media_resolution: :media_resolution_high)

      assert config.speech_config == speech
      assert config.media_resolution == :media_resolution_high
    end
  end

  describe "helpers" do
    test "response_modalities/2 sets modalities" do
      config = GenerationConfig.response_modalities([:text, :image])
      assert config.response_modalities == [:text, :image]
    end

    test "seed/2 sets deterministic seed" do
      assert GenerationConfig.seed(GenerationConfig.new(), 77).seed == 77
    end

    test "media_resolution/2 sets resolution" do
      assert GenerationConfig.media_resolution(:media_resolution_low).media_resolution ==
               :media_resolution_low
    end

    test "speech_config/2 sets speech config" do
      config = GenerationConfig.speech_config(%SpeechConfig{language_code: "es-ES"})
      assert %SpeechConfig{language_code: "es-ES"} = config.speech_config
    end
  end
end
