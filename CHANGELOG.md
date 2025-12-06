# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.1] - 2025-12-05

### Added
- Atomic token budget reservation (`try_reserve_budget/3`) with safety multiplier, reconciliation, and telemetry events (`budget_reserved`, `budget_rejected`)
- Shared retry window gating with jittered release plus telemetry hooks (`retry_window_set/hit/release`)
- Model use-case aliases (`cache_context`, `report_section`, `fast_path`) resolved through `Gemini.Config.model_for_use_case/2` with documented token minima
- Streaming now goes through the rate limiter (UnifiedManager): permits are held for the duration of the stream, budget is reserved up front, and telemetry is emitted for stream start/completion/error/stop

### Fixed
- Concurrency gate TOCTOU race hardened with serialized permit acquisition; default non_blocking remains false for server workloads
- Rate limiter now pre-flight rejects over-budget bursts before dispatching requests and returns surplus budget after responses

## [0.7.0] - 2025-12-05

### 🎉 Major Feature Release: Complete API Parity

This release brings the Elixir client to near-complete feature parity with the Python google-genai SDK, adding comprehensive support for Files, Batches, Operations, and Documents APIs.

### Added

#### 📁 Files API - Complete File Management
- **`Gemini.APIs.Files.upload/2`**: Upload files with resumable protocol, progress tracking, and automatic MIME detection
- **`Gemini.APIs.Files.upload_data/2`**: Upload binary data directly (requires `mime_type` option)
- **`Gemini.APIs.Files.get/2`**: Retrieve file metadata by name
- **`Gemini.APIs.Files.list/1`**: List files with pagination support
- **`Gemini.APIs.Files.list_all/1`**: Automatically paginate through all files
- **`Gemini.APIs.Files.delete/2`**: Delete uploaded files
- **`Gemini.APIs.Files.wait_for_processing/2`**: Poll until file is ready for use
- **`Gemini.APIs.Files.download/2`**: Download generated file content

#### 📦 Batches API - Bulk Processing with 50% Cost Savings
- **`Gemini.APIs.Batches.create/2`**: Create batch content generation jobs
- **`Gemini.APIs.Batches.create_embeddings/2`**: Create batch embedding jobs
- **`Gemini.APIs.Batches.get/2`**: Get batch job status
- **`Gemini.APIs.Batches.list/1`**: List batch jobs with pagination
- **`Gemini.APIs.Batches.list_all/1`**: List all batch jobs
- **`Gemini.APIs.Batches.cancel/2`**: Cancel running batch jobs
- **`Gemini.APIs.Batches.delete/2`**: Delete batch jobs
- **`Gemini.APIs.Batches.wait/2`**: Wait for batch completion with progress callback
- **`Gemini.APIs.Batches.get_responses/1`**: Extract inlined responses from completed batches
- Support for file-based, inlined, GCS, and BigQuery input sources

#### ⏱️ Operations API - Long-Running Task Management
- **`Gemini.APIs.Operations.get/2`**: Get operation status
- **`Gemini.APIs.Operations.list/1`**: List operations with pagination
- **`Gemini.APIs.Operations.list_all/1`**: List all operations
- **`Gemini.APIs.Operations.cancel/2`**: Cancel running operations
- **`Gemini.APIs.Operations.delete/2`**: Delete completed operations
- **`Gemini.APIs.Operations.wait/2`**: Wait with configurable polling
- **`Gemini.APIs.Operations.wait_with_backoff/2`**: Wait with exponential backoff

#### 📄 Documents API - RAG Store Document Management
- **`Gemini.APIs.Documents.get/2`**: Get document metadata
- **`Gemini.APIs.Documents.list/2`**: List documents in a RAG store
- **`Gemini.APIs.Documents.list_all/2`**: List all documents
- **`Gemini.APIs.Documents.delete/2`**: Delete documents
- **`Gemini.APIs.Documents.wait_for_processing/2`**: Wait for document processing
- **`Gemini.APIs.RagStores.get/2`**: Get RAG store metadata
- **`Gemini.APIs.RagStores.list/1`**: List RAG stores
- **`Gemini.APIs.RagStores.create/1`**: Create new RAG stores
- **`Gemini.APIs.RagStores.delete/2`**: Delete RAG stores

#### 🏷️ Enhanced Enum Types - Comprehensive Type Safety
New enum modules in `Gemini.Types.Enums` with `to_api/1` and `from_api/1` converters:
- `HarmCategory` - 12 harm category values
- `HarmBlockThreshold` - 6 threshold levels
- `HarmProbability` - 5 probability levels
- `BlockedReason` - 7 block reasons
- `FinishReason` - 12 finish reasons
- `TaskType` - 9 embedding task types
- `FunctionCallingMode` - 3 function calling modes
- `DynamicRetrievalMode` - 3 retrieval modes
- `ThinkingLevel` - 3 thinking budget levels
- `CodeExecutionOutcome` - 4 execution outcomes
- `ExecutableCodeLanguage` - 2 code languages
- `GroundingAttributionConfidence` - 4 confidence levels
- `AspectRatio` - 4 image aspect ratios
- `ImageSize` - 3 image size options
- `VoiceName` - 6 voice options for TTS

#### 📖 New Documentation Guides
- `docs/guides/files.md` - Complete Files API guide
- `docs/guides/batches.md` - Batch processing guide
- `docs/guides/operations.md` - Long-running operations guide

### Technical Implementation

#### 🏛️ Architecture
- Resumable upload protocol with 8MB chunks and automatic retry
- Consistent polling patterns with configurable timeouts and progress callbacks
- TypedStruct patterns with `@derive Jason.Encoder` for all new types
- Full multi-auth support (`:gemini` and `:vertex_ai`) across all new APIs

#### 🧪 Testing
- 94 new tests for Files, Operations, Batches, and Documents APIs
- Unit tests for all type parsing and helper functions
- Live API test infrastructure for integration testing
- Test fixtures for file uploads

#### 📈 Quality
- Zero compilation warnings
- Complete `@spec` annotations for all public functions
- Comprehensive `@moduledoc` and `@doc` documentation
- Follows CODE_QUALITY.md standards

### Changed
- Updated README.md with new API sections and examples
- Version bump from 0.6.4 to 0.7.0

### Migration Notes

#### For Existing Users
All changes are additive - existing code continues to work unchanged. New APIs are available immediately:

```elixir
# Upload and use a file
{:ok, file} = Gemini.APIs.Files.upload("image.png")
{:ok, ready} = Gemini.APIs.Files.wait_for_processing(file.name)
{:ok, response} = Gemini.generate([
  "Describe this image",
  %{file_uri: ready.uri, mime_type: ready.mime_type}
])

# Create a batch job
{:ok, batch} = Gemini.APIs.Batches.create("gemini-2.0-flash",
  file_name: "files/input123",
  display_name: "My Batch"
)
{:ok, completed} = Gemini.APIs.Batches.wait(batch.name)

# Track long-running operations
{:ok, op} = Gemini.APIs.Operations.get("operations/abc123")
{:ok, completed} = Gemini.APIs.Operations.wait_with_backoff(op.name)
```

## [0.6.4] - 2025-12-05

### Added

#### Response Type Enhancements
- `UsageMetadata` now includes:
  - `thoughts_token_count` - Token count for thinking models (Gemini 2.0+)
  - `tool_use_prompt_token_count` - Tokens used in tool/function prompts
  - `prompt_tokens_details` - Per-modality breakdown of prompt tokens
  - `cache_tokens_details` - Per-modality breakdown of cached tokens
  - `response_tokens_details` - Per-modality breakdown of response tokens
  - `tool_use_prompt_tokens_details` - Per-modality breakdown of tool prompt tokens
  - `traffic_type` - Billing traffic type (ON_DEMAND, PROVISIONED_THROUGHPUT)

- `GenerateContentResponse` now includes:
  - `response_id` - Unique response identifier for tracking
  - `model_version` - Actual model version used (e.g., "gemini-2.0-flash-exp-001")
  - `create_time` - Response creation timestamp

- `Candidate` now includes:
  - `finish_message` - Human-readable message explaining stop reason
  - `avg_logprobs` - Average log probability score

- `PromptFeedback` now includes:
  - `block_reason_message` - Human-readable block explanation

- `Part` now includes:
  - `file_data` - URI-based file references (alternative to inline_data)
  - `function_response` - Function call response data
  - `thought` - Boolean flag for thinking model thought parts

- `SafetyRating` now includes:
  - `probability_score` - Numeric harm probability (0.0-1.0)
  - `severity` - Harm severity level
  - `severity_score` - Numeric severity score

#### Request Type Enhancements
- `GenerationConfig` now includes:
  - `seed` - Deterministic generation seed for reproducible outputs
  - `response_modalities` - Control output modalities (TEXT, IMAGE, AUDIO)
  - `speech_config` - Audio output configuration with voice selection
  - `media_resolution` - Input media resolution control (LOW, MEDIUM, HIGH)

#### New Types
- `ModalityTokenCount` - Per-modality token breakdown
- `TrafficType` - Billing traffic type enum
- `Modality` - Response modality enum (TEXT, IMAGE, AUDIO)
- `MediaResolution` - Input media resolution enum
- `FileData` - URI-based file data struct
- `FunctionResponse` - Function call response struct
- `SpeechConfig`, `VoiceConfig`, `PrebuiltVoiceConfig` - Audio output configuration

### Changed
- Response parsing now handles all new fields from Gemini API
- GenerationConfig encoding includes new fields when present

### Fixed
- Token usage now correctly reports thinking tokens separately from output tokens

## [0.6.3] - 2025-12-05

### Added
- Concurrency gate is now partitionable via `concurrency_key` (e.g., per-tenant or per-location) instead of a single global queue per model.
- Concurrency permit wait is configurable via `permit_timeout_ms`; default is now `:infinity` (no queue drop). Per-call overrides supported.
- Per-request timeout overrides for HTTP and streaming; global default HTTP/stream timeout raised to 120_000ms.
- Streaming knobs: `max_backoff_ms`, `connect_timeout`, and configurable cleanup delay for ManagerV2 (`config :gemini_ex, :streaming, cleanup_delay_ms: ...`).
- Configurable context cache TTL defaults via `config :gemini_ex, :context_cache, default_ttl_seconds: ...`.
- Configurable retry delay fallback via `config :gemini_ex, :rate_limiter, default_retry_delay_ms: ...`.
- Permit leak protection: holders are monitored and reclaimed if the process dies without releasing.

### Changed
- Default HTTP/stream timeout increased from 30_000ms to 120_000ms.
- Concurrency gate uses configurable `permit_timeout_ms` (default `:infinity`) instead of a fixed 60s timeout.

### Fixed
- Streaming client no longer leaks `:persistent_term` state; SSE parse errors now surface instead of being silently dropped.
- Streaming backoff ceiling and connect timeout are tunable; SSE parsing failures return errors.

## [0.6.2] - 2025-12-05

### Fixed

- Eliminated recursive retry loop on `:over_budget` blocking calls; blocking now waits once for the current window to end, then retries through the normal pipeline.
- Over-budget `retry_at` is now set to the window end in non-blocking mode instead of `nil`.
- Requests whose estimated tokens exceed the configured budget return immediately with `request_too_large: true` instead of hanging.

### Added

- `estimated_cached_tokens` option for proactive budgeting with cached contexts; cached token usage (`cachedContentTokenCount`) is now included in recorded input tokens.
- Telemetry for over-budget waits/errors now includes token estimates and wait metadata.
- `max_budget_wait_ms` config/option to cap how long blocking over-budget calls will sleep before returning a `rate_limited` error with `retry_at`.

### Documentation

- README and rate limiting guide updated with over-budget behavior, `estimated_cached_tokens`, and cached context budgeting notes.

## [0.6.1] - 2025-12-04

> ⚠️ **Potentially breaking (upgrade note)**: Token estimation now runs automatically and budget checks fall back to profile defaults. Apps that never set `:estimated_input_tokens` or `:token_budget_per_window` can now receive local `:over_budget` errors. To preserve 0.6.0 behavior, set `token_budget_per_window: nil` (globally or per-call), or disable the rate limiter.

### Added

#### Proactive Rate Limiting Enhancements (ADR Implementation)

- **Auto Token Estimation (ADR-0001)**
  - Automatic input token estimation at the Coordinator boundary before request normalization
  - Token estimates passed to rate limiter via `:estimated_input_tokens` option
  - Safe handling of API maps (`%{contents: [...]}`) in `Tokens.estimate/1` - returns 0 for unknown shapes instead of raising
  - Supports both atom keys (`:contents`) and string keys (`"contents"`)

- **Token Budget Configuration (ADR-0002)**
  - New `token_budget_per_window` config field with conservative defaults
  - New `window_duration_ms` config field (default: 60,000ms)
  - Budget checking falls back to `config.token_budget_per_window` when not in per-request opts
  - `State.record_usage/4` now accepts configurable window duration via opts

- **Enhanced 429 Propagation (ADR-0003)**
  - Retry state now captures `quota_dimensions` and `quota_value` from 429 responses
  - Enhanced quota metric extraction from nested error details

- **Tier-Based Rate Limit Profiles (ADR-0004)**
  - New `:free_tier` profile - Conservative for 15 RPM / 1M TPM (32,000 token budget)
  - New `:paid_tier_1` profile - Standard production 500 RPM / 4M TPM (1,000,000 token budget)
  - New `:paid_tier_2` profile - High throughput 1000 RPM / 8M TPM (2,000,000 token budget)
  - Updated `:dev` and `:prod` profiles with token budgets
  - Profile type expanded to include all tier options

### Changed

- `RateLimiter.Config` struct now includes `token_budget_per_window` and `window_duration_ms` fields
- `Manager.check_token_budget/3` now falls back to config defaults
- `Manager.record_usage_from_response/3` passes window duration from config to State
- Updated `docs/guides/rate_limiting.md` with comprehensive tier documentation

### Documentation

- Added Quick Start section with tier profile selection table
- Expanded Profiles section with all tier configurations
- Enhanced Token Budgeting section explaining automatic estimation
- Added Fine-Tuning section for concurrency vs token budget guidance

## [0.6.0] - 2025-12-04

### Added

- **Context Caching Enhancements**
  - Cache creation now supports `system_instruction` parameter for setting
    system-level instructions that apply to all cached content usage
  - Cache creation now supports `tools` parameter for caching function
    declarations alongside content
  - Cache creation now supports `tool_config` parameter for configuring
    function calling behavior in cached contexts
  - Cache creation now supports `fileUri` in content parts for caching
    files stored in Google Cloud Storage (gs:// URIs)
  - Cache creation now supports `kms_key_name` parameter for customer-
    managed encryption keys (Vertex AI only)
  - Resource name normalization for Vertex AI automatically expands short
    cache names like "cachedContents/abc" to fully qualified paths like
    "projects/{project}/locations/{location}/cachedContents/abc"
  - Model name normalization for Vertex AI automatically expands model
    names to full publisher paths
  - Top-level cache API delegates added to main Gemini module:
    - `Gemini.create_cache/2` - Create cached content
    - `Gemini.list_caches/1` - List all cached contents
    - `Gemini.get_cache/2` - Retrieve cached content by name
    - `Gemini.update_cache/2` - Update cache TTL or expiration
    - `Gemini.delete_cache/2` - Delete cached content
  - `CachedContentUsageMetadata` struct expanded with Vertex AI specific
    fields: `audio_duration_seconds`, `image_count`, `text_count`, and
    `video_duration_seconds`
  - Model validation warning when using models that may not support
    explicit caching (models without version suffixes)
  - Live test covering `system_instruction` with `fileUri` caching

- **Auth-Aware Model Configuration System**
  - Model registry organized by API compatibility:
    - Universal models work identically in both Gemini API and Vertex AI
    - Gemini API models include convenience aliases like `-latest` suffix
    - Vertex AI models include EmbeddingGemma variants
  - Config.default_model/0 automatically selects appropriate model based
    on detected authentication:
    - Gemini API: `gemini-flash-lite-latest`
    - Vertex AI: `gemini-2.0-flash-lite`
  - Config.default_embedding_model/0 selects embedding model by auth:
    - Gemini API: `gemini-embedding-001` (3072 dimensions)
    - Vertex AI: `embeddinggemma` (768 dimensions)
  - Config.default_model_for/1 and Config.default_embedding_model_for/1
    for explicit API type selection
  - Config.models_for/1 returns all models available for a specific API
  - Config.model_available?/2 checks if a model key works with an API
  - Config.model_api/1 returns the API compatibility of a model key
  - Config.current_api_type/0 returns detected auth type
  - Embedding configuration system with per-model settings:
    - Config.embedding_config/1 returns full config for embedding models
    - Config.uses_prompt_prefix?/1 checks if model uses prompt prefixes
    - Config.embedding_prompt_prefix/2 generates task-specific prefixes
    - Config.default_embedding_dimensions/1 returns model default dims
    - Config.needs_normalization?/2 checks if manual normalization needed
  - EmbeddingGemma support with automatic prompt prefix formatting for
    task types (retrieval_query becomes "task: search result | query: ")

- **Test Infrastructure**
  - `Gemini.Test.ModelHelpers` module for centralized model references
  - `Gemini.Test.AuthHelpers` module for shared auth detection logic
  - Helper functions: `auth_available?/0`, `gemini_api_available?/0`,
    `vertex_api_available?/0`, `default_model/0`, `embedding_model/0`,
    `thinking_model/0`, `caching_model/0`, `universal_model/0`

### Changed

- `Auth.build_headers/2` now returns `{:ok, headers}` or `{:error, reason}`
  instead of always returning headers, enabling proper error propagation
- `Gemini.configure/2` now stores config under `:gemini` app environment
  to align with Config.auth_config/0 which reads from both :gemini
  and `:gemini_ex` namespaces
- `EmbedContentRequest.new/2` automatically formats text with prompt
  prefixes when using EmbeddingGemma models on Vertex AI
- All example scripts updated to use `Config.default_model()` instead of
  hardcoded model strings
- All tests updated to use auth-aware model selection via ModelHelpers
- Config module default model comment updated to explain auto-detection

### Fixed

- **Vertex AI Cache Endpoints**: Cache operations now build fully qualified
  paths (`projects/{project}/locations/{location}/cachedContents`) instead
  of calling `/cachedContents` directly, which was causing 404 errors
- **Config Alignment**: `Gemini.configure/2` now properly feeds config to
  Config.auth_config/0 by using the correct app environment key
- **Service Account Auth**: Removed placeholder tokens that masked real
  authentication failures; errors now propagate properly with descriptive
  messages
- **JWT Token Exchange**: Fixed OAuth2 JWT payload to include scope in the
  JWT claims as required by Google's jwt-bearer grant type specification
- **Content Formatting**: Part formatting now handles function calls,
  function responses, thought signatures, file data, and media resolution
  correctly instead of leaving them in snake_case struct format
- **Empty Env Vars**: Environment variable reading now treats empty strings
  as unset, preventing configuration issues with `GEMINI_API_KEY=""`
- **ContextCache.create/2**: Now accepts string content directly in
  addition to lists, matching README documentation examples
- **Model Prefix Handling**: Model name normalization no longer double-
  prefixes when callers pass `models/...` format

### Documentation

- README updated with enhanced context caching examples showing
  system_instruction, fileUri, and model selection
- README includes new Model Configuration System section explaining
  auth-aware defaults and API differences
- README includes embedding model differences table
- Config module documentation expanded with model registry explanation
- Implementation plan documents added in docs/20251204/

## [0.5.2] - 2025-12-03

### Fixed

- Fixed a regression where 429 responses lost their `http_status`, causing the rate limiter to misclassify them as permanent errors. API errors now preserve status and RetryInfo details so automatic backoff/RetryInfo delays are honored by default.

## [0.5.1] - 2025-12-03

### Added

#### Gemini 3 Pro Support

Full support for Google's Gemini 3 model family with new API features:

- **`thinking_level` Parameter** - New thinking control for Gemini 3 models
  - `GenerationConfig.thinking_level(:low)` - Fast responses, minimal reasoning
  - `GenerationConfig.thinking_level(:high)` - Deep reasoning (default for Gemini 3)
  - Note: `:medium` is not currently supported by the API
  - Cannot be used with `thinking_budget` in the same request (API returns 400)

- **`gemini-3-pro-image-preview` Model** - Image generation support
  - Generate images from text prompts
  - Configurable aspect ratios: "16:9", "1:1", "4:3", "3:4", "9:16"
  - Output resolutions: "2K" or "4K"
  - `GenerationConfig.image_config(aspect_ratio: "16:9", image_size: "4K")`

- **`media_resolution` Parameter** - Fine-grained vision processing control
  - `:low` - 280 tokens for images, 70 for video frames
  - `:medium` - 560 tokens for images, 70 for video frames
  - `:high` - 1120 tokens for images, 280 for video frames
  - `Part.inline_data_with_resolution(data, mime_type, :high)`
  - `Part.with_resolution(existing_part, :high)`

- **`thought_signature` Field** - Reasoning context preservation
  - Maintains reasoning context across API calls
  - Required for multi-turn function calling in Gemini 3
  - `Part.with_thought_signature(part, signature)`
  - SDK handles automatically in chat sessions
  - **NEW**: Automatic extraction via `Gemini.extract_thought_signatures/1`
  - **NEW**: Automatic echoing in `Chat.add_model_response/2`

- **Context Caching API** - Cache long context for improved performance
  - `Gemini.APIs.ContextCache.create/2` - Create cached content
  - `Gemini.APIs.ContextCache.list/1` - List cached contents
  - `Gemini.APIs.ContextCache.get/2` - Get specific cache
  - `Gemini.APIs.ContextCache.update/2` - Update cache TTL
  - `Gemini.APIs.ContextCache.delete/2` - Delete cache
  - Use with `cached_content: "cachedContents/id"` in generate requests
  - Minimum 4096 tokens required for caching

- **New Example**: `examples/gemini_3_demo.exs` - Comprehensive Gemini 3 features demonstration

#### Updated Validation

- `Gemini.Validation.ThinkingConfig` now validates Gemini 3's `thinking_level`
- Prevents combining `thinking_level` and `thinking_budget` (API constraint)
- Warns that `:medium` thinking level is not supported

### Changed

#### Embeddings Documentation Updates
- **Fixed EMBEDDINGS.md**: Corrected code examples and removed outdated/confusing information
  - Fixed incorrect module reference (`Coordinator.EmbedContentResponse` → `EmbedContentResponse`)
  - Removed confusing legacy model section (there's only `gemini-embedding-001` now)
  - Updated model comparison to reflect current API (single model with MRL support)
  - Updated async batch section with working code examples (was marked as "planned")
  - Added deprecation notice for `embedding-001`, `embedding-gecko-001`, `gemini-embedding-exp-03-07` (October 2025)

- **Updated embed_content_request.ex**: Removed deprecated model reference from documentation

### Fixed

- Documentation now accurately reflects the current Gemini Embeddings API specification (June 2025)
- Clarified that `gemini-embedding-001` is the only recommended model with full MRL support

### Migration Notes

#### For Gemini 3 Users

```elixir
# Use thinking_level instead of thinking_budget for Gemini 3
config = GenerationConfig.thinking_level(:low)  # Fast
config = GenerationConfig.thinking_level(:high) # Deep reasoning (default)

# Image generation
config = GenerationConfig.image_config(aspect_ratio: "16:9", image_size: "4K")
{:ok, response} = Coordinator.generate_content(
  "Generate an image of a sunset",
  model: "gemini-3-pro-image-preview",
  generation_config: config
)

# Media resolution for vision tasks
Part.inline_data_with_resolution(image_data, "image/jpeg", :high)
```

#### Temperature Recommendation

For Gemini 3, keep temperature at 1.0 (the default). Lower temperatures may cause
looping or degraded performance on complex reasoning tasks.

## [0.5.0] - 2025-12-03

### Added

#### Rate Limiting System (Default ON)

A comprehensive rate limiting, retry, and concurrency management system that is **enabled by default**:

- **RateLimitManager** - Central coordinator that wraps all outbound requests
  - ETS-based state tracking keyed by `{model, location, metric}`
  - Tracks `retry_until` timestamps from 429 RetryInfo responses
  - Token usage sliding windows for budget estimation
  - Configurable via application config or per-request options

- **ConcurrencyGate** - Per-model concurrency limiting
  - Default limit of 4 concurrent requests per model
  - Configurable with `max_concurrency_per_model` (nil/0 disables)
  - Optional adaptive mode: adjusts concurrency based on 429 responses
  - Non-blocking mode returns immediately if no permits available

- **RetryManager** - Intelligent retry with backoff
  - Honors 429 RetryInfo.retryDelay from API responses
  - Exponential backoff with jitter for 5xx/transient errors
  - Configurable max attempts (default: 3)
  - Coordinates with rate limiter to avoid double retries

- **TokenBudget** - Preflight token estimation
  - Track actual usage from responses
  - Block/queue when over configured budget
  - Sliding window tracking per model/location

#### Telemetry Events

New telemetry events for rate limit monitoring (consistent with existing `[:gemini, ...]` namespace):

- `[:gemini, :rate_limit, :request, :start]` - Request submitted
- `[:gemini, :rate_limit, :request, :stop]` - Request completed
- `[:gemini, :rate_limit, :wait]` - Waiting for retry window
- `[:gemini, :rate_limit, :error]` - Rate limit error

#### Structured Errors

New structured error types:

- `{:error, {:rate_limited, retry_at, details}}` - Rate limited with retry info
- `{:error, {:transient_failure, attempts, original_error}}` - Transient failure after retries

#### Configuration Options

```elixir
config :gemini_ex, :rate_limiter,
  max_concurrency_per_model: 4,    # nil/0 disables
  max_attempts: 3,
  base_backoff_ms: 1000,
  jitter_factor: 0.25,
  non_blocking: false,
  disable_rate_limiter: false,
  adaptive_concurrency: false,
  adaptive_ceiling: 8,
  profile: :prod  # :dev | :prod | :custom
```

#### Per-Request Options

- `disable_rate_limiter: true` - Bypass all rate limiting
- `non_blocking: true` - Return immediately if rate limited
- `max_concurrency_per_model: N` - Override concurrency
- `estimated_input_tokens: N` - For budget checking
- `token_budget_per_window: N` - Max tokens per window

#### Documentation

- New rate limiting guide: `docs/guides/rate_limiting.md`
- Comprehensive module documentation for all rate limiter components
- Updated README with rate limiting section

### Changed

- HTTP client now routes all requests through rate limiter by default
- Supervisor now starts RateLimitManager on application boot

### Technical Notes

- **Streaming Safe**: Rate limiter only gates request submission; open streams are not interrupted
- **Coordinate Retry Layers**: Retry logic coordinates between rate limiter and HTTP client to avoid double retries
- **Test Infrastructure**: Added Bypass-based fake Gemini endpoint for testing rate limit behavior

### Migration Guide

Rate limiting is enabled by default. To disable:

```elixir
# Per-request
Gemini.generate("Hello", disable_rate_limiter: true)

# Globally (not recommended)
config :gemini_ex, :rate_limiter, disable_rate_limiter: true
```

The new structured errors are backward compatible - existing error handling will continue to work, but you can now pattern match on rate limit specifics:

```elixir
case Gemini.generate("Hello") do
  {:ok, response} -> handle_success(response)
  {:error, {:rate_limited, retry_at, _}} -> schedule_retry(retry_at)
  {:error, other} -> handle_error(other)
end
```

## [0.4.0] - 2025-11-06

### Added

- **Structured Outputs Enhancement** - Full support for Gemini API November 2025 updates
  - `property_ordering` field in `GenerationConfig` for Gemini 2.0 model support
  - `structured_json/2` convenience helper for structured output setup
  - `property_ordering/2` helper for explicit property ordering
  - `temperature/2` helper for setting temperature values
  - Support for new JSON Schema keywords:
    - `anyOf` - Union types and conditional structures
    - `$ref` - Recursive schema definitions
    - `minimum`/`maximum` - Numeric value constraints
    - `additionalProperties` - Control over extra properties
    - `type: "null"` - Nullable field definitions
    - `prefixItems` - Tuple-like array structures
  - Comprehensive integration tests for structured outputs
  - Working examples demonstrating all new features

### Improved

- Enhanced documentation for structured outputs use cases
- Better code examples in README and API reference
- Expanded test coverage for generation config options

### Notes

- Gemini 2.5+ models preserve schema key order automatically
- Gemini 2.0 models require explicit `property_ordering` field
- All changes are backward compatible - no breaking changes

---

## [0.3.1] - 2025-10-15

### 🎉 Major Feature: Async Batch Embedding API (Phase 4)

This release adds production-scale async batch embedding support with 50% cost savings compared to the interactive API. Process thousands to millions of embeddings asynchronously with Long-Running Operation (LRO) support, state tracking, and priority management.

### Added

#### 🚀 Async Batch Embedding API
- **`async_batch_embed_contents/2`**: Submit large batches asynchronously for background processing
  - 50% cost savings vs interactive embedding API
  - Suitable for RAG system indexing, knowledge base building, and large-scale retrieval
  - Returns immediately with batch ID for polling
  - Support for inline requests with metadata tracking

- **`get_batch_status/1`**: Poll batch job status with progress tracking
  - Real-time progress metrics via `EmbedContentBatchStats`
  - State transitions: PENDING → PROCESSING → COMPLETED/FAILED
  - Track successful, failed, and pending request counts

- **`get_batch_embeddings/1`**: Retrieve results from completed batch jobs
  - Extract embeddings from inline responses
  - Support for file-based output detection
  - Automatic filtering of successful responses

- **`await_batch_completion/2`**: Convenience polling with configurable intervals
  - Automatic polling until completion or timeout
  - Progress callback support for monitoring
  - Configurable poll interval and timeout

#### 📊 Complete Type System
- **`BatchState`**: Job state enum (`:unspecified`, `:pending`, `:processing`, `:completed`, `:failed`, `:cancelled`)
- **`EmbedContentBatchStats`**: Request tracking with progress metrics
  - `progress_percentage/1`: Calculate completion percentage
  - `success_rate/1` and `failure_rate/1`: Quality metrics
  - `is_complete?/1`: Completion check

- **Request Types**:
  - `InlinedEmbedContentRequest`: Single request with metadata
  - `InlinedEmbedContentRequests`: Container for multiple requests
  - `InputEmbedContentConfig`: Union type for file vs inline input
  - `EmbedContentBatch`: Complete batch job request with priority

- **Response Types**:
  - `InlinedEmbedContentResponse`: Single response with success/error
  - `InlinedEmbedContentResponses`: Container with helper functions
  - `EmbedContentBatchOutput`: Union type for file vs inline output
  - `EmbedContentBatch`: Complete batch status with lifecycle tracking

#### 🧪 Comprehensive Test Coverage
- **41 new unit tests** for batch types (BatchState, BatchStats)
- Full TDD approach with test-first implementation
- **425 total tests passing** (up from 384 in v0.3.0)
- Zero compilation warnings maintained

### Technical Implementation

#### 🎯 Production Features
- **Long-Running Operations (LRO)**: Full async job lifecycle support
- **Priority-based Processing**: Control batch execution order with priority field
- **Progress Tracking**: Real-time stats on successful, failed, and pending requests
- **Multi-auth Support**: Works with both Gemini API and Vertex AI
- **Type Safety**: Complete `@spec` annotations for all new functions
- **Error Handling**: Comprehensive error messages and recovery paths

#### 📈 Performance & Cost
- **50% cost savings**: Async batch API offers half the cost of interactive embedding
- **Scalability**: Process millions of embeddings efficiently
- **Production-ready**: Designed for large-scale RAG systems and knowledge bases
- **Flexible polling**: Configurable intervals (default 5s) with timeout (default 10min)

### Usage Examples

```elixir
# Submit async batch for background processing
{:ok, batch} = Gemini.async_batch_embed_contents(
  ["Text 1", "Text 2", "Text 3"],
  display_name: "My Knowledge Base",
  task_type: :retrieval_document,
  output_dimensionality: 768
)

# Poll for status
{:ok, updated_batch} = Gemini.get_batch_status(batch.name)

# Check progress
if updated_batch.batch_stats do
  progress = updated_batch.batch_stats |> EmbedContentBatchStats.progress_percentage()
  IO.puts("Progress: #{Float.round(progress, 1)}%")
end

# Wait for completion (convenience function)
{:ok, completed_batch} = Gemini.await_batch_completion(
  batch.name,
  poll_interval: 10_000,  # 10 seconds
  timeout: 1_800_000,     # 30 minutes
  on_progress: fn b ->
    progress = EmbedContentBatchStats.progress_percentage(b.batch_stats)
    IO.puts("Progress: #{Float.round(progress, 1)}%")
  end
)

# Retrieve embeddings
{:ok, embeddings} = Gemini.get_batch_embeddings(completed_batch)
IO.puts("Retrieved #{length(embeddings)} embeddings")
```

### Changed

- **Enhanced `Coordinator` module**: Added async batch embedding functions alongside existing sync APIs
- **Type system expansion**: New types in `Gemini.Types.Request` and `Gemini.Types.Response` namespaces

### Migration Notes

#### For v0.3.0 Users
- All existing synchronous embedding APIs remain unchanged and fully compatible
- New async batch API is additive - no breaking changes
- Use async batch API for:
  - Large-scale embedding generation (1000s-millions of texts)
  - Background processing with 50% cost savings
  - RAG system indexing and knowledge base building
  - Non-time-critical embedding workflows

- Continue using sync API (`embed_content/2`, `batch_embed_contents/2`) for:
  - Real-time embedding needs
  - Small batches (<100 texts)
  - Interactive workflows requiring immediate results

### Future Enhancements

- File-based batch input/output support (GCS integration)
- Batch cancellation and deletion APIs
- Enhanced progress monitoring with estimated completion times

### Related Documentation

- **API Specification**: `oldDocs/docs/spec/GEMINI-API-07-EMBEDDINGS_20251014.md` (lines 129-442)
- **Implementation Plan**: `EMBEDDING_IMPLEMENTATION_PLAN.md` (Phase 4 section)

## [0.3.0] - 2025-10-14

### 🎉 Major Feature: Complete Embedding Support with MRL

This release adds comprehensive text embedding functionality with Matryoshka Representation Learning (MRL), enabling powerful semantic search, RAG systems, classification, and more.

### Added

#### 📊 Embedding API with Normalization & Distance Metrics
- **`ContentEmbedding.normalize/1`**: L2 normalization to unit length (required for non-3072 dimensions per API spec)
- **`ContentEmbedding.norm/1`**: Calculate L2 norm of embedding vectors
- **`ContentEmbedding.euclidean_distance/2`**: Euclidean distance metric for similarity
- **`ContentEmbedding.dot_product/2`**: Dot product similarity (equals cosine for normalized embeddings)
- **Enhanced `cosine_similarity/2`**: Improved documentation with normalization requirements

#### 🔬 Production-Ready Use Case Examples
- **`examples/use_cases/mrl_normalization_demo.exs`**: Comprehensive MRL demonstration
  - Quality vs storage tradeoffs across dimensions (128-3072)
  - MTEB benchmark comparison table
  - Normalization requirements and effects
  - Distance metrics comparison (cosine, euclidean, dot product)
  - Best practices for dimension selection

- **`examples/use_cases/rag_demo.exs`**: Complete RAG pipeline implementation
  - Build and index knowledge base with RETRIEVAL_DOCUMENT task type
  - Embed queries with RETRIEVAL_QUERY task type
  - Retrieve top-K relevant documents using semantic similarity
  - Generate contextually-aware responses
  - Side-by-side comparison with non-RAG baseline

- **`examples/use_cases/search_reranking.exs`**: Semantic reranking for search
  - E-commerce product search example
  - Compare keyword vs semantic ranking
  - Hybrid ranking strategy (keyword + semantic weighted)
  - Handle synonyms and conceptual relevance

- **`examples/use_cases/classification.exs`**: K-NN classification
  - Few-shot learning with minimal training examples
  - Customer support ticket categorization
  - Confidence scoring and accuracy evaluation
  - Dynamic category addition without retraining

#### 📚 Enhanced Documentation
- **Complete MRL documentation** in `examples/EMBEDDINGS.md`:
  - Matryoshka Representation Learning explanation
  - MTEB benchmark scores table (128d to 3072d)
  - Normalization requirements and best practices
  - Model comparison table (gemini-embedding-001 vs gemini-embedding-001)
  - Critical normalization warnings
  - Distance metrics usage guide

- **README.md embeddings section**:
  - Quick start guide for embeddings
  - MRL concepts and dimension selection
  - Task types for better quality
  - Batch embedding examples
  - Links to advanced use case examples

#### 🧪 Comprehensive Test Coverage
- **26 unit tests** for `ContentEmbedding` module:
  - Normalization accuracy (L2 norm = 1.0)
  - Distance metrics validation
  - Edge cases and error handling
  - Zero vector handling

- **20 integration tests** for embedding coordinator:
  - Single and batch embedding workflows
  - Task type variations
  - Output dimensionality control
  - Error scenarios

### Technical Implementation

#### 🎯 Key Features
- **MRL Support**: Flexible dimensions (128-3072) with minimal quality loss
  - 768d: 67.99 MTEB (25% storage, -0.26% loss) - **RECOMMENDED**
  - 1536d: 68.17 MTEB (50% storage, same as 3072d!)
  - 3072d: 68.17 MTEB (100% storage, pre-normalized)

- **Critical Normalization**: Only 3072-dimensional embeddings are pre-normalized by API
  - All other dimensions MUST be normalized before computing similarity
  - Cosine similarity focuses on direction (semantic meaning), not magnitude
  - Non-normalized embeddings have varying magnitudes that distort calculations

- **Production Quality**: 384 tests passing (100% success rate)
- **Type Safety**: Complete `@spec` annotations for all new functions
- **Code Quality**: Zero compilation warnings maintained

#### 📈 Performance Characteristics
- **Storage Efficiency**: 768d offers 75% storage savings with <0.3% quality loss
- **Quality Benchmarks**: MTEB scores prove minimal degradation across dimensions
- **Real-time Processing**: Efficient normalization and distance calculations

### Changed

- **Updated README.md**: Added embeddings section in features list and comprehensive usage guide
- **Enhanced EMBEDDINGS.md**: Complete rewrite with MRL documentation and advanced examples
- **Model Recommendations**: Updated to highlight `gemini-embedding-001` with MRL support

### Migration Notes

#### For New Users
```elixir
# Generate embedding with recommended 768 dimensions
{:ok, response} = Gemini.embed_content(
  "Your text",
  model: "gemini-embedding-001",
  output_dimensionality: 768
)

# IMPORTANT: Normalize before computing similarity!
alias Gemini.Types.Response.ContentEmbedding

normalized = ContentEmbedding.normalize(response.embedding)
similarity = ContentEmbedding.cosine_similarity(normalized, other_normalized)
```

#### Dimension Selection Guide
- **768d**: Best for most applications (storage/quality balance)
- **1536d**: High quality at 50% storage (same MTEB as 3072d)
- **3072d**: Maximum quality, pre-normalized (largest storage)
- **512d or lower**: Extreme efficiency (>1% quality loss)

### Future Roadmap

**v0.4.0 (Planned)**: Async Batch Embedding API
- Long-running operations (LRO) support
- 50% cost savings vs interactive embedding
- Batch state tracking and priority support

### Related Documentation

- **Comprehensive Guide**: `examples/EMBEDDINGS.md`
- **MRL Demo**: `examples/use_cases/mrl_normalization_demo.exs`
- **RAG Example**: `examples/use_cases/rag_demo.exs`
- **API Specification**: `oldDocs/docs/spec/GEMINI-API-07-EMBEDDINGS_20251014.md`

## [0.2.3] - 2025-10-08

### Fixed
- **CRITICAL: Double-encoding bug in multimodal content** - Fixed confusing base64 encoding behavior (Issue #11 comment from @jaimeiniesta)
  - **Problem**: When users passed `Base.encode64(image_data)` with `type: "base64"`, data was encoded AGAIN internally, causing double-encoding
  - **Symptom**: Users had to pass raw (non-encoded) data despite specifying `type: "base64"`, which was confusing and counterintuitive
  - **Root cause**: `Blob.new/2` always called `Base.encode64()`, even when data was already base64-encoded
  - **Fix**: When `source: %{type: "base64", data: ...}` is specified, data is now treated as already base64-encoded
  - **Impact**:
    - ✅ Users can now pass `Base.encode64(data)` as expected (documentation examples now work correctly)
    - ✅ API behavior matches user expectations: `type: "base64"` means data IS base64-encoded
    - ✅ Applies to both Anthropic-style format (`%{type: "image", source: %{type: "base64", ...}}`) and Gemini SDK style (`%{inline_data: %{data: ..., mime_type: ...}}`)
    - ⚠️  **Breaking change for workarounds**: If you were passing raw (non-encoded) data as a workaround, you must now pass properly base64-encoded data
  - Special thanks to @jaimeiniesta for reporting this confusing behavior!

### Changed
- Enhanced `normalize_single_content/1` to preserve base64 data without re-encoding when `type: "base64"`
- Enhanced `normalize_part/1` to preserve base64 data in `inline_data` maps
- Updated tests to verify correct base64 handling
- Added demonstration script: `examples/fixed_double_encoding_demo.exs`

## [0.2.2] - 2025-10-07

### Added
- **Flexible multimodal content input** - Accept multiple intuitive input formats for images and text (Closes #11)
  - Support Anthropic-style format: `%{type: "text", text: "..."}` and `%{type: "image", source: %{type: "base64", data: "..."}}`
  - Support map format with explicit role and parts: `%{role: "user", parts: [...]}`
  - Support simple string inputs: `"What is this?"`
  - Support mixed formats in single request
  - Automatic MIME type detection from image magic bytes (PNG, JPEG, GIF, WebP)
  - Graceful fallback to explicit MIME type or JPEG default

- **Thinking budget configuration** - Control thinking token usage for cost optimization (Closes #9, Supersedes #10)
  - `GenerationConfig.thinking_budget/2` - Set thinking token budget (0 to disable, -1 for dynamic, or fixed amount)
  - `GenerationConfig.include_thoughts/2` - Enable thought summaries in responses
  - `GenerationConfig.thinking_config/3` - Set both budget and thoughts in one call
  - `Gemini.Validation.ThinkingConfig` module - Model-aware budget validation
  - Support for all Gemini 2.5 series models (Pro, Flash, Flash Lite)

### Fixed
- **Multimodal content handling** - Users can now pass images and text in natural, intuitive formats
  - Previously: Only accepted specific `Content` structs, causing `FunctionClauseError`
  - Now: Accepts flexible formats and automatically normalizes them
  - Backward compatible: All existing code continues to work

- **CRITICAL: Thinking budget field names** - Fixed PR #10's critical bug that prevented thinking budget from working
  - Previously: Sent `thinking_budget` (snake_case) which API silently ignored, users still charged
  - Now: Sends `thinkingBudget` (camelCase) as required by official API, actually disables thinking
  - Added `includeThoughts` support that was missing from PR #10
  - Added model-specific budget validation (Pro: 128-32K, Flash: 0-24K, Lite: 0 or 512-24K)
  - Note: This supersedes PR #10 with a correct, fully-tested implementation

### Changed
- Enhanced `Coordinator.generate_content/2` to accept flexible content formats
- Added automatic content normalization layer
- Added `convert_thinking_config_to_api/1` to properly convert field names to camelCase
- `GenerationConfig.ThinkingConfig` is now a typed struct (not plain map)

## [Unreleased]

## [0.2.1] - 2025-08-08

### Added

- **ALTAR Integration Documentation**: Added detailed documentation for the `ALTAR` protocol integration, explaining the architecture and benefits of the new type-safe, production-grade tool-calling foundation.
- **ALTAR Version Update**: Bumped ALTAR dependency to v0.1.2.

## [0.2.0] - 2025-08-07

### 🎉 Major Feature: Automatic Tool Calling

This release introduces a complete, production-grade tool-calling (function calling) feature set, providing a seamless, Python-SDK-like experience for building powerful AI agents. The implementation is architected on top of the robust, type-safe `ALTAR` protocol for maximum reliability and future scalability.

### Added

#### 🤖 Automatic Tool Execution Engine
- **New Public API**: `Gemini.generate_content_with_auto_tools/2` orchestrates the entire multi-turn tool-calling loop. The library now automatically detects when a model wants to call a tool, executes it, sends the result back, and returns the final, synthesized text response.
- **Recursive Orchestrator**: A resilient, private orchestrator manages the conversation, preventing infinite loops with a configurable `:turn_limit`.
- **Streaming Support**: `Gemini.stream_generate_with_auto_tools/2` provides a fully automated tool-calling experience for streaming. A new `ToolOrchestrator` GenServer manages the complex, multi-stage stream, ensuring the end-user only receives the final text chunks.

#### 🔧 Manual Tool Calling Foundation (For Advanced Users)
- **New `Gemini.Tools` Facade**: Provides a clean, high-level API (`register/2`, `execute_calls/1`) for developers who need full control over the tool-calling loop.
- **Parallel Execution**: `Gemini.Tools.execute_calls/1` uses `Task.async_stream` to execute multiple tool calls from the model in parallel, improving performance.
- **Robust Error Handling**: Individual tool failures are captured as a valid `ToolResult` and do not crash the calling process.

#### 🏛️ Architectural Foundation (`ALTAR` Integration)
- **ALTAR Dependency**: The project now builds upon the `altar` library, using its robust Data Model (`ADM`) and Local Execution Runtime (`LATER`).
- **Supervised `Registry`**: `gemini_ex` now starts and supervises its own named `Altar.LATER.Registry` process (`Gemini.Tools.Registry`), providing a stable, application-wide endpoint for tool management.
- **Formalized `Gemini.Chat` Module**: The chat history management has been completely refactored into a new `Gemini.Chat` struct and module, providing immutable, type-safe handling of complex multi-turn histories that include `function_call` and `function_response` turns.

### Changed

- **`Part` Struct:** The `Gemini.Types.Part` struct was updated to include a `function_call` field, enabling type-safe parsing of model responses.
- **Response Parsing:** The core response parser in `Gemini.Generate` has been significantly enhanced to safely deserialize `functionCall` parts from the API, validating them against the `Altar.ADM` contract.
- **Chat History:** The `Gemini.send_message/2` function has been refactored to use the new, more powerful `Gemini.Chat` module.

### Fixed

- **CRITICAL: Tool Response Role:** The role for `functionResponse` turns sent to the API is now correctly set to `"tool"` (was `"user"`), ensuring API compatibility.
- **Architectural Consistency:** Removed an erroneous `function_response` field from the `Part` struct. `functionResponse` parts are now correctly handled as raw maps, consistent with the library's design.
- **Test Consistency:** Updated all relevant tests to use `camelCase` string keys when asserting against API-formatted data structures, improving test accuracy.

### 📚 Documentation & Examples
- **New Example (`auto_tool_calling_demo.exs`):** A comprehensive script demonstrating how to register multiple tools and use the new automatic execution APIs for both standard and streaming requests.
- **New Example (`manual_tool_calling_demo.exs`):** A clear demonstration of the advanced, step-by-step manual tool-calling loop.

## [0.1.1] - 2025-08-03

### 🐛 Fixed

#### Generation Config Bug Fix
- **Critical Fix**: Fixed `GenerationConfig` options being dropped in `Gemini.APIs.Coordinator` module
  - Previously, only 4 basic options (`temperature`, `max_output_tokens`, `top_p`, `top_k`) were supported
  - Now supports all 12 `GenerationConfig` fields including `response_schema`, `response_mime_type`, `stop_sequences`, etc.
  - Fixed inconsistency between `Gemini.Generate` and `Gemini.APIs.Coordinator` modules
  - Both modules now handle generation config options identically

#### Enhanced Generation Config Support
- **Complete Field Coverage**: Added support for all missing `GenerationConfig` fields:
  - `response_schema` - For structured JSON output
  - `response_mime_type` - For controlling output format
  - `stop_sequences` - For custom stop sequences
  - `candidate_count` - For multiple response candidates
  - `presence_penalty` - For controlling topic repetition
  - `frequency_penalty` - For controlling word repetition
  - `response_logprobs` - For response probability logging
  - `logprobs` - For token probability information

#### Improved Request Building
- **Struct Priority**: `GenerationConfig` structs now take precedence over individual keyword options
- **Key Conversion**: Proper snake_case to camelCase conversion for all API fields
- **Nil Filtering**: Automatic filtering of nil values to reduce request payload size
- **Backward Compatibility**: Existing code using individual options continues to work unchanged

### 🧪 Testing

#### Comprehensive Test Coverage
- **70 New Tests**: Added extensive test suite covering all generation config scenarios
- **Bug Reproduction**: Tests that demonstrate the original bug and verify the fix
- **Field Coverage**: Individual tests for each of the 12 generation config fields
- **Integration Testing**: End-to-end tests with real API request structure validation
- **Regression Prevention**: Tests ensure the bug cannot reoccur in future versions

#### Test Categories Added
- Individual option handling tests
- GenerationConfig struct handling tests
- Mixed option scenarios (struct + individual options)
- Edge case handling (nil values, invalid types)
- API request structure validation
- Backward compatibility verification

### 🔧 Technical Improvements

#### Code Quality
- **Helper Functions**: Added `convert_to_camel_case/1` and `struct_to_api_map/1` utilities
- **Error Handling**: Improved validation and error messages for generation config
- **Documentation**: Enhanced inline documentation for generation config handling
- **Type Safety**: Maintained strict type checking while expanding functionality

#### Performance
- **Request Optimization**: Reduced API request payload size by filtering nil values
- **Processing Efficiency**: Streamlined generation config building process
- **Memory Usage**: More efficient handling of large GenerationConfig structs

### 📚 Documentation

#### Updated Examples
- Enhanced examples to demonstrate new generation config capabilities
- Added response schema examples for structured output
- Updated documentation to reflect consistent behavior across modules

### Migration Notes

#### For Existing Users
No breaking changes - all existing code continues to work. However, you can now use previously unsupported options:

```elixir
# These options now work in all modules:
{:ok, response} = Gemini.generate("Explain AI", [
  response_schema: %{"type" => "object", "properties" => %{"summary" => %{"type" => "string"}}},
  response_mime_type: "application/json",
  stop_sequences: ["END", "STOP"],
  presence_penalty: 0.5,
  frequency_penalty: 0.3
])

# GenerationConfig structs now work consistently:
config = %Gemini.Types.GenerationConfig{
  temperature: 0.7,
  response_schema: %{"type" => "object"},
  max_output_tokens: 1000
}
{:ok, response} = Gemini.generate("Hello", generation_config: config)
```

## [0.1.0] - 2025-07-20

### 🎉 Major Release - Production Ready Multi-Auth Implementation

This is a significant milestone release featuring a complete unified implementation with concurrent multi-authentication support, enhanced examples, and production-ready telemetry system.

### Added

#### 🔐 Multi-Authentication Coordinator
- **Concurrent Auth Support**: Enable simultaneous usage of Gemini API and Vertex AI authentication strategies
- **Per-request Auth Selection**: Choose authentication method on a per-request basis
- **Authentication Strategy Routing**: Automatic credential resolution and header generation
- **Enhanced Configuration**: Improved config system with better environment variable detection

#### 🌊 Unified Streaming Manager  
- **Multi-auth Streaming**: Streaming support across both authentication strategies
- **Advanced Stream Management**: Preserve excellent SSE parsing while adding auth routing
- **Stream Lifecycle Control**: Complete stream state management (start, pause, resume, stop)
- **Event Subscription System**: Enhanced event handling with proper filtering

#### 🎯 Comprehensive Examples Suite
- **`telemetry_showcase.exs`**: Complete telemetry system demonstration with 7 event types
- **Enhanced `demo.exs`**: Updated with better chat sessions and API key masking
- **Enhanced `streaming_demo.exs`**: Real-time streaming with authentication detection
- **Enhanced `multi_auth_demo.exs`**: Concurrent authentication strategies with proper error handling
- **Enhanced `demo_unified.exs`**: Multi-auth architecture showcase
- **Enhanced `live_api_test.exs`**: Comprehensive API testing for both auth methods

#### 📊 Advanced Telemetry System
- **7 Event Types**: request start/stop/exception, stream start/chunk/stop/exception  
- **Helper Functions**: Stream ID generation, content classification, metadata building
- **Performance Monitoring**: Live measurement and analysis capabilities
- **Configuration Management**: Telemetry enable/disable controls

#### 🔧 API Enhancements
- **Backward Compatibility Functions**: Added missing functions (`model_exists?`, `stream_generate`, `start_link`)
- **Response Normalization**: Proper key conversion (`totalTokens` → `total_tokens`, `displayName` → `display_name`)
- **Enhanced Error Handling**: Better error formatting and recovery
- **Content Extraction**: Support for both struct and raw streaming data formats

### Changed

#### 🏗️ Architecture Improvements
- **Type System**: Resolved module conflicts and compilation warnings
- **Configuration**: Updated default model to `gemini-flash-lite-latest` 
- **Code Quality**: Zero compilation warnings achieved across entire codebase
- **Documentation**: Updated model references and improved examples

#### 🔄 Example Organization
- **Removed Legacy Examples**: Cleaned up `simple_test.exs`, `simple_telemetry_test.exs`, `telemetry_demo.exs`
- **Consistent Execution Pattern**: All examples use `mix run examples/[name].exs`
- **Better Error Handling**: Graceful credential failure handling with informative messages
- **Security**: API key masking in output for better security

#### 📝 Documentation Updates
- **README Enhancement**: Added comprehensive examples section with detailed descriptions
- **Model Updates**: Updated references to the latest Gemini models (Gemini 3 Pro Preview, 2.5 Flash/Flash-Lite) and new defaults
- **Configuration Examples**: Improved auth setup documentation
- **Usage Patterns**: Better code examples and patterns

### Fixed

#### 🐛 Critical Fixes
- **Type Module Conflicts**: Resolved duplicate module definitions preventing compilation
- **Chat Session Context**: Fixed `send_message` to properly handle `[Content.t()]` arrays
- **Streaming Debug**: Fixed undefined variables in demo scripts
- **Response Parsing**: Enhanced `build_generate_request` to support multiple content formats

#### 🔧 Minor Improvements
- **Function Coverage**: Implemented all missing backward compatibility functions
- **Token Counting**: Fixed response key normalization for proper token count extraction
- **Stream Management**: Improved stream event collection and display
- **Error Messages**: Better error formatting and user-friendly messages

### Technical Implementation

#### 🏛️ Production Architecture
- **154 Tests Passing**: Complete test coverage with zero failures
- **Multi-auth Foundation**: Robust concurrent authentication system
- **Advanced Streaming**: Real-time SSE with 30-117ms performance
- **Type Safety**: Complete `@spec` annotations and proper error handling
- **Zero Warnings**: Clean compilation across entire codebase

#### 📦 Dependencies
- Maintained stable dependency versions for production reliability
- Enhanced configuration system compatibility
- Improved telemetry integration

### Migration Guide

#### For Existing Users
```elixir
# Old single-auth pattern (still works)
{:ok, response} = Gemini.generate("Hello")

# New multi-auth capability
{:ok, gemini_response} = Gemini.generate("Hello", auth: :gemini)
{:ok, vertex_response} = Gemini.generate("Hello", auth: :vertex_ai)
```

#### Configuration Updates
```elixir
# Enhanced configuration with auto-detection
config :gemini_ex,
  default_model: "gemini-flash-lite-latest",  # Updated default
  timeout: 30_000,
  telemetry_enabled: true  # New telemetry controls
```

### Performance

- **Real-time Streaming**: 30-117ms chunk delivery performance
- **Concurrent Authentication**: Simultaneous multi-strategy usage
- **Zero Compilation Warnings**: Optimized build performance
- **Memory Efficient**: Enhanced streaming with proper backpressure

### Security

- **Credential Masking**: API keys masked in all output for security
- **Multi-auth Isolation**: Secure credential separation between strategies
- **Error Handling**: No sensitive data in error messages

## [0.0.3] - 2025-07-07

### Fixed
- **API Response Parsing**: Fixed issue where `usage_metadata` was always nil on successful `Gemini.generate/2` calls ([#3](https://github.com/nshkrdotcom/gemini_ex/issues/3))
  - The Gemini API returns camelCase keys like `"usageMetadata"` which were not being converted to snake_case atoms
  - Updated `atomize_key` function in coordinator to properly convert camelCase strings to snake_case atoms
  - Now properly populates `usage_metadata` with token count information
- **Chat Sessions**: Fixed conversation context not being maintained between messages
  - The `send_message` function was only sending the new message, not the full conversation history
  - Now builds complete conversation history with proper role assignments before each API call
  - Ensures AI maintains context and remembers information from previous messages

## [0.0.2] - 2025-06-09

### Fixed
- **Documentation Rendering**: Fixed mermaid diagram rendering errors on hex docs by removing emoji characters from diagram labels
- **Package Links**: Removed redundant "Documentation" link in hex package configuration, keeping only "Online documentation"
- **Configuration References**: Updated TELEMETRY_IMPLEMENTATION.md to reference `:gemini_ex` instead of `:gemini` for correct application configuration

### Changed
- Improved hex docs compatibility for better rendering of documentation diagrams
- Enhanced documentation consistency across all markdown files

## [0.0.1] - 2025-06-09

### Added

#### Core Features
- **Dual Authentication System**: Support for both Gemini API keys and Vertex AI OAuth/Service Accounts
- **Advanced Streaming**: Production-grade Server-Sent Events (SSE) streaming with real-time processing
- **Comprehensive API Coverage**: Full support for Gemini API endpoints including content generation, model listing, and token counting
- **Type Safety**: Complete TypeScript-style type definitions with runtime validation
- **Error Handling**: Detailed error types with recovery suggestions and proper HTTP status code mapping
- **Built-in Telemetry**: Comprehensive observability with metrics and event tracking
- **Chat Sessions**: Multi-turn conversation management with state persistence
- **Multimodal Support**: Text, image, audio, and video content processing

#### Authentication
- Multi-strategy authentication coordinator with automatic strategy selection
- Environment variable and application configuration support
- Per-request authentication override capabilities
- Secure credential management with validation
- Support for Google Cloud Service Account JSON files
- OAuth2 Bearer token generation for Vertex AI

#### Streaming Architecture
- Unified streaming manager with state management
- Real-time SSE parsing with event dispatching
- Configurable buffer management and backpressure handling
- Stream lifecycle management (start, pause, resume, stop)
- Event subscription system with filtering capabilities
- Comprehensive error recovery and retry mechanisms

#### HTTP Client
- Dual HTTP client system (standard and streaming)
- Request/response interceptors for middleware support
- Automatic retry logic with exponential backoff
- Connection pooling and timeout management
- Request validation and response parsing
- Content-Type negotiation and encoding support

#### Type System
- Comprehensive type definitions for all API structures
- Runtime type validation with descriptive error messages
- Request and response schema validation
- Content type definitions for multimodal inputs
- Model capability and configuration types
- Error type hierarchy with actionable information

#### Configuration
- Hierarchical configuration system (runtime > environment > application)
- Environment variable detection and parsing
- Application configuration validation
- Default value management
- Configuration hot-reloading support

#### Utilities
- Content extraction helpers
- Response transformation utilities
- Validation helpers
- Debugging and logging utilities
- Performance monitoring tools

### Technical Implementation

#### Architecture
- Layered architecture with clear separation of concerns
- Behavior-driven design for pluggable components
- GenServer-based application supervision tree
- Concurrent request processing with actor model
- Event-driven streaming with backpressure management

#### Dependencies
- `req` ~> 0.4.0 for HTTP client functionality
- `jason` ~> 1.4 for JSON encoding/decoding
- `typed_struct` ~> 0.3.0 for type definitions
- `joken` ~> 2.6 for JWT handling in Vertex AI authentication
- `telemetry` ~> 1.2 for observability and metrics

#### Development Tools
- `ex_doc` for comprehensive documentation generation
- `credo` for code quality analysis
- `dialyxir` for static type analysis

### Documentation
- Complete API reference documentation
- Architecture documentation with Mermaid diagrams
- Authentication system technical specification
- Getting started guide with examples
- Advanced usage patterns and best practices
- Error handling and troubleshooting guide

### Security
- Secure credential storage and transmission
- Input validation and sanitization
- Rate limiting and throttling support
- SSL/TLS enforcement for all communications
- No sensitive data logging

### Performance
- Optimized for high-throughput scenarios
- Memory-efficient streaming implementation
- Connection reuse and pooling
- Minimal latency overhead
- Concurrent request processing

[0.7.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.7.0
[0.6.4]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.6.4
[0.6.3]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.6.3
[0.6.2]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.6.2
[0.6.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.6.1
[0.6.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.6.0
[0.5.2]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.5.2
[0.5.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.5.1
[0.5.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.5.0
[0.4.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.4.0
[0.3.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.3.1
[0.3.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.3.0
[0.2.3]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.2.3
[0.2.2]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.2.2
[0.2.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.2.1
[0.2.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.2.0
[0.1.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.1.1
[0.1.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.1.0
[0.0.3]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.3
[0.0.2]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.2
[0.0.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.1
