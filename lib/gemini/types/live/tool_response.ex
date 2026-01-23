defmodule Gemini.Types.Live.ToolResponse do
  @moduledoc """
  Tool response from the client in Live API sessions.

  Client-generated response to a ToolCall received from the server.
  Individual FunctionResponse objects are matched to their respective
  FunctionCall objects by the ID field.

  ## Fields

  - `function_responses` - List of function responses

  ## Example

      %ToolResponse{
        function_responses: [
          %{
            id: "call_123",
            name: "get_weather",
            response: %{content: %{temperature: 72, conditions: "sunny"}}
          }
        ]
      }
  """

  @type function_response :: %{
          optional(:id) => String.t(),
          optional(:name) => String.t(),
          optional(:response) => map()
        }

  @type t :: %__MODULE__{
          function_responses: [function_response()] | nil
        }

  defstruct [:function_responses]

  @doc """
  Creates a new ToolResponse.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      function_responses: Keyword.get(opts, :function_responses)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("functionResponses", convert_function_responses_to_api(value.function_responses))
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      function_responses:
        parse_function_responses(data["functionResponses"] || data["function_responses"])
    }
  end

  defp convert_function_responses_to_api(nil), do: nil

  defp convert_function_responses_to_api(responses) when is_list(responses) do
    Enum.map(responses, fn resp ->
      %{}
      |> maybe_put("id", resp[:id] || resp["id"])
      |> maybe_put("name", resp[:name] || resp["name"])
      |> maybe_put("response", resp[:response] || resp["response"])
    end)
  end

  defp parse_function_responses(nil), do: nil

  defp parse_function_responses(responses) when is_list(responses) do
    Enum.map(responses, fn resp ->
      %{
        id: resp["id"],
        name: resp["name"],
        response: resp["response"]
      }
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
