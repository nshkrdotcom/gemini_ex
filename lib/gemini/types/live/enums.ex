defmodule Gemini.Types.Live.Enums do
  @moduledoc """
  Enumeration types for the Live API (WebSocket).

  This module provides type-safe enums for Live API configuration values,
  including activity handling, speech sensitivity, and turn coverage.

  ## Usage

      alias Gemini.Types.Live.Enums.{ActivityHandling, StartSensitivity, TurnCoverage}

      # Configure activity handling
      handling = ActivityHandling.to_api(:start_of_activity_interrupts)

      # Set speech sensitivity
      sensitivity = StartSensitivity.to_api(:high)
  """

  defmodule ActivityHandling do
    @moduledoc """
    The different ways of handling user activity.

    ## Values

    - `:unspecified` - Default behavior is `START_OF_ACTIVITY_INTERRUPTS`
    - `:start_of_activity_interrupts` - Start of activity will interrupt the model's response (barge in)
    - `:no_interruption` - The model's response will not be interrupted
    """

    @type t :: :unspecified | :start_of_activity_interrupts | :no_interruption

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "ACTIVITY_HANDLING_UNSPECIFIED"
    def to_api(:start_of_activity_interrupts), do: "START_OF_ACTIVITY_INTERRUPTS"
    def to_api(:no_interruption), do: "NO_INTERRUPTION"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("ACTIVITY_HANDLING_UNSPECIFIED"), do: :unspecified
    def from_api("START_OF_ACTIVITY_INTERRUPTS"), do: :start_of_activity_interrupts
    def from_api("NO_INTERRUPTION"), do: :no_interruption
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule StartSensitivity do
    @moduledoc """
    Determines how start of speech is detected.

    ## Values

    - `:unspecified` - Default is HIGH sensitivity
    - `:high` - Automatic detection will detect the start of speech more often
    - `:low` - Automatic detection will detect the start of speech less often
    """

    @type t :: :unspecified | :high | :low

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "START_SENSITIVITY_UNSPECIFIED"
    def to_api(:high), do: "START_SENSITIVITY_HIGH"
    def to_api(:low), do: "START_SENSITIVITY_LOW"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("START_SENSITIVITY_UNSPECIFIED"), do: :unspecified
    def from_api("START_SENSITIVITY_HIGH"), do: :high
    def from_api("START_SENSITIVITY_LOW"), do: :low
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule EndSensitivity do
    @moduledoc """
    Determines how end of speech is detected.

    ## Values

    - `:unspecified` - Default is HIGH sensitivity
    - `:high` - Automatic detection ends speech more often
    - `:low` - Automatic detection ends speech less often
    """

    @type t :: :unspecified | :high | :low

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "END_SENSITIVITY_UNSPECIFIED"
    def to_api(:high), do: "END_SENSITIVITY_HIGH"
    def to_api(:low), do: "END_SENSITIVITY_LOW"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("END_SENSITIVITY_UNSPECIFIED"), do: :unspecified
    def from_api("END_SENSITIVITY_HIGH"), do: :high
    def from_api("END_SENSITIVITY_LOW"), do: :low
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule TurnCoverage do
    @moduledoc """
    Options about which input is included in the user's turn.

    ## Values

    - `:unspecified` - Default behavior is `TURN_INCLUDES_ONLY_ACTIVITY`
    - `:turn_includes_only_activity` - User's turn only includes activity since last turn
    - `:turn_includes_all_input` - User's turn includes all realtime input since last turn
    """

    @type t :: :unspecified | :turn_includes_only_activity | :turn_includes_all_input

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "TURN_COVERAGE_UNSPECIFIED"
    def to_api(:turn_includes_only_activity), do: "TURN_INCLUDES_ONLY_ACTIVITY"
    def to_api(:turn_includes_all_input), do: "TURN_INCLUDES_ALL_INPUT"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("TURN_COVERAGE_UNSPECIFIED"), do: :unspecified
    def from_api("TURN_INCLUDES_ONLY_ACTIVITY"), do: :turn_includes_only_activity
    def from_api("TURN_INCLUDES_ALL_INPUT"), do: :turn_includes_all_input
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule VadSignalType do
    @moduledoc """
    Voice Activity Detection signal types.

    ## Values

    - `:unspecified` - Unspecified signal type
    - `:start_of_speech` - Start of speech detected
    - `:end_of_speech` - End of speech detected
    """

    @type t :: :unspecified | :start_of_speech | :end_of_speech

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "VAD_SIGNAL_TYPE_UNSPECIFIED"
    def to_api(:start_of_speech), do: "START_OF_SPEECH"
    def to_api(:end_of_speech), do: "END_OF_SPEECH"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("VAD_SIGNAL_TYPE_UNSPECIFIED"), do: :unspecified
    def from_api("START_OF_SPEECH"), do: :start_of_speech
    def from_api("END_OF_SPEECH"), do: :end_of_speech
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end
end
