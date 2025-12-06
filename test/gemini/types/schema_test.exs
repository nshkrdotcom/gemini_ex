defmodule Gemini.Types.SchemaTest do
  @moduledoc """
  Tests for the Schema type which defines JSON Schema for function parameters.
  """

  use ExUnit.Case, async: true

  alias Gemini.Types.Schema

  describe "new/1" do
    test "creates schema with type only" do
      assert {:ok, schema} = Schema.new(type: :string)
      assert schema.type == :string
    end

    test "creates schema with all fields" do
      {:ok, schema} =
        Schema.new(
          type: :object,
          description: "A person object",
          properties: %{
            "name" => %{type: :string, description: "Person's name"},
            "age" => %{type: :integer, description: "Person's age"}
          },
          required: ["name"]
        )

      assert schema.type == :object
      assert schema.description == "A person object"
      assert map_size(schema.properties) == 2
      assert schema.required == ["name"]
    end

    test "creates array schema with items" do
      {:ok, schema} =
        Schema.new(
          type: :array,
          items: %{type: :string},
          description: "List of names"
        )

      assert schema.type == :array
      assert schema.items.type == :string
    end

    test "creates schema with enum" do
      {:ok, schema} =
        Schema.new(
          type: :string,
          enum: ["red", "green", "blue"]
        )

      assert schema.type == :string
      assert schema.enum == ["red", "green", "blue"]
    end
  end

  describe "string/1" do
    test "creates string schema with description" do
      schema = Schema.string("A user's name")

      assert schema.type == :string
      assert schema.description == "A user's name"
    end
  end

  describe "integer/1" do
    test "creates integer schema with description" do
      schema = Schema.integer("User's age")

      assert schema.type == :integer
      assert schema.description == "User's age"
    end
  end

  describe "boolean/1" do
    test "creates boolean schema" do
      schema = Schema.boolean("Is active")

      assert schema.type == :boolean
      assert schema.description == "Is active"
    end
  end

  describe "number/1" do
    test "creates number schema" do
      schema = Schema.number("Price in USD")

      assert schema.type == :number
      assert schema.description == "Price in USD"
    end
  end

  describe "array/2" do
    test "creates array schema with items" do
      items = Schema.string("Item name")
      schema = Schema.array(items, "List of items")

      assert schema.type == :array
      assert schema.items.type == :string
      assert schema.description == "List of items"
    end
  end

  describe "object/2" do
    test "creates object schema with properties" do
      properties = %{
        "name" => Schema.string("Person's name"),
        "email" => Schema.string("Email address")
      }

      schema = Schema.object(properties, required: ["name"], description: "A person")

      assert schema.type == :object
      assert map_size(schema.properties) == 2
      assert schema.required == ["name"]
      assert schema.description == "A person"
    end
  end

  describe "to_api_map/1" do
    test "converts simple schema to API format" do
      schema = Schema.string("A name")
      api_map = Schema.to_api_map(schema)

      assert api_map["type"] == "STRING"
      assert api_map["description"] == "A name"
    end

    test "converts object schema to API format" do
      {:ok, schema} =
        Schema.new(
          type: :object,
          properties: %{
            "name" => %{type: :string},
            "age" => %{type: :integer}
          },
          required: ["name"]
        )

      api_map = Schema.to_api_map(schema)

      assert api_map["type"] == "OBJECT"
      assert is_map(api_map["properties"])
      assert api_map["properties"]["name"]["type"] == "STRING"
      assert api_map["properties"]["age"]["type"] == "INTEGER"
      assert api_map["required"] == ["name"]
    end

    test "converts array schema to API format" do
      schema = Schema.array(Schema.string("Item"), "Items list")
      api_map = Schema.to_api_map(schema)

      assert api_map["type"] == "ARRAY"
      assert api_map["items"]["type"] == "STRING"
    end

    test "converts nested object schema" do
      address_schema =
        Schema.object(%{
          "street" => Schema.string("Street address"),
          "city" => Schema.string("City name")
        })

      person_schema =
        Schema.object(%{
          "name" => Schema.string("Person name"),
          "address" => address_schema
        })

      api_map = Schema.to_api_map(person_schema)

      assert api_map["type"] == "OBJECT"
      assert api_map["properties"]["address"]["type"] == "OBJECT"
      assert api_map["properties"]["address"]["properties"]["city"]["type"] == "STRING"
    end
  end

  describe "from_api_map/1" do
    test "parses simple schema from API format" do
      api_map = %{"type" => "STRING", "description" => "A name"}

      {:ok, schema} = Schema.from_api_map(api_map)

      assert schema.type == :string
      assert schema.description == "A name"
    end

    test "parses object schema from API format" do
      api_map = %{
        "type" => "OBJECT",
        "properties" => %{
          "name" => %{"type" => "STRING"},
          "age" => %{"type" => "INTEGER"}
        },
        "required" => ["name"]
      }

      {:ok, schema} = Schema.from_api_map(api_map)

      assert schema.type == :object
      assert map_size(schema.properties) == 2
      assert schema.required == ["name"]
    end
  end
end
