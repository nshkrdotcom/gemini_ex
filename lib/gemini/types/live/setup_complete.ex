defmodule Gemini.Types.Live.SetupComplete do
  @moduledoc """
  Setup complete message from the server.

  Sent in response to a Setup message from the client when the session
  is successfully configured and ready for use.

  ## Fields

  - `session_id` - The session ID of the live session

  ## Example

      %SetupComplete{session_id: "session_abc123"}
  """

  @type t :: %__MODULE__{
          session_id: String.t() | nil
        }

  defstruct [:session_id]

  @doc """
  Creates a new SetupComplete.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      session_id: Keyword.get(opts, :session_id)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("sessionId", value.session_id)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      session_id: data["sessionId"] || data["session_id"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
