# Gap Analysis: Embeddings & Tokenization

## Executive Summary

**Overall Gap Score: 65% feature parity**
- Embeddings API: 20% complete (types exist, no API module)
- Token Counting: 70% complete (API works, no local tokenization)
- Local Tokenization: 0% complete (heuristic estimation only)

## Feature Comparison Table

| Feature | Python genai | Elixir | Gap Level |
|---------|-------------|--------|-----------|
| **Embeddings API** | | | |
| Single embedding request | ✅ `models.embed_content()` | ❌ No API module | CRITICAL |
| Batch embedding request | ✅ Supported | ❌ No API module | CRITICAL |
| Async embedding | ✅ `aio.models.embed_content()` | ❌ No async | CRITICAL |
| Gemini API endpoint | ✅ `:batchEmbedContents` | ❌ Not implemented | CRITICAL |
| Vertex AI endpoint | ✅ `:predict` | ❌ Not implemented | CRITICAL |
| EmbedContentConfig | ✅ Full support | ⚠️ Types exist | MEDIUM |
| Task type specification | ✅ Yes | ✅ Types defined | LOW |
| **Token Counting** | | | |
| API token counting | ✅ `models.compute_tokens()` | ✅ `Tokens.count()` | CLOSED |
| Batch token counting | ✅ Parallel | ✅ `count_batch()` | CLOSED |
| Token budget checking | ✅ Integrated | ✅ `check_fit()` | CLOSED |
| Local tokenization | ✅ `LocalTokenizer` | ❌ No equivalent | CRITICAL |
| Offline counting | ✅ Full support | ❌ Heuristic only | CRITICAL |
| Token detail breakdown | ✅ `compute_tokens()` | ❌ Not available | MEDIUM |
| Schema/tool counting | ✅ Supported | ❌ Not supported | MEDIUM |

## Python Embeddings Implementation

### models.py - embed_content()

```python
def embed_content(
    self,
    *,
    model: str,
    contents: Union[ContentListUnion, ContentListUnionDict],
    config: Optional[EmbedContentConfigOrDict] = None,
) -> EmbedContentResponse:
    """Calculates embeddings for the given contents."""
```

**Key Capabilities:**
- Single method for single and batch embeddings
- Automatic Gemini vs Vertex AI detection
- Response format conversion
- Full HttpOptions support

### Configuration Options

```python
EmbedContentConfig:
  output_dimensionality: int  # Embedding size
  title: str                  # For retrieval tasks
  task_type: TaskType         # RETRIEVAL_QUERY, SEMANTIC_SIMILARITY, etc.
  mime_type: str              # Content type
  auto_truncate: bool         # Truncate long inputs
```

## Elixir Embeddings Status

### Existing Types (Complete)

```elixir
# Request types
EmbedContentRequest
BatchEmbedContentsRequest
InputEmbedContentConfig

# Response types
EmbedContentResponse
BatchEmbedContentsResponse
ContentEmbedding
```

### Missing API Module

```elixir
# These don't exist yet!
Gemini.embed_content("Hello")
Gemini.batch_embed_contents(["Text 1", "Text 2"])

# No coordinator integration for embedding endpoints
```

## Python Local Tokenization

### LocalTokenizer Architecture

```
LocalTokenizer
  ├── __init__(model_name)
  │   ├── get_tokenizer_name() -> "gemma3"
  │   ├── load_model_proto() -> SentencePiece proto
  │   └── get_sentencepiece() -> SentencePieceProcessor
  │
  ├── count_tokens(contents, config)
  │   └── _TextsAccumulator processes content tree
  │
  └── compute_tokens(contents)
      └── Returns token IDs and piece bytes
```

### Key Features

1. **SentencePiece Integration**
   - Direct binding to `sentencepiece` library
   - Byte-level tokenization
   - Token ID and piece extraction

2. **Model Registry**
   ```python
   _GEMINI_MODELS_TO_TOKENIZER_NAMES = {
       "gemini-2.5-pro": "gemma3",
       "gemini-2.5-flash": "gemma3",
   }
   ```

3. **Model Caching**
   - SHA256 verification
   - Temporary directory caching
   - Auto-download from GitHub

4. **Detailed Output**
   ```python
   ComputeTokensResult(
       tokens_info=[
           TokensInfo(
               token_ids=[279, 329, 1313],
               tokens=[b' What', b' is', b' your'],
               role='user'
           )
       ]
   )
   ```

## Elixir Token Implementation

### Gemini.APIs.Tokens (465 lines)

**Implemented:**
```elixir
Tokens.count("Hello, world!")
# => {:ok, %CountTokensResponse{total_tokens: 3}}

Tokens.count_batch(["Text 1", "Text 2"], max_concurrency: 5)
# => {:ok, [%CountTokensResponse{...}, ...]}

Tokens.estimate("Long text...")  # Heuristic only
# => {:ok, 42}

Tokens.check_fit(content, "gemini-2.5-pro")
# => {:ok, %{fits: true, tokens: 100, limit: 1000000}}
```

**Missing:**
- No local tokenization
- Heuristic: `word_count * 1.3` or `char_count / 4.0`
- No token detail breakdown
- No schema/tool counting

## Local Tokenization Options

### Option 1: SentencePiece Binding (Recommended)
**Effort:** 3-5 weeks

**Pros:**
- Exact feature parity
- Accurate tokenization
- Community-backed

**Cons:**
- Rust/C FFI required
- Complex dependencies
- Model caching needed

### Option 2: Python Bridge (Quick)
**Effort:** 1-2 weeks

**Pros:**
- Reuse existing code
- Fast implementation
- Proven reliability

**Cons:**
- Python runtime required
- Cross-process overhead
- Production complexity

### Option 3: Pure Elixir
**Effort:** 8-10 weeks

**Pros:**
- No external dependencies
- Full control
- Native solution

**Cons:**
- Complex algorithm
- Maintenance burden
- Lower performance

### Option 4: Accept Limitation (Status Quo)
**Effort:** None

**Pros:**
- No cost
- Works for most cases

**Cons:**
- Inaccurate budgeting
- Edge case failures
- Production risk

## Recommendations

### Phase 1: Implement Embedding API (1-2 weeks)
**Priority:** CRITICAL

```elixir
defmodule Gemini.APIs.Embeddings do
  def embed_content(text, opts \\ [])
  def batch_embed_contents(texts, opts \\ [])
end
```

### Phase 2: Add Local Tokenization (3-8 weeks)
**Priority:** HIGH

**Recommended:** Python Bridge initially, then native SentencePiece

```elixir
defmodule Gemini.LocalTokenizer do
  def new(model_name)
  def count_tokens(contents, config)
  def compute_tokens(contents)
end
```

### Phase 3: Enhance Token APIs (1-2 weeks)
**Priority:** MEDIUM

- Token detail breakdown
- Schema/tool counting
- Proactive budget enforcement

### Phase 4: Native Tokenization (Future)
**Priority:** LOW

- Native Rust/FFI binding
- Performance optimization

## API Module Completeness

| Module | Python | Elixir | Status |
|--------|--------|--------|--------|
| Embeddings API | ✅ | ❌ | CRITICAL GAP |
| Token API | ✅ | ✅ | CLOSED |
| Local Tokenizer | ✅ | ❌ | CRITICAL GAP |
| Batch Operations | ✅ | ✅ (Tokens) | PARTIAL |
| Async Support | ✅ | ❌ | MEDIUM GAP |

## Conclusion

The Elixir implementation has **strong type safety** but lacks **functional completeness**:

1. **Embedding API calls** (0% implemented) - CRITICAL
2. **Local tokenization** (0%, heuristic only) - CRITICAL
3. **Advanced token analysis** (basic only) - MEDIUM

**Estimated Effort:** 4-12 weeks for full parity, depending on tokenization approach
