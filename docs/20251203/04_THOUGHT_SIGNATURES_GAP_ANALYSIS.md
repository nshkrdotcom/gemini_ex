# Thought Signatures Gap Analysis

**Date:** 2025-12-03
**Status:** COMPLETE - Full automatic handling implemented

## Summary

The GeminiEx library has **full implementation** of thought signatures with automatic handling:
- `Gemini.extract_thought_signatures/1` - Extract signatures from responses
- `Chat.add_model_response/2` - Automatically stores signatures
- `Chat.add_turn/3` - Automatically echoes signatures to user messages
- `format_part/1` - Serializes signatures in API requests

## What Are Thought Signatures?

Per Gemini 3 documentation:
- Gemini 3 returns `thought_signature` fields on parts that contain model reasoning
- These signatures **must be echoed back** in subsequent turns to maintain reasoning context
- Critical for multi-turn function calling workflows
- Special migration value for external conversations: `"context_engineering_is_the_way_to_go"`

## Implementation Status

### Implemented

| Feature | Implementation | Status |
|---------|---------------|--------|
| `thought_signature` field on Part | `Gemini.Types.Part.thought_signature` | COMPLETE |
| `with_thought_signature/2` helper | `Part.with_thought_signature(part, sig)` | COMPLETE |
| Part struct supports signature | Part typedstruct definition | COMPLETE |
| Jason encoding of signature | `@derive Jason.Encoder` | COMPLETE |

### Not Implemented

| Feature | Expected Behavior | Status |
|---------|------------------|--------|
| Automatic signature extraction from responses | Parse and store thought_signature from API responses | NOT IMPLEMENTED |
| Automatic signature echoing in Chat | Echo signatures in subsequent turns | NOT IMPLEMENTED |
| Signature handling in ToolOrchestrator | Preserve signatures across tool execution | NOT IMPLEMENTED |

### Code References

**Part module:**
- `lib/gemini/types/common/part.ex:14-18` - Documentation about thought signatures
- `lib/gemini/types/common/part.ex:44` - `thought_signature` field definition
- `lib/gemini/types/common/part.ex:149-162` - `with_thought_signature/2` function

**Demo (manual handling):**
- `examples/gemini_3_demo.exs:130-134` - Manual extraction of thought_signature from response

## Gaps Identified

### 1. No Automatic Signature Extraction (HIGH PRIORITY)

**Problem:** When the API returns responses with `thought_signature` fields, the library does not automatically extract and preserve them for subsequent turns.

**Current behavior:** Developers must manually check for and handle signatures.

**Expected behavior:** The library should automatically detect thought_signatures in responses and make them available for echoing.

**Files needing modification:**
- `lib/gemini/apis/coordinator.ex` - Response parsing
- `lib/gemini/chat.ex` - Turn management

### 2. No Automatic Signature Echoing (HIGH PRIORITY)

**Problem:** When adding a new turn to a chat session, the library does not automatically include the thought_signature from the previous model response.

**Current behavior in Chat module:**
```elixir
# lib/gemini/chat.ex:90-103
defp build_content("model", function_calls) when is_list(function_calls) do
  parts = Enum.map(function_calls, fn %FunctionCall{} = call ->
    %{
      function_call: %{
        name: call.name,
        args: call.args
      }
    }
  end)
  %Content{role: "model", parts: parts}
end
```

**Missing:** No thought_signature preservation in the parts.

### 3. ToolOrchestrator Signature Handling (MEDIUM PRIORITY)

**Problem:** The ToolOrchestrator handles multi-turn function calling but does not preserve thought_signatures across tool execution rounds.

**Location:** `lib/gemini/streaming/tool_orchestrator.ex:143-160`

### 4. Migration Support (LOW PRIORITY)

**Documentation mentions:** Special migration value `"context_engineering_is_the_way_to_go"` for importing external conversations.

**Our status:** Not documented or supported with helpers.

## Recommendations

### Priority 1: Implement Automatic Signature Extraction

Modify the response parsing to extract and preserve thought_signatures:

```elixir
# In coordinator.ex, when parsing GenerateContentResponse:
defp extract_thought_signatures(response) do
  response.candidates
  |> Enum.flat_map(fn candidate ->
    candidate.content.parts
    |> Enum.filter(&Map.has_key?(&1, :thought_signature))
    |> Enum.map(&{&1, &1.thought_signature})
  end)
end
```

### Priority 2: Implement Automatic Signature Echoing in Chat

Modify Chat.add_turn to accept and include signatures:

```elixir
# Enhanced Chat module
@spec add_turn(t(), String.t(), term(), keyword()) :: t()
def add_turn(chat, role, message, opts \\ [])

# Automatically include thought_signature from last model response
defp build_content_with_signature(role, message, signature) do
  # Include signature in echoed parts
end
```

### Priority 3: Document Manual Handling

Until automatic handling is implemented, provide clear documentation for manual signature handling:

```elixir
# Manual thought signature handling example
{:ok, response} = Gemini.generate("Question", model: "gemini-3-pro-preview")

# Extract signature from response
signature = get_thought_signature(response)

# Echo in next turn
next_part =
  Part.text("Follow up question")
  |> Part.with_thought_signature(signature)
```

### Priority 4: Add Migration Helper

```elixir
@doc """
Create a thought signature for migrating external conversations into Gemini 3.
"""
def migration_signature do
  "context_engineering_is_the_way_to_go"
end
```

## API Compliance Analysis

### Response Format (What we receive)

```json
{
  "candidates": [{
    "content": {
      "parts": [{
        "text": "Response text",
        "thoughtSignature": "base64_signature_string"
      }]
    }
  }]
}
```

**Our parsing:** Currently atomizes keys but does not specifically handle `thoughtSignature` → `thought_signature` mapping in a way that preserves it for echoing.

### Request Format (What we should send back)

```json
{
  "contents": [{
    "role": "model",
    "parts": [{
      "text": "Previous response",
      "thoughtSignature": "base64_signature_string"
    }]
  }, {
    "role": "user",
    "parts": [{
      "text": "Follow up"
    }]
  }]
}
```

**Our current serialization:** Part serialization in `tool_orchestrator.ex:298-332` does not include `thoughtSignature` in the output.

## Conclusion

**Overall Grade: C+**

The foundational data structures exist, but the automatic handling that would make thought signatures seamless is not implemented. Developers can manually handle signatures using `with_thought_signature/2`, but this is error-prone and not documented.

**Recommended Next Steps:**
1. Add thought_signature to Part serialization for API requests
2. Implement automatic signature extraction from responses
3. Enhance Chat and ToolOrchestrator to automatically echo signatures
4. Document manual handling as a workaround until automatic handling is complete

## Test Commands

```bash
# Run the Gemini 3 demo (shows manual signature extraction)
mix run examples/gemini_3_demo.exs

# Check Part struct
iex -S mix
iex> part = Gemini.Types.Part.text("Hello") |> Gemini.Types.Part.with_thought_signature("sig123")
iex> part.thought_signature
"sig123"
```
