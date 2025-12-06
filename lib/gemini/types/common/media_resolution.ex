defmodule Gemini.Types.MediaResolution do
  @moduledoc """
  Media resolution enum for controlling token allocation on media inputs.
  """

  @type t ::
          :media_resolution_unspecified
          | :media_resolution_low
          | :media_resolution_medium
          | :media_resolution_high

  @api_values %{
    "MEDIA_RESOLUTION_UNSPECIFIED" => :media_resolution_unspecified,
    "MEDIA_RESOLUTION_LOW" => :media_resolution_low,
    "MEDIA_RESOLUTION_MEDIUM" => :media_resolution_medium,
    "MEDIA_RESOLUTION_HIGH" => :media_resolution_high
  }

  @reverse_api_values %{
    media_resolution_unspecified: "MEDIA_RESOLUTION_UNSPECIFIED",
    media_resolution_low: "MEDIA_RESOLUTION_LOW",
    media_resolution_medium: "MEDIA_RESOLUTION_MEDIUM",
    media_resolution_high: "MEDIA_RESOLUTION_HIGH"
  }

  @doc """
  Convert API value to enum atom.
  """
  @spec from_api(String.t() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(value) when is_atom(value), do: value

  def from_api(value) when is_binary(value),
    do: Map.get(@api_values, value, :media_resolution_unspecified)

  @doc """
  Convert enum atom to API string.
  """
  @spec to_api(t() | atom() | nil) :: String.t() | nil
  def to_api(nil), do: nil
  def to_api(value) when is_binary(value), do: value
  def to_api(value), do: Map.get(@reverse_api_values, value, "MEDIA_RESOLUTION_UNSPECIFIED")
end
