defmodule Gemini.Types.Modality do
  @moduledoc """
  Response modality types for multimodal generation.
  """

  @type t :: :modality_unspecified | :text | :image | :audio

  @api_values %{
    "TEXT" => :text,
    "IMAGE" => :image,
    "AUDIO" => :audio,
    "MODALITY_UNSPECIFIED" => :modality_unspecified
  }

  @reverse_api_values %{
    text: "TEXT",
    image: "IMAGE",
    audio: "AUDIO",
    modality_unspecified: "MODALITY_UNSPECIFIED"
  }

  @doc """
  Convert API modality string to atom.
  """
  @spec from_api(String.t() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(value) when is_atom(value), do: value

  def from_api(value) when is_binary(value),
    do: Map.get(@api_values, value, :modality_unspecified)

  @doc """
  Convert modality atom to API string.
  """
  @spec to_api(t() | nil) :: String.t() | nil
  def to_api(nil), do: nil
  def to_api(value) when is_binary(value), do: value
  def to_api(value), do: Map.get(@reverse_api_values, value, "MODALITY_UNSPECIFIED")
end
