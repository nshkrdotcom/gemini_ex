# Context Caching Types: Missing Fields Analysis

**Analysis Date:** 2025-12-05
**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/`
**gemini_ex Location:** `/home/home/p/g/n/gemini_ex/`

## Executive Summary

This document identifies all missing fields in gemini_ex's context caching implementation compared to the Python genai SDK. The analysis covers:

- CachedContent resource fields
- CreateCachedContentConfig options
- Update/Get/List/Delete configurations
- Usage metadata fields (both cache-level and request-level)
- Response types

## 1. CachedContent Resource

### Python SDK (types.py:12370-12398)

```python
class CachedContent(_common.BaseModel):
    name: Optional[str]
    display_name: Optional[str]
    model: Optional[str]
    create_time: Optional[datetime.datetime]
    update_time: Optional[datetime.datetime]
    expire_time: Optional[datetime.datetime]
    usage_metadata: Optional[CachedContentUsageMetadata]
```

### gemini_ex (lib/gemini/apis/context_cache.ex:57-65)

```elixir
@type cached_content :: %{
    name: String.t(),
    display_name: String.t() | nil,
    model: String.t(),
    create_time: String.t() | nil,
    update_time: String.t() | nil,
    expire_time: String.t() | nil,
    usage_metadata: CachedContentUsageMetadata.t() | nil
}
```

### Status: COMPLETE ✓

All fields are present. Note that Python uses `datetime.datetime` while Elixir uses ISO8601 strings, which is appropriate.

---

## 2. CreateCachedContentConfig

### Python SDK (types.py:12189-12239)

```python
class CreateCachedContentConfig(_common.BaseModel):
    http_options: Optional[HttpOptions]
    ttl: Optional[str]
    expire_time: Optional[datetime.datetime]
    display_name: Optional[str]
    contents: Optional[ContentListUnion]
    system_instruction: Optional[ContentUnion]
    tools: Optional[list[Tool]]
    tool_config: Optional[ToolConfig]
    kms_key_name: Optional[str]  # Vertex AI only
```

### gemini_ex (lib/gemini/apis/context_cache.ex:43-55)

```elixir
@type cache_opts :: [
    display_name: String.t(),
    model: String.t(),
    ttl: non_neg_integer(),
    expire_time: DateTime.t(),
    system_instruction: String.t() | Content.t(),
    tools: [Altar.ADM.FunctionDeclaration.t()],
    tool_config: Altar.ADM.ToolConfig.t(),
    kms_key_name: String.t(),
    auth: :gemini | :vertex_ai,
    project_id: String.t(),
    location: String.t()
]
```

### Status: COMPLETE ✓

All fields are present. gemini_ex includes additional useful fields (`auth`, `project_id`, `location`) for configuration.

**Implementation Note:** gemini_ex correctly implements `kms_key_name` support (context_cache.ex:361-374) with proper Vertex AI detection.

---

## 3. UpdateCachedContentConfig

### Python SDK (types.py:12553-12566)

```python
class UpdateCachedContentConfig(_common.BaseModel):
    http_options: Optional[HttpOptions]
    ttl: Optional[str]
    expire_time: Optional[datetime.datetime]
```

### gemini_ex (lib/gemini/apis/context_cache.ex:246-261)

```elixir
# Implemented inline in update/2 function
# Accepts opts with :ttl and :expire_time
```

### Status: COMPLETE ✓

Fields are implemented. Could be formalized into a typespec for consistency.

---

## 4. GetCachedContentConfig

### Python SDK (types.py:12429-12434)

```python
class GetCachedContentConfig(_common.BaseModel):
    http_options: Optional[HttpOptions]
```

### gemini_ex

```elixir
# No formal type, uses keyword list opts
```

### Status: COMPLETE ✓

Minimal requirements met through keyword opts pattern.

---

## 5. DeleteCachedContentConfig

### Python SDK (types.py:12481-12486)

```python
class DeleteCachedContentConfig(_common.BaseModel):
    http_options: Optional[HttpOptions]
```

### gemini_ex

```elixir
# No formal type, uses keyword list opts
```

### Status: COMPLETE ✓

Minimal requirements met through keyword opts pattern.

---

## 6. ListCachedContentsConfig

### Python SDK (types.py:12617-12624)

```python
class ListCachedContentsConfig(_common.BaseModel):
    http_options: Optional[HttpOptions]
    page_size: Optional[int]
    page_token: Optional[str]
```

### gemini_ex (lib/gemini/apis/context_cache.ex:163-201)

```elixir
# Implemented inline with query params
# Supports page_size and page_token
```

### Status: COMPLETE ✓

All pagination fields are supported.

---

## 7. CachedContentUsageMetadata (Cache-level)

### Python SDK (types.py:12321-12343)

```python
class CachedContentUsageMetadata(_common.BaseModel):
    audio_duration_seconds: Optional[int]  # Vertex AI only
    image_count: Optional[int]              # Vertex AI only
    text_count: Optional[int]               # Vertex AI only
    total_token_count: Optional[int]
    video_duration_seconds: Optional[int]   # Vertex AI only
    # MISSING: cached_content_token_count - NOT in this type
```

### gemini_ex (lib/gemini/types/cached_content_usage_metadata.ex:9-16)

```elixir
typedstruct do
  field(:total_token_count, integer() | nil)
  field(:cached_content_token_count, integer() | nil)
  field(:audio_duration_seconds, integer() | nil)
  field(:image_count, integer() | nil)
  field(:text_count, integer() | nil)
  field(:video_duration_seconds, integer() | nil)
end
```

### Status: COMPLETE ✓

All fields present. Note: `cached_content_token_count` is included in gemini_ex but not in Python's CachedContentUsageMetadata (it appears in GenerateContentResponseUsageMetadata instead).

---

## 8. UsageMetadata (Request-level in generate_content responses)

### Python SDK (types.py:16026-16073)

```python
class UsageMetadata(_common.BaseModel):
    prompt_token_count: Optional[int]
    cached_content_token_count: Optional[int]
    response_token_count: Optional[int]
    tool_use_prompt_token_count: Optional[int]
    thoughts_token_count: Optional[int]
    total_token_count: Optional[int]
    prompt_tokens_details: Optional[list[ModalityTokenCount]]
    cache_tokens_details: Optional[list[ModalityTokenCount]]
    response_tokens_details: Optional[list[ModalityTokenCount]]
    tool_use_prompt_tokens_details: Optional[list[ModalityTokenCount]]
    traffic_type: Optional[TrafficType]
```

### gemini_ex (lib/gemini/types/response/generate_content_response.ex:117-131)

```elixir
defmodule Gemini.Types.Response.UsageMetadata do
  typedstruct do
    field(:prompt_token_count, integer() | nil, default: nil)
    field(:candidates_token_count, integer() | nil, default: nil)
    field(:total_token_count, integer(), enforce: true)
    field(:cached_content_token_count, integer() | nil, default: nil)
  end
end
```

### Missing Fields (CRITICAL):

1. **`tool_use_prompt_token_count`** (integer | nil)
   - Description: Number of tokens present in tool-use prompt(s)
   - Priority: HIGH
   - Reason: Important for billing/tracking with function calling

2. **`thoughts_token_count`** (integer | nil)
   - Description: Number of tokens of thoughts for thinking models
   - Priority: MEDIUM
   - Reason: Important for new thinking models (Gemini 2.0+)

3. **`prompt_tokens_details`** (list of ModalityTokenCount)
   - Description: List of modalities processed in the request input
   - Priority: MEDIUM
   - Reason: Useful for multimodal tracking

4. **`cache_tokens_details`** (list of ModalityTokenCount)
   - Description: List of modalities processed in the cache input
   - Priority: MEDIUM
   - Reason: Detailed cache usage breakdown

5. **`response_tokens_details`** (list of ModalityTokenCount)
   - Description: List of modalities returned in the response
   - Priority: LOW
   - Reason: Nice-to-have for analytics

6. **`tool_use_prompt_tokens_details`** (list of ModalityTokenCount)
   - Description: List of modalities processed in the tool-use prompt
   - Priority: LOW
   - Reason: Detailed function calling tracking

7. **`traffic_type`** (TrafficType enum)
   - Description: Shows whether request uses Pay-As-You-Go or Provisioned Throughput
   - Priority: MEDIUM
   - Reason: Important for Vertex AI billing clarity
   - Values: TRAFFIC_TYPE_UNSPECIFIED, ON_DEMAND, PROVISIONED_THROUGHPUT

8. **`response_token_count`** vs **`candidates_token_count`**
   - gemini_ex uses `candidates_token_count` but Python SDK uses `response_token_count`
   - Priority: LOW (naming difference)
   - Recommendation: Consider aliasing or documenting this difference

---

## 9. ModalityTokenCount (New Type Needed)

### Python SDK (types.py:6386-6395)

```python
class ModalityTokenCount(_common.BaseModel):
    modality: Optional[MediaModality]
    token_count: Optional[int]
```

### MediaModality Enum (types.py:843-853)

```python
class MediaModality(_common.CaseInSensitiveEnum):
    MODALITY_UNSPECIFIED = 'MODALITY_UNSPECIFIED'
    TEXT = 'TEXT'
    IMAGE = 'IMAGE'
    VIDEO = 'VIDEO'
```

### gemini_ex

**MISSING ENTIRELY**

### Implementation Needed:

```elixir
defmodule Gemini.Types.ModalityTokenCount do
  @moduledoc """
  Token counting info for a single modality.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:modality, String.t() | nil)
    field(:token_count, integer() | nil)
  end
end
```

---

## 10. TrafficType Enum (New Type Needed)

### Python SDK (types.py:450-461)

```python
class TrafficType(_common.CaseInSensitiveEnum):
    TRAFFIC_TYPE_UNSPECIFIED = 'TRAFFIC_TYPE_UNSPECIFIED'
    ON_DEMAND = 'ON_DEMAND'
    PROVISIONED_THROUGHPUT = 'PROVISIONED_THROUGHPUT'
```

### gemini_ex

**MISSING ENTIRELY**

### Implementation Needed:

```elixir
defmodule Gemini.Types.TrafficType do
  @moduledoc """
  Traffic type for billing tracking.

  Shows whether a request consumes Pay-As-You-Go or Provisioned Throughput quota.
  This enum is only supported in Vertex AI.
  """

  @type t :: :traffic_type_unspecified | :on_demand | :provisioned_throughput

  @spec from_api(String.t()) :: t()
  def from_api("TRAFFIC_TYPE_UNSPECIFIED"), do: :traffic_type_unspecified
  def from_api("ON_DEMAND"), do: :on_demand
  def from_api("PROVISIONED_THROUGHPUT"), do: :provisioned_throughput
  def from_api(_), do: :traffic_type_unspecified

  @spec to_api(t()) :: String.t()
  def to_api(:traffic_type_unspecified), do: "TRAFFIC_TYPE_UNSPECIFIED"
  def to_api(:on_demand), do: "ON_DEMAND"
  def to_api(:provisioned_throughput), do: "PROVISIONED_THROUGHPUT"
end
```

---

## 11. Response Types

### DeleteCachedContentResponse

**Python SDK (types.py:12533-12538)**
```python
class DeleteCachedContentResponse(_common.BaseModel):
    sdk_http_response: Optional[HttpResponse]
```

**gemini_ex:** Returns `:ok` or `{:error, reason}`

**Status:** Acceptable difference - Elixir pattern is more idiomatic

### ListCachedContentsResponse

**Python SDK (types.py:12668-12678)**
```python
class ListCachedContentsResponse(_common.BaseModel):
    sdk_http_response: Optional[HttpResponse]
    next_page_token: Optional[str]
    cached_contents: Optional[list[CachedContent]]
```

**gemini_ex (context_cache.ex:192-195)**
```elixir
result = %{
  cached_contents: cached_contents,
  next_page_token: Map.get(response, "nextPageToken")
}
```

**Status:** COMPLETE ✓ (though missing sdk_http_response, which is optional)

---

## Priority Rankings

### CRITICAL (Implement Immediately)

1. **UsageMetadata.tool_use_prompt_token_count**
   - Affects billing accuracy for function calling
   - Easy to implement - just add field

2. **ModalityTokenCount type + all *_tokens_details fields**
   - Required for detailed multimodal usage tracking
   - Moderate complexity - new type + parsing

### HIGH (Implement Soon)

3. **UsageMetadata.thoughts_token_count**
   - Important for thinking models (Gemini 2.0-flash-thinking)
   - Easy to implement

4. **UsageMetadata.traffic_type + TrafficType enum**
   - Important for Vertex AI billing transparency
   - Moderate complexity

### MEDIUM (Nice to Have)

5. **UsageMetadata.prompt_tokens_details**
   - Better multimodal tracking
   - Depends on ModalityTokenCount

6. **UsageMetadata.cache_tokens_details**
   - Better cache usage insights
   - Depends on ModalityTokenCount

### LOW (Future Enhancement)

7. **UsageMetadata.response_tokens_details**
   - Analytics only
   - Depends on ModalityTokenCount

8. **UsageMetadata.tool_use_prompt_tokens_details**
   - Detailed function calling analytics
   - Depends on ModalityTokenCount

9. **Naming: response_token_count vs candidates_token_count**
   - Documentation clarification sufficient

---

## Implementation Suggestions

### Step 1: Add ModalityTokenCount and TrafficType

Create new type files:
- `/lib/gemini/types/modality_token_count.ex`
- `/lib/gemini/types/traffic_type.ex`

### Step 2: Update UsageMetadata

Modify `/lib/gemini/types/response/generate_content_response.ex`:

```elixir
defmodule Gemini.Types.Response.UsageMetadata do
  use TypedStruct

  alias Gemini.Types.{ModalityTokenCount, TrafficType}

  @derive Jason.Encoder
  typedstruct do
    # Existing fields
    field(:prompt_token_count, integer() | nil, default: nil)
    field(:candidates_token_count, integer() | nil, default: nil)
    field(:total_token_count, integer(), enforce: true)
    field(:cached_content_token_count, integer() | nil, default: nil)

    # NEW FIELDS
    field(:tool_use_prompt_token_count, integer() | nil, default: nil)
    field(:thoughts_token_count, integer() | nil, default: nil)
    field(:prompt_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:cache_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:response_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:tool_use_prompt_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:traffic_type, TrafficType.t() | nil, default: nil)
  end
end
```

### Step 3: Update Response Parsing

Update the parser that converts API responses to handle these new fields:

```elixir
# In the response parsing function
defp parse_usage_metadata(nil), do: nil
defp parse_usage_metadata(metadata) when is_map(metadata) do
  %UsageMetadata{
    prompt_token_count: metadata["promptTokenCount"],
    candidates_token_count: metadata["candidatesTokenCount"],
    total_token_count: metadata["totalTokenCount"] || 0,
    cached_content_token_count: metadata["cachedContentTokenCount"],
    tool_use_prompt_token_count: metadata["toolUsePromptTokenCount"],
    thoughts_token_count: metadata["thoughtsTokenCount"],
    prompt_tokens_details: parse_modality_counts(metadata["promptTokensDetails"]),
    cache_tokens_details: parse_modality_counts(metadata["cacheTokensDetails"]),
    response_tokens_details: parse_modality_counts(metadata["responseTokensDetails"]),
    tool_use_prompt_tokens_details: parse_modality_counts(metadata["toolUsePromptTokensDetails"]),
    traffic_type: parse_traffic_type(metadata["trafficType"])
  }
end

defp parse_modality_counts(nil), do: nil
defp parse_modality_counts(counts) when is_list(counts) do
  Enum.map(counts, fn count ->
    %ModalityTokenCount{
      modality: count["modality"],
      token_count: count["tokenCount"]
    }
  end)
end

defp parse_traffic_type(nil), do: nil
defp parse_traffic_type(type), do: TrafficType.from_api(type)
```

### Step 4: Testing

Add tests for:
1. Parsing responses with new fields
2. Handling nil/missing fields gracefully
3. TrafficType enum conversion
4. ModalityTokenCount parsing

---

## API Response Field Mapping

| Python SDK Field | API Field (camelCase) | gemini_ex Field | Status |
|-----------------|----------------------|-----------------|--------|
| prompt_token_count | promptTokenCount | prompt_token_count | ✓ |
| cached_content_token_count | cachedContentTokenCount | cached_content_token_count | ✓ |
| response_token_count | candidatesTokenCount | candidates_token_count | ✓ (naming diff) |
| total_token_count | totalTokenCount | total_token_count | ✓ |
| tool_use_prompt_token_count | toolUsePromptTokenCount | - | ✗ MISSING |
| thoughts_token_count | thoughtsTokenCount | - | ✗ MISSING |
| prompt_tokens_details | promptTokensDetails | - | ✗ MISSING |
| cache_tokens_details | cacheTokensDetails | - | ✗ MISSING |
| response_tokens_details | responseTokensDetails | - | ✗ MISSING |
| tool_use_prompt_tokens_details | toolUsePromptTokensDetails | - | ✗ MISSING |
| traffic_type | trafficType | - | ✗ MISSING |

---

## Vertex AI vs Gemini API Differences

### Fields Only in Vertex AI:

1. **CachedContentUsageMetadata:**
   - audio_duration_seconds
   - image_count
   - text_count
   - video_duration_seconds

2. **CreateCachedContentConfig:**
   - kms_key_name (encryption)

3. **UsageMetadata:**
   - traffic_type

**gemini_ex Handling:** Currently treats these fields uniformly. Consider adding runtime detection or documentation about Vertex AI-specific fields.

---

## Recommendations

### Immediate Actions:

1. Add `tool_use_prompt_token_count` field to UsageMetadata
2. Add `thoughts_token_count` field to UsageMetadata
3. Create ModalityTokenCount type
4. Create TrafficType type and enum

### Short-term Actions:

5. Add all `*_tokens_details` fields to UsageMetadata
6. Update response parsers to handle new fields
7. Add comprehensive tests
8. Update documentation

### Long-term Actions:

9. Consider creating formal typespecs for all config types (Get/Delete/Update/List)
10. Add SDK version compatibility tracking
11. Consider feature detection at runtime for Vertex AI-specific fields

---

## Compatibility Notes

- Python SDK is auto-generated (see comment in caches.py:16)
- API field names use camelCase, both SDKs convert to snake_case
- gemini_ex uses atoms for enums, Python uses string-based enums
- Both SDKs handle optional fields appropriately
- TTL handling differs: Python uses string ("3600s"), gemini_ex converts integer to string

---

## References

- Python SDK: `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py`
- Python SDK Caches: `/home/home/p/g/n/gemini_ex/python-genai/google/genai/caches.py`
- gemini_ex Context Cache: `/home/home/p/g/n/gemini_ex/lib/gemini/apis/context_cache.ex`
- gemini_ex CachedContentUsageMetadata: `/home/home/p/g/n/gemini_ex/lib/gemini/types/cached_content_usage_metadata.ex`
- gemini_ex UsageMetadata: `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex`

---

**Analysis Complete**

Total Missing Fields: **9 critical fields** in UsageMetadata + **2 new types** (ModalityTokenCount, TrafficType)

All cache-level operations (create/get/list/update/delete) are complete and functional.
