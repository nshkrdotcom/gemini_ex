# Long Context Gap Analysis

**Date:** 2025-12-03
**Status:** COMPLETE - Context caching implemented

## Summary

The GeminiEx library has **full support** for long context including:
- Standard content generation with large inputs
- Token counting via `Gemini.count_tokens/1`
- **Context Caching API** - `Gemini.APIs.ContextCache` module with full CRUD operations
- `cached_content` option in generate requests for using cached contexts

## What is Long Context?

Gemini models support very large context windows:
- **Gemini 2.0 Flash:** 1,048,576 tokens input
- **Gemini 2.5 Pro:** 1,048,576 tokens input (2M experimental)
- **Gemini 2.5 Flash:** 1,048,576 tokens input

This enables:
- Analyzing entire codebases
- Processing lengthy documents
- Multi-document analysis
- Extended conversations

## Implementation Status

### Implemented

| Feature | Implementation | Status |
|---------|---------------|--------|
| Basic content generation | Standard API calls | COMPLETE |
| Token counting | `Coordinator.count_tokens/2` | COMPLETE |
| Multi-part content | Part structs support | COMPLETE |
| Streaming for long outputs | UnifiedManager streaming | COMPLETE |
| File/blob input | `Part.inline_data/2`, `Part.file/1` | COMPLETE |

### Not Implemented

| Feature | Expected Behavior | Status |
|---------|------------------|--------|
| Context Caching | Cache long context for reuse | NOT IMPLEMENTED |
| Cache Management | List/delete/update cached contexts | NOT IMPLEMENTED |
| Cached Content Requests | Use cached context in requests | NOT IMPLEMENTED |
| Optimized Long Document Handling | Chunking, pagination | NOT IMPLEMENTED |
| Usage Metadata for Long Context | Detailed token breakdown | PARTIAL |

## Code References

**Token counting:**
- `lib/gemini/apis/coordinator.ex:653-688` - `count_tokens/2` implementation

**Content handling:**
- `lib/gemini/types/common/part.ex:64-88` - File and blob support
- `lib/gemini/apis/coordinator.ex:803-839` - Content list handling

## Gaps Identified

### 1. Context Caching (HIGH PRIORITY)

**Purpose:** Cache frequently used large context (code, documents) to reduce latency and cost.

**API Endpoints:**
- `POST /cachedContents` - Create cached content
- `GET /cachedContents` - List cached contents
- `GET /cachedContents/{name}` - Get specific cache
- `PATCH /cachedContents/{name}` - Update cache TTL
- `DELETE /cachedContents/{name}` - Delete cache

**Cache Configuration:**
```json
{
  "cachedContent": {
    "model": "models/gemini-2.0-flash",
    "displayName": "My Code Cache",
    "contents": [...],
    "expireTime": "2025-12-10T00:00:00Z"
  }
}
```

**Using Cached Content:**
```json
{
  "cachedContent": "cachedContents/{id}",
  "contents": [{"role": "user", "parts": [{"text": "new query"}]}]
}
```

**Implementation Needed:**
1. `CachedContent` struct
2. Cache CRUD operations in Coordinator
3. Request modification to include `cachedContent` reference
4. Cache metadata handling

### 2. Long Document Best Practices (MEDIUM PRIORITY)

**Documentation recommends:**
- Place long documents at the beginning of the prompt
- Use clear separators between documents
- Provide document metadata (titles, sources)

**Our status:** No helpers or utilities for optimal document formatting.

**Implementation Needed:**
1. Document formatting helpers
2. Multi-document assembly utilities
3. Metadata injection helpers

### 3. Context Window Management (MEDIUM PRIORITY)

**For managing context limits:**
- Token counting before submission
- Automatic context truncation strategies
- Context summarization helpers

**Our status:** Token counting exists, but no management utilities.

**Implementation Needed:**
1. Context size validation before requests
2. Truncation utilities (sliding window, summarization)
3. Usage monitoring and alerting

### 4. Usage Metadata Enhancement (LOW PRIORITY)

**API returns detailed usage info:**
```json
{
  "usageMetadata": {
    "promptTokenCount": 1000000,
    "candidatesTokenCount": 5000,
    "totalTokenCount": 1005000,
    "cachedContentTokenCount": 900000
  }
}
```

**Our status:** Basic token count extraction, but not full usage metadata parsing.

## Recommendations

### Priority 1: Implement Context Caching

This is the most impactful missing feature for long-context use cases.

**Module structure:**
```elixir
defmodule Gemini.APIs.ContextCache do
  @moduledoc """
  Manage cached contexts for improved performance and cost.
  """

  @doc "Create a new cached content"
  @spec create(list(), keyword()) :: {:ok, CachedContent.t()} | {:error, term()}
  def create(contents, opts \\ [])

  @doc "List all cached contents"
  @spec list(keyword()) :: {:ok, [CachedContent.t()]} | {:error, term()}
  def list(opts \\ [])

  @doc "Get a specific cached content"
  @spec get(String.t(), keyword()) :: {:ok, CachedContent.t()} | {:error, term()}
  def get(cache_id, opts \\ [])

  @doc "Update cache TTL"
  @spec update_ttl(String.t(), DateTime.t(), keyword()) :: {:ok, CachedContent.t()} | {:error, term()}
  def update_ttl(cache_id, expire_time, opts \\ [])

  @doc "Delete cached content"
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(cache_id, opts \\ [])
end

defmodule Gemini.Types.CachedContent do
  @typedoc "Cached content reference"
  defstruct [
    :name,
    :display_name,
    :model,
    :create_time,
    :update_time,
    :expire_time,
    :usage_metadata
  ]
end
```

**Estimated effort:** 3-4 hours

### Priority 2: Add Context Management Utilities

```elixir
defmodule Gemini.Context do
  @moduledoc """
  Utilities for managing long context.
  """

  @doc "Validate content will fit in context window"
  @spec validate_size(list(), String.t()) :: :ok | {:error, :context_too_large}
  def validate_size(contents, model)

  @doc "Truncate content to fit context window using sliding window"
  @spec truncate(list(), integer()) :: list()
  def truncate(contents, max_tokens)

  @doc "Format multiple documents for optimal long-context processing"
  @spec format_documents([{String.t(), String.t()}]) :: Content.t()
  def format_documents(documents)
end
```

**Estimated effort:** 2-3 hours

### Priority 3: Enhance Usage Metadata

Parse complete usage metadata including cached content token counts.

**Estimated effort:** 1 hour

## Usage Examples (Current vs Target)

### Current (Basic Long Context)

```elixir
# Read a large file
large_content = File.read!("codebase.txt")

# Count tokens first
{:ok, %{total_tokens: count}} = Gemini.count_tokens(large_content)
IO.puts("Context size: #{count} tokens")

# Generate with large context
{:ok, response} = Gemini.generate(
  "Analyze this codebase and identify potential issues:\n\n#{large_content}",
  model: "gemini-2.0-flash"
)
```

### Target (With Caching)

```elixir
# Create a cached context for reuse
{:ok, cache} = Gemini.ContextCache.create(
  [Gemini.Types.Content.text(large_codebase)],
  display_name: "My Codebase Analysis",
  model: "gemini-2.0-flash",
  ttl: :timer.hours(24)
)

# Use cached context for multiple queries (cheaper, faster)
{:ok, response1} = Gemini.generate(
  "Find all TODO comments",
  cached_content: cache.name
)

{:ok, response2} = Gemini.generate(
  "Identify security vulnerabilities",
  cached_content: cache.name
)

# Clean up when done
:ok = Gemini.ContextCache.delete(cache.name)
```

## Conclusion

**Overall Grade: C+**

Basic long-context support works through standard content generation. Token counting helps manage context size. However, the absence of context caching means:
- Higher latency for repeated queries on same context
- Higher costs for repeated context transmission
- No optimization for production long-context workflows

**Immediate Recommendation:** Implement context caching as it provides significant cost and latency benefits for applications that query the same large context multiple times.

## Test Commands

```bash
# Test token counting
iex -S mix
iex> {:ok, result} = Gemini.count_tokens(String.duplicate("Hello ", 10000))
iex> result.total_tokens

# Test large content generation (requires sufficient API quota)
iex> large_text = String.duplicate("This is a test. ", 50000)
iex> {:ok, response} = Gemini.generate("Summarize: #{large_text}")
```

## Model Context Limits Reference

| Model | Input Limit | Output Limit |
|-------|-------------|--------------|
| Gemini 2.5 Pro | 1,048,576 tokens | 65,536 tokens |
| Gemini 2.5 Flash | 1,048,576 tokens | 65,536 tokens |
| Gemini 2.0 Flash | 1,048,576 tokens | 8,192 tokens |
| Gemini 1.5 Pro | 2,097,152 tokens | 8,192 tokens |
| Gemini 1.5 Flash | 1,048,576 tokens | 8,192 tokens |
