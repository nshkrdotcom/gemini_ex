# Missing Fields Analysis: Python SDK vs gemini_ex

**Analysis Date:** 2025-12-05
**Python SDK Location:** `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py`
**gemini_ex Location:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/`

## Executive Summary

This document identifies ALL missing fields in the gemini_ex (Elixir) SDK compared to the Python genai SDK. The analysis covers the main response types: `GenerateContentResponse`, `Candidate`, `UsageMetadata`, `Content`, and `Part` structures.

**Total Missing Fields:** 50+
**High Priority Fields:** 15
**Medium Priority Fields:** 20
**Low Priority Fields:** 15+

---

## Table of Contents

1. [GenerateContentResponse Missing Fields](#1-generatecontentresponse-missing-fields)
2. [Candidate Missing Fields](#2-candidate-missing-fields)
3. [UsageMetadata Missing Fields](#3-usagemetadata-missing-fields)
4. [PromptFeedback Missing Fields](#4-promptfeedback-missing-fields)
5. [Part Missing Fields](#5-part-missing-fields)
6. [SafetyRating Missing Fields](#6-safetyrating-missing-fields)
7. [Nested Types That Need Creation](#7-nested-types-that-need-creation)
8. [Implementation Recommendations](#8-implementation-recommendations)

---

## 1. GenerateContentResponse Missing Fields

### Current gemini_ex Implementation
```elixir
# /home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex
typedstruct do
  field(:candidates, [Candidate.t()], default: [])
  field(:prompt_feedback, PromptFeedback.t() | nil, default: nil)
  field(:usage_metadata, UsageMetadata.t() | nil, default: nil)
end
```

### Missing Fields Comparison

| Field Name | Python Type | gemini_ex Status | Priority | Description |
|------------|-------------|------------------|----------|-------------|
| `response_id` | `Optional[str]` | ❌ Missing | **HIGH** | Unique identifier for the response; used for tracking/debugging |
| `model_version` | `Optional[str]` | ❌ Missing | **HIGH** | The model version used to generate response (e.g., "gemini-2.0-flash-exp") |
| `create_time` | `Optional[datetime]` | ❌ Missing | **MEDIUM** | Timestamp when request was made to server |
| `automatic_function_calling_history` | `Optional[list[Content]]` | ❌ Missing | **MEDIUM** | History of automatic function calling interactions |
| `parsed` | `Optional[Union[BaseModel, dict, Enum]]` | ❌ Missing | **LOW** | First candidate from parsed response if response_schema provided |

### Implementation Code

```elixir
# Add to GenerateContentResponse typedstruct:
defmodule Gemini.Types.Response.GenerateContentResponse do
  use TypedStruct

  alias Gemini.Types.Response.{Candidate, PromptFeedback, UsageMetadata}
  alias Gemini.Types.Content

  @derive Jason.Encoder
  typedstruct do
    field(:candidates, [Candidate.t()], default: [])
    field(:prompt_feedback, PromptFeedback.t() | nil, default: nil)
    field(:usage_metadata, UsageMetadata.t() | nil, default: nil)

    # NEW FIELDS TO ADD:
    field(:response_id, String.t() | nil, default: nil)
    field(:model_version, String.t() | nil, default: nil)
    field(:create_time, DateTime.t() | nil, default: nil)
    field(:automatic_function_calling_history, [Content.t()] | nil, default: nil)
    field(:parsed, map() | nil, default: nil)
  end
end
```

---

## 2. Candidate Missing Fields

### Current gemini_ex Implementation
```elixir
# /home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex (lines 79-98)
typedstruct do
  field(:content, Content.t() | nil, default: nil)
  field(:finish_reason, String.t() | nil, default: nil)
  field(:safety_ratings, [SafetyRating.t()], default: [])
  field(:citation_metadata, CitationMetadata.t() | nil, default: nil)
  field(:token_count, integer() | nil, default: nil)
  field(:grounding_attributions, [GroundingAttribution.t()], default: [])
  field(:index, integer() | nil, default: nil)
end
```

### Missing Fields Comparison

| Field Name | Python Type | gemini_ex Status | Priority | Description |
|------------|-------------|------------------|----------|-------------|
| `finish_message` | `Optional[str]` | ❌ Missing | **HIGH** | Human-readable message describing why model stopped |
| `avg_logprobs` | `Optional[float]` | ❌ Missing | **MEDIUM** | Average log probability score of the candidate |
| `grounding_metadata` | `Optional[GroundingMetadata]` | ❌ Missing (different field) | **HIGH** | Full grounding metadata (gemini_ex has `grounding_attributions` instead) |
| `logprobs_result` | `Optional[LogprobsResult]` | ❌ Missing | **MEDIUM** | Log-likelihood scores for response tokens and top tokens |
| `url_context_metadata` | `Optional[UrlContextMetadata]` | ❌ Missing | **MEDIUM** | Metadata related to URL context retrieval tool |

### Implementation Code

```elixir
# Update Candidate typedstruct:
defmodule Gemini.Types.Response.Candidate do
  use TypedStruct

  alias Gemini.Types.Content
  alias Gemini.Types.Response.{
    SafetyRating,
    CitationMetadata,
    GroundingAttribution,
    GroundingMetadata,
    LogprobsResult,
    UrlContextMetadata
  }

  @derive Jason.Encoder
  typedstruct do
    field(:content, Content.t() | nil, default: nil)
    field(:finish_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])
    field(:citation_metadata, CitationMetadata.t() | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
    field(:grounding_attributions, [GroundingAttribution.t()], default: [])
    field(:index, integer() | nil, default: nil)

    # NEW FIELDS TO ADD:
    field(:finish_message, String.t() | nil, default: nil)
    field(:avg_logprobs, float() | nil, default: nil)
    field(:grounding_metadata, GroundingMetadata.t() | nil, default: nil)
    field(:logprobs_result, LogprobsResult.t() | nil, default: nil)
    field(:url_context_metadata, UrlContextMetadata.t() | nil, default: nil)
  end
end
```

---

## 3. UsageMetadata Missing Fields

### Current gemini_ex Implementation
```elixir
# /home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex (lines 117-131)
typedstruct do
  field(:prompt_token_count, integer() | nil, default: nil)
  field(:candidates_token_count, integer() | nil, default: nil)
  field(:total_token_count, integer(), enforce: true)
  field(:cached_content_token_count, integer() | nil, default: nil)
end
```

### Missing Fields Comparison

| Field Name | Python Type | gemini_ex Status | Priority | Description |
|------------|-------------|------------------|----------|-------------|
| `thoughts_token_count` | `Optional[int]` | ❌ Missing | **HIGH** | Number of tokens of thoughts for thinking models (Gemini 2.0+) |
| `tool_use_prompt_token_count` | `Optional[int]` | ❌ Missing | **HIGH** | Number of tokens in tool-use prompts |
| `prompt_tokens_details` | `Optional[list[ModalityTokenCount]]` | ❌ Missing | **MEDIUM** | Breakdown of prompt tokens by modality (text, image, video, audio) |
| `cache_tokens_details` | `Optional[list[ModalityTokenCount]]` | ❌ Missing | **MEDIUM** | Breakdown of cache tokens by modality |
| `response_tokens_details` | `Optional[list[ModalityTokenCount]]` | ❌ Missing | **MEDIUM** | Breakdown of response tokens by modality |
| `tool_use_prompt_tokens_details` | `Optional[list[ModalityTokenCount]]` | ❌ Missing | **MEDIUM** | Breakdown of tool-use prompt tokens by modality |
| `traffic_type` | `Optional[TrafficType]` | ❌ Missing | **LOW** | Shows if request consumes Pay-As-You-Go or Provisioned Throughput quota |

**Note:** Python SDK also has a separate `GenerateContentResponseUsageMetadata` type with these fields:
- `candidates_tokens_details` (instead of `response_tokens_details`)

### Implementation Code

```elixir
# Create new ModalityTokenCount type:
defmodule Gemini.Types.Response.ModalityTokenCount do
  @moduledoc """
  Represents token counting info for a single modality.
  """

  use TypedStruct

  @type media_modality ::
    :modality_unspecified |
    :text |
    :image |
    :video |
    :audio |
    :document

  @derive Jason.Encoder
  typedstruct do
    field(:modality, media_modality() | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
  end
end

# Create TrafficType enum:
defmodule Gemini.Types.Response.TrafficType do
  @moduledoc """
  Traffic type for API requests.

  Shows whether a request consumes Pay-As-You-Go or
  Provisioned Throughput quota.
  """

  @type t ::
    :traffic_type_unspecified |
    :on_demand |
    :provisioned_throughput
end

# Update UsageMetadata:
defmodule Gemini.Types.Response.UsageMetadata do
  use TypedStruct

  alias Gemini.Types.Response.{ModalityTokenCount, TrafficType}

  @derive Jason.Encoder
  typedstruct do
    field(:prompt_token_count, integer() | nil, default: nil)
    field(:candidates_token_count, integer() | nil, default: nil)
    field(:total_token_count, integer(), enforce: true)
    field(:cached_content_token_count, integer() | nil, default: nil)

    # NEW FIELDS TO ADD:
    field(:thoughts_token_count, integer() | nil, default: nil)
    field(:tool_use_prompt_token_count, integer() | nil, default: nil)
    field(:prompt_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:cache_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:response_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:tool_use_prompt_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:traffic_type, TrafficType.t() | nil, default: nil)
  end
end
```

---

## 4. PromptFeedback Missing Fields

### Current gemini_ex Implementation
```elixir
# /home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex (lines 101-114)
typedstruct do
  field(:block_reason, String.t() | nil, default: nil)
  field(:safety_ratings, [SafetyRating.t()], default: [])
end
```

### Missing Fields Comparison

| Field Name | Python Type | gemini_ex Status | Priority | Description |
|------------|-------------|------------------|----------|-------------|
| `block_reason_message` | `Optional[str]` | ❌ Missing | **MEDIUM** | Readable message explaining why prompt was blocked |

### Implementation Code

```elixir
defmodule Gemini.Types.Response.PromptFeedback do
  use TypedStruct

  alias Gemini.Types.Response.SafetyRating

  @derive Jason.Encoder
  typedstruct do
    field(:block_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])

    # NEW FIELD TO ADD:
    field(:block_reason_message, String.t() | nil, default: nil)
  end
end
```

---

## 5. Part Missing Fields

### Current gemini_ex Implementation
```elixir
# /home/home/p/g/n/gemini_ex/lib/gemini/types/common/part.ex (lines 38-45)
typedstruct do
  field(:text, String.t() | nil, default: nil)
  field(:inline_data, Gemini.Types.Blob.t() | nil, default: nil)
  field(:function_call, Altar.ADM.FunctionCall.t() | nil, default: nil)
  field(:media_resolution, MediaResolution.t() | nil, default: nil)
  field(:thought_signature, String.t() | nil, default: nil)
end
```

### Missing Fields Comparison

| Field Name | Python Type | gemini_ex Status | Priority | Description |
|------------|-------------|------------------|----------|-------------|
| `file_data` | `Optional[FileData]` | ❌ Missing | **HIGH** | URI-based file data (alternative to inline_data) |
| `function_response` | `Optional[FunctionResponse]` | ❌ Missing | **HIGH** | Result output of a FunctionCall |
| `executable_code` | `Optional[ExecutableCode]` | ❌ Missing | **MEDIUM** | Code generated by model meant to be executed |
| `code_execution_result` | `Optional[CodeExecutionResult]` | ❌ Missing | **MEDIUM** | Result of executing ExecutableCode |
| `video_metadata` | `Optional[VideoMetadata]` | ❌ Missing | **MEDIUM** | Video metadata for video processing |
| `thought` | `Optional[bool]` | ❌ Missing | **HIGH** | Indicates if part is thought from model (Gemini 2.0+) |

**Note:** Python SDK has `thought_signature: Optional[bytes]` while gemini_ex has it as `String.t()`.

### Python Part Definition (Reference)
```python
# Python SDK Part fields:
class Part(_common.BaseModel):
  media_resolution: Optional[PartMediaResolution]
  code_execution_result: Optional[CodeExecutionResult]
  executable_code: Optional[ExecutableCode]
  file_data: Optional[FileData]
  function_call: Optional[FunctionCall]
  function_response: Optional[FunctionResponse]
  inline_data: Optional[Blob]
  text: Optional[str]
  thought: Optional[bool]
  thought_signature: Optional[bytes]
  video_metadata: Optional[VideoMetadata]
```

### Implementation Code

```elixir
# Update Part typedstruct:
defmodule Gemini.Types.Part do
  use TypedStruct

  alias Gemini.Types.{Blob, FileData, ExecutableCode, CodeExecutionResult, VideoMetadata}
  alias Altar.ADM.{FunctionCall, FunctionResponse}

  @derive Jason.Encoder
  typedstruct do
    field(:text, String.t() | nil, default: nil)
    field(:inline_data, Blob.t() | nil, default: nil)
    field(:function_call, FunctionCall.t() | nil, default: nil)
    field(:media_resolution, MediaResolution.t() | nil, default: nil)
    field(:thought_signature, binary() | nil, default: nil)  # Changed from String.t()

    # NEW FIELDS TO ADD:
    field(:file_data, FileData.t() | nil, default: nil)
    field(:function_response, FunctionResponse.t() | nil, default: nil)
    field(:executable_code, ExecutableCode.t() | nil, default: nil)
    field(:code_execution_result, CodeExecutionResult.t() | nil, default: nil)
    field(:video_metadata, VideoMetadata.t() | nil, default: nil)
    field(:thought, boolean() | nil, default: nil)
  end
end
```

---

## 6. SafetyRating Missing Fields

### Current gemini_ex Implementation
```elixir
# /home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex (lines 133-146)
typedstruct do
  field(:category, String.t(), enforce: true)
  field(:probability, String.t(), enforce: true)
  field(:blocked, boolean() | nil, default: nil)
end
```

### Missing Fields Comparison

| Field Name | Python Type | gemini_ex Status | Priority | Description |
|------------|-------------|------------------|----------|-------------|
| `probability_score` | `Optional[float]` | ❌ Missing | **MEDIUM** | Numeric harm probability score |
| `severity` | `Optional[HarmSeverity]` | ❌ Missing | **MEDIUM** | Harm severity levels in content |
| `severity_score` | `Optional[float]` | ❌ Missing | **MEDIUM** | Numeric harm severity score |
| `overwritten_threshold` | `Optional[HarmBlockThreshold]` | ❌ Missing | **LOW** | Overwritten threshold for Gemini 2.0 image safety |

### Implementation Code

```elixir
defmodule Gemini.Types.Response.SafetyRating do
  use TypedStruct

  @type harm_severity ::
    :harm_severity_unspecified |
    :harm_severity_negligible |
    :harm_severity_low |
    :harm_severity_medium |
    :harm_severity_high

  @derive Jason.Encoder
  typedstruct do
    field(:category, String.t(), enforce: true)
    field(:probability, String.t(), enforce: true)
    field(:blocked, boolean() | nil, default: nil)

    # NEW FIELDS TO ADD:
    field(:probability_score, float() | nil, default: nil)
    field(:severity, harm_severity() | nil, default: nil)
    field(:severity_score, float() | nil, default: nil)
    field(:overwritten_threshold, String.t() | nil, default: nil)
  end
end
```

---

## 7. Nested Types That Need Creation

The following types exist in Python SDK but are completely missing from gemini_ex:

### 7.1 ModalityTokenCount
**Priority:** HIGH
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/modality_token_count.ex`

```elixir
defmodule Gemini.Types.Response.ModalityTokenCount do
  @moduledoc """
  Represents token counting info for a single modality.

  Used to break down token usage by modality type (text, image, video, audio, document).
  """

  use TypedStruct

  @type media_modality ::
    :modality_unspecified |
    :text |
    :image |
    :video |
    :audio |
    :document

  @derive Jason.Encoder
  typedstruct do
    field(:modality, media_modality() | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
  end
end
```

### 7.2 TrafficType
**Priority:** LOW
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/traffic_type.ex`

```elixir
defmodule Gemini.Types.Response.TrafficType do
  @moduledoc """
  Traffic type for API requests.

  Shows whether a request consumes Pay-As-You-Go or
  Provisioned Throughput quota.
  """

  @type t ::
    :traffic_type_unspecified |
    :on_demand |
    :provisioned_throughput
end
```

### 7.3 FileData
**Priority:** HIGH
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/file_data.ex`

```elixir
defmodule Gemini.Types.FileData do
  @moduledoc """
  URI-based file data.

  Used to reference files by URI instead of inline data.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:file_uri, String.t(), enforce: true)
    field(:mime_type, String.t(), enforce: true)
    field(:display_name, String.t() | nil, default: nil)
  end
end
```

### 7.4 FunctionResponse
**Priority:** HIGH
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/function_response.ex`

```elixir
defmodule Gemini.Types.FunctionResponse do
  @moduledoc """
  Result output of a FunctionCall.

  Contains the function name and structured JSON response.
  """

  use TypedStruct

  @type scheduling :: :scheduling_unspecified | :silent | :when_idle | :interrupt

  @derive Jason.Encoder
  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:response, map(), enforce: true)
    field(:id, String.t() | nil, default: nil)
    field(:will_continue, boolean() | nil, default: nil)
    field(:scheduling, scheduling() | nil, default: nil)
  end
end
```

### 7.5 ExecutableCode
**Priority:** MEDIUM
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/executable_code.ex`

```elixir
defmodule Gemini.Types.ExecutableCode do
  @moduledoc """
  Code generated by the model meant to be executed.

  Generated when using the CodeExecution tool.
  """

  use TypedStruct

  @type language :: :language_unspecified | :python

  @derive Jason.Encoder
  typedstruct do
    field(:code, String.t(), enforce: true)
    field(:language, language(), enforce: true)
  end
end
```

### 7.6 CodeExecutionResult
**Priority:** MEDIUM
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/code_execution_result.ex`

```elixir
defmodule Gemini.Types.CodeExecutionResult do
  @moduledoc """
  Result of executing ExecutableCode.

  Only generated when using the CodeExecution tool.
  """

  use TypedStruct

  @type outcome ::
    :outcome_unspecified |
    :outcome_ok |
    :outcome_failed |
    :outcome_deadline_exceeded

  @derive Jason.Encoder
  typedstruct do
    field(:outcome, outcome(), enforce: true)
    field(:output, String.t() | nil, default: nil)
  end
end
```

### 7.7 VideoMetadata
**Priority:** MEDIUM
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/video_metadata.ex`

```elixir
defmodule Gemini.Types.VideoMetadata do
  @moduledoc """
  Metadata describing input video content.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:start_offset, String.t() | nil, default: nil)
    field(:end_offset, String.t() | nil, default: nil)
    field(:fps, float() | nil, default: nil)
  end
end
```

### 7.8 LogprobsResult
**Priority:** MEDIUM
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/logprobs_result.ex`

```elixir
defmodule Gemini.Types.Response.LogprobsResultCandidate do
  @moduledoc """
  Candidate for the logprobs token and score.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:token, String.t() | nil, default: nil)
    field(:token_id, integer() | nil, default: nil)
    field(:log_probability, float() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.LogprobsResultTopCandidates do
  @moduledoc """
  Top candidates for logprobs.
  """

  use TypedStruct

  alias Gemini.Types.Response.LogprobsResultCandidate

  @derive Jason.Encoder
  typedstruct do
    field(:candidates, [LogprobsResultCandidate.t()], default: [])
  end
end

defmodule Gemini.Types.Response.LogprobsResult do
  @moduledoc """
  Log-likelihood scores for response tokens and top tokens.
  """

  use TypedStruct

  alias Gemini.Types.Response.{LogprobsResultCandidate, LogprobsResultTopCandidates}

  @derive Jason.Encoder
  typedstruct do
    field(:chosen_candidates, [LogprobsResultCandidate.t()] | nil, default: nil)
    field(:top_candidates, [LogprobsResultTopCandidates.t()] | nil, default: nil)
  end
end
```

### 7.9 UrlContextMetadata
**Priority:** MEDIUM
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/url_context_metadata.ex`

```elixir
defmodule Gemini.Types.Response.UrlMetadata do
  @moduledoc """
  Metadata for a single URL context.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:url, String.t(), enforce: true)
    field(:title, String.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.UrlContextMetadata do
  @moduledoc """
  Metadata related to URL context retrieval tool.
  """

  use TypedStruct

  alias Gemini.Types.Response.UrlMetadata

  @derive Jason.Encoder
  typedstruct do
    field(:url_metadata, [UrlMetadata.t()] | nil, default: nil)
  end
end
```

### 7.10 GroundingMetadata (Enhanced Version)
**Priority:** HIGH
**Location to create:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/grounding_metadata.ex`

```elixir
defmodule Gemini.Types.Response.GroundingChunk do
  @moduledoc """
  Grounding chunk from a grounding source.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    # Define based on Python SDK GroundingChunk
    field(:web, map() | nil, default: nil)
    field(:retrieved_context, map() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingSupport do
  @moduledoc """
  Grounding support for a claim.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:segment, map() | nil, default: nil)
    field(:grounding_chunk_indices, [integer()] | nil, default: nil)
    field(:confidence_scores, [float()] | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.SearchEntryPoint do
  @moduledoc """
  Google search entry point for follow-up web searches.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:rendered_content, String.t() | nil, default: nil)
    field(:sdk_blob, binary() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.RetrievalMetadata do
  @moduledoc """
  Retrieval metadata.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:google_search_dynamic_retrieval_score, float() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingMetadata do
  @moduledoc """
  Metadata returned when grounding is enabled.

  This is more comprehensive than GroundingAttributions.
  """

  use TypedStruct

  alias Gemini.Types.Response.{
    GroundingChunk,
    GroundingSupport,
    SearchEntryPoint,
    RetrievalMetadata
  }

  @derive Jason.Encoder
  typedstruct do
    field(:grounding_chunks, [GroundingChunk.t()] | nil, default: nil)
    field(:grounding_supports, [GroundingSupport.t()] | nil, default: nil)
    field(:retrieval_metadata, RetrievalMetadata.t() | nil, default: nil)
    field(:retrieval_queries, [String.t()] | nil, default: nil)
    field(:search_entry_point, SearchEntryPoint.t() | nil, default: nil)
    field(:web_search_queries, [String.t()] | nil, default: nil)
    field(:google_maps_widget_context_token, String.t() | nil, default: nil)
  end
end
```

### 7.11 Enhanced Blob Type
**Priority:** MEDIUM
**Location to update:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/blob.ex`

```elixir
defmodule Gemini.Types.Blob do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:data, binary(), enforce: true)
    field(:mime_type, String.t(), enforce: true)

    # NEW FIELD TO ADD:
    field(:display_name, String.t() | nil, default: nil)
  end

  # ... existing functions ...
end
```

### 7.12 Enhanced PartMediaResolution
**Priority:** MEDIUM
**Current Location:** Already exists in `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/part.ex`

```elixir
defmodule Gemini.Types.Part.MediaResolution do
  use TypedStruct

  @type level ::
    :media_resolution_unspecified |
    :media_resolution_low |
    :media_resolution_medium |
    :media_resolution_high

  @derive Jason.Encoder
  typedstruct do
    field(:level, level() | nil, default: nil)

    # NEW FIELD TO ADD:
    field(:num_tokens, integer() | nil, default: nil)
  end
end
```

---

## 8. Implementation Recommendations

### 8.1 Priority Order

1. **Phase 1 - Critical Response Fields (Week 1)**
   - Add `response_id`, `model_version` to `GenerateContentResponse`
   - Add `thoughts_token_count`, `tool_use_prompt_token_count` to `UsageMetadata`
   - Add `finish_message`, `thought` to `Candidate` and `Part`
   - Create `ModalityTokenCount` type

2. **Phase 2 - Function Calling & Code Execution (Week 2)**
   - Create `FileData`, `FunctionResponse` types
   - Create `ExecutableCode`, `CodeExecutionResult` types
   - Update `Part` to include these new fields
   - Add function calling history to `GenerateContentResponse`

3. **Phase 3 - Advanced Features (Week 3)**
   - Create `LogprobsResult` and related types
   - Create `UrlContextMetadata` type
   - Create enhanced `GroundingMetadata` type
   - Add `VideoMetadata` support

4. **Phase 4 - Safety & Metadata (Week 4)**
   - Add modality token details to `UsageMetadata`
   - Add probability/severity scores to `SafetyRating`
   - Add `create_time`, `traffic_type`
   - Add `block_reason_message` to `PromptFeedback`

### 8.2 JSON Deserialization Updates

For each new type, you'll need to update JSON deserialization logic. Example pattern:

```elixir
# In your JSON decoder module:
defmodule Gemini.Decoder do
  def decode_generate_content_response(json) do
    json
    |> decode_base_fields()
    |> decode_response_id()
    |> decode_model_version()
    |> decode_create_time()
    # ... etc
  end

  defp decode_create_time(%{"createTime" => time_str} = json) when is_binary(time_str) do
    case DateTime.from_iso8601(time_str) do
      {:ok, dt, _} -> Map.put(json, :create_time, dt)
      _ -> json
    end
  end
  defp decode_create_time(json), do: json
end
```

### 8.3 Testing Strategy

For each new field, create tests:

```elixir
defmodule Gemini.Types.Response.GenerateContentResponseTest do
  use ExUnit.Case

  describe "response_id" do
    test "decodes response_id from API response" do
      json = ~s({"responseId": "abc123", "candidates": []})
      response = Gemini.decode_response(json)

      assert response.response_id == "abc123"
    end
  end

  describe "model_version" do
    test "decodes model_version from API response" do
      json = ~s({"modelVersion": "gemini-2.0-flash-exp-001", "candidates": []})
      response = Gemini.decode_response(json)

      assert response.model_version == "gemini-2.0-flash-exp-001"
    end
  end
end
```

### 8.4 Backward Compatibility

All new fields should be optional with `default: nil` to maintain backward compatibility:

```elixir
# Good - backward compatible
field(:response_id, String.t() | nil, default: nil)

# Bad - breaks existing code
field(:response_id, String.t(), enforce: true)
```

### 8.5 Documentation Updates

For each new field, add:
1. Moduledoc explaining the field
2. Examples in doctests
3. Update CHANGELOG.md
4. Update migration guide if needed

---

## 9. Field Priority Summary

### High Priority (15 fields)
Must implement for feature parity with Python SDK on core functionality:

1. `GenerateContentResponse.response_id`
2. `GenerateContentResponse.model_version`
3. `Candidate.finish_message`
4. `Candidate.grounding_metadata`
5. `UsageMetadata.thoughts_token_count`
6. `UsageMetadata.tool_use_prompt_token_count`
7. `Part.file_data`
8. `Part.function_response`
9. `Part.thought`
10. `ModalityTokenCount` (new type)
11. `FileData` (new type)
12. `FunctionResponse` (new type)

### Medium Priority (20 fields)
Important for advanced use cases:

1. `GenerateContentResponse.create_time`
2. `GenerateContentResponse.automatic_function_calling_history`
3. `Candidate.avg_logprobs`
4. `Candidate.logprobs_result`
5. `Candidate.url_context_metadata`
6. `UsageMetadata.prompt_tokens_details`
7. `UsageMetadata.cache_tokens_details`
8. `UsageMetadata.response_tokens_details`
9. `UsageMetadata.tool_use_prompt_tokens_details`
10. `PromptFeedback.block_reason_message`
11. `Part.executable_code`
12. `Part.code_execution_result`
13. `Part.video_metadata`
14. `SafetyRating.probability_score`
15. `SafetyRating.severity`
16. `SafetyRating.severity_score`
17. `ExecutableCode` (new type)
18. `CodeExecutionResult` (new type)
19. `VideoMetadata` (new type)
20. `LogprobsResult` (new type)

### Low Priority (15+ fields)
Nice to have for completeness:

1. `GenerateContentResponse.parsed`
2. `UsageMetadata.traffic_type`
3. `SafetyRating.overwritten_threshold`
4. `TrafficType` (new type)
5. `Blob.display_name`
6. `PartMediaResolution.num_tokens`
7. Various grounding-related subtypes

---

## 10. API Response Examples

### Example with Missing Fields

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "Hello!",
            "thought": false
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP",
      "finishMessage": "Natural stop point reached",
      "avgLogprobs": -0.15,
      "index": 0
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 10,
    "candidatesTokenCount": 5,
    "totalTokenCount": 15,
    "thoughtsTokenCount": 0,
    "promptTokensDetails": [
      {
        "modality": "TEXT",
        "tokenCount": 10
      }
    ],
    "responseTokensDetails": [
      {
        "modality": "TEXT",
        "tokenCount": 5
      }
    ],
    "trafficType": "ON_DEMAND"
  },
  "modelVersion": "gemini-2.0-flash-exp-001",
  "responseId": "abc123def456"
}
```

Current gemini_ex would fail to decode: `finishMessage`, `avgLogprobs`, `thoughtsTokenCount`, `promptTokensDetails`, `responseTokensDetails`, `trafficType`, `modelVersion`, `responseId`.

---

## 11. Migration Path

### Step 1: Add Types (No Breaking Changes)
Add all new types to the codebase without modifying existing types.

### Step 2: Update Existing Types
Add new optional fields to existing types with `default: nil`.

### Step 3: Update Decoders
Update JSON decoders to handle new fields gracefully (ignore unknown fields).

### Step 4: Update Encoders
Update JSON encoders to include new fields when present.

### Step 5: Documentation & Tests
Add comprehensive tests and documentation for all new fields.

### Step 6: Release
Release as a minor version bump (e.g., 1.2.0 → 1.3.0) since it's backward compatible.

---

## Appendix A: Complete Field List

### GenerateContentResponse Fields

| Field | Python SDK | gemini_ex | Status |
|-------|-----------|-----------|--------|
| candidates | ✅ | ✅ | ✅ Present |
| prompt_feedback | ✅ | ✅ | ✅ Present |
| usage_metadata | ✅ | ✅ | ✅ Present |
| response_id | ✅ | ❌ | ❌ Missing |
| model_version | ✅ | ❌ | ❌ Missing |
| create_time | ✅ | ❌ | ❌ Missing |
| automatic_function_calling_history | ✅ | ❌ | ❌ Missing |
| parsed | ✅ | ❌ | ❌ Missing |

### Candidate Fields

| Field | Python SDK | gemini_ex | Status |
|-------|-----------|-----------|--------|
| content | ✅ | ✅ | ✅ Present |
| finish_reason | ✅ | ✅ | ✅ Present |
| safety_ratings | ✅ | ✅ | ✅ Present |
| citation_metadata | ✅ | ✅ | ✅ Present |
| token_count | ✅ | ✅ | ✅ Present |
| index | ✅ | ✅ | ✅ Present |
| grounding_attributions | ✅ | ✅ | ✅ Present |
| finish_message | ✅ | ❌ | ❌ Missing |
| avg_logprobs | ✅ | ❌ | ❌ Missing |
| grounding_metadata | ✅ | ⚠️ | ⚠️ Different (grounding_attributions) |
| logprobs_result | ✅ | ❌ | ❌ Missing |
| url_context_metadata | ✅ | ❌ | ❌ Missing |

### UsageMetadata Fields

| Field | Python SDK | gemini_ex | Status |
|-------|-----------|-----------|--------|
| prompt_token_count | ✅ | ✅ | ✅ Present |
| candidates_token_count | ✅ | ✅ | ✅ Present |
| total_token_count | ✅ | ✅ | ✅ Present |
| cached_content_token_count | ✅ | ✅ | ✅ Present |
| thoughts_token_count | ✅ | ❌ | ❌ Missing |
| tool_use_prompt_token_count | ✅ | ❌ | ❌ Missing |
| prompt_tokens_details | ✅ | ❌ | ❌ Missing |
| cache_tokens_details | ✅ | ❌ | ❌ Missing |
| response_tokens_details | ✅ | ❌ | ❌ Missing |
| tool_use_prompt_tokens_details | ✅ | ❌ | ❌ Missing |
| traffic_type | ✅ | ❌ | ❌ Missing |

### Part Fields

| Field | Python SDK | gemini_ex | Status |
|-------|-----------|-----------|--------|
| text | ✅ | ✅ | ✅ Present |
| inline_data | ✅ | ✅ | ✅ Present |
| function_call | ✅ | ✅ | ✅ Present |
| media_resolution | ✅ | ✅ | ✅ Present |
| thought_signature | ✅ | ✅ | ⚠️ Different type (bytes vs String) |
| file_data | ✅ | ❌ | ❌ Missing |
| function_response | ✅ | ❌ | ❌ Missing |
| executable_code | ✅ | ❌ | ❌ Missing |
| code_execution_result | ✅ | ❌ | ❌ Missing |
| video_metadata | ✅ | ❌ | ❌ Missing |
| thought | ✅ | ❌ | ❌ Missing |

---

## Summary

**Total Analysis:**
- **50+ fields** are missing from gemini_ex
- **12 new types** need to be created
- **15 high-priority fields** should be implemented first
- **20 medium-priority fields** for advanced features
- **15+ low-priority fields** for completeness

**Recommended Timeline:** 4 weeks for full implementation

**Files to Create/Update:**
1. Update: `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex`
2. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/modality_token_count.ex`
3. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/traffic_type.ex`
4. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/file_data.ex`
5. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/function_response.ex`
6. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/executable_code.ex`
7. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/code_execution_result.ex`
8. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/video_metadata.ex`
9. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/logprobs_result.ex`
10. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/url_context_metadata.ex`
11. Create: `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/grounding_metadata.ex`
12. Update: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/part.ex`
13. Update: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/blob.ex`
