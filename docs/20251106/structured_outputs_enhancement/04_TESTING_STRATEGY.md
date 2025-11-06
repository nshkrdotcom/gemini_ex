# Testing Strategy - Structured Outputs Enhancement

**Document:** Testing Strategy
**Initiative:** `structured_outputs_enhancement`
**Date:** November 6, 2025

---

## Overview

Comprehensive testing strategy to ensure the structured outputs enhancement works correctly, maintains backward compatibility, and provides reliable functionality for users.

---

## Testing Pyramid

```
         /\
        /  \  E2E Integration Tests (5%)
       /____\
      /      \
     / Unit   \ Unit Tests (70%)
    /  Tests   \
   /____________\
  /              \
 / Property-Based \ Property Tests (25%)
/     Tests        \
/__________________\
```

**Target Coverage:** 95%+ overall, 100% for new code

---

## Test Categories

### 1. Unit Tests (70% of tests)

**Purpose:** Test individual functions and modules in isolation

**Scope:**
- GenerationConfig field validation
- Helper function behavior
- Coordinator camelCase conversion
- Edge cases and error conditions

---

### 2. Integration Tests (5% of tests)

**Purpose:** Test end-to-end functionality with live API

**Scope:**
- Real API calls with structured outputs
- Validation of API responses
- Streaming behavior
- Model-specific behavior

---

### 3. Property-Based Tests (25% of tests)

**Purpose:** Test invariants and properties across many inputs

**Scope:**
- Schema validation properties
- CamelCase conversion properties
- JSON encoding/decoding properties

---

## Test Files

### File 1: GenerationConfig Unit Tests

**File:** `test/gemini/types/generation_config_test.exs`

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

    test "helper function sets property_ordering" do
      config = GenerationConfig.property_ordering(["x", "y", "z"])
      assert config.property_ordering == ["x", "y", "z"]
    end

    test "helper function works with existing config" do
      config =
        GenerationConfig.new(temperature: 0.5)
        |> GenerationConfig.property_ordering(["a", "b"])

      assert config.temperature == 0.5
      assert config.property_ordering == ["a", "b"]
    end

    test "helper function chains with other helpers" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.json_response()
        |> GenerationConfig.property_ordering(["name", "age"])
        |> GenerationConfig.temperature(0.7)

      assert config.response_mime_type == "application/json"
      assert config.property_ordering == ["name", "age"]
      assert config.temperature == 0.7
    end

    test "encodes to JSON with snake_case key" do
      config = GenerationConfig.new(property_ordering: ["a", "b"])
      json = Jason.encode!(config)

      assert String.contains?(json, ~s("property_ordering"))
      assert String.contains?(json, ~s(["a","b"]))
    end
  end

  describe "structured_json helper" do
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

    test "works with existing config" do
      schema = %{"type" => "number"}
      config =
        GenerationConfig.new(temperature: 0.8)
        |> GenerationConfig.structured_json(schema)

      assert config.temperature == 0.8
      assert config.response_mime_type == "application/json"
      assert config.response_schema == schema
    end

    test "preserves other fields" do
      schema = %{"type" => "object"}
      config =
        GenerationConfig.new(
          temperature: 0.5,
          max_output_tokens: 100,
          stop_sequences: ["END"]
        )
        |> GenerationConfig.structured_json(schema)

      assert config.temperature == 0.5
      assert config.max_output_tokens == 100
      assert config.stop_sequences == ["END"]
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

    test "accepts complex schemas" do
      complex_schema = %{
        "type" => "object",
        "properties" => %{
          "nested" => %{
            "type" => "object",
            "properties" => %{
              "deep" => %{"type" => "string"}
            }
          }
        }
      }

      config = GenerationConfig.structured_json(complex_schema)
      assert config.response_schema == complex_schema
    end
  end

  describe "JSON encoding" do
    test "encodes all fields correctly" do
      config = GenerationConfig.new(
        property_ordering: ["a", "b"],
        response_schema: %{"type" => "object"},
        response_mime_type: "application/json",
        temperature: 0.7
      )

      {:ok, encoded} = Jason.encode(config)
      {:ok, decoded} = Jason.decode(encoded)

      assert decoded["property_ordering"] == ["a", "b"]
      assert decoded["response_schema"] == %{"type" => "object"}
      assert decoded["response_mime_type"] == "application/json"
      assert decoded["temperature"] == 0.7
    end

    test "filters nil values" do
      config = GenerationConfig.new(property_ordering: nil)
      {:ok, encoded} = Jason.encode(config)
      {:ok, decoded} = Jason.decode(encoded)

      assert decoded["property_ordering"] == nil
    end
  end
end
```

---

### File 2: Coordinator Integration Tests

**File:** `test/gemini/apis/coordinator_generation_config_test.exs`

**Add these test cases to existing file:**

```elixir
describe "property_ordering field handling" do
  test "property_ordering individual option is converted to camelCase" do
    {:ok, request} =
      build_test_request("test prompt",
        property_ordering: ["firstName", "lastName", "age"],
        response_schema: %{"type" => "object"},
        response_mime_type: "application/json"
      )

    generation_config = request[:generationConfig]

    assert generation_config[:propertyOrdering] == ["firstName", "lastName", "age"]
    refute Map.has_key?(generation_config, :property_ordering),
           "Should not have snake_case key"
  end

  test "property_ordering in GenerationConfig struct is converted" do
    config = GenerationConfig.new(
      property_ordering: ["name", "age", "email"],
      response_schema: %{"type" => "object"},
      response_mime_type: "application/json",
      temperature: 0.7
    )

    {:ok, request} = build_test_request("test prompt", generation_config: config)

    generation_config = request[:generationConfig]

    assert generation_config["propertyOrdering"] == ["name", "age", "email"]
    assert generation_config["temperature"] == 0.7
    assert generation_config["responseSchema"] == %{"type" => "object"}
  end

  test "empty property_ordering list is filtered out" do
    config = GenerationConfig.new(
      property_ordering: [],
      temperature: 0.5
    )

    {:ok, request} = build_test_request("test prompt", generation_config: config)

    generation_config = request[:generationConfig]

    refute Map.has_key?(generation_config, "propertyOrdering"),
           "Empty list should be filtered out"
    assert generation_config["temperature"] == 0.5
  end

  test "nil property_ordering is filtered out" do
    config = GenerationConfig.new(
      property_ordering: nil,
      temperature: 0.5
    )

    {:ok, request} = build_test_request("test prompt", generation_config: config)

    generation_config = request[:generationConfig]

    refute Map.has_key?(generation_config, "propertyOrdering"),
           "Nil should be filtered out"
    assert generation_config["temperature"] == 0.5
  end

  test "property_ordering with structured_json helper" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "x" => %{"type" => "number"},
        "y" => %{"type" => "number"}
      }
    }

    config =
      GenerationConfig.structured_json(schema)
      |> GenerationConfig.property_ordering(["x", "y"])

    {:ok, request} = build_test_request("test prompt", generation_config: config)

    generation_config = request[:generationConfig]

    assert generation_config["propertyOrdering"] == ["x", "y"]
    assert generation_config["responseMimeType"] == "application/json"
    assert generation_config["responseSchema"] == schema
  end
end

describe "structured_json helper integration" do
  test "structured_json produces correct API request" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "answer" => %{"type" => "string"}
      }
    }

    config = GenerationConfig.structured_json(schema)
    {:ok, request} = build_test_request("What is 2+2?", generation_config: config)

    generation_config = request[:generationConfig]

    assert generation_config["responseMimeType"] == "application/json"
    assert generation_config["responseSchema"] == schema
  end

  test "structured_json with property_ordering for Gemini 2.0" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "first" => %{"type" => "string"},
        "second" => %{"type" => "integer"}
      }
    }

    config =
      GenerationConfig.structured_json(schema)
      |> GenerationConfig.property_ordering(["first", "second"])
      |> GenerationConfig.temperature(0.5)

    {:ok, request} = build_test_request("test", generation_config: config)

    generation_config = request[:generationConfig]

    assert generation_config["responseMimeType"] == "application/json"
    assert generation_config["responseSchema"] == schema
    assert generation_config["propertyOrdering"] == ["first", "second"]
    assert generation_config["temperature"] == 0.5
  end
end
```

---

### File 3: Live API Integration Tests

**File:** `test/integration/structured_outputs_test.exs`

(Complete file - see 02_IMPLEMENTATION_PLAN.md for full content)

---

### File 4: Property-Based Tests

**File:** `test/property/generation_config_property_test.exs`

```elixir
defmodule Gemini.Property.GenerationConfigPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Gemini.Types.GenerationConfig

  describe "property_ordering" do
    property "accepts any list of strings" do
      check all strings <- list_of(string(:printable), min_length: 0, max_length: 20) do
        config = GenerationConfig.new(property_ordering: strings)
        assert config.property_ordering == strings
      end
    end

    property "helper function always returns GenerationConfig struct" do
      check all strings <- list_of(string(:printable)) do
        config = GenerationConfig.property_ordering(strings)
        assert %GenerationConfig{} = config
        assert config.property_ordering == strings
      end
    end

    property "JSON encoding and decoding is reversible for property_ordering" do
      check all strings <- list_of(string(:printable), max_length: 10) do
        config = GenerationConfig.new(property_ordering: strings)

        encoded = Jason.encode!(config)
        {:ok, decoded} = Jason.decode(encoded)

        assert decoded["property_ordering"] == strings
      end
    end
  end

  describe "structured_json" do
    property "always sets both required fields" do
      check all schema <- schema_generator() do
        config = GenerationConfig.structured_json(schema)

        assert config.response_mime_type == "application/json"
        assert config.response_schema == schema
      end
    end

    property "preserves existing config fields" do
      check all temp <- float(min: 0.0, max: 1.0),
                tokens <- integer(1..10_000),
                schema <- schema_generator() do
        config =
          GenerationConfig.new(temperature: temp, max_output_tokens: tokens)
          |> GenerationConfig.structured_json(schema)

        assert config.temperature == temp
        assert config.max_output_tokens == tokens
        assert config.response_schema == schema
      end
    end
  end

  # Helper generators
  defp schema_generator do
    gen all type <- member_of(["string", "number", "integer", "boolean", "object", "array"]) do
      %{"type" => type}
    end
  end
end
```

---

## Test Execution Plan

### Phase 1: Unit Tests

```bash
# Run all unit tests
mix test

# Run specific test file
mix test test/gemini/types/generation_config_test.exs

# Run with coverage
mix test --cover

# Expected: 100% coverage for new code
```

---

### Phase 2: Integration Tests

```bash
# Run integration tests (requires API key)
GEMINI_API_KEY="your_key" mix test --only integration

# Expected: All tests pass, no API errors
```

---

### Phase 3: Property-Based Tests

```bash
# Run property tests
mix test test/property/

# Expected: 100 iterations per property, all pass
```

---

## Test Coverage Requirements

### New Code Coverage: 100%

**Required:**
- `property_ordering` field: 100%
- `property_ordering/2` helper: 100%
- `structured_json/2` helper: 100%
- Coordinator camelCase conversion: 100%

### Overall Coverage: 95%+

**Current baseline:** ~92%
**Target:** 95%+

---

## Edge Cases to Test

### 1. Empty Values

```elixir
# Empty list
config = GenerationConfig.new(property_ordering: [])
# Should be filtered out in API request

# Nil value
config = GenerationConfig.new(property_ordering: nil)
# Should be filtered out in API request
```

### 2. Special Characters

```elixir
# Property names with special characters
config = GenerationConfig.property_ordering([
  "first-name",
  "last_name",
  "age.years",
  "$id"
])
# Should be preserved exactly
```

### 3. Large Lists

```elixir
# Many properties
large_list = Enum.map(1..100, &"prop_#{&1}")
config = GenerationConfig.property_ordering(large_list)
# Should handle without issues
```

### 4. Unicode

```elixir
# Unicode property names
config = GenerationConfig.property_ordering([
  "名前",  # Japanese
  "возраст",  # Russian
  "edad"  # Spanish
])
# Should encode/decode correctly
```

---

## Error Cases to Test

### 1. Invalid Types

```elixir
# Not a list
assert_raise FunctionClauseError, fn ->
  GenerationConfig.new(property_ordering: "not_a_list")
end

# List with non-strings
# Note: This may not raise at struct creation but should be validated
config = GenerationConfig.new(property_ordering: [1, 2, 3])
```

### 2. Mismatched Ordering

```elixir
# Properties in ordering not in schema
schema = %{
  "type" => "object",
  "properties" => %{
    "a" => %{"type" => "string"}
  }
}

config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.property_ordering(["a", "b", "c"])

# API should return error
```

---

## Regression Tests

### Backward Compatibility

```elixir
describe "backward compatibility" do
  test "existing configs without property_ordering still work" do
    config = GenerationConfig.new(
      response_schema: %{"type" => "object"},
      response_mime_type: "application/json",
      temperature: 0.7
    )

    {:ok, response} = Gemini.generate("test", generation_config: config)

    assert response != nil
  end

  test "old-style individual options still work" do
    {:ok, response} = Gemini.generate(
      "test",
      response_schema: %{"type" => "string"},
      response_mime_type: "application/json"
    )

    assert response != nil
  end
end
```

---

## Performance Tests

### JSON Encoding Performance

```elixir
defmodule Gemini.Performance.GenerationConfigTest do
  use ExUnit.Case

  test "JSON encoding with property_ordering is fast" do
    large_ordering = Enum.map(1..1000, &"property_#{&1}")
    config = GenerationConfig.new(property_ordering: large_ordering)

    {time, _result} = :timer.tc(fn -> Jason.encode!(config) end)

    # Should complete in < 10ms
    assert time < 10_000
  end
end
```

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.3'
          otp-version: '27.3.3'

      - name: Install dependencies
        run: mix deps.get

      - name: Run tests
        run: mix test --cover

      - name: Run integration tests
        if: ${{ secrets.GEMINI_API_KEY }}
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
        run: mix test --only integration

      - name: Check coverage
        run: |
          coverage=$(mix test --cover | grep -oP '(?<=Coverage: )\d+')
          if [ $coverage -lt 95 ]; then
            echo "Coverage is below 95%"
            exit 1
          fi
```

---

## Test Checklist

### Before Commit
- [ ] All unit tests pass
- [ ] All integration tests pass (with API key)
- [ ] Property tests pass (100 iterations each)
- [ ] Coverage is 95%+
- [ ] No new Dialyzer warnings
- [ ] Performance tests pass

### Before PR
- [ ] CI passes
- [ ] Code review completed
- [ ] Documentation updated
- [ ] Examples tested manually

### Before Release
- [ ] Full test suite passes on multiple Elixir versions
- [ ] Integration tests pass with live API
- [ ] No regressions found
- [ ] Performance benchmarks meet targets

---

## Success Criteria

### Must Pass
✅ 100% of unit tests
✅ 100% of integration tests
✅ 100% of property tests
✅ 95%+ overall coverage
✅ 100% coverage for new code
✅ No Dialyzer warnings
✅ No Credo warnings

### Should Pass
✅ Performance benchmarks
✅ Stress tests with large inputs
✅ Unicode/special character tests

### Nice to Have
✅ Mutation testing
✅ Fuzzing tests
✅ Load tests

---

**Next Document:** `05_DOCUMENTATION_UPDATES.md` - User-facing documentation
