defmodule Gemini.Types.Live.ToolCall do
  @moduledoc """
  Tool call request from the server in Live API sessions.

  Request for the client to execute the function calls and return
  the responses with matching IDs.

  ## Fields

  - `function_calls` - List of function calls to be executed

  ## Example

      %ToolCall{
        function_calls: [
          %{
            "id" => "call_123",
            "name" => "get_weather",
            "args" => %{"location" => "Seattle"}
          }
        ]
      }
  """

  @type function_call :: %{
          optional(:id) => String.t(),
          optional(:name) => String.t(),
          optional(:args) => map()
        }

  @type t :: %__MODULE__{
          function_calls: [function_call()] | nil
        }

  defstruct [:function_calls]

  @doc """
  Creates a new ToolCall.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      function_calls: Keyword.get(opts, :function_calls)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("functionCalls", convert_function_calls_to_api(value.function_calls))
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      function_calls: parse_function_calls(data["functionCalls"] || data["function_calls"])
    }
  end

  defp convert_function_calls_to_api(nil), do: nil

  defp convert_function_calls_to_api(calls) when is_list(calls) do
    Enum.map(calls, fn call ->
      %{}
      |> maybe_put("id", call[:id] || call["id"])
      |> maybe_put("name", call[:name] || call["name"])
      |> maybe_put("args", call[:args] || call["args"])
    end)
  end

  defp parse_function_calls(nil), do: nil

  defp parse_function_calls(calls) when is_list(calls) do
    Enum.map(calls, fn call ->
      %{
        id: call["id"],
        name: call["name"],
        args: call["args"]
      }
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
