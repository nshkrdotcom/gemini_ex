defmodule Gemini.Types.ToolSerialization do
  @moduledoc """
  Pure data transformation utilities to serialize ALTAR ADM tool structures
  into the exact JSON maps expected by the Gemini API.

  - Converts snake_case atom keys to camelCase string keys
  - Shapes `FunctionDeclaration` into the correct `Tool` list payload
  - Shapes `ToolConfig` into `%{functionCallingConfig: %{...}}`
  """

  alias Altar.ADM.{FunctionDeclaration, ToolConfig}

  @type api_tool :: map()
  @type api_tool_list :: [api_tool]
  @type api_tool_config :: map()

  @doc """
  Convert a list of ADM `FunctionDeclaration` structs into a Gemini API `tools` list.

  Output shape (each entry):
  %{
    "functionDeclarations" => [
      %{
        "name" => String.t(),
        "description" => String.t(),
        "parameters" => map() # OpenAPI-like schema map, passed through as-is
      }
    ]
  }
  """
  @spec to_api_tool_list([FunctionDeclaration.t()]) :: api_tool_list()
  def to_api_tool_list(declarations) when is_list(declarations) do
    # Gemini API expects a list of Tool objects; each Tool wraps a list of function declarations.
    # We place all provided declarations into a single Tool entry per industry docs where a Tool
    # contains `functionDeclarations`.
    # If callers want multiple Tool objects, they can pass multiple groups separately in future.

    if declarations == [] do
      []
    else
      [%{"functionDeclarations" => Enum.map(declarations, &function_declaration_to_map/1)}]
    end
  end

  defp function_declaration_to_map(%FunctionDeclaration{name: name, description: description, parameters: parameters}) do
    %{
      "name" => name,
      "description" => description,
      "parameters" => serialize_schema(parameters)
    }
  end

  # Parameters schema in ADM is already OpenAPI-like maps but uses snake_case keys and UPPERCASE types.
  # We need to recursively convert keys to camelCase strings while preserving values and nested structure.
  @spec serialize_schema(map()) :: map()
  defp serialize_schema(%{} = schema) do
    schema
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      cond do
        key == :properties or key == "properties" ->
          # Do not camelCase property names; they are user-defined parameter names.
          serialized_properties =
            Enum.reduce(value, %{}, fn {prop_key, prop_schema}, props_acc ->
              prop_name =
                case prop_key do
                  k when is_atom(k) -> Atom.to_string(k)
                  k when is_binary(k) -> k
                end

              Map.put(props_acc, prop_name, serialize_schema(prop_schema))
            end)

          Map.put(acc, "properties", serialized_properties)

        true ->
          camel_key = camelize_key(key)
          Map.put(acc, camel_key, serialize_schema_value(value))
      end
    end)
  end

  defp serialize_schema_value(%{} = value), do: serialize_schema(value)
  defp serialize_schema_value(list) when is_list(list), do: Enum.map(list, &serialize_schema_value/1)
  defp serialize_schema_value(value), do: value

  defp camelize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> camelize_string()
  end

  defp camelize_key(key) when is_binary(key) do
    camelize_string(key)
  end

  defp camelize_string(str) do
    case String.split(str, "_") do
      [] -> ""
      [first | rest] -> first <> Enum.map_join(rest, "", &String.capitalize/1)
    end
  end

  @doc """
  Convert ADM `ToolConfig` into Gemini API `toolConfig` map.

  Input:
  %ToolConfig{mode: :auto | :any | :none, function_names: ["..."]}

  Output:
  %{
    functionCallingConfig: %{
      mode: "AUTO" | "ANY" | "NONE",
      allowedFunctionNames: ["..."] # present only when non-empty
    }
  }
  """
  @spec to_api_tool_config(ToolConfig.t()) :: api_tool_config()
  def to_api_tool_config(%ToolConfig{mode: mode, function_names: names}) do
    mode_str =
      case mode do
        :auto -> "AUTO"
        :any -> "ANY"
        :none -> "NONE"
      end

    base = %{mode: mode_str}

    config =
      case names do
        [] -> base
        [_ | _] -> Map.put(base, :allowedFunctionNames, names)
      end

    %{functionCallingConfig: config}
  end
end
