# Implementation Plan - Structured Outputs Enhancement

**Document:** Implementation Plan
**Initiative:** `structured_outputs_enhancement`
**Date:** November 6, 2025

---

## Overview

This document provides a step-by-step implementation plan for adding structured outputs enhancements to `gemini_ex`. Follow these phases in order for successful delivery.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Core Code Changes](#phase-1-core-code-changes)
3. [Phase 2: Testing](#phase-2-testing)
4. [Phase 3: Documentation](#phase-3-documentation)
5. [Phase 4: Examples](#phase-4-examples)
6. [Phase 5: Release](#phase-5-release)
7. [Rollback Plan](#rollback-plan)

---

## Prerequisites

### Before Starting

- [ ] Read `00_OVERVIEW.md`
- [ ] Read `01_API_CHANGES.md`
- [ ] Ensure development environment is set up
- [ ] Run existing test suite to establish baseline
- [ ] Create feature branch: `git checkout -b feature/structured-outputs-enhancement`

### Required Tools

- Elixir 1.18.3+
- OTP 27.3.3+
- Mix
- Git
- Valid Gemini API key for integration testing

### Validation Steps

```bash
# Verify environment
elixir --version
# Elixir 1.18.3 (compiled with Erlang/OTP 27)

# Run tests
cd gemini_ex
mix deps.get
mix test

# Should see all tests passing
```

---

## Phase 1: Core Code Changes

**Estimated Time:** 30-45 minutes
**Risk Level:** Low

### Step 1.1: Update GenerationConfig Struct

**File:** `lib/gemini/types/common/generation_config.ex`

**Location:** Line 24 (in the typedstruct block)

**Action:** Add new field

```elixir
# After line 37 (after thinking_config field)
field(:property_ordering, [String.t()] | nil, default: nil)
```

**Complete Field Order:**
```elixir
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
  field(:property_ordering, [String.t()] | nil, default: nil)  # NEW
end
```

**Verification:**
```bash
# Compile
mix compile

# Should compile without warnings
```

---

### Step 1.2: Add Convenience Helper

**File:** `lib/gemini/types/common/generation_config.ex`

**Location:** After line 189 (after `include_thoughts/2` function)

**Action:** Add new helper function

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

"""
@spec property_ordering(t(), [String.t()]) :: t()
def property_ordering(config \\ %__MODULE__{}, ordering) when is_list(ordering) do
  %{config | property_ordering: ordering}
end

@doc """
Configure structured JSON output with schema.

Convenience helper that sets both response MIME type and schema in one call.

## Parameters
- `config`: GenerationConfig struct (defaults to new config)
- `schema`: JSON Schema map defining the output structure

## Examples

    # Basic structured output
    config = GenerationConfig.structured_json(%{
      "type" => "object",
      "properties" => %{
        "answer" => %{"type" => "string"}
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

"""
@spec structured_json(t(), map()) :: t()
def structured_json(config \\ %__MODULE__{}, schema) when is_map(schema) do
  %{config |
    response_mime_type: "application/json",
    response_schema: schema
  }
end
```

**Verification:**
```bash
# Compile
mix compile

# Test in IEx
iex -S mix

# Try the new functions
alias Gemini.Types.GenerationConfig

config = GenerationConfig.property_ordering(["a", "b", "c"])
IO.inspect(config.property_ordering)
# ["a", "b", "c"]

config2 = GenerationConfig.structured_json(%{"type" => "object"})
IO.inspect(config2.response_mime_type)
# "application/json"
IO.inspect(config2.response_schema)
# %{"type" => "object"}
```

---

### Step 1.3: Update Coordinator CamelCase Conversion

**File:** `lib/gemini/apis/coordinator.ex`

**Action:** Verify `property_ordering` is handled correctly

**Check:** The existing `struct_to_api_map/1` function should already handle the new field automatically via the `convert_to_camel_case/1` function.

**Verification Test:**
```elixir
# In IEx
alias Gemini.Types.GenerationConfig

config = GenerationConfig.new(
  property_ordering: ["name", "age"],
  temperature: 0.7
)

# The coordinator should convert this to:
# %{
#   "propertyOrdering" => ["name", "age"],
#   "temperature" => 0.7
# }
```

**No code changes needed** if the existing implementation uses the generic `convert_to_camel_case/1` helper. The field will be automatically converted from `:property_ordering` to `"propertyOrdering"`.

**If explicit handling is needed,** add to the `build_generation_config/1` function:

```elixir
# In lib/gemini/apis/coordinator.ex, in build_generation_config/1
{:property_ordering, ordering}, acc when is_list(ordering) ->
  Map.put(acc, :propertyOrdering, ordering)
```

**Location to check:** Search for `build_generation_config` function in coordinator.

---

### Step 1.4: Update Type Specs

**File:** `lib/gemini.ex`

**Location:** Line 187 (in the `@type options` definition)

**Action:** Verify the type spec includes all generation config fields

**Current type spec** should already cover this via:
```elixir
generation_config: Gemini.Types.GenerationConfig.t() | nil
```

Since `GenerationConfig.t()` now includes the new field, no changes needed.

**Verification:**
```bash
# Run Dialyzer
mix dialyzer

# Should pass without warnings
```

---

### Step 1.5: Update @derive Jason.Encoder

**File:** `lib/gemini/types/common/generation_config.ex`

**Location:** Line 23

**Action:** Verify `@derive Jason.Encoder` is present

**Current:**
```elixir
@derive Jason.Encoder
typedstruct do
  # ...
end
```

This is already present, so the new field will automatically be included in JSON encoding.

**Verification:**
```elixir
# In IEx
alias Gemini.Types.GenerationConfig

config = GenerationConfig.new(
  property_ordering: ["x", "y"],
  temperature: 0.5
)

Jason.encode!(config)
# Should include: "property_ordering":["x","y"]
```

---

### Phase 1 Checklist

- [ ] Added `property_ordering` field to GenerationConfig struct
- [ ] Added `property_ordering/2` helper function
- [ ] Added `structured_json/2` helper function
- [ ] Verified coordinator handles new field (camelCase conversion)
- [ ] Verified type specs are correct
- [ ] Verified Jason encoding works
- [ ] All code compiles without warnings
- [ ] Ran `mix format` on changed files

**Completion Criteria:** All code compiles, no warnings, helpers work in IEx

---

## Phase 2: Testing

**Estimated Time:** 2-3 hours
**Risk Level:** Low

### Step 2.1: Unit Tests for New Field

**File:** `test/gemini/types/generation_config_test.exs`

**Create if doesn't exist, or add tests to existing file:**

```elixir
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

    test "helper function sets property_ordering" do
      config = GenerationConfig.property_ordering(["x", "y"])
      assert config.property_ordering == ["x", "y"]
    end

    test "helper function chains with other helpers" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.temperature(0.7)
        |> GenerationConfig.property_ordering(["name", "age"])

      assert config.temperature == 0.7
      assert config.property_ordering == ["name", "age"]
    end

    test "encodes to JSON correctly" do
      config = GenerationConfig.new(property_ordering: ["a", "b"])
      json = Jason.encode!(config)

      assert String.contains?(json, ~s("property_ordering":["a","b"]))
    end
  end

  describe "structured_json helper" do
    test "sets both response_mime_type and response_schema" do
      schema = %{"type" => "object"}
      config = GenerationConfig.structured_json(schema)

      assert config.response_mime_type == "application/json"
      assert config.response_schema == schema
    end

    test "works with existing config" do
      config =
        GenerationConfig.new(temperature: 0.5)
        |> GenerationConfig.structured_json(%{"type" => "string"})

      assert config.temperature == 0.5
      assert config.response_mime_type == "application/json"
      assert config.response_schema == %{"type" => "string"}
    end

    test "chains with property_ordering" do
      config =
        GenerationConfig.structured_json(%{
          "type" => "object",
          "properties" => %{
            "x" => %{"type" => "integer"},
            "y" => %{"type" => "integer"}
          }
        })
        |> GenerationConfig.property_ordering(["x", "y"])

      assert config.response_mime_type == "application/json"
      assert config.response_schema["type"] == "object"
      assert config.property_ordering == ["x", "y"]
    end
  end
end
```

**Run tests:**
```bash
mix test test/gemini/types/generation_config_test.exs
```

---

### Step 2.2: Coordinator Integration Tests

**File:** `test/gemini/apis/coordinator_generation_config_test.exs` (already exists)

**Action:** Add tests for new field handling

**Add to existing test suite:**

```elixir
describe "property_ordering field handling" do
  test "property_ordering is converted to camelCase" do
    {:ok, request} =
      build_test_request("test prompt",
        property_ordering: ["firstName", "lastName", "age"]
      )

    generation_config = request[:generationConfig]
    assert generation_config[:propertyOrdering] == ["firstName", "lastName", "age"]
  end

  test "property_ordering in GenerationConfig struct is converted" do
    config = GenerationConfig.new(
      property_ordering: ["name", "age"],
      temperature: 0.7
    )

    {:ok, request} = build_test_request("test prompt", generation_config: config)

    generation_config = request[:generationConfig]
    assert generation_config["propertyOrdering"] == ["name", "age"]
    assert generation_config["temperature"] == 0.7
  end

  test "empty property_ordering is filtered out" do
    config = GenerationConfig.new(property_ordering: [])
    {:ok, request} = build_test_request("test prompt", generation_config: config)

    generation_config = request[:generationConfig]
    refute Map.has_key?(generation_config, "propertyOrdering")
  end

  test "nil property_ordering is filtered out" do
    config = GenerationConfig.new(property_ordering: nil)
    {:ok, request} = build_test_request("test prompt", generation_config: config)

    generation_config = request[:generationConfig]
    refute Map.has_key?(generation_config, "propertyOrdering")
  end
end
```

**Run tests:**
```bash
mix test test/gemini/apis/coordinator_generation_config_test.exs
```

---

### Step 2.3: Integration Tests with Live API

**File:** `test/integration/structured_outputs_test.exs` (create new)

**Note:** These tests require a valid `GEMINI_API_KEY`

```elixir
defmodule Gemini.Integration.StructuredOutputsTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 30_000

  alias Gemini.Types.GenerationConfig

  setup do
    # Skip if no API key
    unless System.get_env("GEMINI_API_KEY") do
      {:ok, skip: true}
    else
      :ok
    end
  end

  describe "structured outputs with Gemini 2.5 Flash" do
    test "generates JSON matching simple schema" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "answer" => %{"type" => "string"}
        },
        "required" => ["answer"]
      }

      config = GenerationConfig.structured_json(schema)

      {:ok, response} = Gemini.generate(
        "What is 2+2? Provide the answer in the specified format.",
        model: "gemini-2.5-flash",
        generation_config: config
      )

      {:ok, text} = Gemini.extract_text(response)
      {:ok, json} = Jason.decode(text)

      assert Map.has_key?(json, "answer")
      assert is_binary(json["answer"])
    end

    test "respects property ordering implicitly" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "firstName" => %{"type" => "string"},
          "lastName" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }

      config = GenerationConfig.structured_json(schema)

      {:ok, response} = Gemini.generate(
        "Generate a person named John Smith, age 30",
        model: "gemini-2.5-flash",
        generation_config: config
      )

      {:ok, text} = Gemini.extract_text(response)
      {:ok, json} = Jason.decode(text)

      assert json["firstName"] == "John"
      assert json["lastName"] == "Smith"
      assert json["age"] == 30
    end

    test "handles anyOf for union types" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "status" => %{
            "anyOf" => [
              %{
                "type" => "object",
                "properties" => %{
                  "success" => %{"type" => "string"}
                }
              },
              %{
                "type" => "object",
                "properties" => %{
                  "error" => %{"type" => "string"}
                }
              }
            ]
          }
        }
      }

      config = GenerationConfig.structured_json(schema)

      {:ok, response} = Gemini.generate(
        "Return a success status with message 'ok'",
        model: "gemini-2.5-flash",
        generation_config: config
      )

      {:ok, text} = Gemini.extract_text(response)
      {:ok, json} = Jason.decode(text)

      assert Map.has_key?(json, "status")
      # Should have either "success" or "error"
      status = json["status"]
      assert Map.has_key?(status, "success") or Map.has_key?(status, "error")
    end

    test "respects numeric constraints" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "confidence" => %{
            "type" => "number",
            "minimum" => 0.0,
            "maximum" => 1.0
          }
        }
      }

      config = GenerationConfig.structured_json(schema)

      {:ok, response} = Gemini.generate(
        "Rate your confidence in this answer: The sky is blue",
        model: "gemini-2.5-flash",
        generation_config: config
      )

      {:ok, text} = Gemini.extract_text(response)
      {:ok, json} = Jason.decode(text)

      confidence = json["confidence"]
      assert is_number(confidence)
      assert confidence >= 0.0
      assert confidence <= 1.0
    end
  end

  @tag :skip  # Only run if you have access to Gemini 2.0
  describe "structured outputs with Gemini 2.0 Flash (requires propertyOrdering)" do
    test "generates JSON with explicit property ordering" do
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

      {:ok, response} = Gemini.generate(
        "Generate a person named Alice, age 25",
        model: "gemini-2.0-flash",
        generation_config: config
      )

      {:ok, text} = Gemini.extract_text(response)
      {:ok, json} = Jason.decode(text)

      assert json["name"] == "Alice"
      assert json["age"] == 25
    end
  end

  describe "streaming with structured outputs" do
    test "streams valid partial JSON" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "story" => %{"type" => "string"}
        }
      }

      config = GenerationConfig.structured_json(schema)

      {:ok, responses} = Gemini.stream_generate(
        "Write a short story (2 sentences)",
        model: "gemini-2.5-flash",
        generation_config: config
      )

      # Concatenate all chunks
      full_text =
        responses
        |> Enum.map(fn resp ->
          {:ok, text} = Gemini.extract_text(resp)
          text
        end)
        |> Enum.join()

      # Should be valid JSON
      {:ok, json} = Jason.decode(full_text)
      assert Map.has_key?(json, "story")
      assert is_binary(json["story"])
    end
  end
end
```

**Run integration tests:**
```bash
GEMINI_API_KEY="your_key" mix test --only integration
```

---

### Step 2.4: Add Tests to Existing Test Suite

**File:** `test/gemini/apis/coordinator_generation_config_test.exs`

**Add scenarios using new JSON Schema keywords:**

```elixir
describe "new JSON Schema keywords (Nov 2025)" do
  test "anyOf keyword is preserved" do
    schema = %{
      "anyOf" => [
        %{"type" => "string"},
        %{"type" => "number"}
      ]
    }

    {:ok, request} = build_test_request(
      "test",
      response_schema: schema,
      response_mime_type: "application/json"
    )

    gen_config = request[:generationConfig]
    assert gen_config[:responseSchema]["anyOf"] == [
      %{"type" => "string"},
      %{"type" => "number"}
    ]
  end

  test "$ref keyword is preserved" do
    schema = %{
      "$defs" => %{
        "Node" => %{"type" => "object"}
      },
      "type" => "object",
      "properties" => %{
        "root" => %{"$ref" => "#/$defs/Node"}
      }
    }

    {:ok, request} = build_test_request(
      "test",
      response_schema: schema,
      response_mime_type: "application/json"
    )

    gen_config = request[:generationConfig]
    assert gen_config[:responseSchema]["$defs"]["Node"] == %{"type" => "object"}
    assert gen_config[:responseSchema]["properties"]["root"]["$ref"] == "#/$defs/Node"
  end

  test "minimum/maximum keywords are preserved" do
    schema = %{
      "type" => "number",
      "minimum" => 0,
      "maximum" => 100
    }

    {:ok, request} = build_test_request(
      "test",
      response_schema: schema,
      response_mime_type: "application/json"
    )

    gen_config = request[:generationConfig]
    assert gen_config[:responseSchema]["minimum"] == 0
    assert gen_config[:responseSchema]["maximum"] == 100
  end

  test "additionalProperties keyword is preserved" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string"}},
      "additionalProperties" => false
    }

    {:ok, request} = build_test_request(
      "test",
      response_schema: schema,
      response_mime_type: "application/json"
    )

    gen_config = request[:generationConfig]
    assert gen_config[:responseSchema]["additionalProperties"] == false
  end

  test "null type is preserved" do
    schema = %{
      "type" => ["string", "null"]
    }

    {:ok, request} = build_test_request(
      "test",
      response_schema: schema,
      response_mime_type: "application/json"
    )

    gen_config = request[:generationConfig]
    assert gen_config[:responseSchema]["type"] == ["string", "null"]
  end

  test "prefixItems keyword is preserved" do
    schema = %{
      "type" => "array",
      "prefixItems" => [
        %{"type" => "number"},
        %{"type" => "number"}
      ],
      "items" => false
    }

    {:ok, request} = build_test_request(
      "test",
      response_schema: schema,
      response_mime_type: "application/json"
    )

    gen_config = request[:generationConfig]
    assert length(gen_config[:responseSchema]["prefixItems"]) == 2
    assert gen_config[:responseSchema]["items"] == false
  end
end
```

---

### Phase 2 Checklist

- [ ] Unit tests for `property_ordering` field
- [ ] Unit tests for `structured_json/2` helper
- [ ] Unit tests for `property_ordering/2` helper
- [ ] Coordinator tests for camelCase conversion
- [ ] Tests for new JSON Schema keywords
- [ ] Integration tests with live API (Gemini 2.5)
- [ ] Integration tests for streaming
- [ ] All tests pass: `mix test`
- [ ] Integration tests pass: `mix test --only integration`

**Completion Criteria:** 95%+ test coverage, all tests passing

---

## Phase 3: Documentation

**Estimated Time:** 3-4 hours
**Risk Level:** Low

### Step 3.1: Create Structured Outputs Guide

**File:** `docs/guides/structured_outputs.md` (create new)

**Content:** See `05_DOCUMENTATION_UPDATES.md` for complete content

**Summary:**
- Overview of structured outputs
- When to use them
- New JSON Schema keywords with examples
- Property ordering behavior
- Streaming considerations
- Best practices
- Error handling
- Real-world patterns

---

### Step 3.2: Update API Reference

**Files to update:**
- `lib/gemini/types/common/generation_config.ex` - Already done (added @doc)
- `lib/gemini.ex` - Add examples using new features

**Action:** Add example to module documentation

**File:** `lib/gemini.ex`

**Location:** Around line 140 (in the examples section)

**Add:**

```elixir
### Structured Outputs

Generate JSON that matches a specific schema:

```elixir
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

# Use structured_json helper
config = Gemini.Types.GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "Analyze this review: 'Great product, highly recommend!'",
  model: "gemini-2.5-flash",
  generation_config: config
)

{:ok, text} = Gemini.extract_text(response)
{:ok, data} = Jason.decode(text)
# => %{"summary" => "...", "sentiment" => "positive", "confidence" => 0.95}
```

For Gemini 2.0 models, add explicit property ordering:

```elixir
config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.property_ordering(["summary", "sentiment", "confidence"])

{:ok, response} = Gemini.generate(
  "Analyze this review",
  model: "gemini-2.0-flash",
  generation_config: config
)
```

See `docs/guides/structured_outputs.md` for comprehensive examples.
```

---

### Step 3.3: Update README

**File:** `README.md`

**Location:** Line 150 (in "Advanced Generation Configuration" section)

**Action:** Enhance examples with new features

**Add after line 181:**

```markdown
### Structured JSON Outputs

Generate responses that guarantee adherence to a JSON Schema:

```elixir
# Simple structured output
schema = %{
  "type" => "object",
  "properties" => %{
    "answer" => %{"type" => "string"},
    "confidence" => %{"type" => "number", "minimum" => 0, "maximum" => 1}
  }
}

config = Gemini.Types.GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "What is the capital of France? Rate your confidence.",
  model: "gemini-2.5-flash",
  generation_config: config
)

# Response is guaranteed valid JSON matching the schema
{:ok, data} = Jason.decode!(response.text)
# => %{"answer" => "Paris", "confidence" => 0.99}
```

**New Features (Nov 2025):**
- `anyOf` for union types
- `$ref` for recursive schemas
- `minimum`/`maximum` for numeric constraints
- `prefixItems` for tuple-like arrays
- Universal model support

See [Structured Outputs Guide](docs/guides/structured_outputs.md) for detailed examples.
```

---

### Step 3.4: Create CHANGELOG Entry

**File:** `CHANGELOG.md`

**Location:** Top of file

**Action:** Add v0.4.0 entry

```markdown
## [0.4.0] - 2025-11-06

### Added

- **Structured Outputs Enhancement** - Full support for Gemini API November 2025 updates
  - Added `property_ordering` field to `GenerationConfig` for Gemini 2.0 model support
  - Added `structured_json/2` convenience helper for easy structured output setup
  - Added `property_ordering/2` helper for explicit property ordering
  - Support for new JSON Schema keywords:
    - `anyOf` - Union types and conditional structures
    - `$ref` - Recursive schemas
    - `minimum`/`maximum` - Numeric constraints
    - `additionalProperties` - Control extra properties
    - `type: "null"` - Nullable fields
    - `prefixItems` - Tuple-like arrays
  - Comprehensive structured outputs guide in `docs/guides/structured_outputs.md`
  - Examples for all new features and patterns

### Improved

- Enhanced documentation for structured outputs
- Better examples in README and API reference
- Improved test coverage for generation config options

### Notes

- Gemini 2.5+ models preserve schema key order automatically
- Gemini 2.0 models require explicit `property_ordering` field
- All changes are backward compatible

See `docs/20251106/structured_outputs_enhancement/` for complete technical documentation.

## [0.3.1] - Previous release...
```

---

### Step 3.5: Update ExDoc Configuration

**File:** `mix.exs`

**Location:** In `docs()` function

**Action:** Add new guide to docs

```elixir
defp docs do
  [
    main: "readme",
    extras: [
      "README.md",
      "CHANGELOG.md",
      "docs/guides/authentication.md",
      "docs/guides/structured_outputs.md",  # NEW
      # ... other files
    ],
    groups_for_extras: [
      "Guides": ~r/docs\/guides\/.*/,
      # ...
    ]
  ]
end
```

---

### Phase 3 Checklist

- [ ] Created `docs/guides/structured_outputs.md`
- [ ] Updated `lib/gemini.ex` module docs
- [ ] Updated README.md with examples
- [ ] Created CHANGELOG entry
- [ ] Updated ExDoc configuration
- [ ] Generated docs: `mix docs`
- [ ] Reviewed generated HTML docs
- [ ] All links work, formatting correct

**Completion Criteria:** Complete, accurate documentation for all new features

---

## Phase 4: Examples

**Estimated Time:** 2-3 hours
**Risk Level:** Low

### Step 4.1: Create Basic Example

**File:** `examples/structured_outputs_demo.exs` (create new)

**Content:** See `06_EXAMPLES.md` for complete code

---

### Step 4.2: Create Advanced Example

**File:** `examples/structured_outputs_advanced.exs` (create new)

**Content:** See `06_EXAMPLES.md` for complete code

---

### Step 4.3: Update Examples README

**File:** `examples/README.md` or create if doesn't exist

**Action:** Document new examples

---

### Phase 4 Checklist

- [ ] Created basic structured outputs example
- [ ] Created advanced structured outputs example
- [ ] Verified examples run successfully
- [ ] Added examples to examples README
- [ ] Examples are well-commented and educational

**Completion Criteria:** Working, documented examples ready for users

---

## Phase 5: Release

**Estimated Time:** 1-2 hours
**Risk Level:** Medium

### Step 5.1: Pre-Release Checklist

- [ ] All tests pass: `mix test`
- [ ] Integration tests pass: `mix test --only integration`
- [ ] Dialyzer passes: `mix dialyzer`
- [ ] Formatting correct: `mix format --check-formatted`
- [ ] Credo passes: `mix credo --strict`
- [ ] Documentation builds: `mix docs`
- [ ] Examples run successfully
- [ ] CHANGELOG is complete and accurate
- [ ] Version bumped in `mix.exs`

---

### Step 5.2: Version Bump

**File:** `mix.exs`

**Action:** Update version

```elixir
def project do
  [
    app: :gemini_ex,
    version: "0.4.0",  # Changed from 0.3.1
    # ...
  ]
end
```

---

### Step 5.3: Git Workflow

```bash
# Ensure all changes are committed
git status

# Add all files
git add .

# Commit
git commit -m "feat: Add structured outputs enhancements

- Add property_ordering field for Gemini 2.0 support
- Add structured_json/2 and property_ordering/2 helpers
- Support new JSON Schema keywords (anyOf, $ref, minimum, maximum, etc.)
- Add comprehensive structured outputs guide
- Add examples and integration tests
- Update documentation

Closes #XXX"

# Push feature branch
git push origin feature/structured-outputs-enhancement

# Create pull request (use GitHub CLI or web interface)
gh pr create --title "Structured Outputs Enhancement" --body "See CHANGELOG.md for details"
```

---

### Step 5.4: Review and Merge

1. Request code review
2. Address feedback
3. Ensure CI passes
4. Merge to main
5. Tag release

```bash
# After merge to main
git checkout main
git pull origin main

# Create tag
git tag -a v0.4.0 -m "Release v0.4.0 - Structured Outputs Enhancement"

# Push tag
git push origin v0.4.0
```

---

### Step 5.5: Publish to Hex.pm

```bash
# Build release
mix hex.build

# Publish (requires authentication)
mix hex.publish
```

---

### Step 5.6: Announce Release

**Platforms:**
- GitHub Release notes
- Hex.pm package page
- Elixir Forum
- Twitter/X
- Discord/Slack communities

**Template:**

```
🎉 gemini_ex v0.4.0 Released!

Structured Outputs Enhancement - Full support for Gemini API November 2025 updates

✨ New Features:
• Support for new JSON Schema keywords (anyOf, $ref, minimum, maximum, etc.)
• property_ordering for Gemini 2.0 models
• Convenient structured_json/2 helper
• Comprehensive guide and examples

📚 Documentation:
https://hexdocs.pm/gemini_ex/0.4.0/

🔗 Links:
GitHub: https://github.com/nshkrdotcom/gemini_ex
Hex: https://hex.pm/packages/gemini_ex

All changes are backward compatible! 🎊
```

---

### Phase 5 Checklist

- [ ] All pre-release checks pass
- [ ] Version bumped
- [ ] Changes committed and pushed
- [ ] Pull request created and reviewed
- [ ] Merged to main
- [ ] Tagged release
- [ ] Published to Hex.pm
- [ ] Release announced

**Completion Criteria:** v0.4.0 successfully published and announced

---

## Rollback Plan

### If Issues Discovered

**Severity: Critical (breaking bugs)**

1. Revert commit on main
2. Unpublish from Hex (if possible)
3. Publish hotfix with previous version
4. Communicate issue to users

**Severity: Medium (non-breaking bugs)**

1. Fix issue in patch release (v0.4.1)
2. Document workaround in GitHub Issues
3. Update docs if needed

**Severity: Low (documentation issues)**

1. Fix documentation
2. Update without version bump
3. Force push docs to Hex

---

## Success Metrics

### Quantitative

- [ ] 0 new failing tests
- [ ] 95%+ test coverage maintained
- [ ] 0 Dialyzer warnings
- [ ] 0 Credo warnings
- [ ] Documentation builds without errors

### Qualitative

- [ ] User feedback is positive
- [ ] No critical issues reported within 1 week
- [ ] Examples are clear and helpful
- [ ] Documentation answers common questions

---

## Timeline Summary

| Phase | Duration | Cumulative |
|-------|----------|-----------|
| Phase 1: Code | 30-45 min | 45 min |
| Phase 2: Testing | 2-3 hours | 3.5 hours |
| Phase 3: Docs | 3-4 hours | 7.5 hours |
| Phase 4: Examples | 2-3 hours | 10.5 hours |
| Phase 5: Release | 1-2 hours | 12 hours |

**Total: 8-12 hours** (1-2 focused work days)

---

**Next Document:** `03_CODE_CHANGES.md` - Exact code to add/modify
