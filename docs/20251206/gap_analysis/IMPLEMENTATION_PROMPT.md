# Gap Analysis Implementation Prompt

**Version:** 0.7.3
**Date:** 2025-12-06
**Objective:** Close critical gaps identified in Python SDK comparison using TDD

---

## Required Reading (MUST READ BEFORE IMPLEMENTATION)

### Gap Analysis Documents (Read in Order)
1. `docs/20251206/gap_analysis/00_executive_summary.md` - High-level overview
2. `docs/20251206/gap_analysis/01_critical_gaps.md` - Detailed critical gaps
3. `docs/20251206/gap_analysis/02_feature_parity_matrix.md` - Complete feature comparison
4. `docs/20251206/gap_analysis/03_implementation_priorities.md` - Implementation roadmap

### Code Quality Standards
- `docs/CODE_QUALITY.md` - Elixir code standards (MUST FOLLOW)
- `CLAUDE.md` - Project context and guidelines

### Python Reference Implementation
- `python-genai/google/genai/` - Complete Python SDK source
- Key files to reference:
  - `types.py` - 18,205 lines of type definitions
  - `models.py` - Content generation, embeddings, image/video
  - `live.py` - WebSocket real-time API
  - `chats.py` - Multi-turn chat sessions
  - `tunings.py` - Model fine-tuning
  - `_transformers.py` - Request/response transformation

### Existing Elixir Implementation
- `lib/gemini/` - Current implementation (READ ALL)
- `lib/gemini/types/` - Type definitions
- `lib/gemini/apis/` - API modules
- `lib/gemini/streaming/` - Streaming implementation
- `lib/gemini/auth/` - Authentication strategies

---

## Implementation Instructions

### TDD Approach (MANDATORY)

For EVERY feature implementation:

1. **Write Tests FIRST**
   ```elixir
   # test/gemini/types/content/function_declaration_test.exs
   defmodule Gemini.Types.Content.FunctionDeclarationTest do
     use ExUnit.Case, async: true

     describe "new/1" do
       test "creates function declaration with required fields" do
         # Test implementation
       end

       test "validates name is present" do
         # Test implementation
       end
     end
   end
   ```

2. **Run Tests (Should Fail)**
   ```bash
   mix test test/gemini/types/content/function_declaration_test.exs
   ```

3. **Implement Feature**
   ```elixir
   defmodule Gemini.Types.Content.FunctionDeclaration do
     use TypedStruct

     @moduledoc """
     Function declaration for tool calling.
     """

     typedstruct do
       field :name, String.t(), enforce: true
       field :description, String.t(), enforce: true
       field :parameters, map()
       field :response, map()
     end
   end
   ```

4. **Run Tests (Should Pass)**
   ```bash
   mix test test/gemini/types/content/function_declaration_test.exs
   ```

5. **Verify No Warnings**
   ```bash
   mix compile --warnings-as-errors
   ```

6. **Run Dialyzer**
   ```bash
   mix dialyzer
   ```

### Quality Gates (MUST PASS)

Before marking ANY task complete:

```bash
# All tests must pass
mix test

# No compilation warnings
mix compile --warnings-as-errors

# No dialyzer errors
mix dialyzer

# Code quality
mix credo --strict
```

---

## Priority Implementation Order

### Tier 1: Quick Wins (Do First)

#### 1.1 Add system_instruction to GenerateContentRequest

**Files to modify:**
- `lib/gemini/types/request/generate_content_request.ex`
- `lib/gemini/apis/coordinator.ex`
- `test/gemini/types/request/generate_content_request_test.exs`

**Test first:**
```elixir
test "includes system_instruction in request" do
  request = GenerateContentRequest.new(%{
    model: "gemini-2.0-flash",
    contents: [%{role: "user", parts: [%{text: "Hello"}]}],
    system_instruction: %{parts: [%{text: "You are helpful."}]}
  })

  assert request.system_instruction != nil
end
```

#### 1.2 Add Missing GenerationConfig Fields

**Files to modify:**
- `lib/gemini/types/request/generation_config.ex`
- `test/gemini/types/request/generation_config_test.exs`

**Fields to add:**
- `response_modalities`
- `speech_config`
- `media_resolution`
- `routing_config`

### Tier 2: Function Calling (Critical Path)

#### 2.1 Complete Tool Types

**Files to create:**
- `lib/gemini/types/content/function_declaration.ex`
- `lib/gemini/types/content/function_call.ex`
- `lib/gemini/types/content/function_response.ex`
- `lib/gemini/types/content/schema.ex`

**Test files to create:**
- `test/gemini/types/content/function_declaration_test.exs`
- `test/gemini/types/content/function_call_test.exs`
- `test/gemini/types/content/function_response_test.exs`
- `test/gemini/types/content/schema_test.exs`

#### 2.2 Function Execution Module

**Files to create:**
- `lib/gemini/tools/executor.ex`
- `test/gemini/tools/executor_test.exs`

**Implementation pattern:**
```elixir
defmodule Gemini.Tools.Executor do
  @moduledoc """
  Executes function calls and returns results.
  """

  @type function_registry :: %{String.t() => function()}

  @spec execute(FunctionCall.t(), function_registry()) ::
    {:ok, term()} | {:error, term()}
  def execute(%FunctionCall{name: name, args: args}, registry) do
    case Map.get(registry, name) do
      nil -> {:error, {:unknown_function, name}}
      func ->
        try do
          {:ok, func.(args)}
        rescue
          e -> {:error, {:execution_error, e}}
        end
    end
  end
end
```

#### 2.3 Automatic Function Calling Loop

**Files to create:**
- `lib/gemini/tools/automatic_function_calling.ex`
- `test/gemini/tools/automatic_function_calling_test.exs`

### Tier 3: Live API (WebSocket)

#### 3.1 WebSocket Dependencies

**Add to mix.exs:**
```elixir
{:websockex, "~> 0.4"}
```

#### 3.2 Live Connection Module

**Files to create:**
- `lib/gemini/live/connection.ex`
- `lib/gemini/live/session.ex`
- `lib/gemini/live/message.ex`
- `test/gemini/live/connection_test.exs`
- `test/gemini/live/session_test.exs`

### Tier 4: Type Expansion

**Reference:** `python-genai/google/genai/types.py`

For each missing type:
1. Find Python definition
2. Write Elixir test
3. Implement TypedStruct
4. Verify with dialyzer

---

## Documentation Updates Required

### Update README.md

1. Add new features to Features list
2. Update Quick Start examples for new functionality
3. Add new API sections (Live API, Enhanced Function Calling)
4. Update version badge to 0.7.3

### Create New Guides

**Files to create:**
- `docs/guides/function_calling.md` - Complete function calling guide
- `docs/guides/live_api.md` - WebSocket real-time API guide
- `docs/guides/system_instructions.md` - System instruction usage

### Update mix.exs for Hex Docs

Add new guides to both `extras` and `groups_for_extras`:

```elixir
extras: [
  # ... existing ...
  "docs/guides/function_calling.md",
  "docs/guides/live_api.md",
  "docs/guides/system_instructions.md",
  # ... existing ...
],
groups_for_extras: [
  # ... existing groups ...
  Features: [
    # ... existing ...
    "docs/guides/function_calling.md",
    "docs/guides/live_api.md",
    "docs/guides/system_instructions.md"
  ]
]
```

Also add to `files` in package:
```elixir
files: ~w(lib mix.exs README.md ... docs/guides)
```

---

## Version Updates

### mix.exs
```elixir
@version "0.7.3"
```

### README.md
```elixir
{:gemini_ex, "~> 0.7.3"}
```

### CHANGELOG.md

Add new entry at top:

```markdown
## [0.7.3] - 2025-12-06

### Added

#### Gap Analysis Documentation
- Comprehensive gap analysis comparing Python genai SDK vs Elixir implementation
- Executive summary with severity classifications
- Feature parity matrix with 55% current coverage score
- Implementation priorities with tiered roadmap

#### System Instruction Support
- Added `system_instruction` field to `GenerateContentRequest`
- System prompts now persist across conversation turns
- Reduces token usage compared to inline instructions

#### Enhanced Function Calling Types
- Complete `FunctionDeclaration` with JSON Schema support
- `FunctionCall` extraction from model responses
- `FunctionResponse` for multi-turn tool conversations
- `Schema` type for parameter definitions

#### Function Execution Framework
- `Gemini.Tools.Executor` for executing function calls
- Function registry pattern for tool management
- Parallel execution support via Task.async_stream
- Comprehensive error handling and recovery

#### Automatic Function Calling
- `AutomaticFunctionCalling` module with AFC loop
- Configurable call depth limits
- Call history tracking
- Seamless integration with existing generate API

### Documentation
- New guide: `docs/guides/function_calling.md`
- New guide: `docs/guides/system_instructions.md`
- Gap analysis documents in `docs/20251206/gap_analysis/`
- Updated README with new features

### Technical
- Zero compilation warnings maintained
- Complete @spec annotations for all new functions
- Follows CODE_QUALITY.md standards throughout
```

---

## Verification Checklist

Before completing implementation:

- [ ] All new features have tests written FIRST
- [ ] All tests pass: `mix test`
- [ ] No compilation warnings: `mix compile --warnings-as-errors`
- [ ] No dialyzer errors: `mix dialyzer`
- [ ] Code quality: `mix credo --strict`
- [ ] Documentation complete for all new modules
- [ ] README.md updated with new features
- [ ] CHANGELOG.md updated with 0.7.3 entry
- [ ] mix.exs version updated to 0.7.3
- [ ] New guides added to mix.exs extras
- [ ] New guides added to mix.exs groups_for_extras
- [ ] docs/guides files included in package files

---

## Success Criteria

### Minimum Viable Release (0.7.3)

1. **System Instruction** works in all generate requests
2. **Function Calling Types** are complete and tested
3. **Documentation** is comprehensive and accurate
4. **All quality gates pass**

### Stretch Goals

1. Function execution framework complete
2. AFC loop implemented
3. Live API foundation started

---

## Commands Reference

```bash
# Run all tests
mix test

# Run specific test file
mix test test/gemini/types/content/function_declaration_test.exs

# Run with coverage
mix test --cover

# Compile with warnings as errors
mix compile --warnings-as-errors

# Run dialyzer
mix dialyzer

# Run credo
mix credo --strict

# Generate docs locally
mix docs

# Format code
mix format
```

---

## Notes

- Always reference Python SDK for implementation details
- Follow existing patterns in the codebase
- Maintain backward compatibility
- Keep API surface minimal and intuitive
- Document all public functions with @doc and @spec
- Use TypedStruct for all new types
- Add @derive Jason.Encoder for API serialization
