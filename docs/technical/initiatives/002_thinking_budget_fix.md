# Initiative 002: Thinking Budget Configuration Fix

**Status:** CRITICAL - Bug Fix Required
**Priority:** P0 (Critical)
**Related Issue:** [#9](https://github.com/nshkrdotcom/gemini_ex/issues/9)
**Related PR:** [#10](https://github.com/nshkrdotcom/gemini_ex/pull/10) - **REQUIRES REJECTION & REWRITE**
**Estimated Effort:** 4-6 hours
**Created:** 2025-10-07
**Owner:** TBD

---

## Executive Summary

### Problem Statement

PR #10 attempted to add thinking budget configuration support for Gemini 2.5 series models, but contains a **critical bug** that prevents it from working. The implementation sends incorrect field names to the Gemini API, causing the API to silently ignore the configuration. Users attempting to disable thinking tokens (to reduce costs) are still being charged because the API doesn't recognize the malformed request.

**User Impact:** Users believe they're disabling thinking tokens but are still being charged, leading to unexpected costs.

### Bug Analysis

**What PR #10 sends to API:**
```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinking_budget": 0
    }
  }
}
```

**What API actually expects (verified against official docs):**
```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 0,
      "includeThoughts": false
    }
  }
}
```

**Result:** API ignores `thinking_budget` (snake_case), uses default thinking behavior, user still charged for thinking tokens.

### Proposed Solution

1. **Fix field name conversion:** Convert `thinking_budget` → `thinkingBudget` (camelCase)
2. **Add includeThoughts support:** Enable thought summaries feature
3. **Add model-aware validation:** Validate budget ranges per model (2.5 Pro, Flash, etc.)
4. **Remove duplicate code:** DRY violation in coordinator.ex
5. **Add comprehensive tests:** Unit, integration, and live API tests

### Success Criteria

- ✅ Setting `thinking_budget: 0` actually disables thinking (verified via live API)
- ✅ `thoughts_token_count` in response is 0 or nil when disabled
- ✅ Dynamic thinking works with `thinking_budget: -1`
- ✅ Model-specific budget ranges enforced
- ✅ `includeThoughts` parameter works correctly
- ✅ All tests pass (unit, integration, live API)
- ✅ No duplicate code in coordinator.ex

### Impact Assessment

**Positive Impacts:**
- Users can actually control thinking token costs
- Enables cost optimization strategies
- Adds thought summaries capability
- Improves API compliance

**Risks:**
- Breaking change for users who thought feature worked (it didn't)
- Need to communicate this was a bug fix
- Must test thoroughly to avoid introducing new bugs

---

## Problem Analysis

### User's Original Complaint

From Issue #9 by @yosuaw:

```elixir
{:ok, response} = Coordinator.generate_content(
  contents,
  [
    model: "gemini-2.5-flash",
    thinking_config: %{thinking_budget: 0}
  ]
)
```

**Expected:** No thinking tokens charged
**Actual:** Response still contains `thoughts_token_count: 16`

**User's conclusion:** Feature not supported

**Actual problem:** Feature attempted in PR #10 but has critical bug

### PR #10's Attempted Fix

**Files Changed:**
1. `lib/gemini/types/common/generation_config.ex` (+24 lines)
2. `lib/gemini/apis/coordinator.ex` (+22 lines)

**What it added:**

**In generation_config.ex:**
```elixir
# Added field
field(:thinking_config, map() | nil, default: nil)

# Added helper function
def thinking_budget(config \\ %__MODULE__{}, budget) when is_integer(budget) do
  thinking_config = %{thinking_budget: budget}
  %{config | thinking_config: thinking_config}
end
```

**In coordinator.ex:**
```elixir
# In build_generation_config/1
{:thinking_config, thinking_config}, acc when is_map(thinking_config) ->
  Map.put(acc, :thinkingConfig, thinking_config)
```

### Why PR #10 Doesn't Work

**Critical Bug:** The code puts the entire `thinking_config` map (with snake_case keys) directly into the API request:

```elixir
# User provides:
thinking_config: %{thinking_budget: 0}

# Code does:
Map.put(acc, :thinkingConfig, thinking_config)
# Result: %{thinkingConfig: %{thinking_budget: 0}}

# Gets serialized to JSON as:
{"thinkingConfig": {"thinking_budget": 0}}

# But API expects:
{"thinkingConfig": {"thinkingBudget": 0}}
```

**The API silently ignores the unknown `thinking_budget` key and uses default behavior.**

### Root Cause Analysis

**Location:** `lib/gemini/apis/coordinator.ex:567`

```elixir
# Current code (BUGGY):
{:thinking_config, thinking_config}, acc when is_map(thinking_config) ->
  Map.put(acc, :thinkingConfig, thinking_config)
  # ^^ BUG: thinking_config still has snake_case keys!
```

**Why API ignores it:**
- API uses strict JSON schema validation
- Unrecognized fields are silently ignored (not an error)
- `thinking_budget` is not recognized (expects `thinkingBudget`)
- Falls back to default behavior (dynamic thinking)

### Evidence from Official Docs

From `docs/gemini_api_reference_2025_10_07/THINKING.md` (lines 270-271):

```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 1024
    }
  }
}
```

**Field name is definitively `thinkingBudget` (camelCase), not `thinking_budget`.**

---

## Official API Specification

### Exact JSON Format

**Source:** https://ai.google.dev/gemini-api/docs/thinking (lines 195-200, 270-271)

```json
{
  "contents": [...],
  "generationConfig": {
    "temperature": 0.7,
    "thinkingConfig": {
      "thinkingBudget": 1024,
      "includeThoughts": false
    }
  }
}
```

### Field Names (ALL camelCase)

- ✅ `thinkingConfig` (camelCase)
- ✅ `thinkingBudget` (camelCase)
- ✅ `includeThoughts` (camelCase)

### Supported Models & Budget Ranges

From official docs (THINKING.md lines 149-155):

| Model | Default | Budget Range | Disable | Dynamic |
|-------|---------|--------------|---------|---------|
| **2.5 Pro** | Dynamic | 128 - 32,768 | ❌ Cannot | `thinkingBudget: -1` |
| **2.5 Flash** | Dynamic | 0 - 24,576 | `thinkingBudget: 0` | `thinkingBudget: -1` |
| **2.5 Flash Preview** | Dynamic | 0 - 24,576 | `thinkingBudget: 0` | `thinkingBudget: -1` |
| **2.5 Flash Lite** | No thinking | 512 - 24,576 | `thinkingBudget: 0` | `thinkingBudget: -1` |
| **2.5 Flash Lite Preview** | No thinking | 512 - 24,576 | `thinkingBudget: 0` | `thinkingBudget: -1` |
| **Robotics-ER 1.5 Preview** | Dynamic | 0 - 24,576 | `thinkingBudget: 0` | `thinkingBudget: -1` |

### Special Values

- **`0`** - Disables thinking entirely (NOT available for 2.5 Pro)
- **`-1`** - Enables dynamic thinking (model decides budget)
- **Positive integer** - Sets max thinking tokens (range varies by model)

### Official SDK Examples

**Python:**
```python
from google.generativeai import types

config = types.GenerateContentConfig(
    thinking_config=types.ThinkingConfig(
        thinking_budget=1024,
        include_thoughts=True
    )
)
```

**JavaScript:**
```javascript
thinkingConfig: {
  thinkingBudget: 1024,
  includeThoughts: true
}
```

**REST/JSON:**
```json
{
  "thinkingConfig": {
    "thinkingBudget": 0
  }
}
```

---

## Current Implementation Analysis

### PR #10 Code Review

#### generation_config.ex Changes

**Added field (CORRECT):**
```elixir
typedstruct do
  # ... existing fields ...
  field(:thinking_config, map() | nil, default: nil)
end
```

✅ **Assessment:** Field addition is fine, but should be typed better.

**Added function (INCOMPLETE):**
```elixir
def thinking_budget(config \\ %__MODULE__{}, budget) when is_integer(budget) do
  thinking_config = %{thinking_budget: budget}
  %{config | thinking_config: thinking_config}
end
```

⚠️ **Issues:**
1. Creates snake_case key `thinking_budget` (should be `thinkingBudget`)
2. No support for `include_thoughts`
3. No validation of budget value
4. No documentation of model-specific ranges

#### coordinator.ex Changes

**In build_generation_config/1 (BUGGY):**
```elixir
{:thinking_config, thinking_config}, acc when is_map(thinking_config) ->
  Map.put(acc, :thinkingConfig, thinking_config)
```

🔴 **Critical Bug:** Directly inserts map with snake_case keys into API request.

**What happens:**
1. User calls with `thinking_config: %{thinking_budget: 0}`
2. Code puts it as `:thinkingConfig` key
3. Map still has `thinking_budget` (snake_case) as internal key
4. Serialized to JSON: `{"thinkingConfig": {"thinking_budget": 0}}`
5. API doesn't recognize `thinking_budget`, ignores it
6. Uses default thinking behavior
7. User charged for thinking tokens despite setting budget to 0

**Duplicate code:** Same plain map handling logic appears twice (lines 387-395, 431-439)

### What PR #10 Got Right

- ✅ Identified need for thinking config
- ✅ Added field to GenerationConfig struct
- ✅ Created helper function pattern
- ✅ Attempted integration with coordinator

### Critical Bugs Identified

1. **🔴 CRITICAL: Wrong field names in API request**
   - Sends: `thinking_budget`
   - Should send: `thinkingBudget`

2. **🔴 Missing feature: includeThoughts not supported**
   - Official API supports this parameter
   - PR #10 doesn't implement it

3. **🟡 No validation:**
   - Accepts any integer value
   - Doesn't check model-specific ranges
   - No error for invalid combinations

4. **🟡 Code duplication:**
   - Plain map handling duplicated in two places
   - Violates DRY principle

5. **🟡 No tests:**
   - Author admitted not adding tests
   - Bug would have been caught with HTTP mock tests

---

## Proposed Solution

### High-Level Approach

1. **Fix field conversion** - Add proper snake_case → camelCase conversion
2. **Add includeThoughts** - Support thought summaries feature
3. **Add validation** - Model-aware budget validation
4. **Refactor duplicates** - DRY up repeated code
5. **Comprehensive tests** - Unit, integration, live API

### Design Principles

- **Correct over clever** - Match official API exactly
- **Validate early** - Catch errors before API call
- **Clear errors** - Help users understand what went wrong
- **Backward compatible** - Maintain existing (working) behavior
- **Well tested** - Prevent regressions

### Detailed Implementation Plan

#### Phase 1: Fix GenerationConfig Type (30 min)

**File:** `lib/gemini/types/common/generation_config.ex`

**Changes:**

```elixir
defmodule Gemini.Types.GenerationConfig do
  use TypedStruct

  # Define thinking config as proper struct (not just map)
  defmodule ThinkingConfig do
    use TypedStruct

    @type t :: %__MODULE__{
      thinking_budget: integer() | nil,
      include_thoughts: boolean() | nil
    }

    typedstruct do
      field(:thinking_budget, integer() | nil, default: nil)
      field(:include_thoughts, boolean() | nil, default: nil)
    end
  end

  typedstruct do
    # ... existing fields ...
    field(:thinking_config, ThinkingConfig.t() | nil, default: nil)
  end

  @doc """
  Set thinking budget.

  ## Parameters
  - budget: Integer controlling thinking tokens
    - `0`: Disable thinking (Flash/Lite only, NOT Pro)
    - `-1`: Dynamic thinking (model decides)
    - `1-24576`: Fixed budget (Flash/Lite)
    - `128-32768`: Fixed budget (Pro only)

  ## Examples
      # Disable thinking
      config = GenerationConfig.thinking_budget(0)

      # Dynamic thinking
      config = GenerationConfig.thinking_budget(-1)

      # Fixed budget
      config = GenerationConfig.thinking_budget(1024)
  """
  @spec thinking_budget(t(), integer()) :: t()
  def thinking_budget(config \\ %__MODULE__{}, budget) when is_integer(budget) do
    thinking_config = %ThinkingConfig{thinking_budget: budget}
    %{config | thinking_config: thinking_config}
  end

  @doc """
  Enable thought summaries in response.

  ## Examples
      config =
        GenerationConfig.new()
        |> GenerationConfig.thinking_budget(2048)
        |> GenerationConfig.include_thoughts(true)
  """
  @spec include_thoughts(t(), boolean()) :: t()
  def include_thoughts(config \\ %__MODULE__{}, include) when is_boolean(include) do
    current_thinking = config.thinking_config || %ThinkingConfig{}
    thinking_config = %{current_thinking | include_thoughts: include}
    %{config | thinking_config: thinking_config}
  end

  @doc """
  Create thinking config with both budget and thoughts.

  ## Examples
      config = GenerationConfig.thinking_config(1024, include_thoughts: true)
  """
  @spec thinking_config(t(), integer(), keyword()) :: t()
  def thinking_config(config \\ %__MODULE__{}, budget, opts \\ []) when is_integer(budget) do
    include = Keyword.get(opts, :include_thoughts, false)

    thinking_config = %ThinkingConfig{
      thinking_budget: budget,
      include_thoughts: include
    }

    %{config | thinking_config: thinking_config}
  end
end
```

#### Phase 2: Fix Coordinator Conversion (45 min)

**File:** `lib/gemini/apis/coordinator.ex`

**Add conversion helper:**

```elixir
# Add near top of module with other private helpers

@doc false
@spec convert_thinking_config_to_api(map() | struct()) :: map()
defp convert_thinking_config_to_api(%GenerationConfig.ThinkingConfig{} = config) do
  %{}
  |> maybe_put_if_not_nil("thinkingBudget", config.thinking_budget)
  |> maybe_put_if_not_nil("includeThoughts", config.include_thoughts)
end

defp convert_thinking_config_to_api(config) when is_map(config) do
  # Support plain maps for backward compatibility
  config
  |> Enum.reduce(%{}, fn
    {:thinking_budget, budget}, acc when is_integer(budget) ->
      Map.put(acc, "thinkingBudget", budget)

    {:include_thoughts, include}, acc when is_boolean(include) ->
      Map.put(acc, "includeThoughts", include)

    # Support both snake_case and camelCase input
    {"thinkingBudget", budget}, acc ->
      Map.put(acc, "thinkingBudget", budget)

    {"includeThoughts", include}, acc ->
      Map.put(acc, "includeThoughts", include)

    _, acc ->
      acc
  end)
end

defp maybe_put_if_not_nil(map, _key, nil), do: map
defp maybe_put_if_not_nil(map, key, value), do: Map.put(map, key, value)
```

**Fix build_generation_config/1:**

```elixir
# Replace the buggy thinking_config handling (line ~567)

# OLD (BUGGY):
{:thinking_config, thinking_config}, acc when is_map(thinking_config) ->
  Map.put(acc, :thinkingConfig, thinking_config)

# NEW (FIXED):
{:thinking_config, thinking_config}, acc when not is_nil(thinking_config) ->
  api_format = convert_thinking_config_to_api(thinking_config)
  Map.put(acc, "thinkingConfig", api_format)
```

**Remove duplicate code:** Consolidate the two identical plain map handling blocks (lines 387-395, 431-439) into a single helper function.

#### Phase 3: Add Validation (1 hour)

**File:** `lib/gemini/validation/thinking_config.ex` (NEW)

```elixir
defmodule Gemini.Validation.ThinkingConfig do
  @moduledoc """
  Validation for thinking configuration parameters based on model capabilities.
  """

  @type validation_result :: :ok | {:error, term()}

  @doc """
  Validate thinking budget for a specific model.

  ## Model Ranges (from official docs)
  - Gemini 2.5 Pro: 128-32,768 (cannot disable with 0)
  - Gemini 2.5 Flash: 0-24,576 (can disable)
  - Gemini 2.5 Flash Lite: 512-24,576 (can disable)

  Special values:
  - 0: Disable thinking
  - -1: Dynamic thinking (model decides)
  """
  @spec validate_budget(integer(), String.t()) :: validation_result()
  def validate_budget(budget, model) when is_integer(budget) and is_binary(model) do
    cond do
      budget == -1 ->
        # Dynamic thinking allowed for all models
        :ok

      String.contains?(model, "gemini-2.5-pro") or String.contains?(model, "gemini-pro-2.5") ->
        validate_pro_budget(budget)

      String.contains?(model, "gemini-2.5-flash-lite") ->
        validate_flash_lite_budget(budget)

      String.contains?(model, "gemini-2.5-flash") or String.contains?(model, "gemini-flash-2.5") ->
        validate_flash_budget(budget)

      true ->
        # Unknown model, allow any value (let API validate)
        :ok
    end
  end

  defp validate_pro_budget(0) do
    {:error, "Gemini 2.5 Pro cannot disable thinking (minimum budget: 128)"}
  end

  defp validate_pro_budget(budget) when budget >= 128 and budget <= 32_768 do
    :ok
  end

  defp validate_pro_budget(budget) do
    {:error, "Gemini 2.5 Pro thinking budget must be between 128 and 32,768, got: #{budget}"}
  end

  defp validate_flash_budget(budget) when budget >= 0 and budget <= 24_576 do
    :ok
  end

  defp validate_flash_budget(budget) do
    {:error, "Gemini 2.5 Flash thinking budget must be between 0 and 24,576, got: #{budget}"}
  end

  defp validate_flash_lite_budget(budget) when budget == 0 or (budget >= 512 and budget <= 24_576) do
    :ok
  end

  defp validate_flash_lite_budget(budget) do
    {:error, "Gemini 2.5 Flash Lite thinking budget must be 0 or between 512 and 24,576, got: #{budget}"}
  end

  @doc """
  Validate complete thinking config.
  """
  @spec validate(map(), String.t()) :: validation_result()
  def validate(%{thinking_budget: budget} = _config, model) when is_integer(budget) do
    validate_budget(budget, model)
  end

  def validate(_config, _model), do: :ok
end
```

**Integrate validation in coordinator:**

```elixir
# In build_generate_request/2 or generate_content/2

with {:ok, request} <- build_generate_request(input, opts),
     :ok <- validate_thinking_config(request, opts) do
  HTTP.post(path, request, opts)
end

defp validate_thinking_config(request, opts) do
  model = Keyword.get(opts, :model, Gemini.Config.get_model(:default))

  case get_in(request, [:generationConfig, "thinkingConfig"]) do
    nil -> :ok
    thinking_config ->
      Gemini.Validation.ThinkingConfig.validate(thinking_config, model)
  end
end
```

---

## Implementation Details

### Complete File Changes

#### 1. lib/gemini/types/common/generation_config.ex

**Lines to add:** ~60 lines
**Lines to modify:** 1 line (thinking_config field)
**New functions:** 3 (`thinking_budget/2`, `include_thoughts/2`, `thinking_config/3`)
**New module:** `ThinkingConfig` sub-module

#### 2. lib/gemini/apis/coordinator.ex

**Lines to add:** ~40 lines
**Lines to modify:** 3 lines
**Lines to remove:** ~10 lines (duplicate code)
**New functions:** 2 (`convert_thinking_config_to_api/1`, `maybe_put_if_not_nil/3`)
**Modified functions:** 1 (`build_generation_config/1`)

#### 3. lib/gemini/validation/thinking_config.ex (NEW FILE)

**Lines to add:** ~90 lines
**New functions:** 5 (validate_budget, validate, validate_pro_budget, validate_flash_budget, validate_flash_lite_budget)

### Function Signatures

```elixir
# generation_config.ex
@spec thinking_budget(t(), integer()) :: t()
@spec include_thoughts(t(), boolean()) :: t()
@spec thinking_config(t(), integer(), keyword()) :: t()

# coordinator.ex
@spec convert_thinking_config_to_api(map() | struct()) :: map()
@spec maybe_put_if_not_nil(map(), String.t(), any()) :: map()

# validation/thinking_config.ex
@spec validate_budget(integer(), String.t()) :: :ok | {:error, String.t()}
@spec validate(map(), String.t()) :: :ok | {:error, String.t()}
```

---

## Backward Compatibility

### Is This a Breaking Change?

**NO** - This is a bug fix. The current implementation doesn't work, so there's nothing to break.

**Current behavior:**
- User sets `thinking_budget: 0`
- Code sends malformed request
- API ignores it and uses default
- User still charged for thinking tokens

**New behavior:**
- User sets `thinking_budget: 0`
- Code sends correct request
- API disables thinking
- User NOT charged for thinking tokens

### Impact on Existing Users

**Users who tried to use this feature:**
- Currently: Silently fails, still charged
- After fix: Works as expected, saves money
- **Impact:** POSITIVE (finally works)

**Users not using this feature:**
- Currently: No thinking config sent
- After fix: Still no thinking config sent
- **Impact:** NONE (unchanged)

### Migration Path

**No migration needed** - This is a pure bug fix that makes broken functionality work.

**User communication:**
- Note in CHANGELOG: "Fixed thinking budget configuration (was sending wrong field names)"
- Note in PR: "This fixes a bug where thinking budget was silently ignored"
- No code changes required from users

---

## Testing Strategy

### Unit Tests

**File:** `test/gemini/types/common/generation_config_test.exs`

```elixir
defmodule Gemini.Types.GenerationConfigTest do
  use ExUnit.Case, async: true
  alias Gemini.Types.GenerationConfig

  describe "thinking_budget/2" do
    test "creates config with disabled thinking (budget = 0)" do
      config = GenerationConfig.thinking_budget(0)

      assert %GenerationConfig.ThinkingConfig{thinking_budget: 0} = config.thinking_config
      assert config.thinking_config.include_thoughts == nil
    end

    test "creates config with limited thinking (positive budget)" do
      config = GenerationConfig.thinking_budget(1024)

      assert config.thinking_config.thinking_budget == 1024
    end

    test "creates config with dynamic thinking (budget = -1)" do
      config = GenerationConfig.thinking_budget(-1)

      assert config.thinking_config.thinking_budget == -1
    end

    test "can chain with other config options" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.temperature(0.7)
        |> GenerationConfig.thinking_budget(512)
        |> GenerationConfig.max_output_tokens(1000)

      assert config.temperature == 0.7
      assert config.thinking_config.thinking_budget == 512
      assert config.max_output_tokens == 1000
    end
  end

  describe "include_thoughts/2" do
    test "enables thought summaries" do
      config = GenerationConfig.include_thoughts(true)

      assert config.thinking_config.include_thoughts == true
    end

    test "can combine with thinking budget" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.thinking_budget(2048)
        |> GenerationConfig.include_thoughts(true)

      assert config.thinking_config.thinking_budget == 2048
      assert config.thinking_config.include_thoughts == true
    end
  end

  describe "thinking_config/3" do
    test "creates complete config in one call" do
      config = GenerationConfig.thinking_config(1024, include_thoughts: true)

      assert config.thinking_config.thinking_budget == 1024
      assert config.thinking_config.include_thoughts == true
    end
  end
end
```

### Conversion Tests

**File:** `test/gemini/apis/coordinator_test.exs`

```elixir
describe "thinking config conversion" do
  test "converts struct to API format with camelCase keys" do
    thinking_config = %GenerationConfig.ThinkingConfig{
      thinking_budget: 1024,
      include_thoughts: true
    }

    api_format = Coordinator.convert_thinking_config_to_api(thinking_config)

    assert api_format == %{
      "thinkingBudget" => 1024,
      "includeThoughts" => true
    }
  end

  test "converts plain map with snake_case to camelCase" do
    thinking_config = %{thinking_budget: 0, include_thoughts: false}

    api_format = Coordinator.convert_thinking_config_to_api(thinking_config)

    assert api_format == %{
      "thinkingBudget" => 0,
      "includeThoughts" => false
    }
  end

  test "omits nil values from API format" do
    thinking_config = %GenerationConfig.ThinkingConfig{thinking_budget: 512}

    api_format = Coordinator.convert_thinking_config_to_api(thinking_config)

    assert api_format == %{"thinkingBudget" => 512}
    refute Map.has_key?(api_format, "includeThoughts")
  end
end
```

### HTTP Mock Tests (CRITICAL)

**File:** `test/gemini/apis/coordinator_integration_test.exs`

```elixir
describe "thinking config API request format" do
  import Mox

  setup :verify_on_exit!

  test "sends correct camelCase field names to API" do
    # This test would have caught the bug!

    expect(Gemini.Client.HTTP.Mock, :post, fn _path, request, _opts ->
      # Verify exact JSON structure sent to API
      assert get_in(request, [:generationConfig, "thinkingConfig", "thinkingBudget"]) == 0
      assert get_in(request, [:generationConfig, "thinkingConfig", "includeThoughts"]) == false

      # Verify NO snake_case keys present
      thinking_config = get_in(request, [:generationConfig, "thinkingConfig"])
      refute Map.has_key?(thinking_config, "thinking_budget")
      refute Map.has_key?(thinking_config, :thinking_budget)

      {:ok, mock_response()}
    end)

    Coordinator.generate_content(
      "test",
      thinking_config: %{thinking_budget: 0, include_thoughts: false}
    )
  end
end
```

### Validation Tests

**File:** `test/gemini/validation/thinking_config_test.exs`

```elixir
defmodule Gemini.Validation.ThinkingConfigTest do
  use ExUnit.Case, async: true
  alias Gemini.Validation.ThinkingConfig

  describe "validate_budget/2 for Gemini 2.5 Pro" do
    test "rejects budget of 0 (cannot disable thinking)" do
      assert {:error, msg} = ThinkingConfig.validate_budget(0, "gemini-2.5-pro")
      assert msg =~ "cannot disable thinking"
    end

    test "accepts budget in valid range (128-32768)" do
      assert :ok = ThinkingConfig.validate_budget(128, "gemini-2.5-pro")
      assert :ok = ThinkingConfig.validate_budget(1024, "gemini-2.5-pro")
      assert :ok = ThinkingConfig.validate_budget(32_768, "gemini-2.5-pro")
    end

    test "rejects budget below minimum" do
      assert {:error, _} = ThinkingConfig.validate_budget(127, "gemini-2.5-pro")
    end

    test "rejects budget above maximum" do
      assert {:error, _} = ThinkingConfig.validate_budget(32_769, "gemini-2.5-pro")
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, "gemini-2.5-pro")
    end
  end

  describe "validate_budget/2 for Gemini 2.5 Flash" do
    test "accepts budget of 0 (can disable)" do
      assert :ok = ThinkingConfig.validate_budget(0, "gemini-2.5-flash")
    end

    test "accepts budget in valid range (0-24576)" do
      assert :ok = ThinkingConfig.validate_budget(0, "gemini-2.5-flash")
      assert :ok = ThinkingConfig.validate_budget(1024, "gemini-2.5-flash")
      assert :ok = ThinkingConfig.validate_budget(24_576, "gemini-2.5-flash")
    end

    test "rejects budget above maximum" do
      assert {:error, _} = ThinkingConfig.validate_budget(24_577, "gemini-2.5-flash")
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, "gemini-2.5-flash")
    end
  end
end
```

### Live API Tests

**File:** `test/live_api_test.exs`

```elixir
@tag :live_api
test "thinking budget actually reduces thinking tokens" do
  # Test with default (dynamic thinking)
  {:ok, response_with_thinking} = Gemini.generate(
    "Solve: 2 + 2",
    model: "gemini-2.5-flash"
  )

  # Test with thinking disabled
  {:ok, response_no_thinking} = Gemini.generate(
    "Solve: 2 + 2",
    model: "gemini-2.5-flash",
    thinking_config: %{thinking_budget: 0}
  )

  thinking_tokens = get_in(response_with_thinking, [:usage_metadata, :thoughts_token_count])
  no_thinking_tokens = get_in(response_no_thinking, [:usage_metadata, :thoughts_token_count])

  # Verify thinking was used in first request
  assert is_integer(thinking_tokens) and thinking_tokens > 0

  # Verify thinking was disabled in second request
  assert no_thinking_tokens == 0 or is_nil(no_thinking_tokens)
end

@tag :live_api
test "thought summaries work when enabled" do
  {:ok, response} = Gemini.generate(
    "Explain quantum computing",
    model: "gemini-2.5-flash",
    thinking_config: %{thinking_budget: 2048, include_thoughts: true}
  )

  # Response should include thought summary
  assert response.candidates
  # Check for thought-related fields in response
end
```

---

## Documentation Updates

### README.md Updates

Add section on thinking budget:

```markdown
### Cost Optimization with Thinking Budgets

Gemini 2.5 series models use internal "thinking" for complex reasoning. You can control thinking token usage:

**Disable thinking** (save costs for simple tasks):
```elixir
{:ok, response} = Gemini.generate(
  "What is 2 + 2?",
  model: "gemini-2.5-flash",
  thinking_config: %{thinking_budget: 0}
)
```

**Set fixed budget** (balance cost and quality):
```elixir
{:ok, response} = Gemini.generate(
  "Write a Python function to sort a list",
  model: "gemini-2.5-flash",
  thinking_config: %{thinking_budget: 1024}
)
```

**Dynamic thinking** (model decides):
```elixir
{:ok, response} = Gemini.generate(
  "Solve this complex math problem...",
  model: "gemini-2.5-flash",
  thinking_config: %{thinking_budget: -1}
)
```

**Get thought summaries** (see model's reasoning):
```elixir
{:ok, response} = Gemini.generate(
  "Explain your reasoning...",
  model: "gemini-2.5-flash",
  thinking_config: %{thinking_budget: 2048, include_thoughts: true}
)
```

**Budget Ranges by Model:**
- **2.5 Pro:** 128-32,768 (cannot disable)
- **2.5 Flash:** 0-24,576 (can disable with 0)
- **2.5 Flash Lite:** 0 or 512-24,576
```

### CHANGELOG.md

```markdown
## [Unreleased]

### Fixed
- **CRITICAL:** Fixed thinking budget configuration sending wrong field names to API
  - API expects `thinkingBudget` (camelCase), was sending `thinking_budget` (snake_case)
  - This caused API to silently ignore thinking budget, users still charged for thinking tokens
  - Closes #9
  - Rejects PR #10 (contained this bug)

### Added
- `includeThoughts` parameter support for thought summaries
- Model-aware validation for thinking budgets
- `Gemini.Validation.ThinkingConfig` module for validation
- `GenerationConfig.include_thoughts/2` function
- `GenerationConfig.thinking_config/3` convenience function

### Changed
- `GenerationConfig.thinking_config` field now uses typed struct instead of plain map
- Improved error messages for invalid thinking budgets
```

### Migration Guide

**For users who attempted to use thinking budget in PR #10:**

```markdown
## Thinking Budget Fix

If you were using thinking budget configuration, you don't need to change your code!
The feature now works correctly.

**Before (didn't work):**
```elixir
# This appeared to work but API silently ignored it
Gemini.generate("test", thinking_config: %{thinking_budget: 0})
```

**After (now works):**
```elixir
# Same code, now actually disables thinking
Gemini.generate("test", thinking_config: %{thinking_budget: 0})
```

**Verification:**
Check the `thoughts_token_count` in the response's `usage_metadata`:
- Before fix: Non-zero even with budget = 0
- After fix: Zero or nil with budget = 0
```

---

## Implementation Checklist

### Phase 1: Core Fix (2-3 hours)

- [ ] **Create validation module** (45 min)
  - [ ] Create `lib/gemini/validation/thinking_config.ex`
  - [ ] Implement `validate_budget/2` with model-specific ranges
  - [ ] Add validation for all supported models
  - [ ] Write unit tests for validation

- [ ] **Update GenerationConfig** (45 min)
  - [ ] Create `ThinkingConfig` sub-module with typed struct
  - [ ] Update `thinking_config` field type
  - [ ] Fix `thinking_budget/2` function
  - [ ] Add `include_thoughts/2` function
  - [ ] Add `thinking_config/3` convenience function
  - [ ] Update @moduledoc

- [ ] **Fix Coordinator** (1-1.5 hours)
  - [ ] Add `convert_thinking_config_to_api/1` function
  - [ ] Add `maybe_put_if_not_nil/3` helper
  - [ ] Fix `build_generation_config/1` to use conversion
  - [ ] Remove duplicate code blocks
  - [ ] Integrate validation
  - [ ] Update function docs

### Phase 2: Testing (1.5-2 hours)

- [ ] **Unit tests** (45 min)
  - [ ] Test `thinking_budget/2` function
  - [ ] Test `include_thoughts/2` function
  - [ ] Test `thinking_config/3` function
  - [ ] Test struct field types

- [ ] **Conversion tests** (30 min)
  - [ ] Test struct → API conversion
  - [ ] Test map → API conversion
  - [ ] Test nil value handling
  - [ ] Test camelCase output

- [ ] **Validation tests** (30 min)
  - [ ] Test Pro model ranges
  - [ ] Test Flash model ranges
  - [ ] Test Flash Lite model ranges
  - [ ] Test dynamic thinking (-1)
  - [ ] Test error messages

- [ ] **Live API tests** (15 min)
  - [ ] Test thinking actually disabled
  - [ ] Test token count verification
  - [ ] Test thought summaries

### Phase 3: Documentation (45-60 min)

- [ ] **Update README** (20 min)
  - [ ] Add thinking budget section
  - [ ] Add examples for all modes
  - [ ] Add model compatibility table

- [ ] **Update CHANGELOG** (10 min)
  - [ ] Add bug fix entry
  - [ ] Add new features
  - [ ] Add breaking changes (none)

- [ ] **HexDocs updates** (15 min)
  - [ ] Update GenerationConfig docs
  - [ ] Add examples to function docs
  - [ ] Link to official thinking docs

- [ ] **Migration guide** (10 min)
  - [ ] Note this is a bug fix
  - [ ] Explain impact on existing code
  - [ ] Provide verification steps

### Phase 4: Review & PR (30 min)

- [ ] **Code review**
  - [ ] Run all tests locally
  - [ ] Check no warnings
  - [ ] Verify format with `mix format`
  - [ ] Run Credo if available

- [ ] **PR preparation**
  - [ ] Create branch: `fix/thinking-budget-field-names`
  - [ ] Commit with clear message
  - [ ] Link to issue #9
  - [ ] Note rejection of PR #10
  - [ ] Reference this design doc

---

## Risk Analysis

### Potential Issues

#### 1. Breaking Existing (Broken) Code
**Probability:** Low
**Impact:** Low
**Mitigation:**
- Current code doesn't work, so "breaking" it means making it work
- No actual API surface changes
- Users who tried it will see it start working (positive!)

**Rollback:** Revert to PR #10 state (but why would we?)

#### 2. Validation Too Strict
**Probability:** Medium
**Impact:** Medium
**Mitigation:**
- Only validate known models
- Unknown models pass through (let API validate)
- Clear error messages guide users
- Can disable validation if needed

**Rollback:** Remove validation calls, keep conversion

#### 3. Model Names Change
**Probability:** Low
**Impact:** Low
**Mitigation:**
- Use substring matching, not exact match
- Test multiple model name variations
- Fall back to API validation for unknowns

**Rollback:** Update validation rules

#### 4. Thought Summaries Break Response Parsing
**Probability:** Very Low
**Impact:** Medium
**Mitigation:**
- Thought summaries are optional feature
- Test response parsing with thoughts enabled
- Gracefully handle unexpected response format

**Rollback:** Remove `includeThoughts` parameter support

#### 5. Conversion Logic Errors
**Probability:** Very Low (with tests)
**Impact:** High
**Mitigation:**
- Comprehensive unit tests
- HTTP mock tests verify exact format
- Live API tests confirm it works
- Multiple code reviews

**Rollback:** Revert conversion function, keep old buggy version

### Rollback Plan

**If fix causes issues:**

1. **Immediate:** Revert the PR
2. **Communicate:** Update issue #9 explaining rollback
3. **Investigate:** Identify specific problem
4. **Fix:** Create new PR addressing issue
5. **Re-deploy:** Test thoroughly before merging

**Rollback triggers:**
- Live API tests fail
- Users report new errors
- Thinking budget still doesn't work
- Response parsing breaks

---

## PR #10 Review Comments

### Comment to Post on PR #10

```markdown
Thanks for the contribution @yosuaw! However, after reviewing this against the official Gemini API documentation, I've discovered a critical bug that prevents this from working correctly.

## Critical Issue: Wrong Field Names Sent to API

The implementation sends `thinking_budget` (snake_case) but the API expects `thinkingBudget` (camelCase). This causes the API to silently ignore the configuration.

**What gets sent:**
```json
{"thinkingConfig": {"thinking_budget": 0}}
```

**What API expects:**
```json
{"thinkingConfig": {"thinkingBudget": 0}}
```

**Result:** Users are still charged for thinking tokens because the API doesn't recognize `thinking_budget`.

This explains why you reported still seeing `thoughts_token_count: 16` in your original issue - the API was ignoring your config!

## Additional Issues Found

1. **Missing `includeThoughts` support** - Official API supports this for thought summaries
2. **No validation** - Should validate budget ranges per model (Pro: 128-32768, Flash: 0-24576)
3. **Duplicate code** - Plain map handling appears twice in coordinator.ex

## Required Changes

I've created a complete fix specification in the design document: `docs/technical/initiatives/002_thinking_budget_fix.md`

The fix requires:
1. ✅ Convert `thinking_budget` → `thinkingBudget` before sending to API
2. ✅ Add `include_thoughts` → `includeThoughts` support
3. ✅ Add model-aware budget validation
4. ✅ Add comprehensive tests (HTTP mock + live API)
5. ✅ Remove duplicate code

## Next Steps

I can either:
- **Option A:** You update this PR with the fixes (I'm happy to help review)
- **Option B:** I create a new PR based on the design doc and credit you for identifying the need

Let me know which you prefer! Either way, thank you for identifying this important feature gap - it led to discovering and documenting the complete fix.

## References
- Design doc: [002_thinking_budget_fix.md](../docs/technical/initiatives/002_thinking_budget_fix.md)
- Official API: https://ai.google.dev/gemini-api/docs/thinking
- Issue analysis: [ISSUE_ANALYSIS.md](../docs/issues/ISSUE_ANALYSIS.md)
```

---

## References

### GitHub Issues & PRs
- **Issue #9:** https://github.com/nshkrdotcom/gemini_ex/issues/9
- **PR #10:** https://github.com/nshkrdotcom/gemini_ex/pull/10

### Official API Documentation
- **Thinking Docs:** https://ai.google.dev/gemini-api/docs/thinking
- **Local Copy:** `docs/gemini_api_reference_2025_10_07/THINKING.md`
- **API Reference:** https://ai.google.dev/api

### Project Documentation
- **Issue Analysis:** `docs/issues/ISSUE_ANALYSIS.md`
- **API Reference:** `docs/issues/OFFICIAL_API_REFERENCE.md`
- **Old vs New Comparison:** `docs/gemini_api_reference_2025_10_07/COMPARISON_WITH_OLD_DOCS.md`

### Code References
- **GenerationConfig:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`
- **Coordinator:** `/home/home/p/g/n/gemini_ex/lib/gemini/apis/coordinator.ex`
- **HTTP Client:** `/home/home/p/g/n/gemini_ex/lib/gemini/client/http.ex`

### Related Initiatives
- **Initiative 001:** Multimodal Content Input Flexibility (Issue #11)

---

**Initiative Status:** Ready for Implementation
**Next Action:** Reject PR #10 with helpful comment, then implement fix
**Estimated Completion:** 4-6 hours of focused development
**Priority:** CRITICAL - Users being charged unexpectedly
