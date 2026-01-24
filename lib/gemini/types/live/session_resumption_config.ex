defmodule Gemini.Types.Live.SessionResumptionConfig do
  @moduledoc """
  Session resumption configuration for Live API sessions.

  This message is included in the session configuration to enable session
  resumption. If configured, the server will send SessionResumptionUpdate
  messages that can be used to restore the session later.

  ## Fields

  - `handle` - Handle of a previous session to resume. If not present, a new session is created.
  - `transparent` - If set, server sends last_consumed_client_message_index for transparent reconnections.

  ## Example

      # Start new session with resumption enabled
      %SessionResumptionConfig{}

      # Resume previous session
      %SessionResumptionConfig{handle: "previous_session_handle"}
  """

  @type t :: %__MODULE__{
          handle: String.t() | nil,
          transparent: boolean() | nil
        }

  defstruct [:handle, :transparent]

  @doc """
  Creates a new SessionResumptionConfig.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      handle: Keyword.get(opts, :handle),
      transparent: Keyword.get(opts, :transparent)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("handle", value.handle)
    |> maybe_put("transparent", value.transparent)
  end

  # Handle plain maps (common when passing config from examples)
  def to_api(%{} = value) when value == %{}, do: %{}

  def to_api(%{} = value) do
    %{}
    |> maybe_put("handle", fetch_value(value, :handle, "handle"))
    |> maybe_put("transparent", fetch_value(value, :transparent, "transparent"))
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      handle: data["handle"],
      transparent: data["transparent"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp fetch_value(map, atom_key, string_key) do
    cond do
      Map.has_key?(map, atom_key) ->
        Map.get(map, atom_key)

      Map.has_key?(map, string_key) ->
        Map.get(map, string_key)

      true ->
        nil
    end
  end
end
