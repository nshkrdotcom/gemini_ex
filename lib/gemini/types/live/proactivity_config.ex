defmodule Gemini.Types.Live.ProactivityConfig do
  @moduledoc """
  Proactivity configuration for Live API sessions.

  Configures the proactivity features of the model. When enabled, the model
  can respond proactively to input and ignore irrelevant input.

  ## Fields

  - `proactive_audio` - If enabled, the model can reject responding to prompts.
    For example, this allows the model to ignore out of context speech or
    stay silent if the user did not make a request.

  ## Example

      %ProactivityConfig{proactive_audio: true}
  """

  @type t :: %__MODULE__{
          proactive_audio: boolean() | nil
        }

  defstruct [:proactive_audio]

  @doc """
  Creates a new ProactivityConfig.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      proactive_audio: Keyword.get(opts, :proactive_audio)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("proactiveAudio", value.proactive_audio)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      proactive_audio: data["proactiveAudio"] || data["proactive_audio"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
