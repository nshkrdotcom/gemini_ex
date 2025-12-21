# Model Reference Cleanup Plan

**Date**: 2025-12-20
**Status**: Ready for Implementation
**Estimated Effort**: 4-5 hours total

## Executive Summary

This document outlines a comprehensive plan to update obsolete `gemini-2.0` model references throughout the codebase. While Gemini 2.0 models remain valid and supported as "Previous Generation" models, the defaults and examples should be updated to use current-generation Gemini 2.5 and Gemini 3 models.

## Current State Analysis

### Model Generations (from Google's official documentation)

| Generation | Models | Status | Recommended Use |
|------------|--------|--------|-----------------|
| **Gemini 3** | `gemini-3-pro-preview`, `gemini-3-flash-preview`, `gemini-3-pro-image-preview` | Preview | Cutting-edge, latest capabilities |
| **Gemini 2.5** | `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite` | **Stable (GA)** | **Production recommended** |
| **Gemini 2.0** | `gemini-2.0-flash`, `gemini-2.0-flash-lite` | Previous Gen | Backward compatibility only |

### Current Manifest Status (`lib/gemini/config.ex`)

The manifest **already includes** all current models correctly:

```elixir
# Gemini 3 models (preview) - ✓ Present
pro_3_preview: "gemini-3-pro-preview",
flash_3_preview: "gemini-3-flash-preview",

# Gemini 2.5 models (GA) - ✓ Present
pro_2_5: "gemini-2.5-pro",
flash_2_5: "gemini-2.5-flash",
flash_2_5_lite: "gemini-2.5-flash-lite",

# Aliases - ✓ Correct
latest: "gemini-3-pro-preview",
stable: "gemini-2.5-pro"
```

**Problem**: Default models still point to 2.0 generation:
```elixir
# NEEDS UPDATE - Line 143
@default_generation_models %{
  gemini: "gemini-flash-lite-latest",      # OK - Uses -latest alias
  vertex_ai: "gemini-2.0-flash-lite"       # OUTDATED
}

# NEEDS UPDATE - Line 97
default_universal: "gemini-2.0-flash-lite"  # OUTDATED
```

---

## Reference Inventory

### Category 1: Core Library Code (lib/)

| File | Line(s) | Current Value | Action |
|------|---------|---------------|--------|
| `lib/gemini/config.ex` | 143 | `vertex_ai: "gemini-2.0-flash-lite"` | **UPDATE** to `"gemini-2.5-flash-lite"` |
| `lib/gemini/config.ex` | 97 | `default_universal: "gemini-2.0-flash-lite"` | **UPDATE** to `"gemini-2.5-flash-lite"` |
| `lib/gemini/config.ex` | 85-91 | Gemini 2.0 model definitions | **KEEP** - Valid for backward compat |
| `lib/gemini/apis/context_cache.ex` | 530-531 | 2.0 models in valid list | **KEEP** - Still cacheable |
| `lib/gemini/apis/batches.ex` | Multiple | Examples in docstrings | **UPDATE** examples |
| `lib/gemini/live/session.ex` | Multiple | `"gemini-2.0-flash-exp"` in docs | **UPDATE** examples |
| `lib/gemini/live/message.ex` | 21 | Example with 2.0 | **UPDATE** example |
| `lib/gemini/types/batch.ex` | 26 | Example with 2.0 | **UPDATE** example |
| `lib/gemini/types/live.ex` | 19 | Example with 2.0 | **UPDATE** example |
| `lib/gemini/client/http.ex` | 339, 348 | Comment references | **KEEP** - Just documentation |

### Category 2: Test Files (test/)

| File | Occurrences | Current Model | Action |
|------|-------------|---------------|--------|
| `test/gemini/live/session_test.exs` | 23 | `"gemini-2.0-flash-exp"` | **UPDATE** to use helper or `"gemini-2.5-flash"` |
| `test/gemini/apis/system_instruction_live_test.exs` | 8 | `"gemini-2.0-flash"` | **UPDATE** to use helper |
| `test/gemini/tools/function_calling_live_test.exs` | 6 | `"gemini-2.0-flash"` | **UPDATE** to use helper |
| `test/gemini/apis/interactions_test.exs` | 9 | `"models/gemini-2.0-flash"` | **KEEP** - Mock tests with known format |
| `test/gemini/apis/batches_test.exs` | 2 | Mock test data | **KEEP** - Mock data |
| `test/live_api/live_session_live_test.exs` | 5 | `"gemini-2.0-flash-exp"` | **UPDATE** |
| `test/live_api/files_live_test.exs` | 1 | `"gemini-2.0-flash-lite"` | **UPDATE** |
| `test/support/model_helpers.ex` | Multiple | Documentation refs | **UPDATE** docs |

### Category 3: Documentation (docs/)

| File | Status | Action |
|------|--------|--------|
| `docs/guides/live_api.md` | 13 occurrences | **UPDATE** all examples |
| `docs/guides/batches.md` | 5 occurrences | **UPDATE** examples |
| `docs/guides/adc.md` | 1 occurrence | **UPDATE** example |
| `docs/20251218/docs_models.md` | Full 2.0 section | **KEEP** - Official Google docs |
| `docs/20251204/...` | Implementation plans | **KEEP** - Historical |
| `docs/20251205/...` | Gap analysis | **KEEP** - Historical |
| `docs/20251206/...` | Gap analysis | **KEEP** - Historical |

### Category 4: Configuration & Root Files

| File | Location | Action |
|------|----------|--------|
| `config/config.exs` | Line 7 (comment) | **UPDATE** comment |
| `README.md` | Lines 215, 386-387, 491, 1265 | **UPDATE** in README rewrite |
| `CHANGELOG.md` | Multiple | **KEEP** - Historical record |

---

## Implementation Plan

### Phase 1: Critical Default Updates (15 minutes)

**File: `lib/gemini/config.ex`**

#### Change 1: Update Vertex AI Default (Line 143)
```elixir
# Before
@default_generation_models %{
  gemini: "gemini-flash-lite-latest",
  vertex_ai: "gemini-2.0-flash-lite"
}

# After
@default_generation_models %{
  gemini: "gemini-flash-lite-latest",
  vertex_ai: "gemini-2.5-flash-lite"
}
```

#### Change 2: Update Default Universal (Line 97)
```elixir
# Before
default_universal: "gemini-2.0-flash-lite",

# After
default_universal: "gemini-2.5-flash-lite",
```

#### Change 3: Add Clarifying Comment (Line 84)
```elixir
# Gemini 2.0 models (Previous Generation - still valid, retained for backward compatibility)
flash_2_0: "gemini-2.0-flash",
...
```

### Phase 2: Update Model Helpers (30 minutes)

**File: `test/support/model_helpers.ex`**

Add new helper functions:

```elixir
@doc """
Returns the recommended model for Live API tests.
Uses gemini-2.5-flash for stable real-time capabilities.
"""
@spec live_test_model() :: String.t()
def live_test_model, do: "gemini-2.5-flash"

@doc """
Returns the recommended model for function calling tests.
"""
@spec function_calling_model() :: String.t()
def function_calling_model, do: "gemini-2.5-flash"

@doc """
Returns the recommended lite model for cost-sensitive tests.
"""
@spec lite_test_model() :: String.t()
def lite_test_model, do: "gemini-2.5-flash-lite"
```

Update documentation to reference 2.5 as current:
```elixir
@moduledoc """
...
## Model Recommendations

For new tests, prefer these current-generation models:
- **Standard**: `gemini-2.5-flash` - Best balance of capability and speed
- **Lite**: `gemini-2.5-flash-lite` - Cost-efficient, high throughput
- **Pro**: `gemini-2.5-pro` - Advanced reasoning

Previous generation models (gemini-2.0-*) remain available for backward compatibility.
"""
```

### Phase 3: Update Test Files (2 hours)

#### Priority 1: Live Session Tests
**File: `test/gemini/live/session_test.exs`**

Replace 23 occurrences of `"gemini-2.0-flash-exp"` with:
- Direct: `"gemini-2.5-flash"`
- Or: `ModelHelpers.live_test_model()`

Example transformation:
```elixir
# Before
assert {:ok, pid} = Session.start_link(model: "gemini-2.0-flash-exp")

# After
assert {:ok, pid} = Session.start_link(model: "gemini-2.5-flash")
```

#### Priority 2: System Instruction Tests
**File: `test/gemini/apis/system_instruction_live_test.exs`**

Replace 8 occurrences:
```elixir
# Before
opts = [model: "gemini-2.0-flash"]

# After
opts = [model: "gemini-2.5-flash"]
```

#### Priority 3: Function Calling Tests
**File: `test/gemini/tools/function_calling_live_test.exs`**

Replace 6 occurrences similarly.

#### Priority 4: Live API Tests
**File: `test/live_api/live_session_live_test.exs`** (5 occurrences)
**File: `test/live_api/files_live_test.exs`** (1 occurrence)

### Phase 4: Update Documentation Examples (1.5 hours)

#### High Priority: Live API Guide
**File: `docs/guides/live_api.md`** (13 occurrences)

```elixir
# Before (throughout file)
model: "gemini-2.0-flash-exp",

# After
model: "gemini-2.5-flash",
```

#### Medium Priority: Batches Guide
**File: `docs/guides/batches.md`** (5 occurrences)

```elixir
# Before
{:ok, batch} = Batches.create("gemini-2.0-flash", ...)

# After
{:ok, batch} = Batches.create("gemini-2.5-flash", ...)
```

#### Low Priority: ADC Guide
**File: `docs/guides/adc.md`** (1 occurrence)

### Phase 5: Update Library Docstrings (45 minutes)

Update examples in:
- `lib/gemini/live/session.ex` - Replace `"gemini-2.0-flash-exp"` with `"gemini-2.5-flash"`
- `lib/gemini/live/message.ex` - Same
- `lib/gemini/apis/batches.ex` - Replace `"gemini-2.0-flash"` with `"gemini-2.5-flash"`
- `lib/gemini/types/batch.ex` - Same
- `lib/gemini/types/live.ex` - Same

### Phase 6: Update Config Comment (5 minutes)

**File: `config/config.exs`**

```elixir
# Before (Line 7)
# - Vertex AI (VERTEX_PROJECT_ID): "gemini-2.0-flash-lite"

# After
# - Vertex AI (VERTEX_PROJECT_ID): "gemini-2.5-flash-lite"
```

---

## Files to NOT Modify

1. **`docs/20251218/docs_models.md`** - Contains official Google documentation including "Previous Gemini models" section
2. **`CHANGELOG.md`** - Historical record of changes
3. **`lib/gemini/config.ex` lines 85-91** - Gemini 2.0 model definitions (still valid, needed for backward compatibility)
4. **`lib/gemini/apis/context_cache.ex` valid models list** - 2.0 models are still cacheable
5. **`test/gemini/apis/interactions_test.exs`** - Mock tests with stable test data
6. **`test/gemini/apis/batches_test.exs`** - Mock tests with stable test data
7. **Historical docs in `docs/202511**/` - Implementation history

---

## Verification Checklist

After implementation, verify:

- [ ] `mix compile` - No warnings related to models
- [ ] `mix test` - All tests pass
- [ ] `mix test --only live` - Live API tests work with new models
- [ ] Default model check:
  ```elixir
  iex> Gemini.Config.default_model()
  # Should show gemini-2.5-flash-lite or gemini-flash-lite-latest

  iex> Gemini.Config.default_model_for(:vertex_ai)
  "gemini-2.5-flash-lite"
  ```
- [ ] Existing 2.0 models still work:
  ```elixir
  iex> Gemini.generate("Hi", model: "gemini-2.0-flash")
  {:ok, ...}  # Should still work
  ```

---

## Summary Table

| Phase | Description | Files | Effort | Priority |
|-------|-------------|-------|--------|----------|
| 1 | Critical Defaults | `lib/gemini/config.ex` | 15 min | **CRITICAL** |
| 2 | Model Helpers | `test/support/model_helpers.ex` | 30 min | HIGH |
| 3 | Test Files | 6 test files | 2 hrs | HIGH |
| 4 | Documentation | 3 guide files | 1.5 hrs | MEDIUM |
| 5 | Library Docstrings | 5 lib files | 45 min | MEDIUM |
| 6 | Config Comment | `config/config.exs` | 5 min | LOW |

**Total Estimated Effort**: 4.5 - 5 hours

---

## Backward Compatibility Notes

- All `gemini-2.0-*` model keys remain in the manifest
- Users can still explicitly request 2.0 models via `model: "gemini-2.0-flash"`
- The `get_model(:flash_2_0)` function continues to work
- Context caching supports 2.0 models
- No breaking changes for existing codebases using 2.0 models explicitly

## References

- Google Gemini Models Documentation: `docs/20251218/docs_models.md`
- Model Manifest: `lib/gemini/config.ex` lines 59-126
- Test Helpers: `test/support/model_helpers.ex`
