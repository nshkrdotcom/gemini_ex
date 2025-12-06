defmodule Gemini.Types.Schema do
  @moduledoc """
  JSON Schema type for defining function parameters in Gemini tool calling.

  This module provides a structured way to define parameter schemas for function
  declarations. It supports all standard JSON Schema types and converts to the
  Gemini API format (with UPPERCASE type names).

  ## Supported Types

  - `:string` - Text values
  - `:integer` - Whole numbers
  - `:number` - Decimal numbers
  - `:boolean` - True/false values
  - `:array` - Lists of items
  - `:object` - Nested objects with properties

  ## Examples

      # Simple string parameter
      schema = Schema.string("User's name")

      # Object with required fields
      schema = Schema.object(%{
        "name" => Schema.string("Person's name"),
        "age" => Schema.integer("Person's age"),
        "email" => Schema.string("Email address")
      }, required: ["name", "email"])

      # Array of strings
      schema = Schema.array(Schema.string("Tag"), "List of tags")

      # Complex nested schema
      address = Schema.object(%{
        "street" => Schema.string("Street address"),
        "city" => Schema.string("City"),
        "zip" => Schema.string("ZIP code")
      })

      person = Schema.object(%{
        "name" => Schema.string("Full name"),
        "address" => address
      })

  ## API Conversion

  Use `to_api_map/1` to convert to the Gemini API format:

      schema = Schema.string("A name")
      Schema.to_api_map(schema)
      #=> %{"type" => "STRING", "description" => "A name"}

  """

  use TypedStruct

  @type schema_type :: :string | :integer | :number | :boolean | :array | :object

  @derive Jason.Encoder
  typedstruct do
    @typedoc "JSON Schema definition for function parameters"
    field(:type, schema_type(), enforce: true)
    field(:description, String.t() | nil, default: nil)
    field(:enum, [String.t()] | nil, default: nil)
    field(:items, t() | map() | nil, default: nil)
    field(:properties, %{String.t() => t() | map()} | nil, default: nil)
    field(:required, [String.t()] | nil, default: nil)
    field(:nullable, boolean() | nil, default: nil)
    field(:format, String.t() | nil, default: nil)
    field(:minimum, number() | nil, default: nil)
    field(:maximum, number() | nil, default: nil)
    field(:min_items, non_neg_integer() | nil, default: nil)
    field(:max_items, non_neg_integer() | nil, default: nil)
    field(:pattern, String.t() | nil, default: nil)
    field(:default, term(), default: nil)
  end

  @doc """
  Create a new Schema with the given options.

  ## Options

  - `:type` (required) - The schema type (`:string`, `:integer`, `:number`, `:boolean`, `:array`, `:object`)
  - `:description` - Human-readable description
  - `:enum` - List of allowed values for strings
  - `:items` - Schema for array items (when type is `:array`)
  - `:properties` - Map of property schemas (when type is `:object`)
  - `:required` - List of required property names
  - `:nullable` - Whether the value can be null
  - `:format` - Format hint (e.g., "date-time", "email")
  - `:minimum` - Minimum value for numbers
  - `:maximum` - Maximum value for numbers
  - `:min_items` - Minimum array length
  - `:max_items` - Maximum array length
  - `:pattern` - Regex pattern for strings
  - `:default` - Default value

  ## Examples

      {:ok, schema} = Schema.new(type: :string, description: "A name")

      {:ok, schema} = Schema.new(
        type: :object,
        properties: %{
          "name" => %{type: :string},
          "age" => %{type: :integer}
        },
        required: ["name"]
      )
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts) when is_list(opts) do
    case Keyword.get(opts, :type) do
      nil ->
        {:error, "type is required"}

      type ->
        items = convert_to_schema(Keyword.get(opts, :items))
        properties = convert_properties(Keyword.get(opts, :properties))

        {:ok,
         %__MODULE__{
           type: type,
           description: Keyword.get(opts, :description),
           enum: Keyword.get(opts, :enum),
           items: items,
           properties: properties,
           required: Keyword.get(opts, :required),
           nullable: Keyword.get(opts, :nullable),
           format: Keyword.get(opts, :format),
           minimum: Keyword.get(opts, :minimum),
           maximum: Keyword.get(opts, :maximum),
           min_items: Keyword.get(opts, :min_items),
           max_items: Keyword.get(opts, :max_items),
           pattern: Keyword.get(opts, :pattern),
           default: Keyword.get(opts, :default)
         }}
    end
  end

  defp convert_properties(nil), do: nil

  defp convert_properties(props) when is_map(props) do
    Map.new(props, fn {k, v} -> {k, convert_to_schema(v)} end)
  end

  # Convert map to Schema struct recursively
  defp convert_to_schema(nil), do: nil
  defp convert_to_schema(%__MODULE__{} = schema), do: schema

  defp convert_to_schema(%{type: type} = map) when is_map(map) do
    items = convert_to_schema(Map.get(map, :items))

    properties =
      case Map.get(map, :properties) do
        nil -> nil
        props when is_map(props) -> Map.new(props, fn {k, v} -> {k, convert_to_schema(v)} end)
      end

    %__MODULE__{
      type: type,
      description: Map.get(map, :description),
      enum: Map.get(map, :enum),
      items: items,
      properties: properties,
      required: Map.get(map, :required),
      nullable: Map.get(map, :nullable),
      format: Map.get(map, :format),
      minimum: Map.get(map, :minimum),
      maximum: Map.get(map, :maximum),
      min_items: Map.get(map, :min_items),
      max_items: Map.get(map, :max_items),
      pattern: Map.get(map, :pattern),
      default: Map.get(map, :default)
    }
  end

  defp convert_to_schema(other), do: other

  @doc """
  Create a string schema with optional description.

  ## Examples

      Schema.string("User's name")
      Schema.string("Status", enum: ["active", "inactive"])
  """
  @spec string(String.t() | nil, keyword()) :: t()
  def string(description \\ nil, opts \\ []) do
    %__MODULE__{
      type: :string,
      description: description,
      enum: Keyword.get(opts, :enum),
      format: Keyword.get(opts, :format),
      pattern: Keyword.get(opts, :pattern),
      nullable: Keyword.get(opts, :nullable)
    }
  end

  @doc """
  Create an integer schema with optional description.

  ## Examples

      Schema.integer("User's age")
      Schema.integer("Count", minimum: 0, maximum: 100)
  """
  @spec integer(String.t() | nil, keyword()) :: t()
  def integer(description \\ nil, opts \\ []) do
    %__MODULE__{
      type: :integer,
      description: description,
      minimum: Keyword.get(opts, :minimum),
      maximum: Keyword.get(opts, :maximum),
      nullable: Keyword.get(opts, :nullable)
    }
  end

  @doc """
  Create a number (float/decimal) schema with optional description.

  ## Examples

      Schema.number("Price in USD")
      Schema.number("Temperature", minimum: -273.15)
  """
  @spec number(String.t() | nil, keyword()) :: t()
  def number(description \\ nil, opts \\ []) do
    %__MODULE__{
      type: :number,
      description: description,
      minimum: Keyword.get(opts, :minimum),
      maximum: Keyword.get(opts, :maximum),
      nullable: Keyword.get(opts, :nullable)
    }
  end

  @doc """
  Create a boolean schema with optional description.

  ## Examples

      Schema.boolean("Is active")
      Schema.boolean("Feature flag")
  """
  @spec boolean(String.t() | nil, keyword()) :: t()
  def boolean(description \\ nil, opts \\ []) do
    %__MODULE__{
      type: :boolean,
      description: description,
      nullable: Keyword.get(opts, :nullable)
    }
  end

  @doc """
  Create an array schema with item schema.

  ## Examples

      Schema.array(Schema.string("Tag"), "List of tags")
      Schema.array(Schema.integer("Score"), "Test scores", min_items: 1)
  """
  @spec array(t() | map(), String.t() | nil, keyword()) :: t()
  def array(items, description \\ nil, opts \\ []) do
    %__MODULE__{
      type: :array,
      items: convert_to_schema(items),
      description: description,
      min_items: Keyword.get(opts, :min_items),
      max_items: Keyword.get(opts, :max_items),
      nullable: Keyword.get(opts, :nullable)
    }
  end

  @doc """
  Create an object schema with properties.

  ## Examples

      Schema.object(%{
        "name" => Schema.string("Person's name"),
        "age" => Schema.integer("Age")
      }, required: ["name"], description: "A person")
  """
  @spec object(%{String.t() => t() | map()}, keyword()) :: t()
  def object(properties, opts \\ []) when is_map(properties) do
    converted_props = Map.new(properties, fn {k, v} -> {k, convert_to_schema(v)} end)

    %__MODULE__{
      type: :object,
      properties: converted_props,
      required: Keyword.get(opts, :required),
      description: Keyword.get(opts, :description),
      nullable: Keyword.get(opts, :nullable)
    }
  end

  @doc """
  Convert a Schema struct to Gemini API map format.

  The Gemini API uses UPPERCASE type names (STRING, INTEGER, etc.)
  and camelCase field names.

  ## Examples

      schema = Schema.string("A name")
      Schema.to_api_map(schema)
      #=> %{"type" => "STRING", "description" => "A name"}
  """
  @spec to_api_map(t() | map()) :: map()
  def to_api_map(%__MODULE__{} = schema) do
    base = %{"type" => type_to_api(schema.type)}

    base
    |> maybe_put("description", schema.description)
    |> maybe_put("enum", schema.enum)
    |> maybe_put("items", items_to_api(schema.items))
    |> maybe_put("properties", properties_to_api(schema.properties))
    |> maybe_put("required", schema.required)
    |> maybe_put("nullable", schema.nullable)
    |> maybe_put("format", schema.format)
    |> maybe_put("minimum", schema.minimum)
    |> maybe_put("maximum", schema.maximum)
    |> maybe_put("minItems", schema.min_items)
    |> maybe_put("maxItems", schema.max_items)
    |> maybe_put("pattern", schema.pattern)
    |> maybe_put("default", schema.default)
  end

  def to_api_map(%{type: _} = map) do
    to_api_map(convert_to_schema(map))
  end

  def to_api_map(map) when is_map(map), do: map

  @doc """
  Parse a Schema from Gemini API map format.

  ## Examples

      api_map = %{"type" => "STRING", "description" => "A name"}
      {:ok, schema} = Schema.from_api_map(api_map)
  """
  @spec from_api_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_api_map(%{} = api_map) do
    case type_from_api(Map.get(api_map, "type")) do
      nil ->
        {:error, "missing or invalid type"}

      type ->
        items = parse_api_items(Map.get(api_map, "items"))
        properties = parse_api_properties(Map.get(api_map, "properties"))

        {:ok,
         %__MODULE__{
           type: type,
           description: Map.get(api_map, "description"),
           enum: Map.get(api_map, "enum"),
           items: items,
           properties: properties,
           required: Map.get(api_map, "required"),
           nullable: Map.get(api_map, "nullable"),
           format: Map.get(api_map, "format"),
           minimum: Map.get(api_map, "minimum"),
           maximum: Map.get(api_map, "maximum"),
           min_items: Map.get(api_map, "minItems"),
           max_items: Map.get(api_map, "maxItems"),
           pattern: Map.get(api_map, "pattern"),
           default: Map.get(api_map, "default")
         }}
    end
  end

  defp parse_api_items(nil), do: nil

  defp parse_api_items(items_map) do
    {:ok, schema} = from_api_map(items_map)
    schema
  end

  defp parse_api_properties(nil), do: nil

  defp parse_api_properties(props) when is_map(props) do
    Map.new(props, fn {k, v} ->
      {:ok, schema} = from_api_map(v)
      {k, schema}
    end)
  end

  # Type conversion helpers
  defp type_to_api(:string), do: "STRING"
  defp type_to_api(:integer), do: "INTEGER"
  defp type_to_api(:number), do: "NUMBER"
  defp type_to_api(:boolean), do: "BOOLEAN"
  defp type_to_api(:array), do: "ARRAY"
  defp type_to_api(:object), do: "OBJECT"

  defp type_from_api("STRING"), do: :string
  defp type_from_api("INTEGER"), do: :integer
  defp type_from_api("NUMBER"), do: :number
  defp type_from_api("BOOLEAN"), do: :boolean
  defp type_from_api("ARRAY"), do: :array
  defp type_from_api("OBJECT"), do: :object
  defp type_from_api(_), do: nil

  defp items_to_api(nil), do: nil
  defp items_to_api(items), do: to_api_map(items)

  defp properties_to_api(nil), do: nil

  defp properties_to_api(properties) when is_map(properties) do
    Map.new(properties, fn {k, v} -> {k, to_api_map(v)} end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
