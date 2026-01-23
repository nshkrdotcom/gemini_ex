defmodule Gemini.Types.Live.RealtimeInputConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.{
    AutomaticActivityDetection,
    RealtimeInputConfig
  }

  describe "new/1" do
    test "creates empty config" do
      config = RealtimeInputConfig.new()
      assert config.automatic_activity_detection == nil
      assert config.activity_handling == nil
      assert config.turn_coverage == nil
    end

    test "creates config with all options" do
      config =
        RealtimeInputConfig.new(
          automatic_activity_detection: %AutomaticActivityDetection{
            disabled: false,
            start_of_speech_sensitivity: :high,
            end_of_speech_sensitivity: :low,
            prefix_padding_ms: 100,
            silence_duration_ms: 500
          },
          activity_handling: :no_interruption,
          turn_coverage: :turn_includes_all_input
        )

      assert config.automatic_activity_detection.disabled == false
      assert config.automatic_activity_detection.start_of_speech_sensitivity == :high
      assert config.activity_handling == :no_interruption
      assert config.turn_coverage == :turn_includes_all_input
    end
  end

  describe "to_api/1" do
    test "converts to camelCase format" do
      config =
        RealtimeInputConfig.new(
          automatic_activity_detection: %AutomaticActivityDetection{
            disabled: true,
            prefix_padding_ms: 100
          },
          activity_handling: :no_interruption,
          turn_coverage: :turn_includes_all_input
        )

      api_format = RealtimeInputConfig.to_api(config)

      assert api_format["automaticActivityDetection"]["disabled"] == true
      assert api_format["automaticActivityDetection"]["prefixPaddingMs"] == 100
      assert api_format["activityHandling"] == "NO_INTERRUPTION"
      assert api_format["turnCoverage"] == "TURN_INCLUDES_ALL_INPUT"
    end

    test "excludes nil fields" do
      config = RealtimeInputConfig.new(activity_handling: :no_interruption)
      api_format = RealtimeInputConfig.to_api(config)

      assert api_format["activityHandling"] == "NO_INTERRUPTION"
      refute Map.has_key?(api_format, "automaticActivityDetection")
      refute Map.has_key?(api_format, "turnCoverage")
    end

    test "handles nil input" do
      assert RealtimeInputConfig.to_api(nil) == nil
    end
  end

  describe "from_api/1" do
    test "parses API response" do
      api_data = %{
        "automaticActivityDetection" => %{
          "disabled" => false,
          "startOfSpeechSensitivity" => "START_SENSITIVITY_HIGH",
          "endOfSpeechSensitivity" => "END_SENSITIVITY_LOW",
          "prefixPaddingMs" => 100,
          "silenceDurationMs" => 500
        },
        "activityHandling" => "NO_INTERRUPTION",
        "turnCoverage" => "TURN_INCLUDES_ALL_INPUT"
      }

      config = RealtimeInputConfig.from_api(api_data)

      assert config.automatic_activity_detection.disabled == false
      assert config.automatic_activity_detection.start_of_speech_sensitivity == :high
      assert config.automatic_activity_detection.end_of_speech_sensitivity == :low
      assert config.automatic_activity_detection.prefix_padding_ms == 100
      assert config.activity_handling == :no_interruption
      assert config.turn_coverage == :turn_includes_all_input
    end

    test "handles nil input" do
      assert RealtimeInputConfig.from_api(nil) == nil
    end
  end
end
