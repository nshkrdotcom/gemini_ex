defmodule Gemini.Types.Live.RealtimeInputConfig do
  @moduledoc """
  Realtime input configuration for Live API sessions.

  Configures the realtime input behavior in BidiGenerateContent, including
  automatic activity detection, activity handling (barge-in behavior),
  and turn coverage settings.

  ## Fields

  - `automatic_activity_detection` - Configuration for automatic voice/text detection
  - `activity_handling` - What effect activity has on model generation
  - `turn_coverage` - Which input is included in the user's turn

  ## Example

      %RealtimeInputConfig{
        automatic_activity_detection: %AutomaticActivityDetection{disabled: false},
        activity_handling: :start_of_activity_interrupts,
        turn_coverage: :turn_includes_only_activity
      }
  """

  alias Gemini.Types.Live.AutomaticActivityDetection
  alias Gemini.Types.Live.Enums.{ActivityHandling, TurnCoverage}

  @type t :: %__MODULE__{
          automatic_activity_detection: AutomaticActivityDetection.t() | nil,
          activity_handling: ActivityHandling.t() | nil,
          turn_coverage: TurnCoverage.t() | nil
        }

  defstruct [:automatic_activity_detection, :activity_handling, :turn_coverage]

  @doc """
  Creates a new RealtimeInputConfig.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      automatic_activity_detection: Keyword.get(opts, :automatic_activity_detection),
      activity_handling: Keyword.get(opts, :activity_handling),
      turn_coverage: Keyword.get(opts, :turn_coverage)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put(
      "automaticActivityDetection",
      AutomaticActivityDetection.to_api(value.automatic_activity_detection)
    )
    |> maybe_put(
      "activityHandling",
      if(value.activity_handling, do: ActivityHandling.to_api(value.activity_handling))
    )
    |> maybe_put(
      "turnCoverage",
      if(value.turn_coverage, do: TurnCoverage.to_api(value.turn_coverage))
    )
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      automatic_activity_detection:
        (data["automaticActivityDetection"] || data["automatic_activity_detection"])
        |> AutomaticActivityDetection.from_api(),
      activity_handling:
        (data["activityHandling"] || data["activity_handling"])
        |> ActivityHandling.from_api(),
      turn_coverage:
        (data["turnCoverage"] || data["turn_coverage"])
        |> TurnCoverage.from_api()
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
