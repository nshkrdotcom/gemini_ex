defmodule Gemini.Types.Live.SessionResumptionUpdate do
  @moduledoc """
  Session resumption state update from the server.

  Only sent if `session_resumption` was set in the connection config.
  Contains information about whether the session can be resumed and the
  handle to use for resumption.

  ## Fields

  - `new_handle` - New handle representing a state that can be resumed. Empty if not resumable.
  - `resumable` - True if the session can be resumed at this point.
  - `last_consumed_client_message_index` - Index of last message processed (only with transparent mode).

  ## Example

      %SessionResumptionUpdate{
        new_handle: "session_handle_123",
        resumable: true,
        last_consumed_client_message_index: 42
      }
  """

  @type t :: %__MODULE__{
          new_handle: String.t() | nil,
          resumable: boolean() | nil,
          last_consumed_client_message_index: integer() | nil
        }

  defstruct [:new_handle, :resumable, :last_consumed_client_message_index]

  @doc """
  Creates a new SessionResumptionUpdate.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      new_handle: Keyword.get(opts, :new_handle),
      resumable: Keyword.get(opts, :resumable),
      last_consumed_client_message_index: Keyword.get(opts, :last_consumed_client_message_index)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("newHandle", value.new_handle)
    |> maybe_put("resumable", value.resumable)
    |> maybe_put("lastConsumedClientMessageIndex", value.last_consumed_client_message_index)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      new_handle: data["newHandle"] || data["new_handle"],
      resumable: data["resumable"],
      last_consumed_client_message_index:
        data["lastConsumedClientMessageIndex"] || data["last_consumed_client_message_index"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
