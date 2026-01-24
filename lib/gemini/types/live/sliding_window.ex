defmodule Gemini.Types.Live.SlidingWindow do
  @moduledoc """
  Sliding window context compression configuration.

  The SlidingWindow method operates by discarding content at the beginning
  of the context window. The resulting context will always begin at the start
  of a USER role turn. System instructions and any prefix turns will always
  remain at the beginning of the result.

  ## Fields

  - `target_tokens` - Target number of tokens to keep. Default is trigger_tokens/2

  ## Example

      %SlidingWindow{target_tokens: 8000}
  """

  @type t :: %__MODULE__{
          target_tokens: integer() | nil
        }

  defstruct [:target_tokens]

  @doc """
  Creates a new SlidingWindow configuration.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      target_tokens: Keyword.get(opts, :target_tokens)
    }
  end

  @doc """
  Converts to API format (camelCase).

  Accepts structs, maps with atom keys, or maps with string keys.
  Uses fetch_value to properly preserve falsey values like 0 or false.
  """
  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("targetTokens", value.target_tokens)
  end

  def to_api(%{} = value) when not is_struct(value) do
    target_tokens = fetch_value(value, [:target_tokens, "target_tokens", "targetTokens"])

    %{}
    |> maybe_put("targetTokens", target_tokens)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      target_tokens: data["targetTokens"] || data["target_tokens"]
    }
  end

  # Fetches value from map trying multiple keys, preserving falsey values like 0 or false
  defp fetch_value(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} -> {:found, value}
        :error -> nil
      end
    end)
    |> case do
      {:found, value} -> value
      nil -> nil
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
