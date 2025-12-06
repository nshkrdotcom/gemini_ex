# Gap Analysis: Files, Batches & Documents

## Executive Summary

The Python genai library has **4,429 lines of code** across 4 major modules implementing file management, batch processing, document management, and semantic search. The Elixir implementation has **minimal support** with only basic FileData type definitions.

**Current Elixir Coverage: 0-5%**

## Feature Comparison Table

| Feature | Python | Elixir | Priority |
|---------|--------|--------|----------|
| **Files API** | ✅ Full | ❌ None | HIGH |
| File Upload | ✅ Resumable | ❌ None | HIGH |
| File Download | ✅ By URI/name | ❌ None | HIGH |
| File List | ✅ Paginated | ❌ None | MEDIUM |
| File Get/Delete | ✅ Yes | ❌ None | MEDIUM |
| **Batches API** | ✅ Full | ❌ Partial | CRITICAL |
| Batch Create (Gen) | ✅ Yes | ❌ No | CRITICAL |
| Batch Create (Embed) | ✅ Yes | ⚠️ Types only | HIGH |
| Batch Get/List | ✅ Yes | ❌ No | HIGH |
| Batch Cancel/Delete | ✅ Yes | ❌ No | MEDIUM |
| **GCS Integration** | ✅ Yes | ❌ No | HIGH |
| **BigQuery Integration** | ✅ Yes | ❌ No | HIGH |
| Inlined Requests | ✅ Yes | ❌ No | MEDIUM |
| **Documents API** | ✅ Full | ❌ None | MEDIUM |
| Document Get/List | ✅ Yes | ❌ No | MEDIUM |
| Document Delete | ✅ Yes | ❌ No | LOW |
| **FileSearchStores** | ✅ Full | ❌ None | MEDIUM |
| Store CRUD | ✅ Yes | ❌ No | MEDIUM |
| File Upload to Store | ✅ Resumable | ❌ No | MEDIUM |
| Chunking Config | ✅ Yes | ❌ No | LOW |
| Custom Metadata | ✅ Yes | ❌ No | LOW |

## Python Implementation Details

### 1. files.py (1,021 lines)

**Core Capabilities:**
- File upload/download with resumable upload support
- Get file metadata by name
- List all files with pagination
- Delete files
- Download generated files by URI
- MIME type detection

**Key Classes:**
- `Files` - Synchronous operations
- `AsyncFiles` - Asynchronous operations

**Key Methods:**
```python
upload(file, config)    # Upload from path or IOBase
download(file, config)  # Download by name, URI, or File object
get(name, config)       # Retrieve file metadata
delete(name, config)    # Remove file
list(config)            # List with pagination
```

### 2. batches.py (2,580 lines)

**Core Capabilities:**
- Create batch jobs for content generation and embeddings
- Job status polling and cancellation
- GCS and BigQuery integration
- Inlined request processing

**Input/Output Options:**
- **GCS Input**: `gs://bucket/path/to/input.jsonl`
- **BigQuery Input**: `bq://project.dataset.table`
- **Inlined Requests**: Pass requests array directly
- **GCS Output**: Results written to `gs://bucket/prefix/`
- **BigQuery Output**: Results written to BigQuery table

**Job States:** PENDING, RUNNING, SUCCEEDED, FAILED

### 3. documents.py (532 lines)

**Core Capabilities:**
- Get document metadata from RAG stores
- Delete documents from stores
- List documents with pagination

**Naming Convention:** `ragStores/{store_id}/documents/{doc_id}`

### 4. file_search_stores.py (1,296 lines)

**Core Capabilities:**
- Create semantic file search stores
- Upload files with chunking configuration
- Custom metadata support
- Vector/semantic search

**Upload Configuration:**
- MIME type specification
- Display name
- Custom metadata (key-value pairs)
- Chunking configuration (size, overlap, strategy)

## Elixir Current State

### Existing Types

```elixir
# Only basic type definition exists
defmodule Gemini.Types.FileData do
  typedstruct do
    field(:file_uri, String.t(), enforce: true)
    field(:mime_type, String.t(), enforce: true)
    field(:display_name, String.t() | nil)
  end
end
```

### Existing Batch Types (Embeddings Only)
- `BatchEmbedContentsRequest`
- `BatchEmbedContentsResponse`
- `BatchState`
- `EmbedContentBatch*` types

**Missing:**
- No Files API module
- No general batch job API
- No Documents API
- No FileSearchStores API
- No GCS/BigQuery integration
- No resumable upload handling

## Implementation Complexity

### Estimated Development Effort

1. **Files API** (12-16 hours)
   - Resumable upload handler
   - Download handler
   - List with pagination
   - Get/Delete operations

2. **Batches API** (16-20 hours)
   - Type definitions (BatchJob, Source, Destination)
   - Create batch (generation + embeddings)
   - Get, List, Cancel, Delete
   - GCS/BigQuery path helpers

3. **Documents API** (6-8 hours)
   - Type definitions
   - CRUD operations
   - Pagination support

4. **FileSearchStores API** (10-12 hours)
   - Store CRUD
   - Upload with resumable support
   - Chunking configuration

5. **Supporting Infrastructure** (8-10 hours)
   - HTTP multipart handlers
   - Resumable upload manager
   - URI builders

**Total Estimated Effort:** 52-66 hours

## Priority Recommendations

### Phase 1: CRITICAL (Week 1)
**Batch Jobs API**
- Create generation batches
- Get/List/Cancel operations
- Complete type definitions

### Phase 2: HIGH (Week 2)
**Files API + GCS/BigQuery Integration**
- Upload/Download operations
- File management
- Storage integration

### Phase 3: MEDIUM (Week 3)
**FileSearchStores API**
- Create/manage search stores
- Upload files with chunking

### Phase 4: LOW (Week 4)
**Documents API + Advanced Features**
- Document management
- Chunking config, custom metadata

## Technical Considerations

### Multi-Auth Integration
- All APIs must support both `:gemini` and `:vertex_ai`
- Different endpoint formats per platform
- GCS requires service account credentials

### HTTP Handling Challenges
- Resumable upload protocol (chunking + state)
- Multipart form data
- Large file handling (memory)
- Progress tracking

### Type Safety
- Union types for source/destination
- State enums for batch jobs
- Platform-specific error handling

## Conclusion

The Elixir implementation is **0-5% complete** for files/batches/documents. This impacts:

1. **Batch processing workflows** - Critical for production
2. **Large-scale operations** - File management and RAG
3. **Enterprise integration** - GCS and BigQuery support
4. **Full API parity** - Multiple core features missing

The multi-auth coordinator provides the foundation, but significant work is required for feature parity.
