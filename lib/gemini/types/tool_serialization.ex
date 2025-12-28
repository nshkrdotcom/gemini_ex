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
  Convert a list of tools into a Gemini API `tools` list.

  Supports:
  - ADM `FunctionDeclaration` structs
  - Built-in tools (`googleSearch`, `urlContext`, `codeExecution`)
  - Atom shorthand for built-ins (`:google_search`, `:url_context`, `:code_execution`)
  """
  @spec to_api_tool_list(list()) :: api_tool_list()
  def to_api_tool_list(declarations) when is_list(declarations) and declarations != [] do
    if Enum.all?(declarations, &match?(%FunctionDeclaration{}, &1)) do
      [
        %{"functionDeclarations" => Enum.map(declarations, &function_declaration_to_map/1)}
      ]
    else
      Enum.flat_map(declarations, &tool_to_api/1)
    end
  end

  def to_api_tool_list([]), do: []

  defp tool_to_api(%FunctionDeclaration{} = fd) do
    [%{"functionDeclarations" => [function_declaration_to_map(fd)]}]
  end

  defp tool_to_api(declarations) when is_list(declarations) do
    if Enum.all?(declarations, &match?(%FunctionDeclaration{}, &1)) do
      [%{"functionDeclarations" => Enum.map(declarations, &function_declaration_to_map/1)}]
    else
      Enum.flat_map(declarations, &tool_to_api/1)
    end
  end

  defp tool_to_api(:google_search), do: [%{"googleSearch" => %{}}]
  defp tool_to_api(:url_context), do: [%{"urlContext" => %{}}]
  defp tool_to_api(:code_execution), do: [%{"codeExecution" => %{}}]

  defp tool_to_api(%{google_search: _} = tool), do: [camelize_keys(tool)]
  defp tool_to_api(%{googleSearch: _} = tool), do: [tool]
  defp tool_to_api(%{url_context: _} = tool), do: [camelize_keys(tool)]
  defp tool_to_api(%{urlContext: _} = tool), do: [tool]
  defp tool_to_api(%{code_execution: _} = tool), do: [camelize_keys(tool)]
  defp tool_to_api(%{codeExecution: _} = tool), do: [tool]

  defp tool_to_api(%{} = tool), do: [tool]
  defp tool_to_api(_), do: []

  defp function_declaration_to_map(%FunctionDeclaration{
         name: name,
         description: description,
         parameters: parameters
       }) do
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
    Enum.reduce(schema, %{}, &serialize_schema_entry/2)
  end

  defp serialize_schema_value(%{} = value), do: serialize_schema(value)

  defp serialize_schema_value(list) when is_list(list),
    do: Enum.map(list, &serialize_schema_value/1)

  defp serialize_schema_value(value), do: value

  defp serialize_schema_entry({key, value}, acc) do
    if key == :properties or key == "properties" do
      Map.put(acc, "properties", serialize_properties(value))
    else
      Map.put(acc, camelize_key(key), serialize_schema_value(value))
    end
  end

  defp serialize_properties(value) do
    # Do not camelCase property names; they are user-defined parameter names.
    Enum.reduce(value, %{}, fn {prop_key, prop_schema}, props_acc ->
      prop_name = normalize_property_name(prop_key)
      Map.put(props_acc, prop_name, serialize_schema(prop_schema))
    end)
  end

  defp normalize_property_name(prop_key) when is_atom(prop_key), do: Atom.to_string(prop_key)
  defp normalize_property_name(prop_key) when is_binary(prop_key), do: prop_key

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

  defp camelize_keys(%{} = map) do
    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, camelize_key(key), camelize_value(value))
    end)
  end

  defp camelize_value(%{} = value), do: camelize_keys(value)
  defp camelize_value(list) when is_list(list), do: Enum.map(list, &camelize_value/1)
  defp camelize_value(value), do: value

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
