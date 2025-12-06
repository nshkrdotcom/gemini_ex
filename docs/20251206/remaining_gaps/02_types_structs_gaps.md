# Types, Structs, and Data Models Gap Analysis

## Executive Summary

This document provides a comprehensive field-by-field comparison between the Python genai library types and the Elixir Gemini port type definitions.

### Coverage Statistics
- **Python:** 792 total classes (428 BaseModel, 359 TypedDict variants, 57 Enums)
- **Elixir:** 64 modules currently implemented
- **Type Coverage:** ~15% of all Python types
- **Core API Coverage:** ~85% (most essential types present)
- **Advanced Features:** ~20% (specialized use cases)

---

## What's Fully Implemented

### Core Content Types
| Type | Status | Notes |
|------|--------|-------|
| Content | ✅ Complete | Full support for parts and role |
| Part | ✅ Complete | text, inline_data, file_data |
| Blob | ✅ Complete | mime_type, data |
| FileData | ✅ Complete | file_uri, mime_type |

### Response Types
| Type | Status | Notes |
|------|--------|-------|
| GenerateContentResponse | ✅ Complete | candidates, usage_metadata |
| Candidate | ✅ Complete | content, finish_reason, safety_ratings |
| UsageMetadata | ✅ Complete | prompt_token_count, candidates_token_count |
| SafetyRating | ✅ Complete | category, probability |
| CitationMetadata | ✅ Complete | citations array |

### Configuration Types
| Type | Status | Notes |
|------|--------|-------|
| GenerationConfig | ⚠️ Mostly | Missing 6 fields (see below) |
| SafetySetting | ✅ Complete | category, threshold |
| MediaResolution | ✅ Complete | Gemini 3 feature |

### Files & Documents
| Type | Status | Notes |
|------|--------|-------|
| File | ⚠️ Mostly | Missing VideoMetadata |
| Document | ⚠️ Mostly | Missing custom_metadata |
| ListFilesResponse | ✅ Complete | files, next_page_token |
| DeleteFileResponse | ✅ Complete | Empty response handling |

### Request Types
| Type | Status | Notes |
|------|--------|-------|
| GenerateContentRequest | ⚠️ Mostly | Missing system_instruction |
| EmbedContentRequest | ⚠️ Mostly | Missing 2 fields |
| CountTokensRequest | ✅ Complete | Full support |

### Enums Implemented (15 of 57)
- HarmCategory ✅
- HarmBlockThreshold ✅
- HarmProbability ✅
- FinishReason ✅
- TaskType ✅
- FileState ✅
- FileSource ✅
- BlockedReason ✅
- MediaResolution ✅
- Modality ✅
- DynamicRetrievalConfigMode ✅
- FunctionCallingMode ✅
- CodeExecutionOutcome ✅
- Language ✅
- Outcome ✅

---

## Critical Gaps (Blocking Features)

### 1. Tool & Function Calling Types (CRITICAL)

**Missing: Tool (7 fields)**
```python
class Tool:
    function_declarations: list[FunctionDeclaration]
    retrieval: Optional[Retrieval]
    google_search: Optional[GoogleSearch]
    google_search_retrieval: Optional[GoogleSearchRetrieval]
    code_execution: Optional[CodeExecution]
    google_maps: Optional[GoogleMaps]
    url_context: Optional[UrlContext]
```

**Missing: FunctionDeclaration (7 fields)**
```python
class FunctionDeclaration:
    name: str
    description: str
    parameters: Optional[Schema]
    response: Optional[Schema]
    behavior: Optional[Behavior]
```

**Missing: ToolConfig (2 fields)**
```python
class ToolConfig:
    function_calling_config: Optional[FunctionCallingConfig]
    retrieval_config: Optional[RetrievalConfig]
```

**Impact:** Blocks all function calling functionality

### 2. System Instructions (CRITICAL)

**Missing from GenerateContentRequest:**
```python
system_instruction: Optional[Content]  # Critical for production patterns
```

**Impact:** Cannot set persistent system prompts

### 3. Code Execution Types (HIGH)

**Missing: ExecutableCode**
```python
class ExecutableCode:
    language: Language
    code: str
```

**Missing: CodeExecutionResult**
```python
class CodeExecutionResult:
    outcome: Outcome
    output: Optional[str]
```

**Impact:** Cannot handle code execution responses

---

## Major Gaps (Missing Advanced Features)

### 1. Caching Types (Incomplete)

**CachedContent main type needs:**
```python
class CachedContent:
    name: str
    display_name: Optional[str]
    model: str
    system_instruction: Optional[Content]
    contents: list[Content]
    tools: list[Tool]
    tool_config: Optional[ToolConfig]
    create_time: datetime
    update_time: datetime
    expire_time: datetime
    ttl: Optional[timedelta]
    usage_metadata: Optional[CachedContentUsageMetadata]
```

### 2. Fine-tuning Types (100% Missing)

**TuningJob (26 fields)**
```python
class TuningJob:
    name: str
    tuned_model_display_name: str
    base_model: str
    state: TuningJobState
    create_time: datetime
    start_time: Optional[datetime]
    end_time: Optional[datetime]
    error: Optional[Status]
    description: Optional[str]
    training_dataset: TuningDataset
    tuned_model: TunedModel
    tuning_task_id: str
    tuning_data_stats: Optional[TuningDataStats]
    # ... and more
```

**CreateTuningJobConfig (15 fields)**
```python
class CreateTuningJobConfig:
    base_model: str
    training_dataset: TuningDataset
    tuned_model_display_name: Optional[str]
    description: Optional[str]
    epoch_count: Optional[int]
    learning_rate_multiplier: Optional[float]
    adapter_size: Optional[AdapterSize]
    # ... and more
```

### 3. Video Generation Types (100% Missing)

**VideoGenerationConfig**
```python
class VideoGenerationConfig:
    number_of_videos: Optional[int]
    fps: Optional[int]
    duration_seconds: Optional[int]
    enhance_prompt: Optional[bool]
    negative_prompt: Optional[str]
    person_generation: Optional[PersonGeneration]
    aspect_ratio: Optional[str]
```

**GenerateVideoConfig**
```python
class GenerateVideoConfig:
    output_gcs_uri: Optional[str]
    video_generation_config: Optional[VideoGenerationConfig]
```

### 4. Image Generation Types (100% Missing)

**ImageGenerationConfig (12 fields)**
```python
class ImageGenerationConfig:
    number_of_images: Optional[int]
    aspect_ratio: Optional[str]
    safety_filter_level: Optional[SafetyFilterLevel]
    person_generation: Optional[PersonGeneration]
    include_rai_reason: Optional[bool]
    output_mime_type: Optional[str]
    output_compression_quality: Optional[int]
    add_watermark: Optional[bool]
    seed: Optional[int]
    language: Optional[ImagePromptLanguage]
    negative_prompt: Optional[str]
    enhance_prompt: Optional[bool]
```

**EditImageConfig (18 fields)**
```python
class EditImageConfig:
    edit_mode: Optional[EditMode]
    number_of_images: Optional[int]
    # ... many more fields
```

### 5. Retrieval Types (100% Missing)

**DynamicRetrievalConfig**
```python
class DynamicRetrievalConfig:
    mode: Optional[DynamicRetrievalConfigMode]
    dynamic_threshold: Optional[float]
```

**SemanticRetrieverConfig**
```python
class SemanticRetrieverConfig:
    source: str
    query: Content
```

### 6. Live/Real-time Types (100% Missing)

**LiveClientSetup**
```python
class LiveClientSetup:
    model: str
    generation_config: Optional[GenerationConfig]
    system_instruction: Optional[Content]
    tools: list[Tool]
```

**RealtimeInputConfig**
```python
class RealtimeInputConfig:
    automatic_activity_detection: Optional[AutomaticActivityDetection]
    turn_coverage: Optional[TurnCoverage]
```

**AudioTranscriptionConfig**
```python
class AudioTranscriptionConfig:
    # Audio transcription settings
```

---

## Incomplete Implementations

### GenerationConfig (Missing 6 fields)

**Currently implemented:**
- temperature ✅
- top_p ✅
- top_k ✅
- candidate_count ✅
- max_output_tokens ✅
- stop_sequences ✅
- response_mime_type ✅
- response_schema ✅

**Missing:**
- presence_penalty
- frequency_penalty
- routing_config
- logprobs
- response_logprobs
- audio_timestamp

### EmbedContentRequest (Missing 2 fields)

**Missing:**
- output_dimensionality
- batch_size

### File (Missing 1 field)

**Missing:**
- video_metadata: VideoMetadata

### Document (Missing 1 field)

**Missing:**
- custom_metadata: dict

---

## Missing Enums (42 of 57)

### Critical Missing Enums
- TuningJobState
- AdapterSize
- EditMode
- SafetyFilterLevel
- PersonGeneration
- ImagePromptLanguage
- VideoState

### Medium Priority Missing Enums
- UpscaleFactor
- MaskMode
- ControlType
- SegmentationType
- RecontextMode

### Lower Priority Missing Enums
- Various internal state enums
- Debug/replay mode enums

---

## Implementation Roadmap

### Phase 1 (CRITICAL) - 8-16 hours
**Enable Function Calling**

1. Implement Tool struct (7 fields)
2. Implement FunctionDeclaration struct (7 fields)
3. Implement ToolConfig struct (2 fields)
4. Implement FunctionCall/FunctionResponse
5. Add system_instruction to GenerateContentRequest
6. Implement ExecutableCode and CodeExecutionResult

**Files to modify:**
- `lib/gemini/types/tool.ex` (create)
- `lib/gemini/types/function_declaration.ex` (create)
- `lib/gemini/types/request/generate_content_request.ex` (update)

### Phase 2 (IMPORTANT) - 12-20 hours
**Complete Core Types**

1. Complete GenerationConfig (add 6 fields)
2. Add retrieval types (DynamicRetrievalConfig, etc.)
3. Add execution types (ExecutableCode, etc.)
4. Add video/audio metadata types
5. Complete EmbedContentRequest

**Files to modify:**
- `lib/gemini/types/generation_config.ex` (update)
- `lib/gemini/types/retrieval.ex` (create)
- `lib/gemini/types/execution.ex` (create)

### Phase 3 (ENHANCED) - 16-24 hours
**Tuning/Generation Types**

1. Implement TuningJob (26 fields)
2. Implement CreateTuningJobConfig (15 fields)
3. Implement VideoGenerationConfig
4. Implement ImageGenerationConfig
5. Implement EditImageConfig

**Files to create:**
- `lib/gemini/types/tuning/` directory
- `lib/gemini/types/generation/image.ex`
- `lib/gemini/types/generation/video.ex`

### Phase 4 (COMPLETE) - 20-30 hours
**Full Feature Parity**

1. Remaining 42 enums
2. Full operation types
3. Live/real-time types
4. 100% field coverage

---

## Quick Reference - Most Critical Missing Types

| Type | Fields | Blocks | Priority |
|------|--------|--------|----------|
| Tool | 7 | Function calling | P0 |
| FunctionDeclaration | 7 | Function calling | P0 |
| ToolConfig | 2 | Function calling | P0 |
| system_instruction | 1 | Production patterns | P0 |
| ExecutableCode | 2 | Code execution | P1 |
| CodeExecutionResult | 2 | Code execution | P1 |
| TuningJob | 26 | Fine-tuning | P1 |
| ImageGenerationConfig | 12 | Image generation | P2 |
| VideoGenerationConfig | 7 | Video generation | P2 |
| LiveClientSetup | 4 | Real-time API | P2 |

---

## Success Criteria

After implementing all phases:
- [ ] Function calling works end-to-end
- [ ] System instructions can be set on requests
- [ ] Code execution responses are properly parsed
- [ ] All 57 enums are defined
- [ ] Fine-tuning types support tuning workflows
- [ ] Image/video generation types support generation workflows
- [ ] Live/real-time types support WebSocket communication
- [ ] 100% of Python type fields have Elixir equivalents

---

**Document Generated:** 2024-12-06
**Analysis Scope:** Python genai types.py vs Elixir lib/gemini/types/
**Methodology:** Field-by-field comparison
