defmodule Gemini.Types.Live.ToolCallCancellation do
  @moduledoc """
  Tool call cancellation notification from the server.

  Notification that previously issued tool calls with the specified IDs
  should be cancelled. This occurs when clients interrupt server turns.

  If there were side-effects to those tool calls, clients may attempt
  to undo them.

  ## Fields

  - `ids` - List of tool call IDs to be cancelled

  ## Example

      %ToolCallCancellation{ids: ["call_123", "call_456"]}
  """

  @type t :: %__MODULE__{
          ids: [String.t()] | nil
        }

  defstruct [:ids]

  @doc """
  Creates a new ToolCallCancellation.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      ids: Keyword.get(opts, :ids)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("ids", value.ids)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      ids: data["ids"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
