defmodule Gemini.Types.Live.AudioTranscriptionConfig do
  @moduledoc """
  Audio transcription configuration for Live API sessions.

  This type enables transcription of voice input or model audio output.
  The transcription aligns with the input audio language (for input) or
  the language code specified for output audio (for output).

  ## Example

      # Enable input transcription
      %AudioTranscriptionConfig{}
  """

  @type t :: %__MODULE__{}

  defstruct []

  @doc """
  Creates a new AudioTranscriptionConfig.
  """
  @spec new(keyword()) :: t()
  def new(_opts \\ []) do
    %__MODULE__{}
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%__MODULE__{}), do: %{}

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(_data), do: %__MODULE__{}
end
