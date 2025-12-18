defmodule Gemini.Types.Interactions.Interaction do
  @moduledoc """
  Interactions `Interaction` resource.

  JSON keys are snake_case, matching the Python SDK and Interactions API.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.{Content, Usage}

  @type status :: String.t()

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:id, String.t())
    field(:status, status())
    field(:agent, String.t(), enforce: false)
    field(:created, DateTime.t(), enforce: false)
    field(:model, String.t(), enforce: false)
    field(:outputs, [Content.t()], enforce: false)
    field(:previous_interaction_id, String.t(), enforce: false)
    field(:role, String.t(), enforce: false)
    field(:updated, DateTime.t(), enforce: false)
    field(:usage, Usage.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = interaction), do: interaction

  def from_api(%{} = data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      status: Map.get(data, "status"),
      agent: Map.get(data, "agent"),
      created: parse_datetime(Map.get(data, "created")),
      model: Map.get(data, "model"),
      outputs: map_list(Map.get(data, "outputs"), &Content.from_api/1),
      previous_interaction_id: Map.get(data, "previous_interaction_id"),
      role: Map.get(data, "role"),
      updated: parse_datetime(Map.get(data, "updated")),
      usage: Usage.from_api(Map.get(data, "usage"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = interaction) do
    %{}
    |> maybe_put("id", interaction.id)
    |> maybe_put("status", interaction.status)
    |> maybe_put("agent", interaction.agent)
    |> maybe_put("created", datetime_to_iso8601(interaction.created))
    |> maybe_put("model", interaction.model)
    |> maybe_put("outputs", map_list(interaction.outputs, &Content.to_api/1))
    |> maybe_put("previous_interaction_id", interaction.previous_interaction_id)
    |> maybe_put("role", interaction.role)
    |> maybe_put("updated", datetime_to_iso8601(interaction.updated))
    |> maybe_put("usage", Usage.to_api(interaction.usage))
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp map_list(nil, _fun), do: nil

  defp map_list(list, fun) when is_list(list) do
    Enum.map(list, fun)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Turn do
  @moduledoc """
  A conversation turn in the Interactions API.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Content

  @type content :: String.t() | [Content.t()] | nil

  @derive Jason.Encoder
  typedstruct do
    field(:role, String.t())
    field(:content, content())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = turn), do: turn

  def from_api(%{} = data) do
    %__MODULE__{
      role: Map.get(data, "role"),
      content: parse_content(Map.get(data, "content"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = turn) do
    %{}
    |> maybe_put("role", turn.role)
    |> maybe_put("content", serialize_content(turn.content))
  end

  defp parse_content(nil), do: nil
  defp parse_content(value) when is_binary(value), do: value

  defp parse_content(value) when is_list(value) do
    Enum.map(value, &Content.from_api/1)
  end

  defp parse_content(_), do: nil

  defp serialize_content(nil), do: nil
  defp serialize_content(value) when is_binary(value), do: value

  defp serialize_content(value) when is_list(value) do
    Enum.map(value, &Content.to_api/1)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Input do
  @moduledoc """
  Input union for Interactions `create`.

  Mirrors Python:
  - string
  - single content block
  - list of content blocks
  - list of turns
  """

  alias Gemini.Types.Interactions.{Content, Turn}

  @type t ::
          String.t()
          | Content.t()
          | [Content.t()]
          | [Turn.t()]
          | map()
          | [map()]

  @spec to_api(t()) :: term()
  def to_api(value) when is_binary(value), do: value
  def to_api(%Turn{} = turn), do: Turn.to_api(turn)
  def to_api(%_{} = content), do: Content.to_api(content)
  def to_api(%{} = map), do: map

  def to_api(list) when is_list(list) do
    case list do
      [%Turn{} | _] -> Enum.map(list, &Turn.to_api/1)
      [%_{} | _] -> Enum.map(list, &Content.to_api/1)
      [%{} | _] -> list
      _ -> list
    end
  end

  def to_api(other), do: other
end
