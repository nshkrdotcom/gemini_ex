# Code Changes - Structured Outputs Enhancement

**Document:** Exact Code Changes
**Initiative:** `structured_outputs_enhancement`
**Date:** November 6, 2025

---

## Overview

This document contains the exact code changes needed for the structured outputs enhancement. Copy and paste directly into the specified files.

---

## File 1: GenerationConfig Struct

**File:** `lib/gemini/types/common/generation_config.ex`

### Change 1.1: Add Field to Typedstruct

**Location:** Line 37 (after `thinking_config` field)

**Add:**
```elixir
field(:property_ordering, [String.t()] | nil, default: nil)
```

**Complete Updated typedstruct Block:**
```elixir
@derive Jason.Encoder
typedstruct do
  field(:stop_sequences, [String.t()], default: [])
  field(:response_mime_type, String.t() | nil, default: nil)
  field(:response_schema, map() | nil, default: nil)
  field(:candidate_count, integer() | nil, default: nil)
  field(:max_output_tokens, integer() | nil, default: nil)
  field(:temperature, float() | nil, default: nil)
  field(:top_p, float() | nil, default: nil)
  field(:top_k, integer() | nil, default: nil)
  field(:presence_penalty, float() | nil, default: nil)
  field(:frequency_penalty, float() | nil, default: nil)
  field(:response_logprobs, boolean() | nil, default: nil)
  field(:logprobs, integer() | nil, default: nil)
  field(:thinking_config, ThinkingConfig.t() | nil, default: nil)
  field(:property_ordering, [String.t()] | nil, default: nil)
end
```

---

### Change 1.2: Add Helper Functions

**Location:** After line 220 (after `thinking_config/3` function, before `end` of module)

**Add These Functions:**

```elixir
@doc """
Set property ordering for Gemini 2.0 models.

Explicitly defines the order in which properties appear in the generated JSON.
Required for Gemini 2.0 Flash and Gemini 2.0 Flash-Lite when using structured outputs.
Not needed for Gemini 2.5+ models (they preserve schema key order automatically).

## Parameters
- `config`: GenerationConfig struct (defaults to new config)
- `ordering`: List of property names in desired order

## Examples

    # For Gemini 2.0 models
    config = GenerationConfig.property_ordering(["name", "age", "email"])

    # Chain with other options
    config =
      GenerationConfig.new()
      |> GenerationConfig.json_response()
      |> GenerationConfig.property_ordering(["firstName", "lastName"])

## Model Compatibility

- **Gemini 2.5+**: Optional (implicit ordering from schema keys)
- **Gemini 2.0**: Required when using structured outputs

"""
@spec property_ordering(t(), [String.t()]) :: t()
def property_ordering(config \\ %__MODULE__{}, ordering) when is_list(ordering) do
  %{config | property_ordering: ordering}
end

@doc """
Configure structured JSON output with schema.

Convenience helper that sets both response MIME type and schema in one call.
This is the recommended way to set up structured outputs.

## Parameters
- `config`: GenerationConfig struct (defaults to new config)
- `schema`: JSON Schema map defining the output structure

## Examples

    # Basic structured output
    config = GenerationConfig.structured_json(%{
      "type" => "object",
      "properties" => %{
        "answer" => %{"type" => "string"},
        "confidence" => %{"type" => "number"}
      }
    })

    # With property ordering for Gemini 2.0
    config =
      GenerationConfig.structured_json(%{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      })
      |> GenerationConfig.property_ordering(["name", "age"])

    # Complex schema with new keywords
    config = GenerationConfig.structured_json(%{
      "type" => "object",
      "properties" => %{
        "score" => %{
          "type" => "number",
          "minimum" => 0,
          "maximum" => 100
        },
        "result" => %{
          "anyOf" => [
            %{"type" => "string"},
            %{"type" => "null"}
          ]
        }
      }
    })

## Supported JSON Schema Keywords

- Basic types: string, number, integer, boolean, object, array
- Object: properties, required, additionalProperties
- Array: items, prefixItems, minItems, maxItems
- String: enum, format, pattern
- Number: minimum, maximum, enum
- Union types: anyOf
- References: $ref
- Nullable: type: ["string", "null"]

See `docs/guides/structured_outputs.md` for comprehensive examples.

"""
@spec structured_json(t(), map()) :: t()
def structured_json(config \\ %__MODULE__{}, schema) when is_map(schema) do
  %{config |
    response_mime_type: "application/json",
    response_schema: schema
  }
end
```

---

## File 2: Coordinator (Optional)

**File:** `lib/gemini/apis/coordinator.ex`

**Note:** This change is **only needed if** the existing `build_generation_config/1` function doesn't use the generic `convert_to_camel_case/1` helper.

### Check First

Search for the `build_generation_config/1` function in coordinator.ex. If it uses pattern matching on specific atoms, you'll need to add this clause:

**Location:** Inside `build_generation_config/1` function, add this clause with the others:

```elixir
{:property_ordering, ordering}, acc when is_list(ordering) and ordering != [] ->
  Map.put(acc, :propertyOrdering, ordering)
```

**Complete Example (if needed):**
```elixir
defp build_generation_config(opts) do
  opts
  |> Enum.reduce(%{}, fn
    # Basic generation parameters
    {:temperature, temp}, acc when is_number(temp) ->
      Map.put(acc, :temperature, temp)

    {:max_output_tokens, max}, acc when is_integer(max) ->
      Map.put(acc, :maxOutputTokens, max)

    {:top_p, top_p}, acc when is_number(top_p) ->
      Map.put(acc, :topP, top_p)

    {:top_k, top_k}, acc when is_integer(top_k) ->
      Map.put(acc, :topK, top_k)

    # Advanced generation parameters
    {:response_schema, schema}, acc when is_map(schema) ->
      Map.put(acc, :responseSchema, schema)

    {:response_mime_type, mime_type}, acc when is_binary(mime_type) ->
      Map.put(acc, :responseMimeType, mime_type)

    {:stop_sequences, sequences}, acc when is_list(sequences) ->
      Map.put(acc, :stopSequences, sequences)

    {:candidate_count, count}, acc when is_integer(count) and count > 0 ->
      Map.put(acc, :candidateCount, count)

    {:presence_penalty, penalty}, acc when is_number(penalty) ->
      Map.put(acc, :presencePenalty, penalty)

    {:frequency_penalty, penalty}, acc when is_number(penalty) ->
      Map.put(acc, :frequencyPenalty, penalty)

    {:response_logprobs, logprobs}, acc when is_boolean(logprobs) ->
      Map.put(acc, :responseLogprobs, logprobs)

    {:logprobs, logprobs}, acc when is_integer(logprobs) ->
      Map.put(acc, :logprobs, logprobs)

    # NEW: Property ordering for Gemini 2.0 models
    {:property_ordering, ordering}, acc when is_list(ordering) and ordering != [] ->
      Map.put(acc, :propertyOrdering, ordering)

    # Ignore unknown options
    _, acc ->
      acc
  end)
end
```

**Alternative:** If the coordinator uses `struct_to_api_map/1` with generic camelCase conversion, no changes needed!

---

## File 3: Mix.exs Version Bump

**File:** `mix.exs`

### Change 3.1: Update Version

**Location:** In `project/0` function

**Change:**
```elixir
# From:
version: "0.3.1",

# To:
version: "0.4.0",
```

---

### Change 3.2: Update Docs Configuration

**Location:** In `docs/0` function

**Add to extras list:**
```elixir
defp docs do
  [
    main: "readme",
    extras: [
      "README.md",
      "CHANGELOG.md",
      "docs/guides/structured_outputs.md",  # ADD THIS LINE
      # ... other existing files
    ],
    groups_for_extras: [
      "Guides": ~r/docs\/guides\/.*/,
      # ...
    ]
  ]
end
```

---

## File 4: CHANGELOG.md

**File:** `CHANGELOG.md`

**Location:** Top of file, before existing entries

**Add:**
```markdown
## [0.4.0] - 2025-11-06

### Added

- **Structured Outputs Enhancement** - Full support for Gemini API November 2025 updates
  - `property_ordering` field in `GenerationConfig` for Gemini 2.0 model compatibility
  - `structured_json/2` convenience helper for easy structured output setup
  - `property_ordering/2` helper for explicit property ordering
  - Full support for new JSON Schema keywords:
    - `anyOf` - Union types and conditional structures
    - `$ref` - Recursive schema definitions
    - `minimum`/`maximum` - Numeric value constraints
    - `additionalProperties` - Control over extra properties
    - `type: "null"` - Nullable field definitions
    - `prefixItems` - Tuple-like array structures
  - Comprehensive structured outputs guide (`docs/guides/structured_outputs.md`)
  - Working examples demonstrating all new features
  - Integration tests validating API behavior

### Improved

- Enhanced documentation for structured outputs use cases
- Better code examples in README and module documentation
- Expanded test coverage for generation config options

### Notes

- **Gemini 2.5+**: Property ordering is implicit (preserves schema key order)
- **Gemini 2.0**: Requires explicit `property_ordering` field for structured outputs
- **Backward Compatibility**: All changes are additive, no breaking changes
- **Migration**: Existing code continues to work without modifications

For complete technical documentation, see:
`docs/20251106/structured_outputs_enhancement/`

---

## [0.3.1] - 2025-XX-XX

... (existing entries continue)
```

---

## File 5: README.md Updates

**File:** `README.md`

### Update 5.1: Add to Advanced Generation Configuration Section

**Location:** After line 181 (after the generation config examples)

**Add:**
```markdown
### Structured JSON Outputs

Generate responses that guarantee adherence to a specific JSON Schema:

```elixir
# Define your schema
schema = %{
  "type" => "object",
  "properties" => %{
    "answer" => %{"type" => "string"},
    "confidence" => %{
      "type" => "number",
      "minimum" => 0.0,
      "maximum" => 1.0
    },
    "reasoning" => %{"type" => "string"}
  },
  "required" => ["answer"]
}

# Use the convenient helper
config = Gemini.Types.GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "What is the capital of France? Rate your confidence and explain.",
  model: "gemini-2.5-flash",
  generation_config: config
)

# Response is guaranteed valid JSON matching the schema
{:ok, text} = Gemini.extract_text(response)
{:ok, data} = Jason.decode(text)
# => %{"answer" => "Paris", "confidence" => 0.99, "reasoning" => "..."}
```

#### New JSON Schema Features (November 2025)

The Gemini API now supports powerful JSON Schema keywords:

```elixir
# Union types with anyOf
%{
  "anyOf" => [
    %{"type" => "string"},
    %{"type" => "number"}
  ]
}

# Numeric constraints
%{
  "type" => "number",
  "minimum" => 0,
  "maximum" => 100
}

# Tuple-like arrays with prefixItems
%{
  "type" => "array",
  "prefixItems" => [
    %{"type" => "number"},  # latitude
    %{"type" => "number"}   # longitude
  ]
}

# Nullable fields
%{
  "type" => ["string", "null"]
}
```

#### Property Ordering (Gemini 2.0 Models)

For Gemini 2.0 models, explicitly specify property order:

```elixir
config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.property_ordering(["answer", "confidence", "reasoning"])

{:ok, response} = Gemini.generate(
  "What is 2+2?",
  model: "gemini-2.0-flash",
  generation_config: config
)
```

**Note:** Gemini 2.5+ models preserve schema key order automatically.

For comprehensive examples and best practices, see the [Structured Outputs Guide](docs/guides/structured_outputs.md).
```

---

### Update 5.2: Add to Features List

**Location:** Line 28 (in the features list)

**Update the existing structured output line:**
```markdown
# From:
- **⚙️ Complete Generation Config**: Full support for all generation config options including structured output

# To:
- **⚙️ Structured Outputs**: Full JSON Schema support with new keywords (anyOf, $ref, numeric constraints, etc.) - *Updated Nov 2025*
```

---

## File 6: Module Documentation Update

**File:** `lib/gemini.ex`

### Update 6.1: Add Structured Outputs Example

**Location:** Around line 146 (after the multimodal content example, before "## Authentication")

**Add:**
```elixir
### Structured Outputs

Generate JSON that matches a specific schema:

```elixir
alias Gemini.Types.GenerationConfig

# Define your schema
schema = %{
  "type" => "object",
  "properties" => %{
    "summary" => %{"type" => "string"},
    "sentiment" => %{
      "type" => "string",
      "enum" => ["positive", "negative", "neutral"]
    },
    "confidence" => %{
      "type" => "number",
      "minimum" => 0.0,
      "maximum" => 1.0
    }
  },
  "required" => ["summary", "sentiment"]
}

# Use the structured_json helper
config = GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "Analyze this review: 'Great product, highly recommend!'",
  model: "gemini-2.5-flash",
  generation_config: config
)

{:ok, text} = Gemini.extract_text(response)
{:ok, data} = Jason.decode(text)
# => %{"summary" => "...", "sentiment" => "positive", "confidence" => 0.95}
```

#### New JSON Schema Keywords (November 2025)

The API now supports powerful schema features:

```elixir
# Union types with anyOf
schema = %{
  "type" => "object",
  "properties" => %{
    "result" => %{
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

# Recursive schemas with $ref
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
    "root" => %{"$ref" => "#/$defs/Node"}
  }
}

# Numeric constraints
schema = %{
  "type" => "object",
  "properties" => %{
    "age" => %{
      "type" => "integer",
      "minimum" => 0,
      "maximum" => 120
    }
  }
}
```

#### Property Ordering for Gemini 2.0

For Gemini 2.0 models, add explicit property ordering:

```elixir
config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.property_ordering(["summary", "sentiment", "confidence"])

{:ok, response} = Gemini.generate(
  prompt,
  model: "gemini-2.0-flash",
  generation_config: config
)
```

**Note:** Gemini 2.5+ models preserve schema key order automatically.

See `docs/guides/structured_outputs.md` for comprehensive examples and best practices.
```

---

## Verification Commands

After making all changes, run these commands to verify:

```bash
# Format code
mix format

# Compile
mix compile

# Run all tests
mix test

# Run Dialyzer
mix dialyzer

# Check formatting
mix format --check-formatted

# Generate docs
mix docs

# Run integration tests
GEMINI_API_KEY="your_key" mix test --only integration
```

---

## Summary of Changes

### Files Modified
1. `lib/gemini/types/common/generation_config.ex` - Add field and helpers
2. `lib/gemini/apis/coordinator.ex` - Add camelCase conversion (if needed)
3. `mix.exs` - Version bump and docs config
4. `CHANGELOG.md` - Release notes
5. `README.md` - Usage examples
6. `lib/gemini.ex` - Module documentation

### Lines of Code
- **Added:** ~200 lines (including docs)
- **Modified:** ~10 lines
- **Deleted:** 0 lines

### Complexity
- **Low:** Simple field addition
- **High Impact:** Enables powerful new features
- **Backward Compatible:** 100%

---

**Next Document:** `04_TESTING_STRATEGY.md` - Comprehensive test plan
