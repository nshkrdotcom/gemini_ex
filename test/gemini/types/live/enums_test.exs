defmodule Gemini.Types.Live.EnumsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.Enums.{
    ActivityHandling,
    EndSensitivity,
    StartSensitivity,
    TurnCoverage,
    VadSignalType
  }

  describe "ActivityHandling" do
    test "to_api/1 converts atoms to API strings" do
      assert ActivityHandling.to_api(:unspecified) == "ACTIVITY_HANDLING_UNSPECIFIED"

      assert ActivityHandling.to_api(:start_of_activity_interrupts) ==
               "START_OF_ACTIVITY_INTERRUPTS"

      assert ActivityHandling.to_api(:no_interruption) == "NO_INTERRUPTION"
    end

    test "from_api/1 converts API strings to atoms" do
      assert ActivityHandling.from_api("ACTIVITY_HANDLING_UNSPECIFIED") == :unspecified

      assert ActivityHandling.from_api("START_OF_ACTIVITY_INTERRUPTS") ==
               :start_of_activity_interrupts

      assert ActivityHandling.from_api("NO_INTERRUPTION") == :no_interruption
    end

    test "from_api/1 handles nil and unknown values" do
      assert ActivityHandling.from_api(nil) == nil
      assert ActivityHandling.from_api("UNKNOWN") == :unspecified
    end
  end

  describe "StartSensitivity" do
    test "to_api/1 converts atoms to API strings" do
      assert StartSensitivity.to_api(:unspecified) == "START_SENSITIVITY_UNSPECIFIED"
      assert StartSensitivity.to_api(:high) == "START_SENSITIVITY_HIGH"
      assert StartSensitivity.to_api(:low) == "START_SENSITIVITY_LOW"
    end

    test "from_api/1 converts API strings to atoms" do
      assert StartSensitivity.from_api("START_SENSITIVITY_UNSPECIFIED") == :unspecified
      assert StartSensitivity.from_api("START_SENSITIVITY_HIGH") == :high
      assert StartSensitivity.from_api("START_SENSITIVITY_LOW") == :low
    end

    test "from_api/1 handles nil and unknown values" do
      assert StartSensitivity.from_api(nil) == nil
      assert StartSensitivity.from_api("UNKNOWN") == :unspecified
    end
  end

  describe "EndSensitivity" do
    test "to_api/1 converts atoms to API strings" do
      assert EndSensitivity.to_api(:unspecified) == "END_SENSITIVITY_UNSPECIFIED"
      assert EndSensitivity.to_api(:high) == "END_SENSITIVITY_HIGH"
      assert EndSensitivity.to_api(:low) == "END_SENSITIVITY_LOW"
    end

    test "from_api/1 converts API strings to atoms" do
      assert EndSensitivity.from_api("END_SENSITIVITY_UNSPECIFIED") == :unspecified
      assert EndSensitivity.from_api("END_SENSITIVITY_HIGH") == :high
      assert EndSensitivity.from_api("END_SENSITIVITY_LOW") == :low
    end

    test "from_api/1 handles nil and unknown values" do
      assert EndSensitivity.from_api(nil) == nil
      assert EndSensitivity.from_api("UNKNOWN") == :unspecified
    end
  end

  describe "TurnCoverage" do
    test "to_api/1 converts atoms to API strings" do
      assert TurnCoverage.to_api(:unspecified) == "TURN_COVERAGE_UNSPECIFIED"
      assert TurnCoverage.to_api(:turn_includes_only_activity) == "TURN_INCLUDES_ONLY_ACTIVITY"
      assert TurnCoverage.to_api(:turn_includes_all_input) == "TURN_INCLUDES_ALL_INPUT"
    end

    test "from_api/1 converts API strings to atoms" do
      assert TurnCoverage.from_api("TURN_COVERAGE_UNSPECIFIED") == :unspecified
      assert TurnCoverage.from_api("TURN_INCLUDES_ONLY_ACTIVITY") == :turn_includes_only_activity
      assert TurnCoverage.from_api("TURN_INCLUDES_ALL_INPUT") == :turn_includes_all_input
    end

    test "from_api/1 handles nil and unknown values" do
      assert TurnCoverage.from_api(nil) == nil
      assert TurnCoverage.from_api("UNKNOWN") == :unspecified
    end
  end

  describe "VadSignalType" do
    test "to_api/1 converts atoms to API strings" do
      assert VadSignalType.to_api(:unspecified) == "VAD_SIGNAL_TYPE_UNSPECIFIED"
      assert VadSignalType.to_api(:start_of_speech) == "START_OF_SPEECH"
      assert VadSignalType.to_api(:end_of_speech) == "END_OF_SPEECH"
    end

    test "from_api/1 converts API strings to atoms" do
      assert VadSignalType.from_api("VAD_SIGNAL_TYPE_UNSPECIFIED") == :unspecified
      assert VadSignalType.from_api("START_OF_SPEECH") == :start_of_speech
      assert VadSignalType.from_api("END_OF_SPEECH") == :end_of_speech
    end

    test "from_api/1 handles nil and unknown values" do
      assert VadSignalType.from_api(nil) == nil
      assert VadSignalType.from_api("UNKNOWN") == :unspecified
    end
  end
end
