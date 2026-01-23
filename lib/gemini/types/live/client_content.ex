defmodule Gemini.Types.Live.ClientContent do
  @moduledoc """
  Client content message for Live API sessions.

  Incremental update of the current conversation delivered from the client.
  All content is unconditionally appended to the conversation history and
  used as part of the prompt to generate content.

  A message here will interrupt any current model generation.

  ## Fields

  - `turns` - Content appended to the current conversation. For single-turn queries,
    this is a single instance. For multi-turn queries, this contains conversation
    history and the latest request.
  - `turn_complete` - If true, indicates that server content generation should start
    with the currently accumulated prompt.

  ## Example

      %ClientContent{
        turns: [
          %{role: "user", parts: [%{text: "Hello!"}]}
        ],
        turn_complete: true
      }
  """

  alias Gemini.Types.Content

  @type t :: %__MODULE__{
          turns: [Content.t() | map()] | nil,
          turn_complete: boolean() | nil
        }

  defstruct [:turns, :turn_complete]

  @doc """
  Creates a new ClientContent.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      turns: Keyword.get(opts, :turns),
      turn_complete: Keyword.get(opts, :turn_complete)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("turns", convert_turns_to_api(value.turns))
    |> maybe_put("turnComplete", value.turn_complete)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      turns: parse_turns(data["turns"]),
      turn_complete: data["turnComplete"] || data["turn_complete"]
    }
  end

  defp convert_turns_to_api(nil), do: nil

  defp convert_turns_to_api(turns) when is_list(turns) do
    Enum.map(turns, fn turn ->
      case turn do
        %Content{} = content ->
          %{
            "role" => content.role,
            "parts" => convert_parts_to_api(content.parts)
          }

        %{role: role, parts: parts} ->
          %{
            "role" => role,
            "parts" => convert_parts_to_api(parts)
          }

        %{"role" => _role} = map ->
          map

        other ->
          other
      end
    end)
  end

  defp convert_parts_to_api(parts) when is_list(parts) do
    Enum.map(parts, fn part ->
      case part do
        %{text: text} -> %{"text" => text}
        %{"text" => _text} = map -> map
        other -> other
      end
    end)
  end

  defp convert_parts_to_api(other), do: other

  defp parse_turns(nil), do: nil

  defp parse_turns(turns) when is_list(turns) do
    Enum.map(turns, fn turn ->
      %{
        role: turn["role"],
        parts: parse_parts(turn["parts"])
      }
    end)
  end

  defp parse_parts(nil), do: nil

  defp parse_parts(parts) when is_list(parts) do
    Enum.map(parts, fn part ->
      %{
        text: part["text"],
        inline_data: part["inlineData"],
        function_call: part["functionCall"],
        function_response: part["functionResponse"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
