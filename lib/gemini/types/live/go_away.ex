defmodule Gemini.Types.Live.GoAway do
  @moduledoc """
  Notice from the server that the connection will soon be terminated.

  When received, clients should prepare to disconnect and optionally
  use session resumption to continue the session on a new connection.

  ## Fields

  - `time_left` - Duration string indicating remaining time before termination

  ## Example

      %GoAway{time_left: "30s"}
  """

  @type t :: %__MODULE__{
          time_left: String.t() | nil
        }

  defstruct [:time_left]

  @doc """
  Creates a new GoAway message.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      time_left: Keyword.get(opts, :time_left)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("timeLeft", value.time_left)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      time_left: data["timeLeft"] || data["time_left"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
