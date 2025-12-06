defmodule Gemini.Types.FileData do
  @moduledoc """
  URI-based file data reference used in parts and tool results.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:file_uri, String.t(), enforce: true)
    field(:mime_type, String.t(), enforce: true)
    field(:display_name, String.t() | nil, default: nil)
  end

  @doc """
  Parse file data from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      file_uri: Map.get(data, "fileUri") || Map.get(data, :file_uri),
      mime_type: Map.get(data, "mimeType") || Map.get(data, :mime_type),
      display_name: Map.get(data, "displayName") || Map.get(data, :display_name)
    }
  end

  @doc """
  Convert file data to API camelCase map.
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = file_data) do
    %{
      "fileUri" => file_data.file_uri,
      "mimeType" => file_data.mime_type,
      "displayName" => file_data.display_name
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
