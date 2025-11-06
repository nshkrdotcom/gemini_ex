# Complete Implementation Prompt: Structured Outputs Enhancement

**Agent Context:** Fresh start - no prior knowledge assumed
**Task:** Implement structured outputs enhancement for gemini_ex v0.4.0
**Approach:** Test-Driven Development (TDD)
**Location:** `gemini_ex` project in N: drive (WSL Ubuntu)

---

## Your Mission

You are tasked with implementing the structured outputs enhancement for the `gemini_ex` Elixir library. This enhancement adds support for the Gemini API's November 2025 structured outputs updates.

**What you'll do:**
1. Read and understand all provided context
2. Implement changes using TDD (write tests first)
3. Ensure 100% backward compatibility
4. Create comprehensive documentation and examples
5. Prepare for v0.4.0 release

**Time estimate:** 8-12 hours of focused work

---

## SECTION 1: REQUIRED READING

### 1.1 API Documentation (November 2025 Update)

**Source:** Gemini API Structured Outputs Documentation

#### Key API Changes

**NEW: `propertyOrdering` Field**

For Gemini 2.0 models only, an explicit property ordering list is required:

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

**Model Behavior:**
- **Gemini 2.5+**: Implicit ordering (preserves schema key order automatically)
- **Gemini 2.0**: Requires explicit `propertyOrdering` array

**NEW: JSON Schema Keywords (All Models)**

The API now supports these additional JSON Schema keywords:

1. **`anyOf`** - Union types / conditional structures
   ```json
   {
     "anyOf": [
       {"type": "string"},
       {"type": "number"}
     ]
   }
   ```

2. **`$ref`** - Recursive schemas
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
     }
   }
   ```

3. **`minimum` / `maximum`** - Numeric constraints
   ```json
   {
     "type": "number",
     "minimum": 0,
     "maximum": 100
   }
   ```

4. **`additionalProperties`** - Control extra properties
   ```json
   {
     "type": "object",
     "properties": {"name": {"type": "string"}},
     "additionalProperties": false
   }
   ```

5. **`type: "null"`** - Nullable fields
   ```json
   {
     "type": ["string", "null"]
   }
   ```

6. **`prefixItems`** - Tuple-like arrays
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

**Property Ordering Guarantee:**
- Gemini 2.5+ models preserve the order of keys in your schema
- This is implicit - you don't need to do anything
- Output JSON will have keys in the same order as your schema

**Streaming Behavior:**
- Structured outputs now work reliably with streaming
- Each chunk is valid partial JSON
- Chunks can be concatenated to form complete JSON

---

### 1.2 Current Implementation State

**File:** `lib/gemini/types/common/generation_config.ex`

Current fields in GenerationConfig struct:
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
  # MISSING: property_ordering field
end
```

Current helper functions include:
- `new/1` - Create config
- `creative/1`, `balanced/1`, `precise/1`, `deterministic/1` - Presets
- `json_response/1`, `text_response/1` - MIME type helpers
- `max_tokens/2`, `stop_sequences/2` - Field setters
- `thinking_budget/2`, `include_thoughts/2` - Thinking config

**Missing:**
- `property_ordering` field
- `property_ordering/2` helper
- `structured_json/2` convenience helper

---

### 1.3 What Needs to Change

**Summary of Changes:**

1. **Add field to GenerationConfig:**
   - `property_ordering` field ([String.t()] | nil)

2. **Add helper functions:**
   - `property_ordering/2` - Set property ordering
   - `structured_json/2` - Convenience helper for structured output

3. **Ensure coordinator handles field:**
   - CamelCase conversion: `property_ordering` → `propertyOrdering`

4. **Update documentation:**
   - README examples
   - Module documentation
   - New comprehensive guide

5. **Create examples:**
   - Basic structured output
   - Advanced features (anyOf, $ref, etc.)
   - Real-world use cases

6. **Comprehensive testing:**
   - Unit tests for new field and helpers
   - Integration tests with live API
   - Property-based tests

---

## SECTION 2: IMPLEMENTATION INSTRUCTIONS (TDD)

### Phase 1: Test-First Implementation (TDD)

#### Step 1.1: Write Tests for `property_ordering` Field

**File to create:** `test/gemini/types/generation_config_test.exs`

**Test to write FIRST:**

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

    test "accepts empty list" do
      config = GenerationConfig.new(property_ordering: [])
      assert config.property_ordering == []
    end
  end
end
```

**Run tests (they should FAIL):**
```bash
mix test test/gemini/types/generation_config_test.exs
```

Expected error: Field `property_ordering` doesn't exist

#### Step 1.2: Implement to Make Tests Pass

**File to modify:** `lib/gemini/types/common/generation_config.ex`

**Add field (line 38, after thinking_config):**
```elixir
field(:property_ordering, [String.t()] | nil, default: nil)
```

**Run tests again:**
```bash
mix test test/gemini/types/generation_config_test.exs
```

Tests should now PASS ✅

---

#### Step 2.1: Write Tests for `property_ordering/2` Helper

**Add to test file:**

```elixir
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
```

**Run tests (should FAIL):**
```bash
mix test test/gemini/types/generation_config_test.exs
```

Expected error: Function `property_ordering/2` undefined

#### Step 2.2: Implement Helper Function

**File:** `lib/gemini/types/common/generation_config.ex`

**Add after line 220 (after thinking_config functions):**

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
```

**Run tests:**
```bash
mix test test/gemini/types/generation_config_test.exs
```

Tests should PASS ✅

---

#### Step 3.1: Write Tests for `structured_json/2` Helper

**Add to test file:**

```elixir
describe "structured_json/2 helper" do
  test "sets both response_mime_type and response_schema" do
    schema = %{"type" => "object", "properties" => %{}}
    config = GenerationConfig.structured_json(schema)

    assert config.response_mime_type == "application/json"
    assert config.response_schema == schema
  end

  test "works with nil config (default)" do
    schema = %{"type" => "string"}
    config = GenerationConfig.structured_json(schema)

    assert config.response_mime_type == "application/json"
    assert config.response_schema == schema
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
    assert config.response_schema == schema
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
    assert config.response_schema == schema
    assert config.property_ordering == ["name", "age"]
  end
end
```

**Run tests (should FAIL):**
```bash
mix test test/gemini/types/generation_config_test.exs
```

#### Step 3.2: Implement structured_json/2 Helper

**File:** `lib/gemini/types/common/generation_config.ex`

**Add after property_ordering/2:**

```elixir
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

**Run tests:**
```bash
mix test test/gemini/types/generation_config_test.exs
```

All tests should PASS ✅

---

#### Step 4: Test JSON Encoding

**Add to test file:**

```elixir
describe "JSON encoding" do
  test "encodes property_ordering correctly" do
    config = GenerationConfig.new(
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
```

**Run tests:**
```bash
mix test test/gemini/types/generation_config_test.exs
```

Should PASS (Jason encoder already handles the field) ✅

---

#### Step 5: Test Coordinator Integration

**File to check/modify:** `test/gemini/apis/coordinator_generation_config_test.exs`

**Add tests:**

```elixir
describe "property_ordering field handling" do
  test "property_ordering individual option converts to camelCase" do
    {:ok, request} =
      build_test_request("test prompt",
        property_ordering: ["firstName", "lastName", "age"]
      )

    generation_config = request[:generationConfig]
    assert generation_config[:propertyOrdering] == ["firstName", "lastName", "age"]
  end

  test "property_ordering in struct converts to camelCase" do
    config = GenerationConfig.new(
      property_ordering: ["name", "age"],
      temperature: 0.7
    )

    {:ok, request} = build_test_request("test", generation_config: config)

    generation_config = request[:generationConfig]
    assert generation_config["propertyOrdering"] == ["name", "age"]
    assert generation_config["temperature"] == 0.7
  end

  test "empty property_ordering is filtered out" do
    config = GenerationConfig.new(property_ordering: [])
    {:ok, request} = build_test_request("test", generation_config: config)

    generation_config = request[:generationConfig]
    refute Map.has_key?(generation_config, "propertyOrdering")
  end
end

describe "structured_json helper integration" do
  test "produces correct API request" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "answer" => %{"type" => "string"}
      }
    }

    config = GenerationConfig.structured_json(schema)
    {:ok, request} = build_test_request("test", generation_config: config)

    gen_config = request[:generationConfig]
    assert gen_config["responseMimeType"] == "application/json"
    assert gen_config["responseSchema"] == schema
  end
end
```

**Run tests:**
```bash
mix test test/gemini/apis/coordinator_generation_config_test.exs
```

**If tests FAIL**, check `lib/gemini/apis/coordinator.ex`:

Look for `build_generation_config/1` function. Add this clause if needed:

```elixir
{:property_ordering, ordering}, acc when is_list(ordering) and ordering != [] ->
  Map.put(acc, :propertyOrdering, ordering)
```

Run tests again until they PASS ✅

---

#### Step 6: Integration Tests with Live API

**File to create:** `test/integration/structured_outputs_test.exs`

```elixir
defmodule Gemini.Integration.StructuredOutputsTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 30_000

  alias Gemini.Types.GenerationConfig

  setup do
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
        "What is 2+2? Respond in the specified format.",
        model: "gemini-2.5-flash",
        generation_config: config
      )

      {:ok, text} = Gemini.extract_text(response)
      {:ok, json} = Jason.decode(text)

      assert Map.has_key?(json, "answer")
      assert is_binary(json["answer"])
    end

    test "handles anyOf for union types" do
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

      config = GenerationConfig.structured_json(schema)

      {:ok, response} = Gemini.generate(
        "Return a success status",
        model: "gemini-2.5-flash",
        generation_config: config
      )

      {:ok, text} = Gemini.extract_text(response)
      {:ok, json} = Jason.decode(text)

      assert Map.has_key?(json, "status")
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
        "Rate your confidence",
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

      full_text =
        responses
        |> Enum.map(fn resp ->
          {:ok, text} = Gemini.extract_text(resp)
          text
        end)
        |> Enum.join()

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

All tests should PASS ✅

---

### Phase 2: Documentation

#### Step 7: Update README

**File:** `README.md`

**Add after line 181 (in Advanced Generation Configuration section):**

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
    }
  }
}

# Use the convenient helper
config = Gemini.Types.GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "What is the capital of France?",
  model: "gemini-2.5-flash",
  generation_config: config
)

{:ok, text} = Gemini.extract_text(response)
{:ok, data} = Jason.decode(text)
# => %{"answer" => "Paris", "confidence" => 0.99}
```

**New Features (November 2025):**
- `anyOf` for union types
- `$ref` for recursive schemas
- `minimum`/`maximum` for numeric constraints
- `prefixItems` for tuple-like arrays

For Gemini 2.0 models, add explicit property ordering:

```elixir
config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.property_ordering(["answer", "confidence"])
```

See [Structured Outputs Guide](docs/guides/structured_outputs.md) for details.
```

---

#### Step 8: Update CHANGELOG

**File:** `CHANGELOG.md`

**Add at top:**

```markdown
## [0.4.0] - 2025-11-06

### Added

- **Structured Outputs Enhancement** - Full support for Gemini API November 2025 updates
  - `property_ordering` field in `GenerationConfig` for Gemini 2.0 model support
  - `structured_json/2` convenience helper for structured output setup
  - `property_ordering/2` helper for explicit property ordering
  - Support for new JSON Schema keywords:
    - `anyOf` - Union types and conditional structures
    - `$ref` - Recursive schema definitions
    - `minimum`/`maximum` - Numeric value constraints
    - `additionalProperties` - Control over extra properties
    - `type: "null"` - Nullable field definitions
    - `prefixItems` - Tuple-like array structures
  - Comprehensive structured outputs guide (`docs/guides/structured_outputs.md`)
  - Working examples demonstrating all new features

### Improved

- Enhanced documentation for structured outputs use cases
- Better code examples in README and API reference
- Expanded test coverage for generation config options

### Notes

- Gemini 2.5+ models preserve schema key order automatically
- Gemini 2.0 models require explicit `property_ordering` field
- All changes are backward compatible - no breaking changes

---

## [0.3.1] - Previous release...
```

---

#### Step 9: Version Bump

**File:** `mix.exs`

**Change:**
```elixir
# From:
version: "0.3.1",

# To:
version: "0.4.0",
```

**Add to docs config:**
```elixir
defp docs do
  [
    main: "readme",
    extras: [
      "README.md",
      "CHANGELOG.md",
      "docs/guides/structured_outputs.md",  # ADD THIS
      # ... other files
    ]
  ]
end
```

---

### Phase 3: Examples

#### Step 10: Create Basic Example

**File to create:** `examples/structured_outputs_basic.exs`

```elixir
Mix.install([
  {:gemini_ex, path: ".."},
  {:jason, "~> 1.4"}
])

defmodule BasicExample do
  alias Gemini.Types.GenerationConfig

  def run do
    IO.puts("\n🚀 Basic Structured Outputs Example\n")

    # Example 1: Simple Q&A
    schema = %{
      "type" => "object",
      "properties" => %{
        "answer" => %{"type" => "string"},
        "confidence" => %{"type" => "number", "minimum" => 0, "maximum" => 1}
      }
    }

    config = GenerationConfig.structured_json(schema)

    case Gemini.generate(
           "What is 2+2? Rate confidence.",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        IO.puts("✅ Answer: #{data["answer"]}")
        IO.puts("   Confidence: #{Float.round(data["confidence"], 2)}")

      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end
end

if System.get_env("GEMINI_API_KEY") do
  BasicExample.run()
else
  IO.puts("⚠️  Set GEMINI_API_KEY to run")
end
```

**Test the example:**
```bash
GEMINI_API_KEY="your_key" mix run examples/structured_outputs_basic.exs
```

---

### Phase 4: Final Verification

#### Step 11: Run All Tests

```bash
# Unit tests
mix test

# Integration tests
GEMINI_API_KEY="your_key" mix test --only integration

# Check coverage
mix test --cover

# Should see 95%+ coverage
```

#### Step 12: Run Quality Checks

```bash
# Format code
mix format

# Check formatting
mix format --check-formatted

# Run Dialyzer
mix dialyzer

# Run Credo
mix credo --strict
```

#### Step 13: Generate Documentation

```bash
# Generate docs
mix docs

# Open in browser
open doc/index.html  # or start doc/index.html on Windows
```

---

## SECTION 3: SUCCESS CRITERIA

Your implementation is complete when:

### Code
- [x] `property_ordering` field added to GenerationConfig
- [x] `property_ordering/2` helper implemented
- [x] `structured_json/2` helper implemented
- [x] Coordinator handles field correctly (camelCase)
- [x] Code compiles with no warnings
- [x] All code formatted (`mix format`)

### Tests
- [x] Unit tests for new field pass
- [x] Unit tests for helpers pass
- [x] Coordinator integration tests pass
- [x] Live API integration tests pass
- [x] Overall test coverage ≥ 95%
- [x] No Dialyzer warnings
- [x] No Credo warnings

### Documentation
- [x] README updated with examples
- [x] CHANGELOG entry created
- [x] Module documentation updated
- [x] Version bumped to 0.4.0
- [x] Docs generate without errors

### Examples
- [x] Basic example works
- [x] Example demonstrates new features
- [x] Example has error handling

### Validation
- [x] Existing tests still pass (backward compatibility)
- [x] Integration tests pass with live API
- [x] Examples run successfully
- [x] Documentation is clear and accurate

---

## SECTION 4: EXECUTION CHECKLIST

Follow this checklist in order:

### Setup (5 minutes)
- [ ] Navigate to gemini_ex project
- [ ] Create feature branch: `git checkout -b feature/structured-outputs`
- [ ] Ensure dependencies installed: `mix deps.get`
- [ ] Run baseline tests: `mix test` (note current pass count)

### TDD Cycle 1: Field (15 minutes)
- [ ] Write tests for `property_ordering` field
- [ ] Run tests (should fail)
- [ ] Add field to GenerationConfig struct
- [ ] Run tests (should pass)
- [ ] Commit: `git add -A && git commit -m "Add property_ordering field"`

### TDD Cycle 2: Helper 1 (15 minutes)
- [ ] Write tests for `property_ordering/2` helper
- [ ] Run tests (should fail)
- [ ] Implement `property_ordering/2` function
- [ ] Run tests (should pass)
- [ ] Commit: `git add -A && git commit -m "Add property_ordering/2 helper"`

### TDD Cycle 3: Helper 2 (15 minutes)
- [ ] Write tests for `structured_json/2` helper
- [ ] Run tests (should fail)
- [ ] Implement `structured_json/2` function
- [ ] Run tests (should pass)
- [ ] Commit: `git add -A && git commit -m "Add structured_json/2 helper"`

### TDD Cycle 4: Integration (30 minutes)
- [ ] Write coordinator tests
- [ ] Run tests (check if pass/fail)
- [ ] Fix coordinator if needed
- [ ] Write live API integration tests
- [ ] Run with API key (should pass)
- [ ] Commit: `git add -A && git commit -m "Add integration tests"`

### Documentation (1 hour)
- [ ] Update README
- [ ] Update CHANGELOG
- [ ] Update version in mix.exs
- [ ] Commit: `git add -A && git commit -m "Update documentation"`

### Examples (30 minutes)
- [ ] Create basic example
- [ ] Test example with API
- [ ] Commit: `git add -A && git commit -m "Add examples"`

### Validation (30 minutes)
- [ ] Run all tests: `mix test`
- [ ] Run integration: `GEMINI_API_KEY=key mix test --only integration`
- [ ] Check coverage: `mix test --cover`
- [ ] Run Dialyzer: `mix dialyzer`
- [ ] Run Credo: `mix credo --strict`
- [ ] Format code: `mix format`
- [ ] Generate docs: `mix docs`
- [ ] Test example: `GEMINI_API_KEY=key mix run examples/structured_outputs_basic.exs`

### Final Steps (15 minutes)
- [ ] Review all changes
- [ ] Ensure no TODOs left
- [ ] Push branch: `git push origin feature/structured-outputs`
- [ ] Create summary of changes

---

## SECTION 5: TROUBLESHOOTING

### Common Issues

**Issue: Tests fail with "undefined field :property_ordering"**
- Solution: Make sure you added the field to the typedstruct block
- Location: `lib/gemini/types/common/generation_config.ex` line 38

**Issue: Coordinator tests fail**
- Solution: Check if `build_generation_config/1` needs the clause for `property_ordering`
- Location: `lib/gemini/apis/coordinator.ex`

**Issue: Integration tests timeout**
- Solution: Ensure `GEMINI_API_KEY` is set correctly
- Command: `export GEMINI_API_KEY="your_key"`

**Issue: Dialyzer warnings**
- Solution: Update type specs if needed
- The new field should be covered by existing specs

**Issue: Example doesn't work**
- Solution: Check that you're using `{:gemini_ex, path: ".."}` in Mix.install
- Ensure API key is set

---

## SECTION 6: REFERENCE - FILE LOCATIONS

All files are in: `\\wsl.localhost\ubuntu-dev\home\home\p\g\n\gemini_ex\`

**Files to modify:**
- `lib/gemini/types/common/generation_config.ex` - Add field and helpers
- `lib/gemini/apis/coordinator.ex` - Possibly add camelCase handling
- `mix.exs` - Version bump, docs config
- `README.md` - Examples
- `CHANGELOG.md` - Release notes

**Files to create:**
- `test/gemini/types/generation_config_test.exs` - Unit tests
- `test/integration/structured_outputs_test.exs` - Integration tests
- `examples/structured_outputs_basic.exs` - Basic example

**Files to check:**
- `test/gemini/apis/coordinator_generation_config_test.exs` - Add tests

---

## SECTION 7: EXPECTED OUTCOME

When complete, you should have:

1. **Working code** that compiles without warnings
2. **Passing tests** with 95%+ coverage
3. **Updated documentation** that is clear and helpful
4. **Working examples** that demonstrate the features
5. **Clean git history** with logical commits

**Final state:**
- Version: 0.4.0
- New field: `property_ordering`
- New helpers: `property_ordering/2`, `structured_json/2`
- Tests: All passing
- Docs: Complete and accurate
- Examples: Working

**Ready for:**
- Code review
- Pull request
- Release to Hex.pm

---

## SECTION 8: COMMANDS QUICK REFERENCE

```bash
# Navigate to project (from Windows/PowerShell)
cd N:\gemini_ex

# Or via WSL
cd /home/home/p/g/n/gemini_ex

# Setup
mix deps.get

# Test cycle
mix test                                    # Run all tests
mix test path/to/test.exs                  # Run specific test
GEMINI_API_KEY=key mix test --only integration  # Integration tests

# Quality checks
mix format                                  # Format code
mix format --check-formatted                # Check formatting
mix dialyzer                                # Type checking
mix credo --strict                          # Code quality
mix test --cover                            # Coverage report

# Documentation
mix docs                                    # Generate docs

# Examples
GEMINI_API_KEY=key mix run examples/structured_outputs_basic.exs

# Git workflow
git checkout -b feature/structured-outputs
git add -A
git commit -m "message"
git push origin feature/structured-outputs
```

---

## READY TO START?

1. Read this entire document
2. Ensure you understand the TDD approach
3. Start with the checklist in SECTION 4
4. Write tests first, then implement
5. Commit frequently with clear messages
6. Validate thoroughly before considering complete

**Time estimate:** 8-12 hours

**Questions?** Refer back to the technical documents in:
`docs/20251106/structured_outputs_enhancement/`

**Let's build it! 🚀**
