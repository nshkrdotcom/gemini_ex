# Gemini Embeddings - Complete Implementation Plan

## Executive Summary

This document outlines the plan to fully implement all features from the official Gemini Embeddings specification (GEMINI-API-07-EMBEDDING_20251014.md) for the Gemini Unified Implementation.

**Current Status:** ✅ **Core features implemented and working**
- Basic `embedContent` and `batchEmbedContents` operations
- All task types supported
- Multi-auth coordination (Gemini API + Vertex AI)
- Output dimensionality control
- Cosine similarity calculation

**Gap Analysis:** Additional features needed for complete spec compliance

---

## Current Implementation Status

### ✅ Already Implemented

1. **Core API Operations** (`lib/gemini/apis/coordinator.ex:261-377`)
   - ✅ `embed_content/2` - Single text embedding
   - ✅ `batch_embed_contents/2` - Batch embedding
   - ✅ Multi-auth support (Gemini API and Vertex AI)
   - ✅ Model selection (`gemini-embedding-001`, `text-embedding-004`)

2. **Type System** (`lib/gemini/types/`)
   - ✅ `EmbedContentRequest` - Single embedding request
   - ✅ `BatchEmbedContentsRequest` - Batch request
   - ✅ `EmbedContentResponse` - Response structure
   - ✅ `ContentEmbedding` - Embedding vector with values
   - ✅ `BatchEmbedContentsResponse` - Batch response

3. **Task Types** (All 8 supported)
   - ✅ `RETRIEVAL_QUERY`
   - ✅ `RETRIEVAL_DOCUMENT`
   - ✅ `SEMANTIC_SIMILARITY`
   - ✅ `CLASSIFICATION`
   - ✅ `CLUSTERING`
   - ✅ `QUESTION_ANSWERING`
   - ✅ `FACT_VERIFICATION`
   - ✅ `CODE_RETRIEVAL_QUERY`

4. **Dimensionality Control**
   - ✅ `output_dimensionality` parameter support
   - ✅ Works with newer models (text-embedding-004)

5. **Similarity Metrics**
   - ✅ `ContentEmbedding.cosine_similarity/2`

6. **Examples & Documentation**
   - ✅ `examples/simple_embedding.exs` - Basic usage
   - ✅ `examples/embedding_demo.exs` - Comprehensive demo
   - ✅ `examples/EMBEDDINGS.md` - Reference guide

---

## Gap Analysis - Features Needed

### 1. ⚠️ **Embedding Normalization** (CRITICAL for quality)

**Spec Reference:** Lines 126-147

**Issue:** The spec states that embeddings with dimensions other than 3072 need to be normalized for accurate semantic similarity.

**Current State:** ❌ Not implemented

**Required Implementation:**
```elixir
# Add to ContentEmbedding module
@spec normalize(t()) :: t()
def normalize(%__MODULE__{values: values} = embedding) do
  magnitude = :math.sqrt(Enum.map(values, &(&1 * &1)) |> Enum.sum())

  if magnitude == 0 do
    embedding
  else
    normalized_values = Enum.map(values, &(&1 / magnitude))
    %__MODULE__{values: normalized_values}
  end
end

@spec norm(t()) :: float()
def norm(%__MODULE__{values: values}) do
  :math.sqrt(Enum.map(values, &(&1 * &1)) |> Enum.sum())
end
```

**Priority:** HIGH
**Effort:** 2 hours
**Files to modify:**
- `lib/gemini/types/response/content_embedding.ex`
- Add tests in `test/gemini/types/response/content_embedding_test.exs`

---

### 2. ⚠️ **Title Parameter Support** (For retrieval documents)

**Spec Reference:** Lines 94-95

**Issue:** Title parameter improves quality for RETRIEVAL_DOCUMENT tasks but may not be fully utilized.

**Current State:** ✅ Partially implemented (parameter exists)

**Enhancement Needed:**
- Add documentation emphasizing title importance
- Create example showing quality improvement with/without title
- Validate title is only used with RETRIEVAL_DOCUMENT task type

**Priority:** MEDIUM
**Effort:** 1 hour
**Files to modify:**
- `examples/EMBEDDINGS.md` - Enhanced documentation
- `examples/embedding_demo.exs` - Add title comparison example

---

### 3. ⚠️ **Dimension Quality Validation** (Helper warnings)

**Spec Reference:** Lines 103, 149-158 (MTEB scores)

**Issue:** Spec recommends specific dimensions (768, 1536, 3072) for best quality/performance.

**Current State:** ❌ No validation or warnings

**Required Implementation:**
```elixir
# Add to EmbedContentRequest
@recommended_dimensions [128, 256, 512, 768, 1536, 2048, 3072]

@spec validate_dimensionality(pos_integer() | nil) :: :ok | {:warning, String.t()}
defp validate_dimensionality(nil), do: :ok
defp validate_dimensionality(dim) when dim in @recommended_dimensions, do: :ok
defp validate_dimensionality(dim) do
  nearest = Enum.min_by(@recommended_dimensions, &abs(&1 - dim))
  {:warning, "Dimension #{dim} not recommended. Consider #{nearest} for better quality."}
end
```

**Priority:** LOW
**Effort:** 1 hour
**Files to modify:**
- `lib/gemini/types/request/embed_content_request.ex`

---

### 4. ⚠️ **Enhanced Distance Metrics**

**Spec Reference:** Line 59 (cosine similarity focus)

**Current State:** ✅ Cosine similarity implemented

**Enhancement Needed:** Add other common distance metrics

**Required Implementation:**
```elixir
# Add to ContentEmbedding module

@spec euclidean_distance(t(), t()) :: float() | {:error, String.t()}
def euclidean_distance(%__MODULE__{values: v1}, %__MODULE__{values: v2}) do
  if length(v1) != length(v2) do
    {:error, "Embeddings must have the same dimensionality"}
  else
    Enum.zip(v1, v2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end
end

@spec dot_product(t(), t()) :: float() | {:error, String.t()}
def dot_product(%__MODULE__{values: v1}, %__MODULE__{values: v2}) do
  if length(v1) != length(v2) do
    {:error, "Embeddings must have the same dimensionality"}
  else
    Enum.zip(v1, v2)
    |> Enum.map(fn {a, b} -> a * b end)
    |> Enum.sum()
  end
end
```

**Priority:** MEDIUM
**Effort:** 2 hours
**Files to modify:**
- `lib/gemini/types/response/content_embedding.ex`

---

### 5. ⚠️ **MRL (Matryoshka Representation Learning) Documentation**

**Spec Reference:** Lines 100-124

**Current State:** ❌ No documentation on MRL capabilities

**Required Documentation:**
- Explain MRL technique and benefits
- Show MTEB benchmark scores for different dimensions
- Document truncation vs. re-embedding behavior
- Best practices for dimension selection

**Priority:** MEDIUM
**Effort:** 2 hours
**Files to modify:**
- `examples/EMBEDDINGS.md` - Add MRL section
- Create `examples/mrl_dimensions_demo.exs` - Show quality/size tradeoffs

---

### 6. ⚠️ **Advanced Use Case Examples**

**Spec Reference:** Lines 160-174

**Current State:** ✅ Basic examples exist

**Enhancement Needed:** Create real-world use case examples

**Required Examples:**

#### A. **RAG System Example** (`examples/use_cases/rag_demo.exs`)
```elixir
# Complete RAG pipeline:
# 1. Embed knowledge base documents
# 2. Embed user query
# 3. Find most relevant documents
# 4. Use documents as context for generation
```

#### B. **Search Reranking Example** (`examples/use_cases/search_reranking.exs`)
```elixir
# Rerank initial search results by semantic similarity
```

#### C. **Anomaly Detection Example** (`examples/use_cases/anomaly_detection.exs`)
```elixir
# Identify outliers in embedding space
```

#### D. **Classification Example** (`examples/use_cases/classification.exs`)
```elixir
# K-NN classification using embeddings
```

#### E. **Clustering Example** (`examples/use_cases/clustering_visualization.exs`)
```elixir
# Hierarchical clustering and visualization
```

**Priority:** MEDIUM
**Effort:** 8 hours (1-2 hours per example)
**Files to create:**
- `examples/use_cases/rag_demo.exs`
- `examples/use_cases/search_reranking.exs`
- `examples/use_cases/anomaly_detection.exs`
- `examples/use_cases/classification.exs`
- `examples/use_cases/clustering_visualization.exs`

---

### 7. ⚠️ **Semantic Similarity Example Matching Spec**

**Spec Reference:** Lines 57-85

**Current State:** ✅ Similarity calculation works, but output format differs

**Enhancement Needed:** Create example matching spec's exact output format

**Required Example:** (`examples/semantic_similarity_spec.exs`)
```elixir
# Replicate exact output from spec:
# Similarity between 'What is the meaning of life?' and 'What is the purpose of existence?': 0.9481
# Similarity between 'What is the meaning of life?' and 'How do I bake a cake?': 0.7471
# Similarity between 'What is the purpose of existence?' and 'How do I bake a cake?': 0.7371
```

**Priority:** LOW
**Effort:** 1 hour
**Files to create:**
- `examples/semantic_similarity_spec.exs`

---

### 8. ⚠️ **Batch API Integration Notes**

**Spec Reference:** Lines 202-203

**Current State:** ❌ No documentation on Batch API usage

**Enhancement Needed:**
- Document that `batch_embed_contents/2` is more efficient
- Add performance comparison (individual vs batch)
- Note 50% cost savings for batch processing
- Link to Batch API cookbook when available

**Priority:** LOW
**Effort:** 1 hour
**Files to modify:**
- `examples/EMBEDDINGS.md` - Add batch API section

---

### 9. ⚠️ **Comprehensive Test Suite**

**Current State:** ❌ Limited tests

**Required Test Coverage:**

#### A. **Unit Tests**
- `test/gemini/types/request/embed_content_request_test.exs`
  - Request building from text
  - Task type serialization
  - API map conversion

- `test/gemini/types/response/content_embedding_test.exs`
  - Normalization
  - Cosine similarity
  - Euclidean distance
  - Dot product
  - Edge cases (zero vectors, different dimensions)

#### B. **Integration Tests**
- `test/gemini/apis/coordinator_embedding_test.exs`
  - Single embedding
  - Batch embedding
  - Different models
  - Different task types
  - Dimension control
  - Error handling

#### C. **Live API Tests** (optional, requires API key)
- `test/live_embedding_test.exs`
  - Real API calls
  - Response validation
  - Quality checks

**Priority:** HIGH
**Effort:** 6 hours
**Files to create:**
- Multiple test files as listed above

---

### 10. ⚠️ **Model Version Support & Deprecation Notices**

**Spec Reference:** Lines 185-200, 211-212

**Current State:** ✅ Supports all current models

**Enhancement Needed:**
- Document model capabilities (dimensions, features)
- Add deprecation warnings for legacy models
- Document stable vs experimental models

**Required Documentation:**

| Model | Status | Default Dimensions | Max Dimensions | Task Types | MRL | Notes |
|-------|--------|-------------------|----------------|------------|-----|-------|
| `text-embedding-004` | ✅ Stable | 768 | 768 | All | Yes | Recommended |
| `gemini-embedding-001` | ✅ Stable | 3072 | 3072 | All | Yes | Legacy |
| `gemini-embedding-exp-03-07` | ⚠️ Experimental | 3072 | 3072 | All | Yes | Deprecating Oct 2025 |
| `embedding-001` | ⚠️ Deprecated | - | - | Limited | No | Use text-embedding-004 |
| `embedding-gecko-001` | ⚠️ Deprecated | - | - | Limited | No | Use text-embedding-004 |

**Priority:** MEDIUM
**Effort:** 2 hours
**Files to modify:**
- `examples/EMBEDDINGS.md` - Add model comparison table
- `lib/gemini/config.ex` - Add deprecation warnings (optional)

---

## Implementation Roadmap

### Phase 1: Critical Features (Priority: HIGH) - 10 hours

1. **Embedding Normalization** (2h)
   - Add `normalize/1` and `norm/1` to ContentEmbedding
   - Add tests
   - Update documentation

2. **Enhanced Distance Metrics** (2h)
   - Add `euclidean_distance/2` and `dot_product/2`
   - Add tests
   - Update examples

3. **Comprehensive Test Suite** (6h)
   - Unit tests for all types
   - Integration tests for coordinator
   - Live API tests (optional)

### Phase 2: Enhanced Documentation (Priority: MEDIUM) - 8 hours

4. **MRL Documentation** (2h)
   - Add MRL explanation to EMBEDDINGS.md
   - Create dimension comparison example
   - Document MTEB benchmarks

5. **Model Comparison & Deprecation** (2h)
   - Create model comparison table
   - Add deprecation notices
   - Document recommended models

6. **Title Parameter Enhancement** (1h)
   - Enhance documentation
   - Add comparison example

7. **Batch API Documentation** (1h)
   - Document efficiency benefits
   - Add performance comparison
   - Note cost savings

8. **Semantic Similarity Spec Example** (1h)
   - Match spec output format exactly

9. **Dimension Quality Validation** (1h)
   - Add validation helpers
   - Add warning system

### Phase 3: Advanced Examples (Priority: MEDIUM) - 8 hours

10. **RAG System Example** (2h)
11. **Search Reranking Example** (1.5h)
12. **Anomaly Detection Example** (1.5h)
13. **Classification Example** (1.5h)
14. **Clustering Visualization Example** (1.5h)

---

## Total Effort Estimate

- **Phase 1 (Critical):** 10 hours
- **Phase 2 (Documentation):** 8 hours
- **Phase 3 (Examples):** 8 hours
- **Total:** ~26 hours (~3-4 work days)

---

## Success Criteria

### Functional Requirements
- ✅ All API operations work correctly
- ✅ All task types supported
- ✅ Multi-auth coordination functional
- ✅ Dimension control working
- ✅ Distance metrics accurate

### Quality Requirements
- ✅ Zero compilation warnings
- ✅ 100% test coverage for core functions
- ✅ All live API tests passing
- ✅ Proper normalization for quality

### Documentation Requirements
- ✅ Complete API reference
- ✅ All use cases documented with examples
- ✅ MRL technique explained
- ✅ Model comparison table
- ✅ Best practices guide

### Spec Compliance
- ✅ All features from GEMINI-API-07-EMBEDDING_20251014.md implemented
- ✅ Examples match spec output format
- ✅ Recommended practices followed

---

## Risk Assessment

### Low Risk
- ✅ Core functionality already working
- ✅ Type system well-designed
- ✅ Multi-auth foundation solid

### Medium Risk
- ⚠️ Advanced examples may require additional dependencies
- ⚠️ Live API testing depends on quota/rate limits
- ⚠️ Clustering visualization may need charting library

### Mitigation Strategies
- Keep examples self-contained (no external dependencies)
- Make live tests optional with proper mocking
- Use ASCII art for simple visualizations

---

## Next Steps

1. **Immediate:** Implement Phase 1 (Critical Features)
   - Start with normalization (highest impact on quality)
   - Add distance metrics
   - Build comprehensive test suite

2. **Short-term:** Complete Phase 2 (Documentation)
   - Document MRL capabilities
   - Add model comparison table
   - Enhance existing docs

3. **Long-term:** Implement Phase 3 (Advanced Examples)
   - Build real-world use case examples
   - Create comprehensive cookbook

---

## Appendix: Current vs. Spec Feature Matrix

| Feature | Spec Requirement | Current Status | Gap | Priority |
|---------|-----------------|----------------|-----|----------|
| **Core Operations** |
| embedContent | Required | ✅ Implemented | None | - |
| batchEmbedContents | Required | ✅ Implemented | None | - |
| **Task Types** |
| All 8 task types | Required | ✅ Implemented | None | - |
| **Dimensionality** |
| output_dimensionality | Required | ✅ Implemented | None | - |
| MRL support | Documented | ✅ Supported | Documentation | MEDIUM |
| Dimension validation | Best practice | ❌ Missing | Validation helpers | LOW |
| **Quality Features** |
| Normalization | Required for <3072 | ❌ Missing | Implementation | HIGH |
| Cosine similarity | Recommended | ✅ Implemented | None | - |
| Other metrics | Optional | ❌ Missing | Implementation | MEDIUM |
| **Parameters** |
| title for retrieval | Recommended | ✅ Implemented | Documentation | MEDIUM |
| **Models** |
| text-embedding-004 | Recommended | ✅ Supported | None | - |
| gemini-embedding-001 | Stable | ✅ Supported | None | - |
| Deprecation notices | Required | ❌ Missing | Documentation | MEDIUM |
| **Documentation** |
| API reference | Required | ✅ Complete | None | - |
| Use cases | Required | ✅ Basic | Advanced examples | MEDIUM |
| Best practices | Required | ✅ Basic | MRL, dimensions | MEDIUM |
| **Testing** |
| Unit tests | Required | ⚠️ Partial | Complete coverage | HIGH |
| Integration tests | Required | ❌ Missing | Implementation | HIGH |
| Live API tests | Optional | ❌ Missing | Implementation | MEDIUM |

---

**Document Version:** 1.0
**Last Updated:** 2025-10-14
**Status:** Planning Complete - Ready for Implementation
