# Official Gemini API Reference Documentation

**Source:** Google AI for Developers (ai.google.dev)
**Date Compiled:** 2025-10-07
**Purpose:** Reference for validating gemini_ex implementation

---

## 📚 Official Documentation Links

### Primary Resources
- **Main Documentation:** https://ai.google.dev/gemini-api/docs
- **API Reference:** https://ai.google.dev/api
- **Quickstart Guide:** https://ai.google.dev/gemini-api/docs/quickstart
- **Models Documentation:** https://ai.google.dev/gemini-api/docs/models
- **GitHub Cookbook:** https://github.com/google-gemini/cookbook

### Specific Feature Documentation
- **Image Understanding:** https://ai.google.dev/gemini-api/docs/image-understanding
- **Thinking Config:** https://ai.google.dev/gemini-api/docs/thinking
- **Files API:** https://ai.google.dev/gemini-api/docs/files
- **Multimodal Content:** https://firebase.google.com/docs/vertex-ai/text-gen-from-multimodal

---

## 🖼️ Multimodal / Image Understanding

### Official Request Body Structure

```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "What is in this image?"
        },
        {
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": "BASE64_ENCODED_IMAGE_DATA"
          }
        }
      ]
    }
  ]
}
```

### Key Specifications

**Field Names:**
- ✅ `inline_data` (snake_case in JSON)
- ✅ `mime_type` (snake_case in JSON)
- ✅ `data` (base64-encoded string)

**Supported MIME Types:**
- `image/png`
- `image/jpeg`
- `image/webp`
- `image/heic`
- `image/heif`

**Limitations:**
- Maximum request size: 20MB
- Maximum images per request: 3,600 files
- Base64 encoding increases request size

### Python SDK Example

```python
import google.generativeai as genai
from google.generativeai import types

response = client.models.generate_content(
    model='gemini-2.5-flash',
    contents=[
        types.Part.from_bytes(
            data=image_bytes,
            mime_type='image/jpeg'
        ),
        'Caption this image.'
    ]
)
```

### Critical Implementation Notes

**For gemini_ex:**

1. The official API uses **snake_case** for JSON fields:
   - ✅ `inline_data` (NOT `inlineData`)
   - ✅ `mime_type` (NOT `mimeType`)

2. The `data` field should contain the **raw base64 string** without prefix:
   - ✅ `"iVBORw0KGgoAAAANSUhEUgAA..."`
   - ❌ `"data:image/png;base64,iVBORw0KGgo..."`

3. Parts can be mixed in any order:
   ```json
   "parts": [
     {"text": "First question"},
     {"inline_data": {...}},
     {"text": "Follow-up question"}
   ]
   ```

---

## 🧠 Thinking Config

### Official Configuration Structure

```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 1024,
      "includeThoughts": true
    }
  }
}
```

### ThinkingBudget Parameter

**Type:** Integer
**Description:** Controls the number of thinking tokens the model can use

**Valid Values by Model:**

#### Gemini 2.5 Pro
- **Range:** 128 to 32,768 tokens
- **Default:** Dynamic thinking (auto-adjusts)
- **Special:** Cannot disable thinking (minimum 128)

#### Gemini 2.5 Flash
- **Range:** 0 to 24,576 tokens
- **Default:** Dynamic thinking
- **Special Values:**
  - `0` - Disables thinking entirely
  - `-1` - Enables dynamic thinking (model controls budget)
  - `1024` - Low thinking budget (equivalent to OpenAI "low")
  - `8192` - Medium thinking budget (equivalent to OpenAI "medium")
  - `24576` - High thinking budget (equivalent to OpenAI "high")

### IncludeThoughts Parameter

**Type:** Boolean (optional)
**Default:** `false`
**Description:** When `true`, includes thought summaries in the response

**Example with Thoughts:**
```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 8192,
      "includeThoughts": true
    }
  }
}
```

### Python SDK Example

```python
import google.generativeai as genai
from google.generativeai import types

response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=prompt,
    config=types.GenerateContentConfig(
        thinking_config=types.ThinkingConfig(
            thinking_budget=1024,
            include_thoughts=True
        )
    )
)
```

### Usage Metadata Response

When thinking is used, the response includes token counts:

```json
{
  "usageMetadata": {
    "promptTokenCount": 10,
    "candidatesTokenCount": 50,
    "thoughtsTokenCount": 256,
    "totalTokenCount": 316
  }
}
```

### Critical Implementation Notes

**For gemini_ex:**

1. **Field Naming in JSON:**
   - ✅ `thinkingConfig` (camelCase)
   - ✅ `thinkingBudget` (camelCase)
   - ✅ `includeThoughts` (camelCase)

2. **Response Field Naming:**
   - ✅ `usageMetadata` (camelCase)
   - ✅ `thoughtsTokenCount` (camelCase)

3. **Validation Requirements:**
   - Reject budgets < 0 (except -1 for dynamic)
   - Reject budgets > 24,576 for Flash
   - Reject budgets > 32,768 for Pro
   - Reject budget 0 for Pro (cannot disable)

4. **Cost Implications:**
   - Thinking tokens are charged at the same rate as output tokens
   - Setting budget to 0 eliminates thinking token charges
   - Dynamic thinking (-1) can vary costs significantly

---

## 📋 Complete generateContent Request Schema

### Full Request Structure

```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "string"
        },
        {
          "inline_data": {
            "mime_type": "string",
            "data": "string"
          }
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "topP": 0.95,
    "topK": 40,
    "maxOutputTokens": 8192,
    "stopSequences": ["string"],
    "responseMimeType": "text/plain",
    "thinkingConfig": {
      "thinkingBudget": 1024,
      "includeThoughts": false
    }
  },
  "systemInstruction": {
    "role": "system",
    "parts": [
      {
        "text": "string"
      }
    ]
  },
  "tools": [
    {
      "functionDeclarations": [
        {
          "name": "string",
          "description": "string",
          "parameters": {
            "type": "object",
            "properties": {},
            "required": []
          }
        }
      ]
    }
  ]
}
```

### Response Structure

```json
{
  "candidates": [
    {
      "content": {
        "role": "model",
        "parts": [
          {
            "text": "string"
          }
        ]
      },
      "finishReason": "STOP",
      "index": 0,
      "safetyRatings": []
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 10,
    "candidatesTokenCount": 50,
    "thoughtsTokenCount": 256,
    "totalTokenCount": 316
  }
}
```

---

## 🔍 Comparison with gemini_ex Implementation

### Issue #11 Analysis: Multimodal Format

**User Expected (from Issue #11):**
```elixir
content = [
  %{type: "text", text: "Describe this image..."},
  %{type: "image", source: %{type: "base64", data: Base.encode64(data)}}
]
```

**Official API Expects:**
```json
{
  "contents": [{
    "parts": [
      {"text": "Describe this image..."},
      {"inline_data": {"mime_type": "image/jpeg", "data": "base64data"}}
    ]
  }]
}
```

**Problems with User's Format:**
1. ❌ Uses `type` field (not in official API)
2. ❌ Uses `source` nested structure (not in official API)
3. ❌ Missing `mime_type` (required by official API)
4. ❌ Uses `inlineData` → Should be `inline_data`

**Correct gemini_ex Format Should Be:**
```elixir
alias Gemini.Types.{Content, Part}

content = Content.new(
  role: "user",
  parts: [
    Part.text("Describe this image..."),
    Part.inline_data(Base.encode64(image_data), "image/jpeg")
  ]
)
```

### Issue #9/PR #10 Analysis: Thinking Config

**User's Code (from Issue #9):**
```elixir
Coordinator.generate_content(
  contents,
  [
    model: "gemini-2.5-flash",
    thinking_config: %{thinking_budget: 0}
  ]
)
```

**Official API Expects:**
```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 0
    }
  }
}
```

**PR #10 Implementation:**
```elixir
# In coordinator.ex build_generation_config/1
{:thinking_config, thinking_config}, acc when is_map(thinking_config) ->
  Map.put(acc, :thinkingConfig, thinking_config)
```

**Analysis:**
- ✅ Correctly converts snake_case → camelCase
- ✅ Accepts map with `thinking_budget` key
- ⚠️ No validation of budget values
- ⚠️ No nested `thinkingBudget` → API expects this structure

**What Should Be Sent to API:**
```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinkingBudget": 0
    }
  }
}
```

**Current Implementation Might Send:**
```json
{
  "generationConfig": {
    "thinkingConfig": {
      "thinking_budget": 0
    }
  }
}
```

**Fix Required:**
```elixir
defp convert_thinking_config_to_api(%{thinking_budget: budget}) do
  %{"thinkingBudget" => budget}
end

defp convert_thinking_config_to_api(%{thinking_budget: budget, include_thoughts: include}) do
  %{"thinkingBudget" => budget, "includeThoughts" => include}
end
```

---

## ✅ Validation Checklist for gemini_ex

### Multimodal Support
- [ ] Accept `inline_data` field (not `inlineData`)
- [ ] Require `mime_type` for all image parts
- [ ] Support all official MIME types (png, jpeg, webp, heic, heif)
- [ ] Validate base64 encoding
- [ ] Enforce 20MB request size limit
- [ ] Allow mixed text and image parts
- [ ] Support multiple images per request (up to 3,600)

### Thinking Config Support
- [ ] Accept `thinking_config` in options
- [ ] Convert to nested `thinkingConfig` → `thinkingBudget` structure
- [ ] Support `include_thoughts` → `includeThoughts`
- [ ] Validate budget ranges by model:
  - Flash: 0-24,576 or -1
  - Pro: 128-32,768 (no 0)
- [ ] Parse `thoughtsTokenCount` from response
- [ ] Document cost implications

### Field Name Conversions
- [ ] **Request (to API):** snake_case → camelCase
  - `inline_data` → keep as `inline_data` (exception!)
  - `mime_type` → keep as `mime_type` (exception!)
  - `thinking_config` → `thinkingConfig`
  - `thinking_budget` → `thinkingBudget`
- [ ] **Response (from API):** camelCase → snake_case
  - `usageMetadata` → `usage_metadata`
  - `thoughtsTokenCount` → `thoughts_token_count`
  - `finishReason` → `finish_reason`

### Error Handling
- [ ] Handle 413 errors (request too large)
- [ ] Validate MIME types before sending
- [ ] Clear error messages for invalid thinking budgets
- [ ] Handle missing required fields (mime_type, data)

---

## 📊 Model Capabilities Summary

| Model | Thinking Support | Budget Range | Can Disable | Max Images |
|-------|-----------------|--------------|-------------|------------|
| Gemini 2.5 Pro | ✅ Yes | 128 - 32,768 | ❌ No | 3,600 |
| Gemini 2.5 Flash | ✅ Yes | 0 - 24,576 | ✅ Yes | 3,600 |
| Gemini 1.5 Pro | ❌ No | N/A | N/A | 3,600 |
| Gemini 1.5 Flash | ❌ No | N/A | N/A | 3,600 |

---

## 🔗 Additional Resources

### Official Examples
- **Cookbook Notebooks:** https://github.com/google-gemini/cookbook
- **Vision Examples:** https://github.com/google-gemini/cookbook/blob/main/quickstarts/Vision.ipynb
- **Thinking Examples:** https://github.com/google-gemini/cookbook/blob/main/quickstarts/Thinking.ipynb

### Community Resources
- **Stack Overflow Tag:** `google-gemini`
- **GitHub Discussions:** https://github.com/google-gemini/cookbook/discussions
- **Google AI Forum:** https://discuss.ai.google.dev/

---

**Document Version:** 1.0
**Last Updated:** 2025-10-07
**Maintained By:** gemini_ex project
**Status:** Official API reference for implementation validation
