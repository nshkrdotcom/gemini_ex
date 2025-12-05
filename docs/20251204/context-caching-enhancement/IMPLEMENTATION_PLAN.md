# Context Caching Enhancement Implementation Plan

**Date:** 2025-12-04
**Status:** Implemented in v0.6.0
**Priority:** High

---

## Executive Summary

This document details the implementation plan to bring the Elixir Gemini client's context caching feature to full parity with the Python `google-genai` SDK. The current implementation covers ~80% of the functionality but is missing critical features like `system_instruction` caching, tool caching, and file upload integration.

---

## Current State Analysis

### What's Already Implemented

| Feature | File | Status |
|---------|------|--------|
| `create/2` - Basic cache creation | `lib/gemini/apis/context_cache.ex:82` | ✅ |
| `list/1` - List caches with pagination | `lib/gemini/apis/context_cache.ex:128` | ✅ |
| `get/2` - Get cache by name | `lib/gemini/apis/context_cache.ex:180` | ✅ |
| `update/2` - Update TTL | `lib/gemini/apis/context_cache.ex:206` | ✅ |
| `delete/2` - Delete cache | `lib/gemini/apis/context_cache.ex:237` | ✅ |
| `cached_content` in generate requests | `lib/gemini/apis/coordinator.ex:1043` | ✅ |
| `cached_content_token_count` in responses | `types/response/generate_content_response.ex:129` | ✅ |
| HTTP PATCH/DELETE methods | `lib/gemini/client/http.ex` | ✅ |
| Unit tests | `test/gemini/apis/context_cache_test.exs` | ✅ |
| Live API tests | `test/gemini/apis/context_cache_live_test.exs` | ✅ |

### What's Missing (Based on Python SDK Analysis)

| Feature | Python Reference | Priority |
|---------|------------------|----------|
| `system_instruction` in cache creation | `caches.py:99-106` | **HIGH** |
| `tools` in cache creation | `caches.py:108-116` | **MEDIUM** |
| `tool_config` in cache creation | `caches.py:118-123` | **MEDIUM** |
| File upload integration (`file_uri`) | `caches.py:283-297` | **HIGH** |
| `kms_key_name` for Vertex AI encryption | `caches.py:173-178` | **LOW** |
| Resource name normalization for Vertex AI | `_transformers.py:1016-1017` | **HIGH** |
| Top-level `Gemini.caches.*` API exposure | N/A | **MEDIUM** |
| `CachedContentUsageMetadata` full struct | `types.py:12321-12343` | **LOW** |
| Model version validation | Documentation | **LOW** |

---

## Python SDK Architecture Reference

### Key Files Analyzed

1. **`python-genai/google/genai/caches.py`** - Main caches module
   - `Caches` class with sync methods
   - `AsyncCaches` class with async methods
   - Separate converters for Gemini API (`_to_mldev`) vs Vertex AI (`_to_vertex`)

2. **`python-genai/google/genai/types.py`** - Type definitions
   - `CreateCachedContentConfig` (lines 12189-12240)
   - `CachedContent` (lines 12370-12399)
   - `CachedContentUsageMetadata` (lines 12321-12343)

3. **`python-genai/google/genai/_transformers.py`** - Resource name handling
   - `t_cached_content_name()` - Normalizes cache names for both APIs
   - `t_caches_model()` - Normalizes model names for cache creation

### Critical Python Patterns to Replicate

```python
# Python CreateCachedContentConfig supports:
config = {
    'display_name': 'My Cache',
    'contents': [...],
    'system_instruction': 'You are an expert...',  # <-- MISSING
    'tools': [...],                                 # <-- MISSING
    'tool_config': {...},                           # <-- MISSING
    'ttl': '3600s',
    'expire_time': datetime,
    'kms_key_name': 'projects/...'                  # <-- MISSING (Vertex only)
}

# Python resource name normalization:
# Input: 'cachedContents/123' (for Gemini API)
# Input: 'projects/P/locations/L/cachedContents/123' (for Vertex AI)
# The SDK auto-expands short names to full resource names for Vertex
```

---

## Implementation Plan

### Phase 1: Core Feature Parity (HIGH Priority)

#### 1.1 Add `system_instruction` Support

**File:** `lib/gemini/apis/context_cache.ex`

**Changes:**
```elixir
# Update cache_opts type
@type cache_opts :: [
  display_name: String.t(),
  model: String.t(),
  ttl: non_neg_integer(),
  expire_time: DateTime.t(),
  system_instruction: String.t() | Content.t()  # <-- NEW
]

# Update create/2 to handle system_instruction
def create(contents, opts \\ []) when is_list(contents) do
  # ... existing code ...

  request_body =
    %{
      model: full_model_name,
      displayName: display_name,
      contents: formatted_contents
    }
    |> Map.merge(ttl_spec)
    |> maybe_add_system_instruction(opts)  # <-- NEW
  # ...
end

defp maybe_add_system_instruction(map, opts) do
  case Keyword.get(opts, :system_instruction) do
    nil -> map
    instruction when is_binary(instruction) ->
      Map.put(map, :systemInstruction, %{
        role: "user",
        parts: [%{text: instruction}]
      })
    %Content{} = content ->
      Map.put(map, :systemInstruction, format_content(content))
  end
end
```

**Tests to Add:**
- `test/gemini/apis/context_cache_test.exs` - Unit tests for system_instruction formatting
- `test/gemini/apis/context_cache_live_test.exs` - Live API test with system_instruction

#### 1.2 Add File URI Support (fileData)

**File:** `lib/gemini/apis/context_cache.ex`

**Changes:**
```elixir
# Update format_parts/1 to handle file_data
defp format_parts(parts) when is_list(parts) do
  Enum.map(parts, fn
    # ... existing handlers ...

    # NEW: Handle file_data (for uploaded files)
    %Gemini.Types.Part{file_data: %{file_uri: uri, mime_type: mime}} ->
      %{fileData: %{fileUri: uri, mimeType: mime}}

    %{file_data: %{file_uri: uri, mime_type: mime}} ->
      %{fileData: %{fileUri: uri, mimeType: mime}}

    # NEW: Handle file reference by name
    %{file_uri: uri} when is_binary(uri) ->
      %{fileData: %{fileUri: uri}}

    other -> other
  end)
end
```

#### 1.3 Resource Name Normalization for Vertex AI

**File:** `lib/gemini/apis/context_cache.ex` (or new `lib/gemini/utils/resource_names.ex`)

**Changes:**
```elixir
defmodule Gemini.Utils.ResourceNames do
  @moduledoc """
  Utilities for normalizing Google Cloud resource names.
  """

  @doc """
  Normalizes a cached content name to the full resource path.

  For Gemini API: "cachedContents/abc123" (unchanged)
  For Vertex AI: "projects/P/locations/L/cachedContents/abc123" (expanded)
  """
  @spec normalize_cached_content_name(String.t(), keyword()) :: String.t()
  def normalize_cached_content_name(name, opts \\ []) do
    auth_type = Keyword.get(opts, :auth, :gemini)

    cond do
      # Already fully qualified for Vertex
      String.starts_with?(name, "projects/") ->
        name

      # Short form for Vertex - needs expansion
      auth_type == :vertex_ai and String.starts_with?(name, "cachedContents/") ->
        project = Keyword.get(opts, :project_id) || get_project_id()
        location = Keyword.get(opts, :location) || get_location()
        "projects/#{project}/locations/#{location}/#{name}"

      # Just the ID for Vertex
      auth_type == :vertex_ai and not String.contains?(name, "/") ->
        project = Keyword.get(opts, :project_id) || get_project_id()
        location = Keyword.get(opts, :location) || get_location()
        "projects/#{project}/locations/#{location}/cachedContents/#{name}"

      # Gemini API - ensure prefix
      not String.starts_with?(name, "cachedContents/") ->
        "cachedContents/#{name}"

      true ->
        name
    end
  end

  @doc """
  Normalizes a model name for cache creation.

  For Vertex AI, must include full project path.
  """
  @spec normalize_cache_model_name(String.t(), keyword()) :: String.t()
  def normalize_cache_model_name(model, opts \\ []) do
    auth_type = Keyword.get(opts, :auth, :gemini)

    cond do
      # Already fully qualified
      String.starts_with?(model, "projects/") ->
        model

      # Vertex AI with models/ prefix
      auth_type == :vertex_ai and String.starts_with?(model, "models/") ->
        project = Keyword.get(opts, :project_id) || get_project_id()
        location = Keyword.get(opts, :location) || get_location()
        "projects/#{project}/locations/#{location}/publishers/google/#{model}"

      # Vertex AI with publishers/ prefix
      auth_type == :vertex_ai and String.starts_with?(model, "publishers/") ->
        project = Keyword.get(opts, :project_id) || get_project_id()
        location = Keyword.get(opts, :location) || get_location()
        "projects/#{project}/locations/#{location}/#{model}"

      # Gemini API - add models/ prefix if missing
      not String.starts_with?(model, "models/") ->
        "models/#{model}"

      true ->
        model
    end
  end
end
```

### Phase 2: Extended Feature Parity (MEDIUM Priority)

#### 2.1 Add Tools Support

**File:** `lib/gemini/apis/context_cache.ex`

```elixir
@type cache_opts :: [
  # ... existing ...
  tools: [Tool.t()],           # <-- NEW
  tool_config: ToolConfig.t()  # <-- NEW
]

defp maybe_add_tools(map, opts) do
  case Keyword.get(opts, :tools) do
    nil -> map
    tools when is_list(tools) ->
      Map.put(map, :tools, Enum.map(tools, &format_tool/1))
  end
end

defp maybe_add_tool_config(map, opts) do
  case Keyword.get(opts, :tool_config) do
    nil -> map
    config -> Map.put(map, :toolConfig, format_tool_config(config))
  end
end
```

#### 2.2 Top-Level API Exposure

**File:** `lib/gemini.ex`

```elixir
# Add to existing module

@doc """
Create a cached content for reuse across multiple requests.

## Examples

    {:ok, cache} = Gemini.create_cache(
      [Content.text("Large document...")],
      display_name: "My Cache",
      model: "gemini-2.0-flash-001",
      system_instruction: "You are an expert analyst.",
      ttl: 3600
    )

    # Use in subsequent requests
    {:ok, response} = Gemini.generate("Summarize the document",
      cached_content: cache.name
    )
"""
defdelegate create_cache(contents, opts \\ []), to: Gemini.APIs.ContextCache, as: :create

@doc "List all cached contents."
defdelegate list_caches(opts \\ []), to: Gemini.APIs.ContextCache, as: :list

@doc "Get a specific cached content by name."
defdelegate get_cache(name, opts \\ []), to: Gemini.APIs.ContextCache, as: :get

@doc "Update cache TTL."
defdelegate update_cache(name, opts), to: Gemini.APIs.ContextCache, as: :update

@doc "Delete a cached content."
defdelegate delete_cache(name, opts \\ []), to: Gemini.APIs.ContextCache, as: :delete
```

#### 2.3 Enhanced Usage Metadata Type

**File:** `lib/gemini/types/cached_content_usage_metadata.ex` (NEW)

```elixir
defmodule Gemini.Types.CachedContentUsageMetadata do
  @moduledoc """
  Metadata on the usage of cached content.
  """

  use TypedStruct

  typedstruct do
    @typedoc "Cached content usage metadata"

    field :total_token_count, integer() | nil
    field :cached_content_token_count, integer() | nil
    # Vertex AI only fields:
    field :audio_duration_seconds, integer() | nil
    field :image_count, integer() | nil
    field :text_count, integer() | nil
    field :video_duration_seconds, integer() | nil
  end
end
```

### Phase 3: Advanced Features (LOW Priority)

#### 3.1 KMS Key Support (Vertex AI Only)

```elixir
@type cache_opts :: [
  # ... existing ...
  kms_key_name: String.t()  # <-- NEW (Vertex AI only)
]

defp maybe_add_kms_key(map, opts) do
  case Keyword.get(opts, :kms_key_name) do
    nil -> map
    key_name ->
      # Validate we're using Vertex AI
      if Keyword.get(opts, :auth) == :vertex_ai do
        Map.put(map, :encryptionSpec, %{kmsKeyName: key_name})
      else
        raise ArgumentError, "kms_key_name is only supported with Vertex AI authentication"
      end
  end
end
```

#### 3.2 Model Version Validation

```elixir
@valid_cache_models [
  "gemini-2.0-flash-001",
  "gemini-2.0-flash-lite-001",
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-3-pro-preview"
]

defp validate_cache_model(model) do
  base_model = model |> String.replace_prefix("models/", "")

  unless Enum.any?(@valid_cache_models, &String.starts_with?(base_model, &1)) do
    Logger.warning(
      "Model #{model} may not support explicit caching. " <>
      "Use models with explicit version suffixes like 'gemini-2.0-flash-001'"
    )
  end

  :ok
end
```

---

## File Changes Summary

| File | Action | Changes |
|------|--------|---------|
| `lib/gemini/apis/context_cache.ex` | MODIFY | Add system_instruction, tools, tool_config, file_data support |
| `lib/gemini/utils/resource_names.ex` | CREATE | Resource name normalization utilities |
| `lib/gemini/types/cached_content_usage_metadata.ex` | CREATE | Full usage metadata type |
| `lib/gemini.ex` | MODIFY | Add `create_cache/2`, `list_caches/1`, etc. delegations |
| `test/gemini/apis/context_cache_test.exs` | MODIFY | Add tests for new features |
| `test/gemini/apis/context_cache_live_test.exs` | MODIFY | Add live tests for new features |

---

## Testing Strategy

### Unit Tests

```elixir
# New tests for context_cache_test.exs

describe "create/2 with system_instruction" do
  test "accepts string system_instruction" do
    # Test formatting
  end

  test "accepts Content struct system_instruction" do
    # Test formatting
  end
end

describe "create/2 with file_data" do
  test "accepts file_uri in parts" do
    # Test fileData formatting
  end
end

describe "resource name normalization" do
  test "expands short names for Vertex AI" do
    # Test normalization
  end

  test "keeps Gemini API names unchanged" do
    # Test pass-through
  end
end
```

### Live API Tests

```elixir
# New tests for context_cache_live_test.exs

describe "caching with system_instruction" do
  @tag :live_api
  test "creates cache with system_instruction and uses it" do
    cache = create_cache_with_system_instruction()
    response = generate_with_cache(cache.name)
    # Verify system instruction influenced the response
  end
end
```

---

## Migration Notes

### Backward Compatibility

All changes are **additive** - existing code will continue to work:

```elixir
# This still works (current API)
ContextCache.create(contents, display_name: "My Cache")

# New optional features
ContextCache.create(contents,
  display_name: "My Cache",
  system_instruction: "You are an expert."  # NEW - optional
)
```

### Breaking Changes

**None** - all new parameters are optional.

---

## Estimated Effort

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1.1 (system_instruction) | 2 hours | None |
| Phase 1.2 (file_data) | 1 hour | None |
| Phase 1.3 (resource names) | 3 hours | Multi-auth coordinator |
| Phase 2.1 (tools) | 2 hours | Phase 1 |
| Phase 2.2 (top-level API) | 1 hour | Phase 1 |
| Phase 2.3 (usage metadata) | 1 hour | None |
| Phase 3 (advanced) | 2 hours | Phase 1-2 |
| Testing | 3 hours | All phases |

**Total: ~15 hours**

---

## Success Criteria

1. ✅ All Python SDK cache creation options are supported
2. ✅ Resource names auto-expand correctly for Vertex AI
3. ✅ Top-level `Gemini.create_cache/2` API available
4. ✅ All existing tests pass
5. ✅ New tests for system_instruction, tools, file_data
6. ✅ Live API tests verify real functionality
7. ✅ Zero compilation warnings
8. ✅ Documentation updated

---

## References

- Python SDK: `python-genai/google/genai/caches.py`
- Python Types: `python-genai/google/genai/types.py` (lines 12189-12420)
- Python Transformers: `python-genai/google/genai/_transformers.py` (lines 1016-1017)
- Current Elixir: `lib/gemini/apis/context_cache.ex`
- API Docs: https://ai.google.dev/gemini-api/docs/caching
