# Complete Gap Implementation Prompt for Gemini Elixir v0.7.0

## 🎯 Mission

You are tasked with implementing **full feature parity** between the Elixir `gemini_ex` library and the Python `google-genai` SDK. This is a comprehensive implementation covering all gaps identified in the gap analysis.

**Success Criteria:**
- All tests pass (`mix test`)
- All live API tests pass (`mix test --include live_api`)
- Zero compilation warnings
- Zero Dialyzer errors (`mix dialyzer`)
- Complete documentation for hex.pm publishing
- Version bumped to 0.7.0

---

## 📚 Required Reading (Execute First)

Before writing any code, you MUST read and understand these files:

### Gap Analysis Documents
```
docs/20251205/gap_analysis/00_SUMMARY.md
docs/20251205/gap_analysis/01_api_endpoints.md
docs/20251205/gap_analysis/02_streaming_live.md
docs/20251205/gap_analysis/03_types_models.md
docs/20251205/gap_analysis/04_function_calling.md
docs/20251205/gap_analysis/05_files_batches_documents.md
docs/20251205/gap_analysis/06_caching_operations.md
docs/20251205/gap_analysis/07_errors_client_config.md
docs/20251205/gap_analysis/08_embeddings_tokens.md
```

### Existing Elixir Implementation (Reference Patterns)
```
lib/gemini.ex                           # Main module - add new public APIs here
lib/gemini/apis/coordinator.ex          # API coordinator - extend with new APIs
lib/gemini/auth/multi_auth_coordinator.ex
lib/gemini/streaming/unified_manager.ex
lib/gemini/types/                       # Type patterns to follow
lib/gemini/client/http_streaming.ex
```

### Python SDK Implementation (Feature Reference)
```
python-genai/google/genai/files.py      # Files API implementation
python-genai/google/genai/batches.py    # Batches API implementation
python-genai/google/genai/operations.py # Long-running operations
python-genai/google/genai/caches.py     # Caching implementation
python-genai/google/genai/live.py       # WebSocket/Live API
python-genai/google/genai/_transformers.py # Token counting
python-genai/google/genai/types.py      # All type definitions
```

### Code Quality Standards
```
CODE_QUALITY.md                         # MUST follow all standards
CLAUDE.md                               # Project context and patterns
```

---

## 🏗️ Implementation Order (TDD Approach)

Implement in this exact order. For each feature:
1. Write comprehensive tests first (including live API tests)
2. Implement the feature to pass tests
3. Add documentation
4. Verify zero warnings/dialyzer errors
5. Move to next feature

### Phase 1: Core APIs (Critical Priority)

#### 1.1 Embeddings API
**Files to create/modify:**
- `lib/gemini/apis/embeddings.ex` - NEW
- `lib/gemini/types/embedding.ex` - Enhance existing
- `test/gemini/apis/embeddings_test.exs` - NEW
- `test/live_api/embeddings_live_test.exs` - NEW

**Required Functions:**
```elixir
Gemini.embed_content(text, opts \\ [])
Gemini.embed_content!(text, opts \\ [])
Gemini.batch_embed_contents(texts, opts \\ [])
Gemini.batch_embed_contents!(texts, opts \\ [])
```

**Live API Tests Must Cover:**
- Single text embedding
- Batch text embeddings (up to 100 texts)
- Different embedding models
- Task type parameter (RETRIEVAL_QUERY, RETRIEVAL_DOCUMENT, etc.)
- Output dimensionality configuration
- Both :gemini and :vertex_ai auth strategies

#### 1.2 Files API
**Files to create/modify:**
- `lib/gemini/apis/files.ex` - NEW
- `lib/gemini/types/file.ex` - Enhance existing
- `test/gemini/apis/files_test.exs` - NEW
- `test/live_api/files_live_test.exs` - NEW

**Required Functions:**
```elixir
Gemini.upload_file(path, opts \\ [])
Gemini.upload_file!(path, opts \\ [])
Gemini.upload_file_resumable(path, opts \\ [])  # For large files
Gemini.get_file(name, opts \\ [])
Gemini.get_file!(name, opts \\ [])
Gemini.list_files(opts \\ [])
Gemini.delete_file(name, opts \\ [])
Gemini.delete_file!(name, opts \\ [])
```

**Live API Tests Must Cover:**
- Upload small file (<10MB)
- Upload large file with resumable upload
- Get file metadata
- List files with pagination
- Delete file
- MIME type detection
- Video/audio file uploads
- URI generation for content generation

#### 1.3 Batches API
**Files to create/modify:**
- `lib/gemini/apis/batches.ex` - NEW
- `lib/gemini/types/batch.ex` - NEW
- `test/gemini/apis/batches_test.exs` - NEW
- `test/live_api/batches_live_test.exs` - NEW

**Required Functions:**
```elixir
Gemini.create_batch(requests, opts \\ [])
Gemini.create_batch!(requests, opts \\ [])
Gemini.get_batch(name, opts \\ [])
Gemini.get_batch!(name, opts \\ [])
Gemini.list_batches(opts \\ [])
Gemini.cancel_batch(name, opts \\ [])
Gemini.delete_batch(name, opts \\ [])
```

**Live API Tests Must Cover:**
- Create generation batch with JSONL
- Create embedding batch
- Get batch status
- List batches with pagination
- Cancel in-progress batch
- Delete completed batch
- GCS source/destination support
- BigQuery destination support (if available)

### Phase 2: Operations & Infrastructure

#### 2.1 Long-Running Operations
**Files to create/modify:**
- `lib/gemini/apis/operations.ex` - NEW
- `lib/gemini/types/operation.ex` - NEW
- `test/gemini/apis/operations_test.exs` - NEW
- `test/live_api/operations_live_test.exs` - NEW

**Required Functions:**
```elixir
Gemini.get_operation(name, opts \\ [])
Gemini.get_operation!(name, opts \\ [])
Gemini.list_operations(opts \\ [])
Gemini.wait_operation(name, opts \\ [])  # Polls until complete
Gemini.cancel_operation(name, opts \\ [])
Gemini.delete_operation(name, opts \\ [])
```

**Types Required:**
```elixir
defmodule Gemini.Types.Operation do
  @type t :: %__MODULE__{
    name: String.t(),
    metadata: map(),
    done: boolean(),
    error: map() | nil,
    response: map() | nil
  }
end
```

**Live API Tests Must Cover:**
- Get operation status
- List operations with filters
- Wait for operation completion (with timeout)
- Cancel operation
- Delete operation
- Progress tracking callbacks

#### 2.2 Cache Pagination Enhancement
**Files to modify:**
- `lib/gemini/apis/caches.ex` - Enhance
- `test/live_api/caches_live_test.exs` - Enhance

**Required Enhancements:**
```elixir
Gemini.list_caches(page_size: 10, page_token: "...")
# Returns: {:ok, %{caches: [...], next_page_token: "..."}}
```

### Phase 3: Advanced Features

#### 3.1 Documents API (RAG Corpus)
**Files to create/modify:**
- `lib/gemini/apis/documents.ex` - NEW
- `lib/gemini/types/document.ex` - NEW
- `test/gemini/apis/documents_test.exs` - NEW
- `test/live_api/documents_live_test.exs` - NEW (Vertex AI only)

**Required Functions:**
```elixir
# Corpus management
Gemini.create_corpus(config, opts \\ [])
Gemini.get_corpus(name, opts \\ [])
Gemini.list_corpora(opts \\ [])
Gemini.delete_corpus(name, opts \\ [])
Gemini.query_corpus(name, query, opts \\ [])

# Document management
Gemini.create_document(corpus, config, opts \\ [])
Gemini.get_document(name, opts \\ [])
Gemini.list_documents(corpus, opts \\ [])
Gemini.delete_document(name, opts \\ [])

# Chunk management
Gemini.create_chunk(document, config, opts \\ [])
Gemini.batch_create_chunks(document, chunks, opts \\ [])
Gemini.get_chunk(name, opts \\ [])
Gemini.list_chunks(document, opts \\ [])
Gemini.update_chunk(name, config, opts \\ [])
Gemini.batch_update_chunks(document, chunks, opts \\ [])
Gemini.delete_chunk(name, opts \\ [])
Gemini.batch_delete_chunks(document, names, opts \\ [])
```

#### 3.2 File Search Stores (Vertex AI)
**Files to create/modify:**
- `lib/gemini/apis/rag_stores.ex` - NEW
- `lib/gemini/types/rag_store.ex` - NEW

#### 3.3 AFC (Automatic Function Calling) Enhancements
**Files to modify:**
- `lib/gemini/tools/altar.ex` - Enhance
- `lib/gemini/types/tool.ex` - Add config types

**Required Enhancements:**
```elixir
# Tool configuration
%ToolConfig{
  function_calling_config: %{
    mode: :auto | :any | :none,
    allowed_function_names: ["func1", "func2"]
  }
}

# Async tool support
defmodule Gemini.Tools.AsyncRunner do
  @callback execute_async(name, args) :: {:ok, task_ref} | {:error, term}
  @callback await_result(task_ref, timeout) :: {:ok, result} | {:error, term}
end
```

#### 3.4 Enhanced Type Definitions
Create comprehensive types matching Python SDK. **Priority types:**

```elixir
# Enums (create lib/gemini/types/enums.ex)
- HarmCategory (10 values)
- HarmBlockThreshold (5 values)
- HarmProbability (5 values)
- BlockedReason (5 values)
- FinishReason (8 values)
- TaskType (5 values)
- Modality (5 values)
- MediaResolution (4 values)
- SpeechConfig (5 values)
- DynamicRetrievalMode (3 values)

# Request types (enhance existing)
- GenerateContentRequest (add all 20+ fields from Python)
- EmbedContentRequest
- BatchEmbedContentsRequest
- CountTokensRequest (enhanced)

# Response types (enhance existing)
- All candidate variations
- Usage metadata (enhanced)
- Citation metadata
- Grounding metadata
```

### Phase 4: Real-Time Features

#### 4.1 WebSocket/Live Sessions
**Files to create:**
- `lib/gemini/live/connection.ex` - NEW
- `lib/gemini/live/session.ex` - NEW
- `lib/gemini/live/audio_handler.ex` - NEW
- `lib/gemini/types/live.ex` - NEW
- `test/gemini/live/` - NEW directory

**Required Functions:**
```elixir
Gemini.Live.connect(model, opts \\ [])
Gemini.Live.send_text(session, text)
Gemini.Live.send_audio(session, audio_data)
Gemini.Live.send_video(session, video_frame)
Gemini.Live.send_tool_response(session, response)
Gemini.Live.receive(session, timeout \\ 5000)
Gemini.Live.close(session)
```

**Implementation Notes:**
- Use `:gun` or `WebSockex` for WebSocket
- Handle bidirectional streaming
- Support audio/video input
- Automatic reconnection
- Session state management

#### 4.2 Local Tokenization (Optional - Complex)
**Files to create:**
- `lib/gemini/tokenizer/sentencepiece.ex` - NEW (NIF wrapper)
- `lib/gemini/tokenizer/registry.ex` - NEW

**Note:** This requires SentencePiece NIF bindings. Consider using existing Elixir tokenizer libraries or marking as future enhancement.

---

## 📝 Documentation Requirements

### For Each New API Module

Add comprehensive `@moduledoc` with:
- Purpose and use cases
- Example usage
- Configuration options
- Error handling
- Auth strategy notes

### Guides to Create
```
guides/embeddings.md          # Embeddings API guide
guides/files.md               # File upload/management guide
guides/batches.md             # Batch processing guide
guides/operations.md          # Long-running operations guide
guides/documents.md           # RAG/Corpus management guide (Vertex AI)
guides/live.md                # Real-time sessions guide
guides/migration_0_7_0.md     # Migration guide from 0.6.x
```

### Update Existing Docs
```
README.md                     # Update with new features, bump version
CHANGELOG.md                  # Add 0.7.0 section
mix.exs                       # Add guides to docs config
```

---

## ✅ Final Verification Checklist

Before completion, verify ALL of these pass:

```bash
# All unit tests pass
mix test

# All live API tests pass (requires GEMINI_API_KEY)
mix test --include live_api

# Zero compilation warnings
mix compile --warnings-as-errors

# Zero Dialyzer errors
mix dialyzer

# Documentation generates without errors
mix docs

# All examples run successfully
mix run examples/demo.exs
mix run examples/streaming_demo.exs
mix run examples/demo_unified.exs
mix run examples/embeddings_demo.exs    # NEW
mix run examples/files_demo.exs          # NEW
mix run examples/batches_demo.exs        # NEW
```

---

## 🔧 Version Bump Requirements

### mix.exs Changes
```elixir
def project do
  [
    app: :gemini_ex,
    version: "0.7.0",  # Bump from 0.6.x
    # ... rest of config
    docs: [
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/embeddings.md",
        "guides/files.md",
        "guides/batches.md",
        "guides/operations.md",
        "guides/documents.md",
        "guides/live.md",
        "guides/migration_0_7_0.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ]
    ]
  ]
end
```

### CHANGELOG.md Addition
```markdown
## [0.7.0] - 2025-12-05

### Added
- **Embeddings API** - Full embed_content and batch_embed_contents support
- **Files API** - Upload, download, list, delete with resumable upload support
- **Batches API** - Batch generation and embedding with GCS/BigQuery support
- **Operations API** - Long-running operation management and polling
- **Documents API** - RAG corpus and document management (Vertex AI)
- **File Search Stores** - Vector search store management (Vertex AI)
- **AFC Enhancements** - Configurable function calling modes and async tools
- **50+ New Types** - Comprehensive type definitions matching Python SDK
- **Live Sessions** - WebSocket-based real-time bidirectional streaming
- **Cache Pagination** - Page token support for cache listing

### Changed
- Enhanced coordinator to route all new APIs
- Improved error types with API-specific variants
- Updated all guides and documentation

### Fixed
- Various type inconsistencies identified in gap analysis
```

### README.md Updates
- Update version badge to 0.7.0
- Add new feature sections
- Update installation instructions
- Add examples for new APIs

---

## 🚀 Execution Instructions

1. **Start with reading** - Read all required documents listed above
2. **Create todo list** - Use TodoWrite to track all implementation tasks
3. **TDD each feature** - Write tests first, then implement
4. **Integrate incrementally** - Update coordinator after each API
5. **Document as you go** - Add docs immediately after implementation
6. **Verify continuously** - Run tests/dialyzer after each feature
7. **Final verification** - Complete full checklist before marking done

---

## 📊 Expected Deliverables

| Category | Count |
|----------|-------|
| New API modules | 6-8 |
| New type modules | 10-15 |
| New test files | 12-16 |
| New guide files | 7 |
| Updated files | 10-15 |
| New examples | 3-4 |

**Estimated Implementation Time:** 40-60 hours of focused work

---

## ⚠️ Critical Reminders

1. **NEVER break existing functionality** - All current tests must continue passing
2. **Follow CODE_QUALITY.md strictly** - @type t, @enforce_keys, @spec everywhere
3. **Test both auth strategies** - :gemini and :vertex_ai for all new APIs
4. **Handle pagination** - All list endpoints must support page tokens
5. **Preserve streaming excellence** - Don't modify SSE parser or ManagerV2
6. **Real API testing** - Live tests are mandatory, not optional
7. **Documentation is required** - No undocumented public functions

---

*This prompt was generated from comprehensive gap analysis comparing gemini_ex v0.6.4 with Python google-genai SDK.*
