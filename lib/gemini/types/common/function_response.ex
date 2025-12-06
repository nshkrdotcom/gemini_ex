defmodule Gemini.Types.FunctionResponse do
  @moduledoc """
  Result output of a function call.
  """

  use TypedStruct

  @type scheduling :: :scheduling_unspecified | :silent | :when_idle | :interrupt

  @derive Jason.Encoder
  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:response, map(), enforce: true)
    field(:id, String.t() | nil, default: nil)
    field(:will_continue, boolean() | nil, default: nil)
    field(:scheduling, scheduling() | nil, default: nil)
  end

  @doc """
  Parse function response from API payload.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      name: Map.get(data, "name") || Map.get(data, :name),
      response: Map.get(data, "response") || Map.get(data, :response),
      id: Map.get(data, "id") || Map.get(data, :id),
      will_continue: Map.get(data, "willContinue") || Map.get(data, :will_continue),
      scheduling: scheduling_from_api(Map.get(data, "scheduling") || Map.get(data, :scheduling))
    }
  end

  @doc """
  Convert function response to API camelCase map.
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = data) do
    %{
      "name" => data.name,
      "response" => data.response,
      "id" => data.id,
      "willContinue" => data.will_continue,
      "scheduling" => scheduling_to_api(data.scheduling)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp scheduling_from_api(nil), do: nil
  defp scheduling_from_api("SILENT"), do: :silent
  defp scheduling_from_api("WHEN_IDLE"), do: :when_idle
  defp scheduling_from_api("INTERRUPT"), do: :interrupt
  defp scheduling_from_api("SCHEDULING_UNSPECIFIED"), do: :scheduling_unspecified
  defp scheduling_from_api(atom) when is_atom(atom), do: atom
  defp scheduling_from_api(_), do: :scheduling_unspecified

  defp scheduling_to_api(nil), do: nil
  defp scheduling_to_api(:silent), do: "SILENT"
  defp scheduling_to_api(:when_idle), do: "WHEN_IDLE"
  defp scheduling_to_api(:interrupt), do: "INTERRUPT"
  defp scheduling_to_api(:scheduling_unspecified), do: "SCHEDULING_UNSPECIFIED"
  defp scheduling_to_api(_), do: "SCHEDULING_UNSPECIFIED"
end
