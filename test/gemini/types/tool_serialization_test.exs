defmodule Gemini.Types.ToolSerializationTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.ToolSerialization
  alias Altar.ADM.{FunctionDeclaration, ToolConfig}

  describe "to_api_tool_list/1" do
    test "transforms FunctionDeclaration into API tool list with camelCase keys and schema" do
      decl = %FunctionDeclaration{
        name: "get_weather",
        description: "Gets the weather",
        parameters: %{
          type: "OBJECT",
          properties: %{
            location: %{type: "STRING", description: "City, State"},
            days: %{type: "INTEGER"},
            units: %{type: "STRING", enum: ["celsius", "fahrenheit"]}
          },
          required: ["location"]
        }
      }

      [tool] = ToolSerialization.to_api_tool_list([decl])

      assert %{"functionDeclarations" => [fd]} = tool
      assert fd["name"] == "get_weather"
      assert fd["description"] == "Gets the weather"

      # parameters should have camelCase keys and preserve values
      params = fd["parameters"]
      assert Map.has_key?(params, "type")
      assert Map.has_key?(params, "properties")
      assert Map.has_key?(params, "required")

      # nested keys inside properties should also be converted
      props = params["properties"]
      # property names are user-defined keys and should remain as-is (strings)
      assert %{
               "location" => %{"type" => "STRING", "description" => "City, State"},
               "days" => %{"type" => "INTEGER"},
               "units" => %{"type" => "STRING", "enum" => ["celsius", "fahrenheit"]}
             } = props

      # required remains as-is
      assert params["required"] == ["location"]
    end

    test "returns empty list when no declarations provided" do
      assert ToolSerialization.to_api_tool_list([]) == []
    end
  end

  describe "to_api_tool_config/1" do
    test "serializes :auto mode without allowedFunctionNames when empty" do
      cfg = %ToolConfig{mode: :auto, function_names: []}
      assert %{functionCallingConfig: %{mode: "AUTO"}} = ToolSerialization.to_api_tool_config(cfg)
    end

    test "serializes :any mode with allowedFunctionNames when provided" do
      cfg = %ToolConfig{mode: :any, function_names: ["get_weather", "get_time"]}

      assert %{
               functionCallingConfig: %{
                 mode: "ANY",
                 allowedFunctionNames: ["get_weather", "get_time"]
               }
             } = ToolSerialization.to_api_tool_config(cfg)
    end

    test "serializes :none mode" do
      cfg = %ToolConfig{mode: :none, function_names: []}
      assert %{functionCallingConfig: %{mode: "NONE"}} = ToolSerialization.to_api_tool_config(cfg)
    end
  end
end
