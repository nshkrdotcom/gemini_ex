# API Changes - Structured Outputs Enhancement

**Document:** API Changes Reference
**Initiative:** `structured_outputs_enhancement`
**Date:** November 6, 2025

---

## Overview

This document provides a comprehensive technical reference for all changes to the Gemini API's structured outputs functionality as of November 5, 2025. It serves as the authoritative source for understanding what changed in the API and how it impacts the `gemini_ex` implementation.

---

## Table of Contents

1. [API Version Changes](#api-version-changes)
2. [Generation Config Changes](#generation-config-changes)
3. [JSON Schema Support](#json-schema-support)
4. [Model Support Matrix](#model-support-matrix)
5. [Streaming Behavior](#streaming-behavior)
6. [Error Handling](#error-handling)
7. [Best Practices from API](#best-practices-from-api)

---

## API Version Changes

### Timeline

| Date | Version | Changes |
|------|---------|---------|
| Pre-Nov 2025 | v1 | Limited JSON Schema support, select models |
| Nov 5, 2025 | v1.1 | Universal model support, expanded keywords |

### Backward Compatibility

✅ **Fully backward compatible** - All existing code continues to work
- Old schemas still work
- No deprecated fields
- Additive changes only

---

## Generation Config Changes

### New Field: `propertyOrdering` (Gemini 2.0 only)

**Field Name:** `propertyOrdering`
**Type:** `Array<string>`
**Required:** No (only for Gemini 2.0 models when using structured output)
**Applicable Models:** Gemini 2.0 Flash, Gemini 2.0 Flash-Lite

**Purpose:** Explicitly define the order in which properties should appear in the generated JSON output.

**API Specification:**
```json
{
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"}
      }
    },
    "propertyOrdering": ["name", "age"]
  }
}
```

**Behavior by Model:**

| Model Version | Property Ordering |
|--------------|-------------------|
| Gemini 2.5 Pro | Implicit (preserves schema key order) |
| Gemini 2.5 Flash | Implicit (preserves schema key order) |
| Gemini 2.5 Flash-Lite | Implicit (preserves schema key order) |
| Gemini 2.0 Flash | **Requires explicit `propertyOrdering`** |
| Gemini 2.0 Flash-Lite | **Requires explicit `propertyOrdering`** |

**Example Request (Gemini 2.0):**
```json
{
  "contents": [{
    "parts": [{"text": "Generate a person record"}]
  }],
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "object",
      "properties": {
        "firstName": {"type": "string"},
        "lastName": {"type": "string"},
        "age": {"type": "integer"}
      },
      "required": ["firstName", "lastName"]
    },
    "propertyOrdering": ["firstName", "lastName", "age"]
  }
}
```

**Elixir Mapping:**
```elixir
# Field name in Elixir
:property_ordering

# Field name in API JSON (camelCase)
"propertyOrdering"

# Example value
["firstName", "lastName", "age"]
```

### Existing Fields (Unchanged)

These fields remain the same but now work with all models:

| Field (Elixir) | Field (API) | Type | Description |
|---------------|-------------|------|-------------|
| `:response_schema` | `responseSchema` | `map()` | JSON Schema for output |
| `:response_mime_type` | `responseMimeType` | `string` | MIME type (e.g., "application/json") |
| `:temperature` | `temperature` | `float` | Sampling temperature |
| `:max_output_tokens` | `maxOutputTokens` | `integer` | Maximum tokens to generate |
| `:top_p` | `topP` | `float` | Nucleus sampling parameter |
| `:top_k` | `topK` | `integer` | Top-k sampling parameter |
| `:candidate_count` | `candidateCount` | `integer` | Number of candidates to generate |
| `:stop_sequences` | `stopSequences` | `[string]` | Sequences that stop generation |
| `:presence_penalty` | `presencePenalty` | `float` | Penalty for token presence |
| `:frequency_penalty` | `frequencyPenalty` | `float` | Penalty for token frequency |
| `:response_logprobs` | `responseLogprobs` | `boolean` | Include token probabilities |
| `:logprobs` | `logprobs` | `integer` | Number of logprobs to return |

---

## JSON Schema Support

### Newly Supported Keywords (Nov 2025)

#### 1. `anyOf` - Union Types

**Purpose:** Define conditional structures or union types

**Specification:**
```json
{
  "anyOf": [
    {"type": "object", "properties": {...}},
    {"type": "object", "properties": {...}}
  ]
}
```

**Use Case:** Model returns one of several possible object structures

**Example:** Content moderation that returns different objects for spam vs. not-spam
```json
{
  "type": "object",
  "properties": {
    "decision": {
      "anyOf": [
        {
          "type": "object",
          "properties": {
            "reason": {"type": "string"},
            "spam_type": {
              "type": "string",
              "enum": ["phishing", "scam", "promotion"]
            }
          },
          "required": ["reason", "spam_type"]
        },
        {
          "type": "object",
          "properties": {
            "summary": {"type": "string"},
            "is_safe": {"type": "boolean"}
          },
          "required": ["summary", "is_safe"]
        }
      ]
    }
  }
}
```

**Elixir Usage:**
```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "decision" => %{
      "anyOf" => [
        %{
          "type" => "object",
          "properties" => %{
            "reason" => %{"type" => "string"},
            "spam_type" => %{
              "type" => "string",
              "enum" => ["phishing", "scam", "promotion"]
            }
          },
          "required" => ["reason", "spam_type"]
        },
        %{
          "type" => "object",
          "properties" => %{
            "summary" => %{"type" => "string"},
            "is_safe" => %{"type" => "boolean"}
          },
          "required" => ["summary", "is_safe"]
        }
      ]
    }
  }
}
```

#### 2. `$ref` - Recursive Schemas

**Purpose:** Define recursive or self-referential structures

**Specification:**
```json
{
  "$defs": {
    "Node": {
      "type": "object",
      "properties": {
        "value": {"type": "string"},
        "children": {
          "type": "array",
          "items": {"$ref": "#/$defs/Node"}
        }
      }
    }
  },
  "type": "object",
  "properties": {
    "root": {"$ref": "#/$defs/Node"}
  }
}
```

**Use Case:** Tree structures, nested comments, organizational hierarchies

**Elixir Usage:**
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
    "root" => %{"$ref" => "#/$defs/Node"}
  }
}
```

#### 3. `minimum` / `maximum` - Numeric Constraints

**Purpose:** Constrain numeric values to specific ranges

**Specification:**
```json
{
  "type": "number",
  "minimum": 0,
  "maximum": 100
}
```

**Use Cases:**
- Confidence scores (0.0-1.0)
- Percentages (0-100)
- Age ranges (0-120)
- Prices (> 0)

**Examples:**

**Confidence Score:**
```elixir
%{
  "type" => "number",
  "minimum" => 0.0,
  "maximum" => 1.0
}
```

**Age:**
```elixir
%{
  "type" => "integer",
  "minimum" => 0,
  "maximum" => 120
}
```

**Price (positive only):**
```elixir
%{
  "type" => "number",
  "minimum" => 0,
  "exclusiveMinimum" => true  # > 0, not >= 0
}
```

#### 4. `additionalProperties` - Control Extra Properties

**Purpose:** Allow or disallow properties not defined in schema

**Specification:**
```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string"}
  },
  "additionalProperties": false
}
```

**Values:**
- `false`: No additional properties allowed (strict)
- `true`: Any additional properties allowed
- Schema object: Additional properties must match schema

**Examples:**

**Strict (no extras):**
```elixir
%{
  "type" => "object",
  "properties" => %{
    "name" => %{"type" => "string"},
    "age" => %{"type" => "integer"}
  },
  "additionalProperties" => false
}
```

**Allow any extras:**
```elixir
%{
  "type" => "object",
  "properties" => %{
    "name" => %{"type" => "string"}
  },
  "additionalProperties" => true
}
```

**Typed extras:**
```elixir
%{
  "type" => "object",
  "properties" => %{
    "name" => %{"type" => "string"}
  },
  "additionalProperties" => %{"type" => "string"}  # Extra props must be strings
}
```

#### 5. `type: "null"` - Nullable Fields

**Purpose:** Allow fields to be null

**Specification:**
```json
{
  "type": ["string", "null"]
}
```

**Use Case:** Optional fields that can be explicitly null vs. undefined

**Examples:**

**Nullable string:**
```elixir
%{
  "type" => ["string", "null"]
}
```

**Nullable object:**
```elixir
%{
  "type" => ["object", "null"],
  "properties" => %{
    "key" => %{"type" => "string"}
  }
}
```

**In object properties:**
```elixir
%{
  "type" => "object",
  "properties" => %{
    "required_field" => %{"type" => "string"},
    "optional_field" => %{"type" => ["string", "null"]}
  },
  "required" => ["required_field"]
}
```

#### 6. `prefixItems` - Tuple-like Arrays

**Purpose:** Define arrays with fixed positions and types (tuples)

**Specification:**
```json
{
  "type": "array",
  "prefixItems": [
    {"type": "number"},
    {"type": "number"}
  ],
  "items": false
}
```

**Use Cases:**
- Coordinates: [latitude, longitude]
- RGB colors: [red, green, blue]
- Date tuples: [year, month, day]

**Examples:**

**Geographic coordinates:**
```elixir
%{
  "type" => "array",
  "prefixItems" => [
    %{"type" => "number", "minimum" => -90, "maximum" => 90},   # latitude
    %{"type" => "number", "minimum" => -180, "maximum" => 180}  # longitude
  ],
  "items" => false  # No additional items
}
```

**RGB color:**
```elixir
%{
  "type" => "array",
  "prefixItems" => [
    %{"type" => "integer", "minimum" => 0, "maximum" => 255},  # red
    %{"type" => "integer", "minimum" => 0, "maximum" => 255},  # green
    %{"type" => "integer", "minimum" => 0, "maximum" => 255}   # blue
  ],
  "items" => false
}
```

**Date tuple:**
```elixir
%{
  "type" => "array",
  "prefixItems" => [
    %{"type" => "integer", "minimum" => 1900},  # year
    %{"type" => "integer", "minimum" => 1, "maximum" => 12},  # month
    %{"type" => "integer", "minimum" => 1, "maximum" => 31}   # day
  ],
  "minItems" => 3,
  "maxItems" => 3
}
```

### Previously Supported Keywords

These keywords were already supported and continue to work:

| Keyword | Type | Purpose |
|---------|------|---------|
| `type` | string | Data type: string, number, integer, boolean, object, array |
| `properties` | object | Object property definitions |
| `required` | array | Required property names |
| `items` | schema | Array item schema (uniform arrays) |
| `enum` | array | Allowed values list |
| `title` | string | Short property description |
| `description` | string | Detailed property description |
| `format` | string | String format (date-time, date, time, email, etc.) |
| `minItems` | integer | Minimum array length |
| `maxItems` | integer | Maximum array length |
| `pattern` | string | Regex pattern for strings |

---

## Model Support Matrix

### Complete Support Table

| Model | Structured Outputs | Property Ordering | Notes |
|-------|-------------------|-------------------|-------|
| **Gemini 2.5 Pro** | ✔️ Full | Implicit | Recommended for production |
| **Gemini 2.5 Flash** | ✔️ Full | Implicit | Fast, high quality |
| **Gemini 2.5 Flash-Lite** | ✔️ Full | Implicit | Cost-effective |
| **Gemini 2.0 Flash** | ✔️ Full | Explicit (`propertyOrdering` required) | Legacy support |
| **Gemini 2.0 Flash-Lite** | ✔️ Full | Explicit (`propertyOrdering` required) | Legacy support |

### Model Selection Guidelines

**For New Projects:**
- Use Gemini 2.5 Flash (best balance of speed/quality)
- Use Gemini 2.5 Pro for complex schemas
- Use Gemini 2.5 Flash-Lite for cost optimization

**For Existing Projects:**
- Can continue using Gemini 2.0 models
- Must add `propertyOrdering` field for structured outputs
- Consider migrating to 2.5 for implicit ordering

---

## Streaming Behavior

### Structured Output Streaming (New Guarantee)

**Pre-Nov 2025:** Streaming with structured outputs was supported but not guaranteed to produce valid partial JSON

**Post-Nov 2025:** Streaming chunks are **guaranteed valid partial JSON strings**

**Specification:**

When using `streamGenerateContent` with structured outputs:
1. Each chunk contains valid partial JSON
2. Chunks can be concatenated to form complete JSON
3. Chunks may be incomplete objects/arrays (trailing commas, unclosed braces)
4. Final chunk completes the JSON structure

**Example Stream:**

```json
// Chunk 1
{"name":"Jo

// Chunk 2
hn","age":30,"addre

// Chunk 3
ss":{"city":"New Y

// Chunk 4
ork"}}
```

**Concatenated result:**
```json
{"name":"John","age":30,"address":{"city":"New York"}}
```

**Implications for gemini_ex:**

Our existing streaming implementation already works correctly. The API change ensures:
- No malformed JSON in streams
- Safer incremental parsing
- Better error handling

**Test Validation Needed:**
- Verify chunks are valid partial JSON
- Test concatenation produces valid complete JSON
- Validate error handling for interrupted streams

---

## Error Handling

### New Error Responses

#### Schema Validation Errors

**Error Type:** `INVALID_ARGUMENT`

**Occurs When:**
- Schema is too complex (too deeply nested)
- Schema uses unsupported keywords
- Schema is malformed JSON
- Property names in `propertyOrdering` don't match schema

**Example Response:**
```json
{
  "error": {
    "code": 400,
    "message": "Invalid schema: Property 'unknownProp' in propertyOrdering not found in responseSchema",
    "status": "INVALID_ARGUMENT"
  }
}
```

**Elixir Error Handling:**
```elixir
case Gemini.generate(prompt, response_schema: schema) do
  {:ok, response} ->
    # Success

  {:error, %Gemini.Error{type: :invalid_argument, message: msg}} ->
    # Schema validation failed
    IO.puts("Schema error: #{msg}")
end
```

#### Model Refusal (Programmatic Detection)

**New Capability:** Structured outputs enable programmatic detection of model refusals

**Schema Pattern:**
```elixir
%{
  "anyOf" => [
    %{
      "type" => "object",
      "properties" => %{
        "result" => %{"type" => "string"}
      }
    },
    %{
      "type" => "object",
      "properties" => %{
        "refusal" => %{"type" => "string"}
      }
    }
  ]
}
```

**Detection:**
```elixir
case Jason.decode!(response.text) do
  %{"result" => result} -> {:ok, result}
  %{"refusal" => reason} -> {:error, {:refused, reason}}
end
```

---

## Best Practices from API

### Official Recommendations (from API docs)

#### 1. Clear Descriptions

**Guideline:** Use `description` field extensively

```elixir
%{
  "type" => "object",
  "properties" => %{
    "sentiment" => %{
      "type" => "string",
      "description" => "The emotional tone of the text: positive, negative, or neutral"
    },
    "confidence" => %{
      "type" => "number",
      "description" => "Confidence score between 0.0 (no confidence) and 1.0 (absolute confidence)"
    }
  }
}
```

#### 2. Strong Typing

**Guideline:** Use specific types, not generic

```elixir
# ❌ Bad: Too generic
%{"type" => "string"}

# ✅ Good: Specific with enum
%{
  "type" => "string",
  "enum" => ["low", "medium", "high"]
}

# ✅ Good: Constrained number
%{
  "type" => "number",
  "minimum" => 0.0,
  "maximum" => 1.0
}
```

#### 3. Prompt Engineering

**Guideline:** Explicitly state what you want in the prompt

```elixir
# ❌ Bad: Vague prompt
"Analyze this text"

# ✅ Good: Explicit instructions
"Extract the following information from the text according to the provided schema:
- sentiment: Determine if the tone is positive, negative, or neutral
- confidence: Rate your confidence in this assessment from 0.0 to 1.0
- key_phrases: List the 3-5 most important phrases that informed your decision"
```

#### 4. Validation

**Guideline:** Always validate output in application code

```elixir
# Schema guarantees syntactic correctness, not semantic correctness
case Gemini.generate(prompt, response_schema: schema) do
  {:ok, response} ->
    case Jason.decode(response.text) do
      {:ok, data} ->
        # Validate business logic
        if data["confidence"] > 0.5 do
          {:ok, data}
        else
          {:error, :low_confidence}
        end
      {:error, _} ->
        {:error, :invalid_json}
    end
end
```

#### 5. Error Handling

**Guideline:** Implement robust error handling

```elixir
def generate_structured(prompt, schema) do
  case Gemini.generate(prompt,
    response_schema: schema,
    response_mime_type: "application/json"
  ) do
    {:ok, response} ->
      parse_and_validate(response)

    {:error, %Gemini.Error{type: :invalid_argument}} ->
      {:error, :schema_error}

    {:error, %Gemini.Error{type: :rate_limit}} ->
      {:error, :rate_limited}

    {:error, error} ->
      {:error, error}
  end
end
```

---

## Schema Complexity Limits

### API Constraints

**Documented Limits:**
- Maximum nesting depth: ~20 levels (not officially specified)
- Maximum properties: ~100 per object (not officially specified)
- Maximum schema size: ~100KB (estimated)

**When Schema is Too Complex:**
- API returns `INVALID_ARGUMENT` error
- Error message: "Schema is too complex"

**Mitigation:**
1. Break schema into smaller parts
2. Use `$ref` to reduce duplication
3. Simplify nested structures
4. Remove unnecessary constraints

**Example - Simplification:**

```elixir
# ❌ Too complex: Deep nesting
%{
  "type" => "object",
  "properties" => %{
    "level1" => %{
      "type" => "object",
      "properties" => %{
        "level2" => %{
          "type" => "object",
          "properties" => %{
            # ... 15 more levels
          }
        }
      }
    }
  }
}

# ✅ Better: Flattened with references
%{
  "$defs" => %{
    "Address" => %{
      "type" => "object",
      "properties" => %{
        "street" => %{"type" => "string"},
        "city" => %{"type" => "string"}
      }
    }
  },
  "type" => "object",
  "properties" => %{
    "name" => %{"type" => "string"},
    "address" => %{"$ref" => "#/$defs/Address"}
  }
}
```

---

## Summary of Changes

### What's New
1. ✅ `propertyOrdering` field for Gemini 2.0 models
2. ✅ Six new JSON Schema keywords
3. ✅ Universal model support
4. ✅ Guaranteed property ordering (2.5+)
5. ✅ Improved streaming with valid partial JSON
6. ✅ Better error messages

### What's Unchanged
1. ✅ All existing fields work the same
2. ✅ Backward compatible
3. ✅ No breaking changes

### Implementation Impact
- **Low complexity:** Only need to add one new field
- **High value:** Enables powerful new use cases
- **Full backward compatibility:** Existing code continues to work

---

**Next Document:** `02_IMPLEMENTATION_PLAN.md` - Step-by-step implementation guide
