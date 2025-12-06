# API Endpoints and Operations Gap Analysis

## Executive Summary

After analyzing the Python genai library (48,170+ lines of code across 30+ modules) and comparing it with the Elixir implementation, I've identified significant gaps in API coverage. The Elixir implementation has successfully ported core functionality but is missing several important APIs and advanced features that exist in the Python version.

### Key Findings

**Python GenAI Library Structure:**
- 11 main API modules (Models, Batches, Files, Caches, Tunings, Documents, Operations, Chats, FileSearchStores, Tokens, Live)
- Specialized modules: LiveMusic, LocalTokenizer, Pagers
- Error classes: APIError, ClientError, ServerError, and function-calling specific errors
- Both sync and async clients for all modules
- Support for pagination with Pager and AsyncPager classes

**Elixir Implementation Status:**
- 10 API modules partially implemented (Coordinator, Models, Batches, Files, ContextCache, Documents, Operations, Tokens, Chat)
- Missing entirely: FileSearchStores (partial), Live/LiveMusic, LocalTokenizer, Tunings
- Limited async support (mostly synchronous with some async via streaming)
- No dedicated paging abstractions
- Basic error handling (single Error module)

---

## Detailed Gap Analysis

| API Module | Python Operations | Elixir Status | Gap Description |
|---|---|---|---|
| **Models** | embed_content, generate_content, generate_content_stream, generate_images, edit_image, upscale_image, recontext_image, segment_image, get, list, update, delete, count_tokens, compute_tokens, generate_videos | Mostly complete | Missing: compute_tokens, edit_image, upscale_image, recontext_image, segment_image, generate_videos, update, delete operations |
| **Batches** | create, create_embeddings, get, list, cancel, delete | Complete | Full parity |
| **Files** | upload, download, get, list, delete | Complete | Full parity |
| **Caches (Context Cache)** | create, get, update, delete, list | Partial | Named "ContextCache" instead of "Caches"; operations present but may have different signatures |
| **Tunings** | tune, get, list, cancel | **MISSING** | Entire module not implemented - critical gap for fine-tuning operations |
| **Documents** | get, list, delete | Partial | Missing hierarchical parent resource support in list operations |
| **Operations** | get, _get_videos_operation, _fetch_predict_videos_operation | Partial | Missing: video operation retrieval, incomplete polling/async operation support |
| **Chats** | send_message, send_message_stream, get_history, record_history, create | Minimal | Only basic create/new exists; missing send_message, send_message_stream with proper streaming |
| **FileSearchStores** | create, get, delete, list, documents, import_file, upload_to_file_search_store | **MISSING** | Entire module missing - critical for file search functionality |
| **Tokens** | create | Partial | Only create for auth tokens; missing comprehensive token management |
| **Live** | AsyncSession, connect, send, receive, send_client_content, send_realtime_input, send_tool_response | **MISSING** | Entire real-time API module missing |
| **LiveMusic** | set_weighted_prompts, set_music_generation_config, play, pause, stop | **MISSING** | Entire experimental music API missing |
| **LocalTokenizer** | token counting utilities, _TextsAccumulator | **MISSING** | No local token counting support |
| **Pagers** | Pager, AsyncPager with iteration support | **MISSING** | No pagination abstraction layer |

---

## Priority-Ranked Implementation Gaps

### CRITICAL - Core API Gaps

#### 1. Tunings Module (HIGH IMPACT)
- **Operations:** tune, get, list, cancel
- Required for fine-tuning capabilities
- Affects users wanting model customization
- **Estimated effort:** HIGH

#### 2. FileSearchStores Module (HIGH IMPACT)
- **Operations:** create, get, delete, list, import_file, upload_to_file_search_store
- Subdocument management required
- Required for semantic search capabilities
- **Estimated effort:** HIGH

#### 3. Live API Module (MEDIUM IMPACT)
- Real-time WebSocket connections
- StreamInput/Output types
- Tool responses during streaming
- **Estimated effort:** VERY HIGH (WebSocket integration)

#### 4. Chat Enhancement (MEDIUM IMPACT)
- Proper send_message with streaming variants
- Message history management
- Stream subscription model
- **Estimated effort:** MEDIUM

### HIGH PRIORITY - Missing Operations

#### 5. Image Manipulation Operations (Missing from Models)
- `edit_image` - Edit generated images
- `upscale_image` - Upscale image quality
- `recontext_image` - Recontextualize images
- `segment_image` - Segment image content
- **Estimated effort:** MEDIUM

#### 6. Video Generation (Missing from Models)
- `generate_videos` - Generate video content
- `_get_videos_operation` - Poll video generation status
- **Estimated effort:** HIGH

#### 7. Model Management (Missing from Models)
- `update` - Update model parameters
- `delete` - Delete models
- **Estimated effort:** LOW

#### 8. Token Management (Missing from Operations)
- `compute_tokens` - Compute token count with streaming
- Better token estimation
- **Estimated effort:** MEDIUM

### MEDIUM PRIORITY - Supporting Infrastructure

#### 9. Paging Abstractions (Utility Layer)
- Pager class for synchronous pagination
- AsyncPager for async pagination
- Proper page iteration
- **Estimated effort:** MEDIUM

#### 10. LocalTokenizer (Optional/Experimental)
- Text-only token counting
- Local model-based estimation
- **Estimated effort:** HIGH (external dependency: sentencepiece)

#### 11. Error Handling Enhancement
- ClientError vs ServerError distinction
- FunctionInvocationError, UnknownFunctionCallArgumentError
- Better error recovery patterns
- **Estimated effort:** LOW

#### 12. Async Parity (Infrastructure)
- Async versions of all blocking operations
- Currently limited to streaming operations
- **Estimated effort:** MEDIUM-HIGH across all modules

---

## Detailed Missing Methods by Module

### Models Module (8 Missing Operations)
- `compute_tokens/1-2` - Alternative to count_tokens with streaming support
- `edit_image/2` - Edit images based on prompt
- `upscale_image/2` - Increase image resolution
- `recontext_image/2` - Reposition image in context
- `segment_image/2` - Segment image regions
- `generate_videos/2` - Generate video from text/images
- `update/2` - Update model configuration
- `delete/1` - Delete a model

### Chat Module (Major Implementation Gap)
- `send_message/2-3` - Send message to chat with proper streaming
- `send_message_stream/2-3` - Stream response for sent message
- `get_history/1` - Retrieve conversation history
- `record_history/1` - Record/save conversation
- Full integration with Coordinator's streaming

### Operations Module (Incomplete Implementation)
- `_get_videos_operation/1-2` - Poll video generation operations
- `_fetch_predict_videos_operation/1-2` - Fetch prediction results
- Proper async operation polling with exponential backoff
- Operation cancellation with verification

### FileSearchStores Module (100% Missing)
```
Core Operations:
- create/2 - Create file search store
- get/1 - Get store details
- delete/1-2 - Delete store with force option
- list/1 - List all stores with pagination
- documents/1 - Access nested documents API
- import_file/2 - Import file into store
- upload_to_file_search_store/2-3 - Upload new file to store
```

### Tunings Module (100% Missing)
```
Core Operations:
- tune/2-3 - Create tuning job
- get/1 - Get tuning job status
- list/1 - List tuning jobs with pagination
- cancel/1 - Cancel running job
- Visualization helpers (display_experiment_button, display_model_tuning_button)
- IPython integration
```

### Live API Module (100% Missing)
```
Core Components:
- AsyncSession class - Manage WebSocket connection
- connect/1-2 - Establish real-time connection
- send/1-2 - Send client messages
- receive/1 - Get server responses
- send_client_content/2 - Send content with tools
- send_realtime_input/2 - Send audio/media
- send_tool_response/3 - Send function call results
- Message type handling
- Error/close handling
```

### LiveMusic Module (100% Missing - Experimental)
```
Core Operations:
- AsyncMusicSession class
- set_weighted_prompts/1 - Configure music prompts
- set_music_generation_config/1 - Set generation parameters
- play/0 - Start playback
- pause/0 - Pause playback
- stop/0 - Stop generation
- Requires Live module foundation
```

### LocalTokenizer Module (100% Missing - Experimental)
```
Core Classes/Functions:
- LocalTokenizer - Local token counter
- _TextsAccumulator - Traverse content for tokens
- count_text_only/1 - Count tokens for text
- Token estimation without API calls
- Support for: text, function calls, function responses
- Warnings for unsupported content types
```

---

## Impact Assessment

**High-Impact Gaps (Blocking User Workflows):**
- Tunings (model fine-tuning is core feature)
- FileSearchStores (semantic search capability)
- Live API (real-time chat use case)
- Image operations (multimodal editing)

**Medium-Impact Gaps (Important Features):**
- Chat send_message/streaming (basic chat functionality)
- Video generation (content creation)
- Pagination abstractions (usability for large datasets)
- Async parity (non-blocking workflows)

**Low-Impact Gaps (Nice-to-Have):**
- LocalTokenizer (can use API alternative)
- Model update/delete (rarely used)
- Error subclasses (functional but less specific)

---

## Backward Compatibility Concerns

Current Elixir API is largely compatible with Python, but:

1. **Naming differences:**
   - `ContextCache` (Elixir) vs `Caches` (Python)
   - Function parameter ordering differs in some cases

2. **Missing abstractions:**
   - No Pager classes means pagination must be manual
   - No LocalTokenizer means can't do offline counting

3. **Missing async versions:**
   - Many Python operations have async variants
   - Elixir mostly single sync approach (except streaming)

---

## Implementation Recommendations

### Phase 1 (Critical)
1. Implement Tunings module (enables fine-tuning)
2. Implement FileSearchStores with Documents (enables search)
3. Enhance Chat with send_message variants

### Phase 2 (High Priority)
4. Implement image manipulation (edit, upscale, recontext, segment)
5. Implement video generation operations
6. Add pagination abstractions (Pager-like behavior)

### Phase 3 (Medium Priority)
7. Implement Live API (real-time communication)
8. Implement LiveMusic (experimental)
9. Add LocalTokenizer (experimental)
10. Complete async parity for all modules

### Phase 4 (Polish)
11. Error subclass refinement
12. Documentation alignment
13. IPython/Interactive features
14. Replay/debugging support

---

## Conclusion

The Elixir implementation provides solid coverage of core content generation features but lacks several advanced and specialized APIs. The most critical gaps are:

1. **Tunings** - Users cannot fine-tune models
2. **FileSearchStores** - Users cannot implement semantic search
3. **Live API** - Users cannot use real-time features
4. **Image Operations** - Limited multimodal editing capabilities

Implementing these four modules would bring the Elixir port to feature parity with ~85-90% of Python genai library functionality.

---

**Document Generated:** 2024-12-06
**Analysis Scope:** Python genai library vs Elixir Gemini client
**Methodology:** Static code analysis + API comparison
