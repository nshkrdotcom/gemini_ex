# Missing Fields Analysis: Python genai SDK vs gemini_ex

**Date:** 2025-12-05
**Python SDK Path:** `/home/home/p/g/n/gemini_ex/python-genai/`
**gemini_ex Path:** `/home/home/p/g/n/gemini_ex/`

## Executive Summary

This document provides a comprehensive comparison of request types and configuration objects between the Python genai SDK and gemini_ex (Elixir). It identifies all missing fields, their types, descriptions, and implementation priorities.

**Total Missing Fields:** 25+
**Critical Missing:** 12
**Medium Priority:** 8
**Low Priority (Vertex AI only):** 5+

---

## Table of Contents

1. [GenerationConfig Missing Fields](#1-generationconfig-missing-fields)
2. [ThinkingConfig Missing Fields](#2-thinkingconfig-missing-fields)
3. [GenerateContentConfig/Request Missing Fields](#3-generatecontentconfig-missing-fields)
4. [SafetySetting Missing Fields](#4-safetysetting-missing-fields)
5. [ToolConfig Missing Fields](#5-toolconfig-missing-fields)
6. [FunctionCallingConfig Missing Fields](#6-functioncallingconfig-missing-fields)
7. [SpeechConfig Missing Fields](#7-speechconfig-missing-fields)
8. [Supporting Types Missing](#8-supporting-types-missing)
9. [Implementation Roadmap](#9-implementation-roadmap)
10. [Code Examples](#10-code-examples)

---

## 1. GenerationConfig Missing Fields

### 1.1 Current State

**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` (lines 9160-9247)
**gemini_ex Location:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`

### 1.2 Comparison Table

| Field Name | Python SDK Type | gemini_ex Status | Priority | Notes |
|------------|-----------------|------------------|----------|-------|
| `stop_sequences` | `list[str]` | ✅ Present | - | - |
| `response_mime_type` | `str` | ✅ Present | - | - |
| `response_schema` | `Schema` | ✅ Present | - | - |
| `candidate_count` | `int` | ✅ Present | - | - |
| `max_output_tokens` | `int` | ✅ Present | - | - |
| `temperature` | `float` | ✅ Present | - | - |
| `top_p` | `float` | ✅ Present | - | - |
| `top_k` | `float` | ✅ Present | - | - |
| `presence_penalty` | `float` | ✅ Present | - | - |
| `frequency_penalty` | `float` | ✅ Present | - | - |
| `response_logprobs` | `bool` | ✅ Present | - | - |
| `logprobs` | `int` | ✅ Present | - | - |
| `thinking_config` | `ThinkingConfig` | ✅ Present | - | - |
| `image_config` | `ImageConfig` | ✅ Present | - | - |
| **`model_selection_config`** | `ModelSelectionConfig` | ❌ **MISSING** | **HIGH** | Model routing/selection |
| **`response_json_schema`** | `Any` | ❌ **MISSING** | **HIGH** | Alternative JSON schema format |
| **`audio_timestamp`** | `bool` | ❌ **MISSING** | **MEDIUM** | Audio timestamp support |
| **`enable_affective_dialog`** | `bool` | ❌ **MISSING** | **LOW** | Vertex AI only |
| **`media_resolution`** | `MediaResolution` enum | ❌ **MISSING** | **HIGH** | Image/video token resolution |
| **`response_modalities`** | `list[Modality]` | ❌ **MISSING** | **CRITICAL** | Multi-modal output control |
| **`routing_config`** | `GenerationConfigRoutingConfig` | ❌ **MISSING** | **LOW** | Vertex AI only |
| **`seed`** | `int` | ❌ **MISSING** | **CRITICAL** | Deterministic generation |
| **`speech_config`** | `SpeechConfig` | ❌ **MISSING** | **CRITICAL** | Audio output configuration |
| **`enable_enhanced_civic_answers`** | `bool` | ❌ **MISSING** | **LOW** | Gemini API only |

### 1.3 Detailed Missing Fields

#### 1.3.1 `model_selection_config` (HIGH PRIORITY)

**Type:** `ModelSelectionConfig`
**Description:** Config for model selection based on feature preferences.

**Python Definition:**
```python
model_selection_config: Optional[ModelSelectionConfig] = Field(
    default=None,
    description="Optional. Config for model selection."
)
```

**ModelSelectionConfig Structure:**
```python
class ModelSelectionConfig:
    feature_selection_preference: Optional[FeatureSelectionPreference]
    # FeatureSelectionPreference values:
    # - FEATURE_SELECTION_PREFERENCE_UNSPECIFIED
    # - PRIORITIZE_QUALITY
    # - BALANCED
    # - PRIORITIZE_COST
```

**Use Case:** Allows automatic model selection based on quality/cost tradeoffs.

---

#### 1.3.2 `response_json_schema` (HIGH PRIORITY)

**Type:** `Any` (accepts raw JSON Schema dict)
**Description:** Alternative to `response_schema` that accepts raw JSON Schema format.

**Python Definition:**
```python
response_json_schema: Optional[Any] = Field(
    default=None,
    description="Output schema of the generated response. This is an alternative to "
                "`response_schema` that accepts [JSON Schema](https://json-schema.org/)."
)
```

**Use Case:** Provides more flexible schema definition using standard JSON Schema format, supporting features like `$ref`, `$defs`, `anyOf`, `oneOf`, etc.

**Implementation Note:** Should be mutually exclusive with `response_schema`.

---

#### 1.3.3 `audio_timestamp` (MEDIUM PRIORITY)

**Type:** `bool`
**Description:** Enables audio timestamp inclusion in requests.

**Python Definition:**
```python
audio_timestamp: Optional[bool] = Field(
    default=None,
    description="Optional. If enabled, audio timestamp will be included in the "
                "request to the model. This field is not supported in Gemini API."
)
```

**Use Case:** For Vertex AI audio processing with temporal information.

**API Support:** Vertex AI only (not Gemini API)

---

#### 1.3.4 `enable_affective_dialog` (LOW PRIORITY)

**Type:** `bool`
**Description:** Enables emotion detection and adaptive responses.

**Python Definition:**
```python
enable_affective_dialog: Optional[bool] = Field(
    default=None,
    description="Optional. If enabled, the model will detect emotions and adapt "
                "its responses accordingly. This field is not supported in Gemini API."
)
```

**Use Case:** Emotional intelligence in conversations (Vertex AI feature).

**API Support:** Vertex AI only

---

#### 1.3.5 `media_resolution` (HIGH PRIORITY)

**Type:** `MediaResolution` enum
**Description:** Controls media (image/video) resolution for token usage optimization.

**Python Definition:**
```python
media_resolution: Optional[MediaResolution] = Field(
    default=None,
    description="Optional. If specified, the media resolution specified will be used."
)
```

**MediaResolution Enum Values:**
```python
class MediaResolution(Enum):
    MEDIA_RESOLUTION_UNSPECIFIED = 'MEDIA_RESOLUTION_UNSPECIFIED'  # Default
    MEDIA_RESOLUTION_LOW = 'MEDIA_RESOLUTION_LOW'                  # 64 tokens
    MEDIA_RESOLUTION_MEDIUM = 'MEDIA_RESOLUTION_MEDIUM'            # 256 tokens
    MEDIA_RESOLUTION_HIGH = 'MEDIA_RESOLUTION_HIGH'                # 256 tokens (zoomed)
```

**Use Case:** Balance quality vs cost for image/video inputs. Low resolution uses fewer tokens.

**Impact:** Cost optimization for multimodal inputs.

---

#### 1.3.6 `response_modalities` (CRITICAL PRIORITY)

**Type:** `list[Modality]`
**Description:** Specifies which modalities the model should return in responses.

**Python Definition:**
```python
response_modalities: Optional[list[Modality]] = Field(
    default=None,
    description="Optional. The modalities of the response."
)
```

**Modality Enum Values:**
```python
class Modality(Enum):
    MODALITY_UNSPECIFIED = 'MODALITY_UNSPECIFIED'
    TEXT = 'TEXT'      # Text responses
    IMAGE = 'IMAGE'    # Image generation
    AUDIO = 'AUDIO'    # Audio/speech output
```

**Use Case:**
- Control output format (text, audio, images)
- Enable multimodal generation (e.g., Gemini 2.0 with audio output)
- Request specific output types

**Impact:** Required for audio output and image generation features.

---

#### 1.3.7 `routing_config` (LOW PRIORITY)

**Type:** `GenerationConfigRoutingConfig`
**Description:** Configuration for model router requests.

**Python Definition:**
```python
routing_config: Optional[GenerationConfigRoutingConfig] = Field(
    default=None,
    description="Optional. Routing configuration. This field is not supported in Gemini API."
)
```

**RoutingConfig Structure:**
```python
class GenerationConfigRoutingConfig:
    auto_mode: Optional[AutoRoutingMode]
    manual_mode: Optional[ManualRoutingMode]
```

**Use Case:** Advanced routing in Vertex AI for model selection.

**API Support:** Vertex AI only

---

#### 1.3.8 `seed` (CRITICAL PRIORITY)

**Type:** `int`
**Description:** Seed for deterministic generation.

**Python Definition:**
```python
seed: Optional[int] = Field(
    default=None,
    description="Optional. Seed."
)
```

**Use Case:**
- Reproducible outputs for testing
- Consistent generation across requests
- A/B testing with controlled randomness

**Impact:** Essential for deterministic testing and debugging.

---

#### 1.3.9 `speech_config` (CRITICAL PRIORITY)

**Type:** `SpeechConfig`
**Description:** Configuration for speech/audio generation.

**Python Definition:**
```python
speech_config: Optional[SpeechConfig] = Field(
    default=None,
    description="Optional. The speech generation config."
)
```

**SpeechConfig Structure:**
```python
class SpeechConfig:
    language_code: Optional[str]                          # e.g., "en-US"
    voice_config: Optional[VoiceConfig]                   # Single speaker config
    multi_speaker_voice_config: Optional[MultiSpeakerVoiceConfig]  # Multi-speaker (Gemini API only)
```

**VoiceConfig Structure:**
```python
class VoiceConfig:
    prebuilt_voice_config: Optional[PrebuiltVoiceConfig]

class PrebuiltVoiceConfig:
    voice_name: Optional[str]  # e.g., "Puck", "Charon", "Kore", "Fenrir", "Aoede"
```

**MultiSpeakerVoiceConfig Structure:**
```python
class MultiSpeakerVoiceConfig:
    speaker_voice_configs: Optional[list[SpeakerVoiceConfig]]

class SpeakerVoiceConfig:
    speaker: Optional[str]              # Speaker name in prompt
    voice_config: Optional[VoiceConfig]  # Voice for this speaker
```

**Use Case:**
- Audio output generation (Gemini 2.0 multimodal live)
- Voice selection for TTS
- Multi-speaker conversations
- Language-specific speech synthesis

**Impact:** Required for audio output features in Gemini 2.0+.

---

#### 1.3.10 `enable_enhanced_civic_answers` (LOW PRIORITY)

**Type:** `bool`
**Description:** Enables enhanced civic/political answers.

**Python Definition:**
```python
enable_enhanced_civic_answers: Optional[bool] = Field(
    default=None,
    description="Optional. Enables enhanced civic answers. It may not be available "
                "for all models. This field is not supported in Vertex AI."
)
```

**Use Case:** Enhanced responses for civic/political queries.

**API Support:** Gemini API only (not Vertex AI)

---

## 2. ThinkingConfig Missing Fields

### 2.1 Current State

**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` (lines 4430-4447)
**gemini_ex Location:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex` (lines 8-44)

### 2.2 Comparison Table

| Field Name | Python SDK Type | gemini_ex Status | Priority | Notes |
|------------|-----------------|------------------|----------|-------|
| `thinking_budget` | `int` | ✅ Present | - | - |
| `thinking_level` | `ThinkingLevel` enum | ✅ Present | - | - |
| `include_thoughts` | `bool` | ✅ Present | - | - |

### 2.3 Analysis

**Status:** ✅ **COMPLETE**
All fields from Python SDK are present in gemini_ex. ThinkingConfig implementation is comprehensive and includes proper documentation for both Gemini 2.5 (thinking_budget) and Gemini 3 (thinking_level) approaches.

**ThinkingLevel Enum:**
```python
class ThinkingLevel(Enum):
    THINKING_LEVEL_UNSPECIFIED = 'THINKING_LEVEL_UNSPECIFIED'
    LOW = 'LOW'    # Minimize latency/cost
    HIGH = 'HIGH'  # Maximize reasoning depth
```

**Note:** gemini_ex now supports `:minimal` and `:medium` for Gemini 3 Flash models.
Gemini 3 Pro remains limited to `:low` and `:high`.

---

## 3. GenerateContentConfig Missing Fields

### 3.1 Current State

**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` (lines 4833-5043)
**gemini_ex Location:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/request/types_request_list_models_request.ex` (GenerateContentRequest)

### 3.2 Comparison Table

Note: `GenerateContentConfig` in Python SDK is a higher-level type that includes both request parameters and generation config. In gemini_ex, this is split between `GenerateContentRequest` and `GenerationConfig`.

| Field Name | Python SDK Type | gemini_ex Status | Priority | Notes |
|------------|-----------------|------------------|----------|-------|
| `contents` | `list[Content]` | ✅ Present | - | In GenerateContentRequest |
| `system_instruction` | `Content` | ✅ Present | - | In GenerateContentRequest |
| `tools` | `list[Tool]` | ✅ Present | - | In GenerateContentRequest |
| `tool_config` | `ToolConfig` | ✅ Present | - | In GenerateContentRequest |
| `safety_settings` | `list[SafetySetting]` | ✅ Present | - | In GenerateContentRequest |
| `generation_config` | `GenerationConfig` | ✅ Present | - | In GenerateContentRequest |
| **`http_options`** | `HttpOptions` | ❌ **MISSING** | **MEDIUM** | HTTP request overrides |
| **`should_return_http_response`** | `bool` | ❌ **MISSING** | **LOW** | Return raw HTTP response |
| **`labels`** | `dict[str, str]` | ❌ **MISSING** | **MEDIUM** | Billing labels |
| **`cached_content`** | `str` | ❌ **MISSING** | **HIGH** | Context cache reference |
| **`automatic_function_calling`** | `AutomaticFunctionCallingConfig` | ❌ **MISSING** | **HIGH** | Auto function execution |

### 3.3 Detailed Missing Fields

#### 3.3.1 `http_options` (MEDIUM PRIORITY)

**Type:** `HttpOptions`
**Description:** Override HTTP request options.

**Python Definition:**
```python
http_options: Optional[HttpOptions] = Field(
    default=None,
    description="Used to override HTTP request options."
)
```

**HttpOptions Structure:**
```python
class HttpOptions:
    timeout: Optional[float]           # Request timeout in seconds
    api_version: Optional[str]         # API version override
    headers: Optional[dict[str, str]]  # Additional headers
```

**Use Case:** Fine-grained control over HTTP behavior (timeouts, headers, API versions).

---

#### 3.3.2 `should_return_http_response` (LOW PRIORITY)

**Type:** `bool`
**Description:** Return raw HTTP response in addition to parsed response.

**Python Definition:**
```python
should_return_http_response: Optional[bool] = Field(
    default=None,
    description="If true, the raw HTTP response will be returned in the "
                "'sdk_http_response' field."
)
```

**Use Case:** Debugging, accessing raw headers, status codes, etc.

---

#### 3.3.3 `labels` (MEDIUM PRIORITY)

**Type:** `dict[str, str]`
**Description:** User-defined labels for billing breakdown.

**Python Definition:**
```python
labels: Optional[dict[str, str]] = Field(
    default=None,
    description="Labels with user-defined metadata to break down billed charges."
)
```

**Use Case:**
- Cost tracking by project/team/environment
- Resource tagging for billing analytics
- Multi-tenant cost attribution

**Example:**
```python
labels = {
    "project": "chatbot",
    "environment": "production",
    "team": "ml-research"
}
```

---

#### 3.3.4 `cached_content` (HIGH PRIORITY)

**Type:** `str` (resource name)
**Description:** Reference to a cached content resource for token optimization.

**Python Definition:**
```python
cached_content: Optional[str] = Field(
    default=None,
    description="Resource name of a context cache that can be used in subsequent requests."
)
```

**Use Case:**
- Context caching for reduced latency and costs
- Reuse system instructions across requests
- Cache large documents/knowledge bases

**Format:** `"cachedContents/{cache-id}"`

**Impact:** Significant cost/latency optimization for repeated contexts.

---

#### 3.3.5 `automatic_function_calling` (HIGH PRIORITY)

**Type:** `AutomaticFunctionCallingConfig`
**Description:** Configuration for automatic function execution.

**Python Definition:**
```python
automatic_function_calling: Optional[AutomaticFunctionCallingConfig] = Field(
    default=None,
    description="The configuration for automatic function calling."
)
```

**AutomaticFunctionCallingConfig Structure:**
```python
class AutomaticFunctionCallingConfig:
    disable: Optional[bool]  # If True, disable AFC; if False/None, enable AFC
```

**Use Case:**
- Enable/disable automatic function calling loop
- SDK automatically executes functions and continues conversation
- Simplifies agentic workflows

**Impact:** Major feature for autonomous agent implementations.

---

## 4. SafetySetting Missing Fields

### 4.1 Current State

**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` (lines 4764-4777)
**gemini_ex Location:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/safety_setting.ex`

### 4.2 Comparison Table

| Field Name | Python SDK Type | gemini_ex Status | Priority | Notes |
|------------|-----------------|------------------|----------|-------|
| `category` | `HarmCategory` enum | ✅ Present | - | - |
| `threshold` | `HarmBlockThreshold` enum | ✅ Present | - | - |
| **`method`** | `HarmBlockMethod` enum | ❌ **MISSING** | **MEDIUM** | Vertex AI only |

### 4.3 Detailed Missing Fields

#### 4.3.1 `method` (MEDIUM PRIORITY)

**Type:** `HarmBlockMethod` enum
**Description:** Specify if threshold applies to probability or severity score.

**Python Definition:**
```python
method: Optional[HarmBlockMethod] = Field(
    default=None,
    description="Optional. Specify if the threshold is used for probability or "
                "severity score. If not specified, the threshold is used for "
                "probability score. This field is not supported in Gemini API."
)
```

**HarmBlockMethod Enum:**
```python
class HarmBlockMethod(Enum):
    HARM_BLOCK_METHOD_UNSPECIFIED = 'HARM_BLOCK_METHOD_UNSPECIFIED'
    SEVERITY = 'SEVERITY'      # Use severity score
    PROBABILITY = 'PROBABILITY'  # Use probability score (default)
```

**Use Case:** Fine-grained safety control based on severity vs probability.

**API Support:** Vertex AI only (not Gemini API)

### 4.4 Missing HarmCategory Values

**gemini_ex has:** `harassment`, `hate_speech`, `sexually_explicit`, `dangerous_content`

**Python SDK additional values:**
```python
HARM_CATEGORY_CIVIC_INTEGRITY = 'HARM_CATEGORY_CIVIC_INTEGRITY'  # Deprecated
HARM_CATEGORY_IMAGE_HATE = 'HARM_CATEGORY_IMAGE_HATE'  # Vertex AI only
HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT = 'HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT'  # Vertex AI only
HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT = 'HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT'  # Vertex AI only
```

**Priority:** LOW (specialized/deprecated categories)

---

## 5. ToolConfig Missing Fields

### 5.1 Current State

**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` (lines 4341-4353)
**gemini_ex Location:** Inlined in request building (no dedicated type)

### 5.2 Comparison Table

| Field Name | Python SDK Type | gemini_ex Status | Priority | Notes |
|------------|-----------------|------------------|----------|-------|
| `function_calling_config` | `FunctionCallingConfig` | ✅ Present | - | Passed as map |
| **`retrieval_config`** | `RetrievalConfig` | ❌ **MISSING** | **MEDIUM** | Grounding/search config |

### 5.3 Detailed Missing Fields

#### 5.3.1 `retrieval_config` (MEDIUM PRIORITY)

**Type:** `RetrievalConfig`
**Description:** Configuration for retrieval/grounding features.

**Python Definition:**
```python
retrieval_config: Optional[RetrievalConfig] = Field(
    default=None,
    description="Optional. Retrieval config."
)
```

**RetrievalConfig Structure:**
```python
class RetrievalConfig:
    lat_lng: Optional[LatLng]        # User location
    language_code: Optional[str]     # User language

class LatLng:
    latitude: float
    longitude: float
```

**Use Case:**
- Location-aware responses
- Grounding with geographic context
- Language-specific retrieval

---

## 6. FunctionCallingConfig Missing Fields

### 6.1 Current State

**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` (lines 4245-4259)
**gemini_ex Location:** Inlined in tool_config map

### 6.2 Comparison Table

| Field Name | Python SDK Type | gemini_ex Status | Priority | Notes |
|------------|-----------------|------------------|----------|-------|
| `mode` | `FunctionCallingConfigMode` enum | ✅ Present | - | AUTO/ANY/NONE |
| `allowed_function_names` | `list[str]` | ✅ Present | - | Function whitelist |
| **`stream_function_call_arguments`** | `bool` | ❌ **MISSING** | **LOW** | Vertex AI only |

### 6.3 Detailed Missing Fields

#### 6.3.1 `stream_function_call_arguments` (LOW PRIORITY)

**Type:** `bool`
**Description:** Stream function call arguments in multiple parts.

**Python Definition:**
```python
stream_function_call_arguments: Optional[bool] = Field(
    default=None,
    description="Optional. When set to true, arguments of a single function call "
                "will be streamed out in multiple parts/contents/responses. Partial "
                "parameter results will be returned in the [FunctionCall.partial_args] "
                "field. This field is not supported in Gemini API."
)
```

**Use Case:** Streaming partial function arguments for very large/complex calls.

**API Support:** Vertex AI only

### 6.4 Missing FunctionCallingConfigMode Value

**gemini_ex likely has:** `AUTO`, `ANY`, `NONE`

**Python SDK additional value:**
```python
VALIDATED = 'VALIDATED'  # Constrained decoding with validation
```

**Description:** Model validates function calls with constrained decoding. If allowed_function_names are set, calls are limited to those functions.

**Priority:** MEDIUM

---

## 7. SpeechConfig Missing Fields

### 7.1 Current State

**Status:** ❌ **COMPLETELY MISSING** from gemini_ex

**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` (lines 4795-4809)
**gemini_ex Location:** N/A

### 7.2 Required Implementation

**Priority:** CRITICAL (required for audio output)

**SpeechConfig Type:**
```python
class SpeechConfig:
    language_code: Optional[str]
    voice_config: Optional[VoiceConfig]
    multi_speaker_voice_config: Optional[MultiSpeakerVoiceConfig]
```

**VoiceConfig Type:**
```python
class VoiceConfig:
    prebuilt_voice_config: Optional[PrebuiltVoiceConfig]

class PrebuiltVoiceConfig:
    voice_name: Optional[str]
```

**MultiSpeakerVoiceConfig Type:**
```python
class MultiSpeakerVoiceConfig:
    speaker_voice_configs: Optional[list[SpeakerVoiceConfig]]

class SpeakerVoiceConfig:
    speaker: Optional[str]
    voice_config: Optional[VoiceConfig]
```

**Supported Voices:**
- Puck (en-US)
- Charon (en-US)
- Kore (en-US)
- Fenrir (en-US)
- Aoede (en-US)

**Use Case:**
- Audio output generation
- Multi-speaker conversations
- Voice customization

---

## 8. Supporting Types Missing

### 8.1 MediaResolution Enum

**Status:** ❌ MISSING
**Priority:** HIGH

```elixir
defmodule Gemini.Types.MediaResolution do
  @type t :: :unspecified | :low | :medium | :high

  @values %{
    unspecified: "MEDIA_RESOLUTION_UNSPECIFIED",
    low: "MEDIA_RESOLUTION_LOW",           # 64 tokens
    medium: "MEDIA_RESOLUTION_MEDIUM",     # 256 tokens
    high: "MEDIA_RESOLUTION_HIGH"          # 256 tokens, zoomed
  }
end
```

### 8.2 Modality Enum

**Status:** ❌ MISSING
**Priority:** CRITICAL

```elixir
defmodule Gemini.Types.Modality do
  @type t :: :unspecified | :text | :image | :audio

  @values %{
    unspecified: "MODALITY_UNSPECIFIED",
    text: "TEXT",
    image: "IMAGE",
    audio: "AUDIO"
  }
end
```

### 8.3 FeatureSelectionPreference Enum

**Status:** ❌ MISSING
**Priority:** HIGH

```elixir
defmodule Gemini.Types.FeatureSelectionPreference do
  @type t :: :unspecified | :prioritize_quality | :balanced | :prioritize_cost

  @values %{
    unspecified: "FEATURE_SELECTION_PREFERENCE_UNSPECIFIED",
    prioritize_quality: "PRIORITIZE_QUALITY",
    balanced: "BALANCED",
    prioritize_cost: "PRIORITIZE_COST"
  }
end
```

### 8.4 ModelSelectionConfig Type

**Status:** ❌ MISSING
**Priority:** HIGH

```elixir
defmodule Gemini.Types.ModelSelectionConfig do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:feature_selection_preference, FeatureSelectionPreference.t() | nil)
  end
end
```

### 8.5 HarmBlockMethod Enum

**Status:** ❌ MISSING
**Priority:** MEDIUM (Vertex AI only)

```elixir
defmodule Gemini.Types.HarmBlockMethod do
  @type t :: :unspecified | :severity | :probability

  @values %{
    unspecified: "HARM_BLOCK_METHOD_UNSPECIFIED",
    severity: "SEVERITY",
    probability: "PROBABILITY"
  }
end
```

### 8.6 Behavior Enum

**Status:** ❌ MISSING
**Priority:** MEDIUM

```elixir
defmodule Gemini.Types.FunctionBehavior do
  @type t :: :unspecified | :blocking | :non_blocking

  @values %{
    unspecified: "UNSPECIFIED",
    blocking: "BLOCKING",
    non_blocking: "NON_BLOCKING"
  }
end
```

### 8.7 FunctionCallingConfigMode Values

**Status:** Partial - Missing VALIDATED mode
**Priority:** MEDIUM

Add to existing mode enum:
```elixir
@type mode :: :auto | :any | :none | :validated
```

### 8.8 AutomaticFunctionCallingConfig Type

**Status:** ❌ MISSING
**Priority:** HIGH

```elixir
defmodule Gemini.Types.AutomaticFunctionCallingConfig do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:disable, boolean() | nil, default: nil)
  end
end
```

### 8.9 RetrievalConfig Type

**Status:** ❌ MISSING
**Priority:** MEDIUM

```elixir
defmodule Gemini.Types.RetrievalConfig do
  use TypedStruct

  alias Gemini.Types.LatLng

  @derive Jason.Encoder
  typedstruct do
    field(:lat_lng, LatLng.t() | nil, default: nil)
    field(:language_code, String.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.LatLng do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:latitude, float(), enforce: true)
    field(:longitude, float(), enforce: true)
  end
end
```

### 8.10 HttpOptions Type

**Status:** ❌ MISSING
**Priority:** MEDIUM

```elixir
defmodule Gemini.Types.HttpOptions do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:timeout, float() | nil, default: nil)
    field(:api_version, String.t() | nil, default: nil)
    field(:headers, %{String.t() => String.t()} | nil, default: nil)
  end
end
```

---

## 9. Implementation Roadmap

### Phase 1: Critical Features (Week 1)

**Priority:** Must-have for core functionality

1. **`seed` field** - GenerationConfig
   - File: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`
   - Add: `field(:seed, integer() | nil, default: nil)`
   - Impact: Deterministic generation for testing

2. **`response_modalities` field** - GenerationConfig
   - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/modality.ex`
   - Add enum type with TEXT, IMAGE, AUDIO values
   - Add field: `field(:response_modalities, [Modality.t()] | nil, default: nil)`
   - Impact: Required for multimodal output

3. **`speech_config` field** - GenerationConfig
   - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/speech_config.ex`
   - Implement full SpeechConfig, VoiceConfig, PrebuiltVoiceConfig types
   - Add field: `field(:speech_config, SpeechConfig.t() | nil, default: nil)`
   - Impact: Audio output support

4. **`media_resolution` field** - GenerationConfig
   - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/media_resolution.ex`
   - Add enum with LOW, MEDIUM, HIGH values
   - Add field: `field(:media_resolution, MediaResolution.t() | nil, default: nil)`
   - Impact: Cost optimization for multimodal inputs

### Phase 2: High Priority Features (Week 2)

**Priority:** Important for advanced use cases

5. **`cached_content` field** - GenerateContentRequest
   - File: `/home/home/p/g/n/gemini_ex/lib/gemini/types/request/types_request_list_models_request.ex`
   - Add: `field(:cached_content, String.t() | nil, default: nil)`
   - Impact: Context caching support

6. **`automatic_function_calling` field** - GenerateContentConfig
   - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/request/automatic_function_calling_config.ex`
   - Add simple struct with `disable` boolean field
   - Add to request: `field(:automatic_function_calling, AutomaticFunctionCallingConfig.t() | nil)`
   - Impact: AFC support

7. **`model_selection_config` field** - GenerationConfig
   - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/model_selection_config.ex`
   - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/feature_selection_preference.ex`
   - Add field: `field(:model_selection_config, ModelSelectionConfig.t() | nil)`
   - Impact: Automatic model routing

8. **`response_json_schema` field** - GenerationConfig
   - File: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`
   - Add: `field(:response_json_schema, map() | nil, default: nil)`
   - Add validation: mutually exclusive with `response_schema`
   - Impact: Flexible JSON schema support

### Phase 3: Medium Priority Features (Week 3)

**Priority:** Nice to have, improves completeness

9. **`labels` field** - GenerateContentRequest
   - Add: `field(:labels, %{String.t() => String.t()} | nil, default: nil)`
   - Impact: Billing breakdown

10. **`retrieval_config` field** - ToolConfig
    - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/request/retrieval_config.ex`
    - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/lat_lng.ex`
    - Impact: Location-aware grounding

11. **`method` field** - SafetySetting
    - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/harm_block_method.ex`
    - Add: `field(:method, HarmBlockMethod.t() | nil, default: nil)`
    - Impact: Severity-based safety (Vertex AI)

12. **`audio_timestamp` field** - GenerationConfig
    - Add: `field(:audio_timestamp, boolean() | nil, default: nil)`
    - Impact: Audio timestamp support (Vertex AI)

13. **`http_options` field** - GenerateContentRequest
    - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/request/http_options.ex`
    - Impact: Fine-grained HTTP control

14. **VALIDATED mode** - FunctionCallingConfigMode
    - Add to existing mode enum/type
    - Impact: Constrained function calling

15. **`behavior` field** - FunctionDeclaration
    - Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/function_behavior.ex`
    - Impact: Blocking vs non-blocking functions

### Phase 4: Low Priority Features (Week 4)

**Priority:** Vertex AI specific or deprecated features

16. **`routing_config` field** - GenerationConfig (Vertex AI only)
17. **`enable_affective_dialog` field** - GenerationConfig (Vertex AI only)
18. **`enable_enhanced_civic_answers` field** - GenerationConfig (Gemini API only)
19. **`stream_function_call_arguments` field** - FunctionCallingConfig (Vertex AI only)
20. **`should_return_http_response` field** - GenerateContentRequest
21. **Additional HarmCategory values** - Image safety categories (Vertex AI)

---

## 10. Code Examples

### 10.1 Adding `seed` Field

**File:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`

```elixir
# Add to typedstruct block (around line 94)
@derive Jason.Encoder
typedstruct do
  field(:stop_sequences, [String.t()], default: [])
  field(:response_mime_type, String.t() | nil, default: nil)
  field(:response_schema, map() | nil, default: nil)
  field(:candidate_count, integer() | nil, default: nil)
  field(:max_output_tokens, integer() | nil, default: nil)
  field(:temperature, float() | nil, default: nil)
  field(:top_p, float() | nil, default: nil)
  field(:top_k, integer() | nil, default: nil)
  field(:presence_penalty, float() | nil, default: nil)
  field(:frequency_penalty, float() | nil, default: nil)
  field(:response_logprobs, boolean() | nil, default: nil)
  field(:logprobs, integer() | nil, default: nil)
  field(:thinking_config, ThinkingConfig.t() | nil, default: nil)
  field(:property_ordering, [String.t()] | nil, default: nil)
  field(:image_config, ImageConfig.t() | nil, default: nil)

  # NEW FIELDS
  field(:seed, integer() | nil, default: nil)
end

# Add helper function
@doc """
Set seed for deterministic generation.

## Parameters
- `config`: GenerationConfig struct (defaults to new config)
- `seed`: Integer seed value

## Examples

    # Deterministic generation
    config = GenerationConfig.seed(12345)

    # Chain with other options
    config =
      GenerationConfig.new()
      |> GenerationConfig.temperature(0.0)
      |> GenerationConfig.seed(12345)
"""
@spec seed(t(), integer()) :: t()
def seed(config \\ %__MODULE__{}, seed_value) when is_integer(seed_value) do
  %{config | seed: seed_value}
end
```

### 10.2 Adding `response_modalities` Field

**Create file:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/modality.ex`

```elixir
defmodule Gemini.Types.Modality do
  @moduledoc """
  Response modality types for multimodal generation.

  Specifies which types of content the model can return.
  """

  @type t :: :text | :image | :audio | :unspecified

  @values %{
    unspecified: "MODALITY_UNSPECIFIED",
    text: "TEXT",
    image: "IMAGE",
    audio: "AUDIO"
  }

  @doc """
  Convert atom to API string value.
  """
  def to_string(modality) when is_atom(modality) do
    Map.get(@values, modality)
  end

  @doc """
  Convert API string to atom.
  """
  def from_string(str) when is_binary(str) do
    @values
    |> Enum.find(fn {_k, v} -> v == str end)
    |> case do
      {k, _v} -> k
      nil -> :unspecified
    end
  end

  @doc """
  Encode modality list for JSON.
  """
  def encode_list(modalities) when is_list(modalities) do
    Enum.map(modalities, &to_string/1)
  end
end
```

**Update:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`

```elixir
alias Gemini.Types.Modality

# Add to typedstruct
field(:response_modalities, [Modality.t()] | nil, default: nil)

# Add helper function
@doc """
Set response modalities for multimodal output.

Controls which types of content the model can return.

## Parameters
- `config`: GenerationConfig struct (defaults to new config)
- `modalities`: List of modality atoms (:text, :image, :audio)

## Examples

    # Request text and audio output
    config = GenerationConfig.response_modalities([:text, :audio])

    # Request image generation
    config = GenerationConfig.response_modalities([:image])

    # Chain with other options
    config =
      GenerationConfig.new()
      |> GenerationConfig.response_modalities([:text, :audio])
      |> GenerationConfig.speech_config(language_code: "en-US")
"""
@spec response_modalities(t(), [Modality.t()]) :: t()
def response_modalities(config \\ %__MODULE__{}, modalities)
    when is_list(modalities) do
  %{config | response_modalities: modalities}
end
```

### 10.3 Adding `SpeechConfig` Type

**Create file:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/speech_config.ex`

```elixir
defmodule Gemini.Types.SpeechConfig do
  @moduledoc """
  Configuration for speech/audio generation.

  Used with Gemini 2.0+ models that support audio output.

  ## Fields

  - `language_code` - Language for speech synthesis (e.g., "en-US", "es-ES")
  - `voice_config` - Single speaker voice configuration
  - `multi_speaker_voice_config` - Multi-speaker setup (Gemini API only)

  ## Examples

      # Single speaker
      config = %SpeechConfig{
        language_code: "en-US",
        voice_config: %VoiceConfig{
          prebuilt_voice_config: %PrebuiltVoiceConfig{
            voice_name: "Puck"
          }
        }
      }

      # Multi-speaker (Gemini API only)
      config = %SpeechConfig{
        language_code: "en-US",
        multi_speaker_voice_config: %MultiSpeakerVoiceConfig{
          speaker_voice_configs: [
            %SpeakerVoiceConfig{
              speaker: "Alice",
              voice_config: %VoiceConfig{
                prebuilt_voice_config: %PrebuiltVoiceConfig{
                  voice_name: "Kore"
                }
              }
            },
            %SpeakerVoiceConfig{
              speaker: "Bob",
              voice_config: %VoiceConfig{
                prebuilt_voice_config: %PrebuiltVoiceConfig{
                  voice_name: "Fenrir"
                }
              }
            }
          ]
        }
      }
  """

  use TypedStruct

  alias Gemini.Types.{VoiceConfig, MultiSpeakerVoiceConfig}

  @derive Jason.Encoder
  typedstruct do
    field(:language_code, String.t() | nil, default: nil)
    field(:voice_config, VoiceConfig.t() | nil, default: nil)
    field(:multi_speaker_voice_config, MultiSpeakerVoiceConfig.t() | nil, default: nil)
  end

  @doc """
  Create speech config with single speaker.
  """
  def single_speaker(language_code, voice_name) do
    %__MODULE__{
      language_code: language_code,
      voice_config: %VoiceConfig{
        prebuilt_voice_config: %PrebuiltVoiceConfig{
          voice_name: voice_name
        }
      }
    }
  end

  @doc """
  Create speech config with multiple speakers.

  Note: Multi-speaker is only supported in Gemini API, not Vertex AI.
  """
  def multi_speaker(language_code, speaker_configs) do
    %__MODULE__{
      language_code: language_code,
      multi_speaker_voice_config: %MultiSpeakerVoiceConfig{
        speaker_voice_configs: speaker_configs
      }
    }
  end
end

defmodule Gemini.Types.VoiceConfig do
  @moduledoc """
  Configuration for a single voice.
  """

  use TypedStruct

  alias Gemini.Types.PrebuiltVoiceConfig

  @derive Jason.Encoder
  typedstruct do
    field(:prebuilt_voice_config, PrebuiltVoiceConfig.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.PrebuiltVoiceConfig do
  @moduledoc """
  Configuration for prebuilt voices.

  ## Available Voices (en-US)

  - "Puck" - Energetic, youthful
  - "Charon" - Deep, authoritative
  - "Kore" - Warm, friendly
  - "Fenrir" - Strong, confident
  - "Aoede" - Melodic, expressive
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:voice_name, String.t() | nil, default: nil)
  end

  @available_voices ~w[Puck Charon Kore Fenrir Aoede]

  @doc """
  List of available prebuilt voices.
  """
  def available_voices, do: @available_voices

  @doc """
  Validate voice name.
  """
  def valid_voice?(name) when is_binary(name) do
    name in @available_voices
  end
end

defmodule Gemini.Types.MultiSpeakerVoiceConfig do
  @moduledoc """
  Configuration for multi-speaker setup.

  Note: Only supported in Gemini API, not Vertex AI.
  """

  use TypedStruct

  alias Gemini.Types.SpeakerVoiceConfig

  @derive Jason.Encoder
  typedstruct do
    field(:speaker_voice_configs, [SpeakerVoiceConfig.t()] | nil, default: nil)
  end
end

defmodule Gemini.Types.SpeakerVoiceConfig do
  @moduledoc """
  Configuration for a single speaker in multi-speaker setup.
  """

  use TypedStruct

  alias Gemini.Types.VoiceConfig

  @derive Jason.Encoder
  typedstruct do
    field(:speaker, String.t() | nil, default: nil)
    field(:voice_config, VoiceConfig.t() | nil, default: nil)
  end
end
```

**Update:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`

```elixir
alias Gemini.Types.SpeechConfig

# Add to typedstruct
field(:speech_config, SpeechConfig.t() | nil, default: nil)

# Add helper function
@doc """
Configure speech/audio generation.

## Parameters
- `config`: GenerationConfig struct (defaults to new config)
- `opts`: Keyword list of speech options
  - `:language_code` - Language code (e.g., "en-US")
  - `:voice_name` - Voice name (e.g., "Puck", "Kore")
  - `:speaker_configs` - List of SpeakerVoiceConfig for multi-speaker

## Examples

    # Single speaker
    config = GenerationConfig.speech_config(
      language_code: "en-US",
      voice_name: "Puck"
    )

    # Multi-speaker
    speaker_configs = [
      %SpeakerVoiceConfig{
        speaker: "Alice",
        voice_config: %VoiceConfig{
          prebuilt_voice_config: %PrebuiltVoiceConfig{voice_name: "Kore"}
        }
      },
      %SpeakerVoiceConfig{
        speaker: "Bob",
        voice_config: %VoiceConfig{
          prebuilt_voice_config: %PrebuiltVoiceConfig{voice_name: "Fenrir"}
        }
      }
    ]

    config = GenerationConfig.speech_config(
      language_code: "en-US",
      speaker_configs: speaker_configs
    )
"""
@spec speech_config(t(), keyword()) :: t()
def speech_config(config \\ %__MODULE__{}, opts) when is_list(opts) do
  speech_cfg =
    case Keyword.get(opts, :speaker_configs) do
      nil ->
        # Single speaker
        SpeechConfig.single_speaker(
          Keyword.get(opts, :language_code, "en-US"),
          Keyword.get(opts, :voice_name, "Puck")
        )

      speaker_configs ->
        # Multi-speaker
        SpeechConfig.multi_speaker(
          Keyword.get(opts, :language_code, "en-US"),
          speaker_configs
        )
    end

  %{config | speech_config: speech_cfg}
end
```

### 10.4 Adding `media_resolution` Field

**Create file:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/media_resolution.ex`

```elixir
defmodule Gemini.Types.MediaResolution do
  @moduledoc """
  Media resolution for image/video inputs.

  Controls the token usage for multimodal inputs.

  ## Resolution Levels

  - `:low` - 64 tokens (fastest, cheapest)
  - `:medium` - 256 tokens (balanced)
  - `:high` - 256 tokens with zoomed reframing (highest quality)
  - `:unspecified` - Default/auto

  ## Examples

      # Low resolution for cost optimization
      config = GenerationConfig.media_resolution(:low)

      # High resolution for detailed analysis
      config = GenerationConfig.media_resolution(:high)
  """

  @type t :: :unspecified | :low | :medium | :high

  @values %{
    unspecified: "MEDIA_RESOLUTION_UNSPECIFIED",
    low: "MEDIA_RESOLUTION_LOW",
    medium: "MEDIA_RESOLUTION_MEDIUM",
    high: "MEDIA_RESOLUTION_HIGH"
  }

  @doc """
  Convert atom to API string value.
  """
  def to_string(resolution) when is_atom(resolution) do
    Map.get(@values, resolution, @values.unspecified)
  end

  @doc """
  Convert API string to atom.
  """
  def from_string(str) when is_binary(str) do
    @values
    |> Enum.find(fn {_k, v} -> v == str end)
    |> case do
      {k, _v} -> k
      nil -> :unspecified
    end
  end

  @doc """
  Get token count for resolution level.
  """
  def token_count(:low), do: 64
  def token_count(:medium), do: 256
  def token_count(:high), do: 256  # Same as medium but with zoom
  def token_count(_), do: nil
end
```

**Update:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`

```elixir
alias Gemini.Types.MediaResolution

# Add to typedstruct
field(:media_resolution, MediaResolution.t() | nil, default: nil)

# Add helper function
@doc """
Set media resolution for image/video inputs.

Controls the token usage for multimodal inputs.

## Parameters
- `config`: GenerationConfig struct (defaults to new config)
- `resolution`: Resolution level (:low, :medium, :high)

## Examples

    # Low resolution (64 tokens) - cost optimization
    config = GenerationConfig.media_resolution(:low)

    # High resolution (256 tokens, zoomed) - quality
    config = GenerationConfig.media_resolution(:high)

    # Chain with other options
    config =
      GenerationConfig.new()
      |> GenerationConfig.media_resolution(:medium)
      |> GenerationConfig.max_tokens(1000)
"""
@spec media_resolution(t(), MediaResolution.t()) :: t()
def media_resolution(config \\ %__MODULE__{}, resolution)
    when resolution in [:unspecified, :low, :medium, :high] do
  %{config | media_resolution: resolution}
end
```

### 10.5 Adding `cached_content` Field

**Update:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/request/types_request_list_models_request.ex`

```elixir
defmodule Gemini.Types.Request.GenerateContentRequest do
  use TypedStruct

  alias Gemini.Types.{Content, SafetySetting, GenerationConfig}

  @derive Jason.Encoder
  typedstruct do
    field(:contents, [Content.t()], enforce: true)
    field(:tools, [map()], default: [])
    field(:tool_config, map() | nil, default: nil)
    field(:safety_settings, [SafetySetting.t()], default: [])
    field(:system_instruction, Content.t() | nil, default: nil)
    field(:generation_config, GenerationConfig.t() | nil, default: nil)

    # NEW FIELD
    field(:cached_content, String.t() | nil, default: nil)
  end

  # Update new/2 function to accept cached_content
  def new(contents, opts \\ []) do
    with {:ok, normalized_contents} <- normalize_contents(contents),
         {:ok, system_instruction} <-
           normalize_system_instruction(Keyword.get(opts, :system_instruction)) do
      request = %__MODULE__{
        contents: normalized_contents,
        generation_config: Keyword.get(opts, :generation_config),
        safety_settings: Keyword.get(opts, :safety_settings, []),
        system_instruction: system_instruction,
        tools: Keyword.get(opts, :tools, []),
        tool_config: Keyword.get(opts, :tool_config),
        cached_content: Keyword.get(opts, :cached_content)  # NEW
      }

      {:ok, request}
    end
  end
end
```

**Update:** `/home/home/p/g/n/gemini_ex/lib/gemini/apis/generate.ex`

```elixir
# Update build_generate_request/2 to include cached_content
def build_generate_request(contents, opts) do
  contents_list = normalize_contents(contents)

  %GenerateContentRequest{
    contents: contents_list,
    generation_config: Keyword.get(opts, :generation_config),
    safety_settings: Keyword.get(opts, :safety_settings, []),
    system_instruction: normalize_system_instruction(Keyword.get(opts, :system_instruction)),
    tools: Keyword.get(opts, :tools, []),
    tool_config: Keyword.get(opts, :tool_config),
    cached_content: Keyword.get(opts, :cached_content)  # NEW
  }
  |> Map.from_struct()
  |> Enum.filter(fn {_k, v} -> v != nil and v != [] end)
  |> Map.new()
end
```

### 10.6 Using New Fields - Complete Example

```elixir
# Example: Multimodal audio generation with context caching

# 1. Create context cache (separate API call, not shown here)
cache_name = "cachedContents/abc123"

# 2. Configure generation with new fields
config =
  GenerationConfig.new()
  |> GenerationConfig.temperature(0.7)
  |> GenerationConfig.seed(42)                              # Deterministic
  |> GenerationConfig.response_modalities([:text, :audio])  # Request audio output
  |> GenerationConfig.speech_config(                        # Configure speech
    language_code: "en-US",
    voice_name: "Puck"
  )
  |> GenerationConfig.media_resolution(:medium)             # Balance quality/cost
  |> GenerationConfig.max_tokens(1000)

# 3. Generate content with cached context
{:ok, response} = Gemini.Generate.content(
  "Tell me about the document",
  model: "gemini-2.0-flash-exp",
  generation_config: config,
  cached_content: cache_name  # Use cached context
)

# Response will include text and audio modalities
# Audio will use Puck voice in en-US
# Results will be deterministic due to seed
# Input media uses medium resolution (256 tokens)
```

---

## Summary

This comprehensive analysis identified **25+ missing fields** across GenerationConfig, ThinkingConfig, GenerateContentConfig, SafetySetting, ToolConfig, and supporting types. The most critical missing features are:

1. **`seed`** - Essential for deterministic testing
2. **`response_modalities`** - Required for multimodal output (audio, images)
3. **`speech_config`** - Complete type missing, needed for audio generation
4. **`media_resolution`** - Cost optimization for multimodal inputs
5. **`cached_content`** - Performance optimization via context caching
6. **`automatic_function_calling`** - Simplified agentic workflows
7. **`model_selection_config`** - Automatic model routing
8. **`response_json_schema`** - Flexible schema definition

The implementation roadmap prioritizes these fields across 4 phases, with critical features in Phase 1 (Week 1) and lower-priority Vertex AI-specific features in Phase 4.

All code examples follow gemini_ex conventions using TypedStruct, Jason encoding, and helper functions with comprehensive documentation.

**Files requiring modification:**
- `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex`
- `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/safety_setting.ex`
- `/home/home/p/g/n/gemini_ex/lib/gemini/types/request/types_request_list_models_request.ex`
- `/home/home/p/g/n/gemini_ex/lib/gemini/apis/generate.ex`
- Multiple new type files for enums and supporting types
