defmodule Gemini.Types.Live.ContextWindowCompression do
  @moduledoc """
  Context window compression configuration for Live API sessions.

  Enables context window compression - a mechanism for managing the model's
  context window so that it does not exceed a given length.

  ## Fields

  - `trigger_tokens` - Number of tokens that triggers compression (default: 80% of context limit)
  - `sliding_window` - Sliding window compression mechanism configuration

  ## Example

      %ContextWindowCompression{
        trigger_tokens: 16000,
        sliding_window: %SlidingWindow{target_tokens: 8000}
      }
  """

  alias Gemini.Types.Live.SlidingWindow

  @type t :: %__MODULE__{
          trigger_tokens: integer() | nil,
          sliding_window: SlidingWindow.t() | nil
        }

  defstruct [:trigger_tokens, :sliding_window]

  @doc """
  Creates a new ContextWindowCompression configuration.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      trigger_tokens: Keyword.get(opts, :trigger_tokens),
      sliding_window: Keyword.get(opts, :sliding_window)
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
    |> maybe_put("triggerTokens", value.trigger_tokens)
    |> maybe_put("slidingWindow", SlidingWindow.to_api(value.sliding_window))
  end

  def to_api(%{} = value) when not is_struct(value) do
    trigger_tokens = fetch_value(value, [:trigger_tokens, "trigger_tokens", "triggerTokens"])

    sliding_window =
      fetch_value(value, [:sliding_window, "sliding_window", "slidingWindow"])

    %{}
    |> maybe_put("triggerTokens", trigger_tokens)
    |> maybe_put("slidingWindow", SlidingWindow.to_api(sliding_window))
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      trigger_tokens: data["triggerTokens"] || data["trigger_tokens"],
      sliding_window:
        (data["slidingWindow"] || data["sliding_window"])
        |> SlidingWindow.from_api()
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
