# Agent Prompt: Fill Missing Fields in gemini_ex (v0.6.4)

**Date:** 2025-12-05
**Target Version:** 0.6.4
**Scope:** Response types, Request types, Caching types (EXCLUDING "other types")

---

## MISSION

You are implementing missing fields in the gemini_ex Elixir library to achieve feature parity with Google's Python genai SDK. This is a TDD-driven implementation targeting version 0.6.4.

**CRITICAL:** Use Test-Driven Development. Write tests FIRST, watch them fail, then implement.

---

## REQUIRED READING (Read ALL of these first)

### Gap Analysis Documents (Read in order)
1. `/home/home/p/g/n/gemini_ex/docs/20251205/response-types/missing_fields.md` - 50+ missing response fields
2. `/home/home/p/g/n/gemini_ex/docs/20251205/request-types/missing_fields.md` - 25+ missing request fields
3. `/home/home/p/g/n/gemini_ex/docs/20251205/caching-types/missing_fields.md` - 9 missing caching fields

### Reference Implementation (Python SDK)
4. `/home/home/p/g/n/gemini_ex/python-genai/google/genai/types.py` - Authoritative type definitions

### Existing gemini_ex Code (Understand patterns)
5. `/home/home/p/g/n/gemini_ex/lib/gemini/types/response/generate_content_response.ex` - Response types
6. `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/generation_config.ex` - GenerationConfig
7. `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/part.ex` - Part type
8. `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/safety_setting.ex` - SafetySetting
9. `/home/home/p/g/n/gemini_ex/lib/gemini/apis/coordinator.ex` - Request building & response parsing
10. `/home/home/p/g/n/gemini_ex/lib/gemini/apis/context_cache.ex` - Cache implementation

### Test Patterns
11. `/home/home/p/g/n/gemini_ex/test/gemini/types/` - Existing type tests
12. `/home/home/p/g/n/gemini_ex/test/live_api_test.exs` - Live API test patterns

### Other Docs
13. `/home/home/p/g/n/gemini_ex/CHANGELOG.md` - Changelog format
14. `/home/home/p/g/n/gemini_ex/README.md` - Documentation style

---

## IMPLEMENTATION SCOPE

### Phase 1: Critical Types (Do First)

#### New Types to Create:
```
lib/gemini/types/response/modality_token_count.ex    # ModalityTokenCount struct
lib/gemini/types/response/traffic_type.ex            # TrafficType enum
lib/gemini/types/common/file_data.ex                 # FileData struct
lib/gemini/types/common/function_response.ex         # FunctionResponse struct
lib/gemini/types/common/modality.ex                  # Modality enum
lib/gemini/types/common/media_resolution.ex          # MediaResolution enum
lib/gemini/types/common/speech_config.ex             # SpeechConfig + VoiceConfig + PrebuiltVoiceConfig
```

#### Types to Update:

**UsageMetadata** (lib/gemini/types/response/generate_content_response.ex):
- Add: `thoughts_token_count` (integer | nil)
- Add: `tool_use_prompt_token_count` (integer | nil)
- Add: `prompt_tokens_details` ([ModalityTokenCount.t()] | nil)
- Add: `cache_tokens_details` ([ModalityTokenCount.t()] | nil)
- Add: `response_tokens_details` ([ModalityTokenCount.t()] | nil)
- Add: `tool_use_prompt_tokens_details` ([ModalityTokenCount.t()] | nil)
- Add: `traffic_type` (TrafficType.t() | nil)

**GenerateContentResponse** (lib/gemini/types/response/generate_content_response.ex):
- Add: `response_id` (String.t() | nil)
- Add: `model_version` (String.t() | nil)
- Add: `create_time` (DateTime.t() | nil)

**Candidate** (lib/gemini/types/response/generate_content_response.ex):
- Add: `finish_message` (String.t() | nil)
- Add: `avg_logprobs` (float() | nil)

**PromptFeedback** (lib/gemini/types/response/generate_content_response.ex):
- Add: `block_reason_message` (String.t() | nil)

**Part** (lib/gemini/types/common/part.ex):
- Add: `file_data` (FileData.t() | nil)
- Add: `function_response` (FunctionResponse.t() | nil)
- Add: `thought` (boolean() | nil)

**GenerationConfig** (lib/gemini/types/common/generation_config.ex):
- Add: `seed` (integer() | nil)
- Add: `response_modalities` ([Modality.t()] | nil)
- Add: `speech_config` (SpeechConfig.t() | nil)
- Add: `media_resolution` (MediaResolution.t() | nil)

**SafetyRating** (lib/gemini/types/response/generate_content_response.ex):
- Add: `probability_score` (float() | nil)
- Add: `severity` (String.t() | nil)
- Add: `severity_score` (float() | nil)

### Phase 2: Update Coordinators

**lib/gemini/apis/coordinator.ex**:
- Update `normalize_response/1` to parse new fields from API response
- Update `build_generation_config/1` to include new GenerationConfig fields
- Handle camelCase → snake_case conversion for all new fields

### Phase 3: Medium Priority (If Time Permits)
- ExecutableCode, CodeExecutionResult types
- VideoMetadata type
- LogprobsResult types
- GroundingMetadata types (enhanced version)

---

## TDD WORKFLOW

For EACH new field/type:

### Step 1: Write Failing Test
```elixir
# test/gemini/types/response/usage_metadata_test.exs
defmodule Gemini.Types.Response.UsageMetadataTest do
  use ExUnit.Case

  alias Gemini.Types.Response.UsageMetadata

  describe "thoughts_token_count" do
    test "parses from API response" do
      json = %{
        "totalTokenCount" => 100,
        "thoughtsTokenCount" => 50
      }

      metadata = UsageMetadata.from_api(json)
      assert metadata.thoughts_token_count == 50
    end

    test "handles nil when not present" do
      json = %{"totalTokenCount" => 100}
      metadata = UsageMetadata.from_api(json)
      assert metadata.thoughts_token_count == nil
    end
  end
end
```

### Step 2: Run Test (Should Fail)
```bash
mix test test/gemini/types/response/usage_metadata_test.exs
```

### Step 3: Implement Minimum Code
Add field and parsing logic.

### Step 4: Run Test (Should Pass)
```bash
mix test test/gemini/types/response/usage_metadata_test.exs
```

### Step 5: Refactor if needed

---

## CODE PATTERNS TO FOLLOW

### TypedStruct Pattern
```elixir
defmodule Gemini.Types.Response.ModalityTokenCount do
  @moduledoc """
  Token counting info for a single modality.

  Used in UsageMetadata to break down token usage by modality type.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:modality, String.t() | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
  end

  @doc """
  Parse from API response map.
  """
  def from_api(nil), do: nil
  def from_api(data) when is_map(data) do
    %__MODULE__{
      modality: data["modality"],
      token_count: data["tokenCount"]
    }
  end
end
```

### Enum Pattern
```elixir
defmodule Gemini.Types.Modality do
  @moduledoc """
  Response modality types for multimodal generation.
  """

  @type t :: :text | :image | :audio | :unspecified

  @api_values %{
    "TEXT" => :text,
    "IMAGE" => :image,
    "AUDIO" => :audio,
    "MODALITY_UNSPECIFIED" => :unspecified
  }

  def from_api(nil), do: nil
  def from_api(str) when is_binary(str), do: Map.get(@api_values, str, :unspecified)

  def to_api(:text), do: "TEXT"
  def to_api(:image), do: "IMAGE"
  def to_api(:audio), do: "AUDIO"
  def to_api(_), do: "MODALITY_UNSPECIFIED"
end
```

### Response Parsing Pattern (in coordinator.ex)
```elixir
defp parse_usage_metadata(nil), do: nil
defp parse_usage_metadata(data) when is_map(data) do
  %UsageMetadata{
    prompt_token_count: data["promptTokenCount"],
    candidates_token_count: data["candidatesTokenCount"],
    total_token_count: data["totalTokenCount"] || 0,
    cached_content_token_count: data["cachedContentTokenCount"],
    # NEW FIELDS
    thoughts_token_count: data["thoughtsTokenCount"],
    tool_use_prompt_token_count: data["toolUsePromptTokenCount"],
    prompt_tokens_details: parse_modality_counts(data["promptTokensDetails"]),
    cache_tokens_details: parse_modality_counts(data["cacheTokensDetails"]),
    response_tokens_details: parse_modality_counts(data["responseTokensDetails"]),
    traffic_type: TrafficType.from_api(data["trafficType"])
  }
end

defp parse_modality_counts(nil), do: nil
defp parse_modality_counts(counts) when is_list(counts) do
  Enum.map(counts, &ModalityTokenCount.from_api/1)
end
```

---

## VERSION BUMP INSTRUCTIONS

### 1. Update mix.exs
Change line 4:
```elixir
@version "0.6.3"
```
To:
```elixir
@version "0.6.4"
```

### 2. Update README.md
Find the installation section and update:
```elixir
{:gemini_ex, "~> 0.6.3"}
```
To:
```elixir
{:gemini_ex, "~> 0.6.4"}
```

### 3. Add CHANGELOG Entry
Add at the TOP of CHANGELOG.md (after the header):

```markdown
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
  - `severity_score` - Numeric severity score (0.0-1.0)

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
```

---

## VALIDATION CHECKLIST

Before marking complete, verify:

- [ ] All tests pass: `mix test`
- [ ] No compiler warnings: `mix compile --warnings-as-errors`
- [ ] Code formatted: `mix format`
- [ ] Dialyzer passes: `mix dialyzer` (if configured)
- [ ] Version bumped to 0.6.4 in mix.exs
- [ ] Version bumped to 0.6.4 in README.md
- [ ] CHANGELOG.md updated with 0.6.4 entry
- [ ] All new types have @moduledoc
- [ ] All public functions have @doc

---

## FIELD MAPPING REFERENCE

| Python SDK Field | API Field (camelCase) | Elixir Field |
|-----------------|----------------------|--------------|
| thoughts_token_count | thoughtsTokenCount | thoughts_token_count |
| tool_use_prompt_token_count | toolUsePromptTokenCount | tool_use_prompt_token_count |
| prompt_tokens_details | promptTokensDetails | prompt_tokens_details |
| cache_tokens_details | cacheTokensDetails | cache_tokens_details |
| response_tokens_details | responseTokensDetails | response_tokens_details |
| response_id | responseId | response_id |
| model_version | modelVersion | model_version |
| create_time | createTime | create_time |
| finish_message | finishMessage | finish_message |
| avg_logprobs | avgLogprobs | avg_logprobs |
| block_reason_message | blockReasonMessage | block_reason_message |
| file_data | fileData | file_data |
| function_response | functionResponse | function_response |
| probability_score | probabilityScore | probability_score |
| severity_score | severityScore | severity_score |
| response_modalities | responseModalities | response_modalities |
| speech_config | speechConfig | speech_config |
| media_resolution | mediaResolution | media_resolution |

---

## PRIORITY ORDER

1. **CRITICAL** - UsageMetadata fields (thoughts_token_count, tool_use_prompt_token_count)
2. **CRITICAL** - ModalityTokenCount type + *_tokens_details fields
3. **HIGH** - GenerateContentResponse fields (response_id, model_version)
4. **HIGH** - GenerationConfig fields (seed, response_modalities)
5. **HIGH** - Part fields (file_data, function_response, thought)
6. **MEDIUM** - SpeechConfig and related voice types
7. **MEDIUM** - SafetyRating score fields
8. **MEDIUM** - Candidate fields (finish_message, avg_logprobs)
9. **LOW** - PromptFeedback.block_reason_message

---

## DO NOT IMPLEMENT (Out of Scope)

These are in the "other-types" doc and should be skipped:
- File API types
- Grounding types (GroundingChunk, GroundingSupport, etc.)
- Image generation types
- Live API types
- Complete tool types (GoogleSearch, FileSearch, etc.)
- HttpOptions, HttpRetryOptions
- Complete FinishReason enum values

---

## START HERE

1. Read all required documents listed above
2. Create test file for ModalityTokenCount
3. Implement ModalityTokenCount
4. Create test file for TrafficType
5. Implement TrafficType
6. Update UsageMetadata with new fields + tests
7. Continue through the priority list
8. Bump version and update CHANGELOG last

Good luck!
