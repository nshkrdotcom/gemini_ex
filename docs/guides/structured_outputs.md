# Structured Outputs Guide

## Overview

Structured outputs allow you to get JSON responses from Gemini models that strictly adhere to a predefined JSON Schema. This feature is essential for:

- Building reliable APIs that return predictable data structures
- Extracting structured information from unstructured text
- Ensuring type safety in downstream processing
- Integrating with typed languages and strict validation systems

## Quick Start

```elixir
alias Gemini.Types.GenerationConfig

# Define your schema
schema = %{
  "type" => "object",
  "properties" => %{
    "answer" => %{"type" => "string"},
    "confidence" => %{"type" => "number"}
  },
  "required" => ["answer"]
}

# Use the convenient helper (response_json_schema by default)
config = GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "What is the capital of France?",
  model: "gemini-2.5-flash",
  generation_config: config
)

{:ok, text} = Gemini.extract_text(response)
{:ok, data} = Jason.decode(text)
# => %{"answer" => "Paris", "confidence" => 0.95}
```

## JSON Schema vs Internal Schema

`GenerationConfig.structured_json/2` sets `response_json_schema` (standard JSON Schema) by
default. If you need Gemini's internal schema format, pass `schema_type: :response_schema`:

```elixir
config =
  GenerationConfig.structured_json(%{"type" => "OBJECT"}, schema_type: :response_schema)
```

## New Features (November 2025)

The November 2025 Gemini API update added support for advanced JSON Schema keywords:

### 1. Union Types with `anyOf`

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "status" => %{
      "anyOf" => [
        %{
          "type" => "object",
          "properties" => %{"success" => %{"type" => "string"}}
        },
        %{
          "type" => "object",
          "properties" => %{"error" => %{"type" => "string"}}
        }
      ]
    }
  }
}
```

### 2. Recursive Schemas with `$ref`

```elixir
schema = %{
  "$defs" => %{
    "Node" => %{
      "type" => "object",
      "properties" => %{
        "value" => %{"type" => "string"},
        "children" => %{
          "type" => "array",
          "items" => %{"$ref" => "#/$defs/Node"}
        }
      }
    }
  },
  "type" => "object",
  "properties" => %{
    "tree" => %{"$ref" => "#/$defs/Node"}
  }
}
```

### 3. Numeric Constraints

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "score" => %{
      "type" => "number",
      "minimum" => 0.0,
      "maximum" => 100.0
    },
    "age" => %{
      "type" => "integer",
      "minimum" => 0,
      "maximum" => 150
    }
  }
}
```

### 4. Control Over Additional Properties

```elixir
# Strict mode - no extra properties allowed
schema = %{
  "type" => "object",
  "properties" => %{
    "name" => %{"type" => "string"}
  },
  "additionalProperties" => false,
  "required" => ["name"]
}

# Allow extra properties with specific type
schema = %{
  "type" => "object",
  "properties" => %{
    "name" => %{"type" => "string"}
  },
  "additionalProperties" => %{"type" => "string"}
}
```

### 5. Nullable Fields

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "middleName" => %{
      "type" => ["string", "null"]
    }
  }
}
```

### 6. Tuple-like Arrays with `prefixItems`

```elixir
# Define a 2D point as [x, y]
schema = %{
  "type" => "object",
  "properties" => %{
    "coordinates" => %{
      "type" => "array",
      "prefixItems" => [
        %{"type" => "number"},
        %{"type" => "number"}
      ],
      "items" => false  # No additional items allowed
    }
  }
}
```

## Model-Specific Considerations

### Gemini 2.5+ Models (Recommended)

These models automatically preserve the order of properties in your schema:

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "firstName" => %{"type" => "string"},
    "lastName" => %{"type" => "string"},
    "age" => %{"type" => "integer"}
  }
}

config = GenerationConfig.structured_json(schema)
# Output will have properties in order: firstName, lastName, age
```

### Gemini 2.0 Models

These models require explicit property ordering:

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "firstName" => %{"type" => "string"},
    "lastName" => %{"type" => "string"},
    "age" => %{"type" => "integer"}
  }
}

config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.property_ordering(["firstName", "lastName", "age"])
```

## Common Patterns

### Extract Multiple Entities

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "people" => %{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "role" => %{"type" => "string"}
        }
      }
    }
  }
}

config = GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "Extract all people mentioned: John is the CEO and Sarah is the CTO.",
  model: "gemini-2.5-flash",
  generation_config: config
)
```

### Sentiment Analysis

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "sentiment" => %{
      "type" => "string",
      "enum" => ["positive", "negative", "neutral"]
    },
    "confidence" => %{
      "type" => "number",
      "minimum" => 0.0,
      "maximum" => 1.0
    },
    "keywords" => %{
      "type" => "array",
      "items" => %{"type" => "string"}
    }
  },
  "required" => ["sentiment", "confidence"]
}
```

### Data Validation and Classification

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "isValid" => %{"type" => "boolean"},
    "category" => %{
      "type" => "string",
      "enum" => ["bug", "feature", "question", "documentation"]
    },
    "priority" => %{
      "type" => "string",
      "enum" => ["low", "medium", "high", "critical"]
    }
  },
  "required" => ["isValid", "category", "priority"]
}
```

## Best Practices

### 1. Use Required Fields

Always specify which fields are required to ensure complete responses:

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "answer" => %{"type" => "string"},
    "sources" => %{"type" => "array", "items" => %{"type" => "string"}}
  },
  "required" => ["answer"]  # sources is optional
}
```

### 2. Add Descriptions for Complex Schemas

Help the model understand your schema intent:

```elixir
schema = %{
  "type" => "object",
  "description" => "Product information extracted from text",
  "properties" => %{
    "name" => %{
      "type" => "string",
      "description" => "The product name"
    },
    "price" => %{
      "type" => "number",
      "description" => "Price in USD",
      "minimum" => 0
    }
  }
}
```

### 3. Use Enums for Classification

Constrain outputs to known values:

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "language" => %{
      "type" => "string",
      "enum" => ["elixir", "python", "javascript", "rust", "go"]
    }
  }
}
```

### 4. Combine with Other Generation Config Options

```elixir
config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.temperature(0.1)  # Lower temperature for consistency
  |> GenerationConfig.max_tokens(1000)
```

## Streaming Support

Structured outputs work with streaming responses. Each chunk will contain valid partial JSON:

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "story" => %{"type" => "string"}
  }
}

config = GenerationConfig.structured_json(schema)

{:ok, stream} = Gemini.stream_generate(
  "Write a short story",
  model: "gemini-2.5-flash",
  generation_config: config
)

full_text =
  stream
  |> Enum.map(fn resp ->
    {:ok, text} = Gemini.extract_text(resp)
    text
  end)
  |> Enum.join()

{:ok, data} = Jason.decode(full_text)
```

## Troubleshooting

### Schema Validation Errors

If you get schema validation errors, ensure:
- All required JSON Schema fields are present
- Types are correctly specified
- Enums contain at least one value
- References (`$ref`) point to valid definitions

### Empty or Malformed Responses

If responses don't match your schema:
- Check that your prompt clearly describes what you want
- Simplify complex schemas for testing
- Verify the model supports the schema keywords you're using
- Try lowering the temperature for more consistent results

### Property Ordering Issues (Gemini 2.0)

If property order is incorrect on Gemini 2.0 models:
- Use `property_ordering/2` to explicitly set the order
- Ensure the ordering list matches all properties in your schema
- Upgrade to Gemini 2.5+ for automatic ordering

## Examples

See the `examples/` directory for working code:
- `structured_outputs_basic.exs` - Simple structured output example
- `structured_outputs_standalone.exs` - Standalone example with Mix.install

## Further Reading

- [JSON Schema Specification](https://json-schema.org/)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [GenerationConfig API Reference](https://hexdocs.pm/gemini_ex/Gemini.Types.GenerationConfig.html)
