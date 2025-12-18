defmodule Gemini.Types.GenerationConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.GenerationConfig

  describe "property_ordering field" do
    test "accepts list of strings" do
      config = GenerationConfig.new(property_ordering: ["a", "b", "c"])
      assert config.property_ordering == ["a", "b", "c"]
    end

    test "defaults to nil" do
      config = GenerationConfig.new()
      assert config.property_ordering == nil
    end

    test "accepts empty list" do
      config = GenerationConfig.new(property_ordering: [])
      assert config.property_ordering == []
    end
  end

  describe "property_ordering/2 helper" do
    test "sets property_ordering" do
      config = GenerationConfig.property_ordering(["x", "y", "z"])
      assert config.property_ordering == ["x", "y", "z"]
    end

    test "works with existing config" do
      config =
        GenerationConfig.new(temperature: 0.5)
        |> GenerationConfig.property_ordering(["a", "b"])

      assert config.temperature == 0.5
      assert config.property_ordering == ["a", "b"]
    end

    test "chains with other helpers" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.json_response()
        |> GenerationConfig.property_ordering(["name", "age"])
        |> GenerationConfig.temperature(0.7)

      assert config.response_mime_type == "application/json"
      assert config.property_ordering == ["name", "age"]
      assert config.temperature == 0.7
    end
  end

  describe "structured_json/2 helper" do
    test "sets both response_mime_type and response_json_schema" do
      schema = %{"type" => "object", "properties" => %{}}
      config = GenerationConfig.structured_json(schema)

      assert config.response_mime_type == "application/json"
      assert config.response_json_schema == schema
    end

    test "works with nil config (default)" do
      schema = %{"type" => "string"}
      config = GenerationConfig.structured_json(schema)

      assert config.response_mime_type == "application/json"
      assert config.response_json_schema == schema
    end

    test "preserves other fields" do
      schema = %{"type" => "object"}

      config =
        GenerationConfig.new(
          temperature: 0.5,
          max_output_tokens: 100
        )
        |> GenerationConfig.structured_json(schema)

      assert config.temperature == 0.5
      assert config.max_output_tokens == 100
      assert config.response_mime_type == "application/json"
      assert config.response_json_schema == schema
    end

    test "chains with property_ordering" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }

      config =
        GenerationConfig.structured_json(schema)
        |> GenerationConfig.property_ordering(["name", "age"])

      assert config.response_mime_type == "application/json"
      assert config.response_json_schema == schema
      assert config.property_ordering == ["name", "age"]
    end

    test "supports internal response_schema when requested" do
      schema = %{"type" => "OBJECT"}

      config = GenerationConfig.structured_json(schema, schema_type: :response_schema)

      assert config.response_schema == schema
      assert config.response_json_schema == nil
    end
  end

  describe "JSON encoding" do
    test "encodes property_ordering correctly" do
      config =
        GenerationConfig.new(
          property_ordering: ["a", "b", "c"],
          temperature: 0.7
        )

      {:ok, encoded} = Jason.encode(config)
      {:ok, decoded} = Jason.decode(encoded)

      assert decoded["property_ordering"] == ["a", "b", "c"]
      assert decoded["temperature"] == 0.7
    end

    test "filters nil property_ordering" do
      config = GenerationConfig.new(property_ordering: nil)
      {:ok, encoded} = Jason.encode(config)
      {:ok, decoded} = Jason.decode(encoded)

      assert decoded["property_ordering"] == nil
    end
  end
end
