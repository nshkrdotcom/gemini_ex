defmodule Gemini.Types.Live.AutomaticActivityDetection do
  @moduledoc """
  Automatic activity detection configuration for Live API sessions.

  Configures automatic detection of user activity (voice and text input).
  When enabled (the default), the server automatically detects when the
  user starts and stops speaking.

  ## Fields

  - `disabled` - If true, automatic detection is disabled and client must send activity signals
  - `start_of_speech_sensitivity` - How likely speech is to be detected at start
  - `end_of_speech_sensitivity` - How likely detected speech is to end
  - `prefix_padding_ms` - Duration of speech required before start-of-speech is committed
  - `silence_duration_ms` - Duration of silence required before end-of-speech is committed

  ## Example

      %AutomaticActivityDetection{
        disabled: false,
        start_of_speech_sensitivity: :high,
        end_of_speech_sensitivity: :low,
        prefix_padding_ms: 100,
        silence_duration_ms: 500
      }
  """

  alias Gemini.Types.Live.Enums.{EndSensitivity, StartSensitivity}

  @type t :: %__MODULE__{
          disabled: boolean() | nil,
          start_of_speech_sensitivity: StartSensitivity.t() | nil,
          end_of_speech_sensitivity: EndSensitivity.t() | nil,
          prefix_padding_ms: integer() | nil,
          silence_duration_ms: integer() | nil
        }

  defstruct [
    :disabled,
    :start_of_speech_sensitivity,
    :end_of_speech_sensitivity,
    :prefix_padding_ms,
    :silence_duration_ms
  ]

  @doc """
  Creates a new AutomaticActivityDetection configuration.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      disabled: Keyword.get(opts, :disabled),
      start_of_speech_sensitivity: Keyword.get(opts, :start_of_speech_sensitivity),
      end_of_speech_sensitivity: Keyword.get(opts, :end_of_speech_sensitivity),
      prefix_padding_ms: Keyword.get(opts, :prefix_padding_ms),
      silence_duration_ms: Keyword.get(opts, :silence_duration_ms)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("disabled", value.disabled)
    |> maybe_put(
      "startOfSpeechSensitivity",
      normalize_enum(value.start_of_speech_sensitivity, &StartSensitivity.to_api/1)
    )
    |> maybe_put(
      "endOfSpeechSensitivity",
      normalize_enum(value.end_of_speech_sensitivity, &EndSensitivity.to_api/1)
    )
    |> maybe_put("prefixPaddingMs", value.prefix_padding_ms)
    |> maybe_put("silenceDurationMs", value.silence_duration_ms)
  end

  def to_api(%{} = value) do
    %{}
    |> maybe_put("disabled", fetch_value(value, [:disabled, "disabled"]))
    |> maybe_put(
      "startOfSpeechSensitivity",
      fetch_enum(
        value,
        [:start_of_speech_sensitivity, "startOfSpeechSensitivity", "start_of_speech_sensitivity"],
        &StartSensitivity.to_api/1
      )
    )
    |> maybe_put(
      "endOfSpeechSensitivity",
      fetch_enum(
        value,
        [:end_of_speech_sensitivity, "endOfSpeechSensitivity", "end_of_speech_sensitivity"],
        &EndSensitivity.to_api/1
      )
    )
    |> maybe_put(
      "prefixPaddingMs",
      fetch_value(value, [:prefix_padding_ms, "prefixPaddingMs", "prefix_padding_ms"])
    )
    |> maybe_put(
      "silenceDurationMs",
      fetch_value(value, [:silence_duration_ms, "silenceDurationMs", "silence_duration_ms"])
    )
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      disabled: data["disabled"],
      start_of_speech_sensitivity:
        (data["startOfSpeechSensitivity"] || data["start_of_speech_sensitivity"])
        |> StartSensitivity.from_api(),
      end_of_speech_sensitivity:
        (data["endOfSpeechSensitivity"] || data["end_of_speech_sensitivity"])
        |> EndSensitivity.from_api(),
      prefix_padding_ms: data["prefixPaddingMs"] || data["prefix_padding_ms"],
      silence_duration_ms: data["silenceDurationMs"] || data["silence_duration_ms"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp fetch_enum(map, keys, fun) do
    map
    |> fetch_value(keys)
    |> normalize_enum(fun)
  end

  defp fetch_value(map, keys) do
    Enum.reduce_while(keys, nil, fn key, _acc ->
      if Map.has_key?(map, key) do
        {:halt, Map.get(map, key)}
      else
        {:cont, nil}
      end
    end)
  end

  defp normalize_enum(nil, _fun), do: nil
  defp normalize_enum(value, fun) when is_atom(value), do: fun.(value)
  defp normalize_enum(value, _fun), do: value
end
