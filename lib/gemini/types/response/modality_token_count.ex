defmodule Gemini.Types.Response.ModalityTokenCount do
  @moduledoc """
  Token counting information for a single modality.
  """

  use TypedStruct

  alias Gemini.Types.Modality

  @derive Jason.Encoder
  typedstruct do
    field(:modality, Modality.t() | :document | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
  end

  @doc """
  Parse from API payload.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      modality:
        data
        |> Map.get("modality")
        |> Kernel.||(Map.get(data, :modality))
        |> Modality.from_api(),
      token_count: Map.get(data, "tokenCount") || Map.get(data, :token_count)
    }
  end

  @doc """
  Convert to API payload map.
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = data) do
    %{
      "modality" => Modality.to_api(data.modality),
      "tokenCount" => data.token_count
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
