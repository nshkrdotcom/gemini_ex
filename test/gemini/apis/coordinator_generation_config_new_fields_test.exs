defmodule Gemini.APIs.CoordinatorGenerationConfigNewFieldsTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.{GenerationConfig, SpeechConfig, VoiceConfig, PrebuiltVoiceConfig}

  describe "__test_build_generation_config__/1" do
    test "includes seed and modalities" do
      config =
        Coordinator.__test_build_generation_config__(
          seed: 99,
          response_modalities: [:text, :audio]
        )

      assert config[:seed] == 99
      assert config[:responseModalities] == ["TEXT", "AUDIO"]
    end

    test "includes media_resolution" do
      config =
        Coordinator.__test_build_generation_config__(media_resolution: :media_resolution_low)

      assert config[:mediaResolution] == "MEDIA_RESOLUTION_LOW"
    end

    test "includes speech_config" do
      voice = %VoiceConfig{prebuilt_voice_config: %PrebuiltVoiceConfig{voice_name: "Puck"}}
      speech = %SpeechConfig{language_code: "en-US", voice_config: voice}

      config = Coordinator.__test_build_generation_config__(speech_config: speech)

      assert config["speechConfig"] == %{
               "languageCode" => "en-US",
               "voiceConfig" => %{"prebuiltVoiceConfig" => %{"voiceName" => "Puck"}}
             }
    end

    test "includes extended image_config fields" do
      config =
        Coordinator.__test_build_generation_config__(
          image_config: %{
            aspect_ratio: "1:1",
            image_size: "2K",
            output_mime_type: "image/jpeg",
            output_compression_quality: 80
          }
        )

      assert config["imageConfig"] == %{
               "aspectRatio" => "1:1",
               "imageSize" => "2K",
               "outputMimeType" => "image/jpeg",
               "outputCompressionQuality" => 80
             }
    end

    test "includes response_json_schema" do
      schema = %{"type" => "object", "properties" => %{"answer" => %{"type" => "string"}}}

      config =
        Coordinator.__test_build_generation_config__(
          response_json_schema: schema,
          response_mime_type: "application/json"
        )

      assert config[:responseJsonSchema] == schema
      assert config[:responseMimeType] == "application/json"
    end
  end

  describe "__test_struct_to_api_map__/1" do
    test "encodes response modalities and media_resolution on struct" do
      gc =
        %GenerationConfig{
          response_modalities: [:text],
          media_resolution: :media_resolution_high
        }

      result = Coordinator.__test_struct_to_api_map__(gc)

      assert (Map.get(result, "responseModalities") || Map.get(result, :responseModalities)) == [
               "TEXT"
             ]

      assert (Map.get(result, "mediaResolution") || Map.get(result, :mediaResolution)) ==
               "MEDIA_RESOLUTION_HIGH"
    end

    test "encodes speech_config on struct" do
      gc = %GenerationConfig{
        speech_config: %SpeechConfig{
          language_code: "en-US",
          voice_config: %VoiceConfig{
            prebuilt_voice_config: %PrebuiltVoiceConfig{voice_name: "Aoede"}
          }
        }
      }

      result = Coordinator.__test_struct_to_api_map__(gc)

      speech_config = Map.get(result, "speechConfig") || Map.get(result, :speechConfig)

      assert speech_config == %{
               "languageCode" => "en-US",
               "voiceConfig" => %{"prebuiltVoiceConfig" => %{"voiceName" => "Aoede"}}
             }
    end

    test "encodes extended image_config on struct" do
      gc = %GenerationConfig{
        image_config: %GenerationConfig.ImageConfig{
          aspect_ratio: "1:1",
          image_size: "4K",
          output_mime_type: "image/png",
          output_compression_quality: 90
        }
      }

      result = Coordinator.__test_struct_to_api_map__(gc)

      image_config = Map.get(result, "imageConfig") || Map.get(result, :imageConfig)

      assert image_config == %{
               "aspectRatio" => "1:1",
               "imageSize" => "4K",
               "outputMimeType" => "image/png",
               "outputCompressionQuality" => 90
             }
    end

    test "encodes response_json_schema on struct" do
      schema = %{"type" => "object", "properties" => %{"value" => %{"type" => "integer"}}}
      gc = %GenerationConfig{response_json_schema: schema}

      result = Coordinator.__test_struct_to_api_map__(gc)

      assert (Map.get(result, "responseJsonSchema") || Map.get(result, :responseJsonSchema)) ==
               schema
    end
  end
end
