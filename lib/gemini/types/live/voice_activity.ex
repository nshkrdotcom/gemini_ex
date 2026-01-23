defmodule Gemini.Types.Live.VoiceActivity do
  @moduledoc """
  Voice activity signal for Live API sessions.

  Indicates voice activity detection status in the audio stream.

  ## Fields

  - `vad_signal_type` - The type of voice activity signal (start/end of speech)

  ## Example

      %VoiceActivity{vad_signal_type: :start_of_speech}
  """

  alias Gemini.Types.Live.Enums.VadSignalType

  @type t :: %__MODULE__{
          vad_signal_type: VadSignalType.t() | nil
        }

  defstruct [:vad_signal_type]

  @doc """
  Creates a new VoiceActivity.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      vad_signal_type: Keyword.get(opts, :vad_signal_type)
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
      "vadSignalType",
      if(value.vad_signal_type, do: VadSignalType.to_api(value.vad_signal_type))
    )
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      vad_signal_type:
        (data["vadSignalType"] || data["vad_signal_type"])
        |> VadSignalType.from_api()
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
