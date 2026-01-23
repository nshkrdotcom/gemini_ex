defmodule Gemini.Types.Live.Transcription do
  @moduledoc """
  Transcription of audio (input or output) in Live API sessions.

  Represents the text transcription of audio content. Transcriptions are sent
  independently of other server messages and there is no guaranteed ordering.

  ## Fields

  - `text` - The transcription text

  ## Example

      %Transcription{text: "Hello, how can I help you today?"}
  """

  @type t :: %__MODULE__{
          text: String.t() | nil
        }

  defstruct [:text]

  @doc """
  Creates a new Transcription.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      text: Keyword.get(opts, :text)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("text", value.text)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      text: data["text"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
