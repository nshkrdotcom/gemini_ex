# Comparison: Old vs New Gemini API Documentation

**Old Docs Location:** `oldDocs/docs/spec/`
**New Docs Location:** `docs/gemini_api_reference_2025_10_07/`
**Comparison Date:** 2025-10-07

---

## Document Size Comparison

| Document | Old (6+ months ago) | New (2025-10-07) | Change |
|----------|---------------------|------------------|--------|
| **Image Understanding** | 290 lines | 895 lines | **+605 lines (+208%)** |
| **Thinking** | 96 lines | 717 lines | **+621 lines (+647%)** |

**Key Finding:** Documentation has **significantly expanded** with much more detail, examples, and capabilities.

---

## Image Understanding Documentation Changes

### What's New in 2025-10-07

#### 1. **Enhanced Multimodal Capabilities**
- **Object Detection** (Gemini 2.0+) - NEW SECTION
  - Bounding box coordinates normalized to [0, 1000]
  - Ability to detect and locate objects in images
  - Complete examples in all languages

- **Segmentation** (Gemini 2.5+) - NEW SECTION
  - Contour masks for detected items
  - Segmentation masks with labels
  - Probability maps for segmentation confidence

#### 2. **More Language Examples**
- **Old docs:** Mostly shell/curl examples
- **New docs:** Complete examples in:
  - Python (using `google.genai`)
  - JavaScript (using `@google/genai`)
  - Go (using Gemini Go SDK)
  - REST/Shell (curl)

#### 3. **File API Integration**
- Expanded documentation on uploading images
- Clear guidance on when to use inline vs File API
- Complete workflow examples

#### 4. **Improved Structure**
- More detailed "Before you begin" section
- Token calculation details
- Supported formats clearly listed
- Tips and best practices section

### Critical API Format Confirmations

✅ **Confirmed from NEW docs (line 134-136):**
```json
{
  "inline_data": {
    "mime_type": "image/jpeg",
    "data": "base64_encoded_data"
  }
}
```

**Field Names:**
- ✅ `inline_data` (snake_case in JSON)
- ✅ `mime_type` (snake_case in JSON)

This **CONFIRMS** the bug analysis in `docs/issues/ISSUE_ANALYSIS.md` - the API uses snake_case for these specific fields.

---

## Thinking Documentation Changes

### What's New in 2025-10-07

#### 1. **Comprehensive Thinking Budget Documentation**

**Old docs (96 lines):**
- Basic explanation of thinking budgets
- Simple example showing budget of 1024
- Limited to Gemini 2.5 Flash Preview

**New docs (717 lines):**
- **Complete model support matrix** - NEW
- **Detailed budget ranges per model** - NEW
- **Dynamic thinking explanation** - EXPANDED
- **Thought summaries** - NEW FEATURE
- **Thought signatures** - NEW FEATURE
- **Pricing details** - NEW SECTION

#### 2. **Supported Models Table** (CRITICAL NEW INFO)

| Model | Default Behavior | Budget Range | Disable Thinking | Dynamic Thinking |
|-------|-----------------|--------------|------------------|------------------|
| **2.5 Pro** | Dynamic thinking | 128 to 32,768 | ❌ Cannot disable | `thinkingBudget = -1` |
| **2.5 Flash** | Dynamic thinking | 0 to 24,576 | ✅ `thinkingBudget = 0` | `thinkingBudget = -1` |
| **2.5 Flash Preview** | Dynamic thinking | 0 to 24,576 | ✅ `thinkingBudget = 0` | `thinkingBudget = -1` |
| **2.5 Flash Lite** | No thinking | 512 to 24,576 | ✅ `thinkingBudget = 0` | `thinkingBudget = -1` |
| **Robotics-ER 1.5 Preview** | Dynamic thinking | 0 to 24,576 | ✅ `thinkingBudget = 0` | `thinkingBudget = -1` |

**This table was NOT in old docs!**

#### 3. **New Features Documented**

**Thought Summaries:**
- Streaming thought summaries
- Non-streaming thought summaries
- How to enable with `includeThoughts` parameter

**Thought Signatures:**
- New feature for multi-turn conversations
- Helps maintain context in chat sessions
- Examples showing implementation

**Pricing Information:**
- Input token pricing
- Output token pricing
- Thinking token pricing (same as output)
- Regional pricing variations

#### 4. **Tool Integration**
- Search tool integration
- Code execution tool integration
- Structured output integration
- Function calling integration

### Critical API Format Confirmations

✅ **Confirmed from NEW docs (lines 195-196, 270-271):**

**JavaScript Example:**
```javascript
thinkingConfig: {
  thinkingBudget: 1024,
}
```

**REST/JSON Example:**
```json
{
  "thinkingConfig": {
    "thinkingBudget": 1024
  }
}
```

**Field Names:**
- ✅ `thinkingConfig` (camelCase in JSON)
- ✅ `thinkingBudget` (camelCase in JSON)
- ✅ `includeThoughts` (camelCase in JSON)

This **CONFIRMS** the bug in PR #10 - it's sending `thinking_budget` (snake_case) instead of `thinkingBudget` (camelCase).

---

## Key Differences Summary

### Documentation Quality

| Aspect | Old Docs | New Docs |
|--------|----------|----------|
| **Completeness** | Basic | Comprehensive |
| **Code Examples** | Mostly Shell | Python, JS, Go, Shell |
| **Structure** | Simple | Multi-section with subsections |
| **Tables** | Few | Many (model support, pricing, etc.) |
| **Best Practices** | Limited | Extensive |
| **What's Next** | Basic | Detailed with links |

### Feature Coverage

| Feature | Old Docs | New Docs |
|---------|----------|----------|
| **Basic Generation** | ✅ Yes | ✅ Yes |
| **Thinking Budget** | ✅ Basic | ✅ Complete with ranges |
| **Object Detection** | ❌ No | ✅ Yes (NEW) |
| **Segmentation** | ❌ No | ✅ Yes (NEW) |
| **Thought Summaries** | ❌ No | ✅ Yes (NEW) |
| **Thought Signatures** | ❌ No | ✅ Yes (NEW) |
| **Pricing Details** | ❌ No | ✅ Yes (NEW) |
| **Model Support Matrix** | ❌ No | ✅ Yes (NEW) |
| **Dynamic Thinking** | ⚠️ Mentioned | ✅ Fully explained |

---

## Impact on gemini_ex Implementation

### 1. Issue #11 (Multimodal) - Validation

The new docs **confirm** the API format identified in our issue analysis:
- Uses `inline_data` not `inlineData`
- Uses `mime_type` not `mimeType`
- User's confusion is justified - they need clear examples

**Action:** The recommended fix in `ISSUE_ANALYSIS.md` is correct.

### 2. PR #10 (Thinking Config) - Bug Confirmation

The new docs **prove** PR #10 has a critical bug:
- API expects: `thinkingBudget` (camelCase)
- PR #10 sends: `thinking_budget` (snake_case)
- API will silently ignore malformed config

**Action:** PR #10 must be rejected and fixed as documented in `ISSUE_ANALYSIS.md`.

### 3. Missing Features in gemini_ex

Based on new documentation, `gemini_ex` is missing:

#### High Priority:
- ✅ **Object detection** - Not yet implemented
- ✅ **Segmentation** - Not yet implemented
- ⚠️ **Thought summaries** (`includeThoughts`) - Partially in PR #10 but buggy
- ❌ **Thought signatures** - Not implemented

#### Medium Priority:
- Model-specific budget validation
- Dynamic thinking support (`thinkingBudget = -1`)
- Pricing calculator utilities

#### Low Priority:
- Advanced segmentation options
- Bounding box parsing utilities

---

## Recommendations

### Immediate Actions

1. **Fix PR #10** - Use camelCase field names as confirmed in new docs
2. **Fix Issue #11** - Follow snake_case format for `inline_data` as confirmed
3. **Update validation** - Use new model support matrix for budget validation

### Short-term Improvements

4. **Add object detection support** - New capability in Gemini 2.0+
5. **Add segmentation support** - New capability in Gemini 2.5+
6. **Implement thought summaries** - Complete the `includeThoughts` support
7. **Add thought signatures** - For better multi-turn conversations

### Long-term Enhancements

8. **Add pricing utilities** - Help users estimate costs
9. **Model capability detection** - Automatically check what features a model supports
10. **Enhanced examples** - Update docs with comprehensive examples like official docs

---

## Validation Against Official API

The new documentation provides **definitive proof** for our issue analysis:

### Field Naming Conventions

**JSON API Uses MIXED Convention:**
- **snake_case:** `inline_data`, `mime_type`, `file_data`, `file_uri`
- **camelCase:** `thinkingConfig`, `thinkingBudget`, `includeThoughts`, `mimeType` (in SDK)

**Why this matters:**
- API is inconsistent in naming (likely legacy reasons)
- Must follow EXACT convention per field
- Cannot assume all fields follow same pattern
- **Must test against real API to verify**

### Budget Ranges Are Model-Specific

**Old assumption:** Universal budget range
**New reality:** Each model has different ranges and capabilities

**Impact on gemini_ex:**
```elixir
# WRONG (old assumption):
def validate_thinking_budget(budget) when budget >= 0 and budget <= 24_576

# RIGHT (new requirement):
def validate_thinking_budget(budget, model) do
  case model do
    <<"gemini-2.5-pro", _::binary>> when budget >= 128 and budget <= 32_768 -> :ok
    <<"gemini-2.5-flash", _::binary>> when budget >= 0 and budget <= 24_576 -> :ok
    <<"gemini-2.5-flash-lite", _::binary>> when budget >= 512 and budget <= 24_576 -> :ok
    # ...
  end
end
```

---

## Documentation Evolution Timeline

**~6 months ago (Old docs):**
- Basic thinking support introduced
- Simple image understanding
- Limited examples

**2025-10-07 (New docs):**
- Comprehensive thinking capabilities
- Advanced vision features (detection, segmentation)
- Complete multi-language examples
- Detailed pricing and limitations
- Best practices for each use case

**Growth:** ~600% increase in documentation size reflects significant API maturity.

---

## Files Comparison Reference

### Old Docs
- **Location:** `oldDocs/docs/spec/`
- **Image:** `GEMINI-DOCS-17-IMAGE-UNDERSTANDING.md` (290 lines)
- **Thinking:** `GEMINI-DOCS-14-THINKING.md` (96 lines)
- **Last Updated:** Unknown (6+ months ago)

### New Docs
- **Location:** `docs/gemini_api_reference_2025_10_07/`
- **Image:** `IMAGE_UNDERSTANDING.md` (895 lines)
- **Thinking:** `THINKING.md` (717 lines)
- **Fetched:** 2025-10-07
- **Source:** https://ai.google.dev/gemini-api/docs/

---

**Conclusion:** The new documentation is **significantly more comprehensive** and **validates all findings** from the issue analysis. It provides clear evidence for the bugs identified in PR #10 and the API format questions in Issue #11.
