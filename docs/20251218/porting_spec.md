# Python SDK Port Specification - December 18, 2025

## Summary

This document details the changes required to port commits from the Python `google-genai` SDK (from commit `436ca2e1d536d57d662284b6b1079215de3d787f` to `f16142bc74a36c0fc7ef4a22abaf0d3250ef233f`) to the Elixir `gemini_ex` implementation.

**Total Commits to Port:** 21
**SDK Version Range:** v1.56.0 (pyproject.toml)

**Verification Note:** `git log 436ca2e1..f16142bc` yields 21 commits (includes `00422de` docs update).

---

## Commit Overview

| Commit Hash | Type | Summary |
|-------------|------|---------|
| `f16142b` | chore | Rename `total_reasoning_tokens` to `total_thought_tokens` |
| `0de263e` | chore | Remove the `object` field from Interaction |
| `e0a2612` | chore | Add `gemini-3-flash-preview` to interaction model list |
| `f22b46b` | chore | Clean up internal configurations |
| `22500b5` | docs | Update codegen_instructions for Gemini 3 Flash |
| `c66e0ce` | **feat** | Add PersonGeneration to ImageConfig for Vertex Gempix |
| `b4c063e` | docs | Regenerate docs for 1.56.0 |
| `7d92395` | release | Release 1.56.0 |
| `e247e3b` | chore | Lazy import yaml in types.py |
| `336b823` | **feat** | Add ULTRA_HIGH MediaResolution and new ThinkingLevel enums |
| `dc7f00f` | **feat** | Define and use DocumentMimeType for DocumentContent |
| `5749e22` | chore | Cleanup type fields (remove discriminator descriptions) |
| `3472650` | chore | Fix interactions paths |
| `31f80d7` | chore | Increase required version of google-auth |
| `96d644c` | **feat** | Add minimal and medium thinking levels |
| `356c320` | **feat** | Add ultra high resolution to media resolution in Parts |
| `4385e16` | feat | Add minimal and medium thinking levels (dup) |
| `cec3646` | feat | Add minimal and medium thinking levels (dup) |
| `8a0489d` | chore | Fix tests |
| `8fd4886` | **feat** | Add support for Struct in ToolResult Content |
| `00422de` | docs | Update and restructure codegen_instructions |

---

## Changes By Category

### Category 1: Type/Enum Updates (HIGH PRIORITY)

#### 1.1 Rename `total_reasoning_tokens` to `total_thought_tokens`

**Python Change (commit `f16142b`):**
```python
# In google/genai/_interactions/types/usage.py
- total_reasoning_tokens: Optional[int] = None
+ total_thought_tokens: Optional[int] = None
"""Number of tokens of thoughts for thinking models."""
```

**Elixir Files to Update:**
- `lib/gemini/types/interactions/usage.ex`

**Required Changes:**
```elixir
# In Gemini.Types.Interactions.Usage

# 1. Update struct field (line 184)
- field(:total_reasoning_tokens, non_neg_integer())
+ field(:total_thought_tokens, non_neg_integer())

# 2. Update from_api/1 (line 209)
- total_reasoning_tokens: Map.get(data, "total_reasoning_tokens"),
+ total_thought_tokens: Map.get(data, "total_thought_tokens"),

# 3. Update to_api/1 (line 240)
- |> maybe_put("total_reasoning_tokens", usage.total_reasoning_tokens)
+ |> maybe_put("total_thought_tokens", usage.total_thought_tokens)
```

**Impact:** Breaking change for any code referencing `total_reasoning_tokens`

---

#### 1.2 Add ThinkingLevel Enums: `:minimal` and `:medium` (HIGH PRIORITY)

**Python Change (commits `96d644c`, `336b823`):**
```python
class ThinkingLevel(_common.CaseInSensitiveEnum):
  """The number of thoughts tokens that the model should generate."""
  THINKING_LEVEL_UNSPECIFIED = 'THINKING_LEVEL_UNSPECIFIED'
  LOW = 'LOW'
  MEDIUM = 'MEDIUM'  # NOW SUPPORTED
  HIGH = 'HIGH'
  MINIMAL = 'MINIMAL'  # NEW - Gemini 3 Flash only
```

**For Interactions API (commit `336b823`):**
```python
ThinkingLevel: TypeAlias = Literal["minimal", "low", "medium", "high"]
```

**Model Support (from official docs):**
| Model | Supported Levels |
|-------|-----------------|
| Gemini 3 Pro | `low`, `high` |
| Gemini 3 Flash | `minimal`, `low`, `medium`, `high` |

**Note:** `minimal` does NOT guarantee thinking is off - the model may still think minimally for complex tasks.

**Elixir Files to Update:**
1. `lib/gemini/types/enums.ex` (ThinkingLevel module)
2. `lib/gemini/types/common/generation_config.ex` (ThinkingConfig type)
3. `lib/gemini/validation/thinking_config.ex` (Validation logic)
4. `lib/gemini/types/interactions/config.ex` (Interactions ThinkingLevel doc/type)

**Required Changes in `lib/gemini/types/enums.ex`:**
```elixir
defmodule ThinkingLevel do
  @moduledoc """
  Thinking configuration levels for Gemini 3 models.

  ## Values
  - `:unspecified` - Unspecified thinking level
  - `:minimal` - Minimal thinking (Gemini 3 Flash only)
  - `:low` - Low thinking level
  - `:medium` - Medium thinking level (Gemini 3 Flash only)
  - `:high` - High thinking level (default)

  ## Model Support
  - **Gemini 3 Pro**: `:low`, `:high`
  - **Gemini 3 Flash**: `:minimal`, `:low`, `:medium`, `:high`
  """

  @type t :: :unspecified | :minimal | :low | :medium | :high

  @spec to_api(t()) :: String.t()
  def to_api(:unspecified), do: "THINKING_LEVEL_UNSPECIFIED"
  def to_api(:minimal), do: "MINIMAL"
  def to_api(:low), do: "LOW"
  def to_api(:medium), do: "MEDIUM"
  def to_api(:high), do: "HIGH"

  @spec from_api(String.t() | nil) :: t() | nil
  def from_api("THINKING_LEVEL_UNSPECIFIED"), do: :unspecified
  def from_api("MINIMAL"), do: :minimal
  def from_api("minimal"), do: :minimal
  def from_api("LOW"), do: :low
  def from_api("low"), do: :low
  def from_api("MEDIUM"), do: :medium
  def from_api("medium"), do: :medium
  def from_api("HIGH"), do: :high
  def from_api("high"), do: :high
  def from_api(nil), do: nil
  def from_api(_), do: :high  # Default to high
end
```

**Required Changes in `lib/gemini/types/interactions/config.ex`:**
```elixir
@moduledoc """
Thinking level for Interactions generation ("minimal", "low", "medium", "high").
"""

@type t :: String.t()
```

**Required Changes in `lib/gemini/types/common/generation_config.ex`:**
```elixir
# Update the @type thinking_level in ThinkingConfig module (line 36)
- @type thinking_level :: :low | :medium | :high
+ @type thinking_level :: :unspecified | :minimal | :low | :medium | :high
```

**Required Changes in `lib/gemini/validation/thinking_config.ex`:**
```elixir
# Update type definition (line 31)
- @type thinking_level :: :low | :medium | :high
+ @type thinking_level :: :unspecified | :minimal | :low | :medium | :high

# Update module doc (lines 5-11) to reflect current support:
@moduledoc """
Validation for thinking configuration parameters based on model capabilities.

## Gemini 3 Models

Use `thinking_level` for Gemini 3 models:
- `:minimal` - Minimal thinking (Flash only). Model may still think for complex tasks.
- `:low` - Minimizes latency and cost
- `:medium` - Balanced thinking (Flash only)
- `:high` - Maximizes reasoning depth (default)

## Model Support
- **Gemini 3 Pro**: `:low`, `:high`
- **Gemini 3 Flash**: `:minimal`, `:low`, `:medium`, `:high`
...
"""

# Update validate_level/1 function (lines 51-61):
@spec validate_level(thinking_level(), String.t() | nil) :: validation_result()
def validate_level(level, model \\ nil)

def validate_level(:unspecified, _model), do: :ok
def validate_level(:low, _model), do: :ok
def validate_level(:high, _model), do: :ok

def validate_level(:minimal, model) do
  if model && String.contains?(model, "gemini-3-pro") && !String.contains?(model, "flash") do
    {:error, "Thinking level :minimal is only supported on Gemini 3 Flash models"}
  else
    :ok
  end
end

def validate_level(:medium, model) do
  if model && String.contains?(model, "gemini-3-pro") && !String.contains?(model, "flash") do
    {:error, "Thinking level :medium is only supported on Gemini 3 Flash models"}
  else
    :ok
  end
end

def validate_level(level, _model) do
  {:error, "Invalid thinking level: #{inspect(level)}. Use :minimal, :low, :medium, or :high."}
end
```

**Required Changes in `lib/gemini/apis/coordinator.ex`:**
```elixir
# Allow :minimal (and optionally :unspecified) when building GenerationConfig maps.
defp convert_thinking_level(:minimal), do: "minimal"
defp convert_thinking_level(:unspecified), do: nil

# In convert_thinking_config_to_api/1 map handling:
{:thinking_level, level}, acc when level in [:unspecified, :minimal, :low, :medium, :high] ->
  Map.put(acc, "thinkingLevel", convert_thinking_level(level))
```

**Docs Update (GenerationConfig):** Expand `thinking_level` docs and examples to include
`:minimal` and `:medium` with model-specific support (Gemini 3 Flash only).

---

#### 1.3 Add ULTRA_HIGH MediaResolution

**Python Change (commits `356c320`, `336b823`):**
```python
# In types.py - PartMediaResolutionLevel
MEDIA_RESOLUTION_ULTRA_HIGH = 'MEDIA_RESOLUTION_ULTRA_HIGH'
"""Media resolution set to ultra high."""

# In interactions content types
resolution: Optional[Literal["low", "medium", "high", "ultra_high"]] = None
```

**Elixir Files to Update:**
- `lib/gemini/types/common/media_resolution.ex`
- `lib/gemini/types/interactions/content.ex` (ImageContent, VideoContent)

**Required Changes in `lib/gemini/types/common/media_resolution.ex`:**
```elixir
@type t ::
        :media_resolution_unspecified
        | :media_resolution_low
        | :media_resolution_medium
        | :media_resolution_high
        | :media_resolution_ultra_high  # ADD THIS

@api_values %{
  "MEDIA_RESOLUTION_UNSPECIFIED" => :media_resolution_unspecified,
  "MEDIA_RESOLUTION_LOW" => :media_resolution_low,
  "MEDIA_RESOLUTION_MEDIUM" => :media_resolution_medium,
  "MEDIA_RESOLUTION_HIGH" => :media_resolution_high,
  "MEDIA_RESOLUTION_ULTRA_HIGH" => :media_resolution_ultra_high  # ADD THIS
}

@reverse_api_values %{
  media_resolution_unspecified: "MEDIA_RESOLUTION_UNSPECIFIED",
  media_resolution_low: "MEDIA_RESOLUTION_LOW",
  media_resolution_medium: "MEDIA_RESOLUTION_MEDIUM",
  media_resolution_high: "MEDIA_RESOLUTION_HIGH",
  media_resolution_ultra_high: "MEDIA_RESOLUTION_ULTRA_HIGH"  # ADD THIS
}
```

**Required Changes in `lib/gemini/types/interactions/content.ex`:**

For `ImageContent` and `VideoContent`:
```elixir
# Update the @type resolution to include ultra_high
@type resolution :: :low | :medium | :high | :ultra_high | String.t()
```

---

#### 1.4 Add DocumentMimeType

**Python Change (commit `dc7f00f`):**
```python
# New file: google/genai/_interactions/types/document_mime_type.py
DocumentMimeType: TypeAlias = Union[str, Literal["application/pdf"]]
```

**Elixir Files to Update:**
- Create new type or add to existing enum module
- `lib/gemini/types/interactions/content.ex` (DocumentContent)

**Required Changes:**

Option A: Add to enums.ex:
```elixir
defmodule DocumentMimeType do
  @moduledoc """
  MIME types for document content in Interactions.
  """

  @type t :: :application_pdf | String.t()

  @spec to_api(t()) :: String.t()
  def to_api(:application_pdf), do: "application/pdf"
  def to_api(value) when is_binary(value), do: value

  @spec from_api(String.t() | nil) :: t() | nil
  def from_api("application/pdf"), do: :application_pdf
  def from_api(nil), do: nil
  def from_api(value), do: value
end
```

Option B: Just use String.t() with documentation (simpler, recommended):
```elixir
# In DocumentContent, update doc:
@moduledoc """
A document content block (`type: "document"`).

## Supported MIME Types
- `"application/pdf"` - PDF documents
"""
```

---

### Category 2: Interactions API Changes (MEDIUM PRIORITY)

#### 2.1 Remove `object` Field from Interaction

**Python Change (commit `0de263e`):**
```python
# Removed from Interaction class:
- object: Optional[Literal["interaction"]] = None
- """Output only. The object type of the interaction. Always set to `interaction`."""
```

**Elixir Files to Update:**
- `lib/gemini/types/interactions/interaction.ex`

**Required Changes:**
```elixir
# In Gemini.Types.Interactions.Interaction

# 1. Remove from typedstruct (line 21)
- field(:object, String.t(), enforce: false)

# 2. Remove from from_api/1 (line 40)
- object: Map.get(data, "object"),

# 3. Remove from to_api/1 (line 60)
- |> maybe_put("object", interaction.object)
```

**Impact:** Breaking change - removes field from struct

---

#### 2.2 Add `gemini-3-flash-preview` to Model List

**Python Change (commit `e0a2612`):**
```python
# In model.py and model_param.py
Model: TypeAlias = Union[
    Literal[
        ...
        "gemini-3-pro-preview",
        "gemini-3-flash-preview",  # NEW
    ],
    str,
]
```

**Elixir Impact:** Minimal - model names are typically passed as strings. Consider adding to documentation or validation if applicable.

---

#### 2.3 Support for Struct in ToolResult Content

**Python Change (commit `8fd4886`):**
```python
# ResultItemsItem now includes `object` type for arbitrary struct data
ResultItemsItem: TypeAlias = Union[str, ImageContent, object]  # Added `object`
```

**Elixir Files to Update:**
- `lib/gemini/types/interactions/content.ex` (FunctionResultContent, MCPServerToolResultContent)

**Required Changes:**
The current Elixir implementation uses `term()` for `result` field which already supports arbitrary data:
```elixir
field(:result, term())  # Already flexible enough
```

No change needed - Elixir's dynamic typing already handles this case. Document that result items can be:
- String
- ImageContent struct
- Any arbitrary map/struct data

---

#### 2.4 Cleanup Type Field Descriptions

**Python Change (commit `5749e22`):**
Removed discriminator comments from all content types:
```python
- """Used as the OpenAPI type discriminator for the content oneof."""
```

**Elixir Impact:** Documentation only - no functional changes needed. The `type` field already exists without this doc string in Elixir.

---

#### 2.5 Fix Interactions Paths for Vertex AI

**Python Change (commit `3472650`):**
Interactions get/cancel/delete paths now flow through `_build_maybe_vertex_path`, ensuring
Vertex AI paths include `projects/{project_id}/locations/{location}`.

**Elixir Files to Update:**
- `lib/gemini/apis/interactions.ex`

**Required Changes:**
```elixir
# When auth == :vertex_ai, build get/cancel/delete paths with project/location:
defp vertex_interaction_path(%{project_id: project_id, location: location}, api_version, id, suffix \\ "") do
  "/#{api_version}/projects/#{project_id}/locations/#{location}/interactions/#{id}#{suffix}"
end

# Use vertex_interaction_path/4 in build_get_url/build_cancel_url/build_delete_url for Vertex.
```

**Tests to Add:**
- Vertex AI get/cancel/delete path tests mirroring Python `test_paths.py`.

---

### Category 3: ImageConfig Changes (MEDIUM PRIORITY)

#### 3.1 Add PersonGeneration to ImageConfig (Vertex AI Only)

**Python Change (commit `c66e0ce`):**
```python
# In types.py - ImageConfig
person_generation: Optional[str] = Field(
    default=None,
    description="""Controls the generation of people. Supported values are:
    ALLOW_ALL, ALLOW_ADULT, ALLOW_NONE.""",
)

# In models.py - _ImageConfig_to_mldev (Gemini API)
if getv(from_object, ['person_generation']) is not None:
    raise ValueError(
        'person_generation parameter is not supported in Gemini API.'
    )

# In models.py - _ImageConfig_to_vertex (Vertex AI)
if getv(from_object, ['person_generation']) is not None:
    setv(to_object, ['personGeneration'], getv(from_object, ['person_generation']))
```

**Elixir Files to Update:**
- `lib/gemini/types/generation/image.ex` already has this - verify it matches

**Verification Required:**
The Elixir implementation already has `person_generation` in `ImageGenerationConfig`. Verify:
1. The type values match: `ALLOW_ALL`, `ALLOW_ADULT`, `ALLOW_NONE`
2. Vertex AI converter includes it
3. Gemini API converter raises an error

Current Elixir type:
```elixir
@type person_generation :: :allow_adult | :allow_all | :dont_allow
```

**Note:** Python uses `ALLOW_NONE` but Elixir has `:dont_allow`. Consider aligning:
```elixir
@type person_generation :: :allow_adult | :allow_all | :allow_none
```

---

### Category 4: Structured Output Enhancements (MEDIUM PRIORITY)

#### 4.1 Add `response_json_schema` Field (IMPORTANT)

**Gap Identified:** The Elixir implementation currently only supports `response_schema` which converts to `responseSchema` in the API. However, the official documentation and Python SDK recommend using `response_json_schema` which converts to `responseJsonSchema`.

**Python SDK Types (types.py lines 5081-5111):**
```python
# Option 1: Schema type (Gemini's internal format)
response_schema: Optional[SchemaUnion] = Field(...)  # -> responseSchema

# Option 2: JSON Schema (recommended, standard format)
response_json_schema: Optional[Any] = Field(...)  # -> responseJsonSchema
```

**Elixir Alignment Goal:**
- Keep `response_schema` -> `responseSchema` (Gemini internal schema)
- Add `response_json_schema` -> `responseJsonSchema` (standard JSON Schema)

**Required Changes in `lib/gemini/types/common/generation_config.ex`:**
```elixir
# Add new field (after response_schema on line 87)
field(:response_json_schema, map() | nil, default: nil)
```

**Required Changes in `lib/gemini/apis/coordinator.ex`:**
```elixir
# Add handler in build_generation_config (after response_schema handler ~line 1387)
{:response_json_schema, schema}, acc when is_map(schema) ->
  Map.put(acc, :responseJsonSchema, schema)
```

**Usage Difference:**
```elixir
# response_schema - For Gemini's Schema type
config = %{response_schema: %{type: "OBJECT", properties: %{...}}}

# response_json_schema - For standard JSON Schema (recommended)
config = %{response_json_schema: %{"type" => "object", "properties" => %{...}}}
```

---

#### 4.2 Add `routing_config` and `model_selection_config` (LOW PRIORITY)

**Python SDK Fields:**
```python
routing_config: Optional[GenerationConfigRoutingConfig]
model_selection_config: Optional[ModelSelectionConfig]
```

**Impact:** Low priority - these are advanced routing features not commonly used.
Add them only if you plan to support routing/selection features in the Elixir SDK.

---

#### 4.3 Add Built-in Tools Support for GenerateContent (HIGH PRIORITY)

**Documentation Feature (Gemini 3):**
```json
{
  "tools": [{"googleSearch": {}}, {"urlContext": {}}, {"codeExecution": {}}],
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseJsonSchema": {...}
  }
}
```

**Elixir Alignment Goal:**
- Keep `response_mime_type` and `response_schema`
- Add `response_json_schema` (see 4.1)
- Extend `tools` serialization beyond FunctionDeclaration (built-in tools below)

**Gap Identified:** `ToolSerialization.ex` only handles `FunctionDeclaration` (user-defined functions). It does NOT serialize built-in tools:
- `googleSearch` - Google Search grounding
- `urlContext` - URL context fetching
- `codeExecution` - Code execution

These built-in tools ARE implemented in the **Interactions API** (`lib/gemini/types/interactions/tool.ex`) but NOT in the main `generateContent` API.

**Required Changes in `lib/gemini/types/tool_serialization.ex`:**
```elixir
@doc """
Convert tools list to API format, supporting both FunctionDeclarations and built-in tools.
"""
@spec to_api_tool_list(list()) :: api_tool_list()
def to_api_tool_list(tools) when is_list(tools) do
  Enum.flat_map(tools, fn
    # Built-in tools (pass through as-is)
    %{google_search: _} = tool -> [camelize_keys(tool)]
    %{googleSearch: _} = tool -> [tool]
    %{url_context: _} = tool -> [camelize_keys(tool)]
    %{urlContext: _} = tool -> [tool]
    %{code_execution: _} = tool -> [camelize_keys(tool)]
    %{codeExecution: _} = tool -> [tool]

    # Atom shorthand for built-in tools
    :google_search -> [%{"googleSearch" => %{}}]
    :url_context -> [%{"urlContext" => %{}}]
    :code_execution -> [%{"codeExecution" => %{}}]

    # FunctionDeclaration (existing logic)
    %FunctionDeclaration{} = fd ->
      [%{"functionDeclarations" => [function_declaration_to_map(fd)]}]

    # List of FunctionDeclarations
    declarations when is_list(declarations) ->
      [%{"functionDeclarations" => Enum.map(declarations, &function_declaration_to_map/1)}]

    # Pass through unknown maps
    %{} = tool -> [tool]

    _ -> []
  end)
end
```

**Usage Example:**
```elixir
# With built-in tools (Gemini 3)
Gemini.generate("Search for latest news",
  model: "gemini-3-pro-preview",
  tools: [:google_search, :url_context],
  response_json_schema: %{"type" => "object", ...}
)

# Or with map format
Gemini.generate("Execute this code",
  model: "gemini-3-pro-preview",
  tools: [%{google_search: %{}}, %{code_execution: %{}}]
)
```

**Files to Update:**
- `lib/gemini/types/tool_serialization.ex` - Add built-in tool support

---

### Category 5: Model Registry Updates (HIGH PRIORITY)

#### 5.1 Add `gemini-3-flash-preview` Model (CRITICAL - Just Released)

**New Model:** Add `gemini-3-flash-preview` to the model registry.

**File to Update:** `lib/gemini/config.ex`

**Required Changes:**
```elixir
# In @universal_models (after pro_3_image_preview, ~line 62)
@universal_models %{
  # Gemini 3 models (preview)
  pro_3_preview: "gemini-3-pro-preview",
  pro_3_image_preview: "gemini-3-pro-image-preview",
  flash_3_preview: "gemini-3-flash-preview",  # ADD THIS
  ...
}
```

**Model Capabilities (from docs):**
- Input: Text, Image, Video, Audio, PDF
- Output: Text
- Input tokens: 1,048,576
- Output tokens: 65,536
- Thinking: Supported (levels: minimal, low, medium, high)
- Caching: Supported
- Function calling: Supported
- Structured outputs: Supported
- Code execution: Supported
- Search grounding: Supported
- URL context: Supported

---

#### 5.2 Add Additional Model Variants (MEDIUM PRIORITY)

**Additional models from documentation not in registry:**

| Model ID | Category | Notes |
|----------|----------|-------|
| `gemini-2.0-flash-001` | Stable | Dated stable variant |
| `gemini-2.0-flash-exp` | Experimental | Experimental 2.0 Flash |
| `gemini-2.0-flash-lite-001` | Stable | Dated Flash Lite variant |
| `gemini-2.5-flash-preview-09-2025` | Preview | Specific preview version |
| `gemini-2.5-flash-lite-preview-09-2025` | Preview | Specific preview version |
| `gemini-2.5-flash-image` | Image | Stable image generation |
| `gemini-2.5-flash-image-preview` | Image | Preview image generation |
| `gemini-2.5-flash-native-audio-preview-09-2025` | Live/Audio | Dated native audio preview |
| `gemini-2.5-flash-native-audio-preview-12-2025` | Live/Audio | Latest audio preview |

**Suggested additions to `lib/gemini/config.ex`:**
```elixir
@universal_models %{
  # ... existing models ...

  # Gemini 3 Flash (NEW)
  flash_3_preview: "gemini-3-flash-preview",

  # Gemini 2.5 Image models
  flash_2_5_image: "gemini-2.5-flash-image",
  flash_2_5_image_preview: "gemini-2.5-flash-image-preview",

  # Gemini 2.5 dated previews
  flash_2_5_preview_09_2025: "gemini-2.5-flash-preview-09-2025",
  flash_2_5_lite_preview_09_2025: "gemini-2.5-flash-lite-preview-09-2025",

  # Gemini 2.5 Live/Audio
  flash_2_5_native_audio_preview_09_2025: "gemini-2.5-flash-native-audio-preview-09-2025",
  flash_2_5_native_audio_preview_12_2025: "gemini-2.5-flash-native-audio-preview-12-2025",

  # Gemini 2.0 dated variants
  flash_2_0_001: "gemini-2.0-flash-001",
  flash_2_0_exp: "gemini-2.0-flash-exp",
  flash_2_0_lite_001: "gemini-2.0-flash-lite-001",
}
```

---

#### 5.3 Update Interactions API Model List (MEDIUM PRIORITY)

**Python SDK model list** (`_interactions/types/model.py`) includes `gemini-3-flash-preview`.

**Elixir equivalent:** Any model type aliases or validation in Interactions should accept the new model.

**Files to check:**
- `lib/gemini/apis/interactions.ex` - Model validation
- `lib/gemini/types/interactions/params.ex` - Model parameter types

---

#### 5.4 Optional: Centralized Model Capabilities (LOW PRIORITY)

**Current State:** Model capabilities are scattered:
- `thinking_config.ex` - Hardcoded model checks for thinking levels
- `context_cache.ex` - Has its own caching-supported model list

**Suggested Enhancement:** Consider a centralized capability registry:
```elixir
@model_capabilities %{
  "gemini-3-flash-preview" => %{
    thinking: true,
    thinking_levels: [:minimal, :low, :medium, :high],
    caching: true,
    structured_outputs: true,
    function_calling: true,
    code_execution: true,
    search_grounding: true,
    url_context: true,
    image_generation: false,
    live_api: false
  },
  "gemini-3-pro-preview" => %{
    thinking: true,
    thinking_levels: [:low, :high],  # No :minimal or :medium
    # ...
  }
}
```

This would allow capability-based validation rather than string matching.

---

### Category 6: Veo 3.1 Video Generation Updates (MEDIUM PRIORITY)

**Current State:** Implementation only supports basic Veo 2.0 text-to-video. Veo 3.1 introduces major new features.

#### 6.1 Add Veo 3.x Model IDs

**Models from documentation not in implementation:**

| Model ID | Description |
|----------|-------------|
| `veo-3.1-generate-preview` | Veo 3.1 with audio, 720p/1080p |
| `veo-3.1-fast-generate-preview` | Veo 3.1 Fast variant |
| `veo-3.0-generate-001` | Veo 3.0 stable |
| `veo-3.0-fast-generate-001` | Veo 3.0 Fast |

**Elixir Baseline:** Existing support targets `veo-2.0-generate-001`; expand to the model IDs above.

---

#### 6.2 Add Image Input Parameter (Image-to-Video)

**Documentation Feature:**
```python
operation = client.models.generate_videos(
    model="veo-3.1-generate-preview",
    prompt=prompt,
    image=image.parts[0].as_image(),  # NEW
)
```

**Required Changes in `lib/gemini/types/generation/video.ex`:**
```elixir
# Add to VideoGenerationConfig
field(:image, Gemini.Types.Blob.t() | nil, default: nil)
```

---

#### 6.3 Add Last Frame Parameter (Interpolation)

**Documentation Feature (Veo 3.1 only):**
```python
operation = client.models.generate_videos(
    model="veo-3.1-generate-preview",
    prompt=prompt,
    image=first_image,
    config=types.GenerateVideosConfig(
      last_frame=last_image  # NEW
    ),
)
```

---

#### 6.4 Add Reference Images Parameter (Veo 3.1 only)

**Documentation Feature:**
```python
reference = types.VideoGenerationReferenceImage(
  image=dress_image,
  reference_type="asset"
)

operation = client.models.generate_videos(
    model="veo-3.1-generate-preview",
    prompt=prompt,
    config=types.GenerateVideosConfig(
      reference_images=[ref1, ref2, ref3],  # Up to 3
    ),
)
```

**Required New Type:**
```elixir
typedstruct module: VideoGenerationReferenceImage do
  field(:image, Gemini.Types.Blob.t())
  field(:reference_type, String.t(), default: "asset")  # "asset" or "style"
end
```

---

#### 6.5 Add Video Extension Parameter (Veo 3.1 only)

**Documentation Feature:**
```python
operation = client.models.generate_videos(
    model="veo-3.1-generate-preview",
    video=operation.response.generated_videos[0].video,  # Extend previous video
    prompt=prompt,
)
```

---

#### 6.6 Add Resolution Parameter

**Documentation Feature:**
- `"720p"` (default)
- `"1080p"` (only 8s duration)

---

#### 6.7 Gemini API Support for Video Generation

**Documentation shows Gemini API (not just Vertex AI) now supports video:**
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-generate-preview:predictLongRunning"
```

---
**Required Gemini API Support:** Extend `lib/gemini/apis/videos.ex` to support Gemini API endpoints
(`predictLongRunning`) alongside Vertex AI.

---

#### Veo 3.1 Scope Summary

**Already in scope from existing Elixir video support:**
- `negativePrompt`, `aspectRatio`, `durationSeconds`, `personGeneration`, `seed`, async polling

**Add for Veo 3.x parity:**
- Model IDs for Veo 3.x (preview + stable)
- `image` (image-to-video), `lastFrame`, `referenceImages`, `video` (extension), `resolution`
- Gemini API support in addition to Vertex AI

---

### Category 7: Computer Use API (OUT OF SCOPE)

Computer Use is explicitly out of scope for this implementation. Do not add model IDs,
tool serialization, or content/event types for this feature.

---

### Category 8: Deep Research Agent (VERIFY ONLY)

**Official Doc (external):** Deep Research Agent (`deep-research-pro-preview-12-2025`).

Deep Research is assumed fully implemented. Only verify that existing types, models, and
examples match the official docs. If discrepancies are found, document them and fix.

---

### Category 9: Converter Changes (LOW PRIORITY)

#### 7.1 Reorder Tool Fields in Converters

**Python Change (commits in `_live_converters.py`, `_tokens_converters.py`):**
Reordered field processing - fields like `function_declarations` and `google_search_retrieval` moved to different positions in the converter functions.

**Elixir Impact:** Field order in converters doesn't affect functionality in Elixir. No changes needed unless strict JSON field ordering is required.

#### 7.2 Move `behavior` Parameter Check

**Python Change:**
```python
# In _FunctionDeclaration_to_vertex - moved behavior check to end
if getv(from_object, ['behavior']) is not None:
    raise ValueError('behavior parameter is not supported in Vertex AI.')
```

**Elixir Impact:** If implementing function declaration conversion for Vertex AI, ensure behavior parameter is validated. Currently may not be implemented.

---

### Python-Only / Docs-Only Commits (No Elixir Port Required)

These commits do not introduce API surface changes that need Elixir equivalents:

- `22500b5`, `00422de` - Documentation-only updates (codegen instructions)
- `b4c063e` - Documentation regeneration for 1.56.0
- `7d92395` - Release metadata for 1.56.0
- `e247e3b` - Lazy import for Python `yaml`
- `31f80d7` - Python dependency version bump (`google-auth`)
- `8a0489d` - Python test fixes

---

## Implementation Plan

### Phase 1: Critical Model & Type Updates (Priority: HIGH)

1. **Add `gemini-3-flash-preview`** to model registry in `config.ex` (CRITICAL)
2. Update `Usage` struct: rename `total_reasoning_tokens` to `total_thought_tokens`
3. Update `ThinkingLevel` enum: add `:minimal` and `:medium`
4. Update Thinking config validation + coordinator conversion for new levels
5. Update `MediaResolution`: add `:media_resolution_ultra_high`
6. Update `ImageContent`/`VideoContent` resolution type to include `ultra_high`

### Phase 2: Structured Output & Built-in Tools (Priority: HIGH)

1. Add `response_json_schema` field to `GenerationConfig`
2. Add handler in coordinator to convert to `responseJsonSchema`
3. **Enhance `ToolSerialization` to support built-in tools** (googleSearch, urlContext, codeExecution)
4. Update `structured_json/2` helper to optionally use JSON Schema
5. Add tests for JSON Schema structured outputs with tools

### Phase 3: Interaction Type Updates (Priority: MEDIUM)

1. Remove `object` field from `Interaction` struct
2. Verify Interactions API accepts `gemini-3-flash-preview`
3. Fix Vertex AI get/cancel/delete interaction paths
4. Document struct support in tool results

### Phase 4: Model Registry Expansion (Priority: MEDIUM)

1. Add additional model variants to `config.ex`:
   - `gemini-2.0-flash-001`
   - `gemini-2.0-flash-exp`
   - `gemini-2.0-flash-lite-001`
   - `gemini-2.5-flash-image`
   - `gemini-2.5-flash-image-preview`
   - `gemini-2.5-flash-preview-09-2025`
   - `gemini-2.5-flash-lite-preview-09-2025`
   - `gemini-2.5-flash-native-audio-preview-09-2025`
   - `gemini-2.5-flash-native-audio-preview-12-2025`
   - `gemini-2.5-computer-use-preview-10-2025`
   - `deep-research-pro-preview-12-2025`
2. Update context cache model list if needed

### Phase 5: ImageConfig Verification (Priority: MEDIUM)

1. Verify `PersonGeneration` values align with Python SDK
2. Ensure Vertex AI converter includes person_generation
3. Ensure Gemini API converter raises error for person_generation

### Phase 6: Video Generation (Veo 3.x) (Priority: MEDIUM)

1. Add Veo 3.x model IDs
2. Add `image`, `lastFrame`, `referenceImages`, `video`, and `resolution` parameters
3. Add Gemini API `predictLongRunning` support alongside Vertex AI

### Phase 7: Computer Use + Deep Research (Priority: HIGH)

1. Align Computer Use tool schema with official docs (types + content/events)
2. Extend Deep Research agent config to match official schema
3. Add examples/tests for both features once schemas are finalized

### Phase 8: Testing (Priority: HIGH)

1. Update existing tests for renamed fields
2. Add tests for new enum values
3. Add tests for `response_json_schema`
4. Add tests for built-in tool serialization
5. Add tests for Vertex Interactions paths
6. Test new model registry entries where applicable

---

## Breaking Changes Summary

| Change | Impact | Migration |
|--------|--------|-----------|
| `total_reasoning_tokens` -> `total_thought_tokens` | Field rename | Update all references |
| Remove `object` from Interaction | Field removal | Remove any code accessing this field |
| ThinkingLevel new values | Additive | No migration needed |
| MediaResolution new values | Additive | No migration needed |
| DocumentMimeType | Optional | Can use strings directly |

---

## Test Updates Required

```elixir
# 1. Update usage tests
test "parses total_thought_tokens from API response" do
  data = %{"total_thought_tokens" => 150}
  usage = Usage.from_api(data)
  assert usage.total_thought_tokens == 150
end

# 2. Add ThinkingLevel tests
test "ThinkingLevel supports minimal" do
  assert ThinkingLevel.to_api(:minimal) == "MINIMAL"
  assert ThinkingLevel.from_api("MINIMAL") == :minimal
  assert ThinkingLevel.from_api("minimal") == :minimal
  assert ThinkingLevel.from_api("MEDIUM") == :medium
end

# 3. Add MediaResolution tests
test "MediaResolution supports ultra_high" do
  assert MediaResolution.to_api(:media_resolution_ultra_high) == "MEDIA_RESOLUTION_ULTRA_HIGH"
  assert MediaResolution.from_api("MEDIA_RESOLUTION_ULTRA_HIGH") == :media_resolution_ultra_high
end

# 4. Update Interaction tests
test "Interaction does not include object field" do
  data = %{"id" => "test", "status" => "completed"}
  interaction = Interaction.from_api(data)
  refute Map.has_key?(interaction, :object)
end

# 5. Add response_json_schema tests
test "response_json_schema converts to responseJsonSchema" do
  schema = %{
    "type" => "object",
    "properties" => %{
      "name" => %{"type" => "string"},
      "age" => %{"type" => "integer"}
    },
    "required" => ["name"]
  }

  opts = [response_json_schema: schema, response_mime_type: "application/json"]
  config = Coordinator.build_generation_config(opts)

  assert config[:responseJsonSchema] == schema
  assert config[:responseMimeType] == "application/json"
end

# 6. Add built-in tools tests
test "ToolSerialization supports built-in tools" do
  # Atom shorthand
  tools = [:google_search, :url_context, :code_execution]
  result = ToolSerialization.to_api_tool_list(tools)

  assert %{"googleSearch" => %{}} in result
  assert %{"urlContext" => %{}} in result
  assert %{"codeExecution" => %{}} in result
end

test "ToolSerialization supports map format built-in tools" do
  tools = [%{google_search: %{}}, %{code_execution: %{}}]
  result = ToolSerialization.to_api_tool_list(tools)

  assert %{"googleSearch" => %{}} in result
  assert %{"codeExecution" => %{}} in result
end

# 7. Add Vertex Interactions path tests
test "Interactions build paths include project/location for Vertex AI" do
  credentials = %{project_id: "proj", location: "us-central1"}
  {:ok, url} =
    Interactions.build_get_url(:vertex_ai, credentials, "v1beta1", "interaction-id", false, nil)

  assert String.contains?(url, "/v1beta1/projects/proj/locations/us-central1/interactions/interaction-id")
end
```

---

## Files to Modify (Complete List)

| File | Changes |
|------|---------|
| `lib/gemini/config.ex` | **Add `gemini-3-flash-preview`** and other models from official docs |
| `lib/gemini/types/interactions/usage.ex` | Rename `total_reasoning_tokens` -> `total_thought_tokens` |
| `lib/gemini/types/interactions/interaction.ex` | Remove `object` field |
| `lib/gemini/types/interactions/content.ex` | Update resolution type to include `ultra_high` |
| `lib/gemini/types/interactions/config.ex` | Update ThinkingLevel docs for `minimal`/`medium` |
| `lib/gemini/apis/interactions.ex` | Fix Vertex AI get/cancel/delete paths |
| `lib/gemini/types/interactions/agent_config.ex` | Align Deep Research agent schema |
| `lib/gemini/types/interactions/tool.ex` | Align Computer Use tool schema (and add content/event types if needed) |
| `lib/gemini/types/enums.ex` | Add ThinkingLevel `:minimal` and `:medium` values |
| `lib/gemini/types/common/media_resolution.ex` | Add `:media_resolution_ultra_high` value |
| `lib/gemini/types/common/generation_config.ex` | Add `response_json_schema` field, update ThinkingConfig type |
| `lib/gemini/validation/thinking_config.ex` | Update validation for `:minimal` |
| `lib/gemini/apis/coordinator.ex` | Add `response_json_schema` handler + update thinking level conversion |
| `lib/gemini/types/tool_serialization.ex` | Add built-in tools support (googleSearch, urlContext, codeExecution) |
| `lib/gemini/apis/context_cache.ex` | Update caching-supported model list |
| `lib/gemini/types/generation/image.ex` | Verify PersonGeneration alignment |
| `lib/gemini/apis/videos.ex` | Add Veo 3.x models, Gemini API support |
| `lib/gemini/types/generation/video.ex` | Add image, lastFrame, referenceImages, video, resolution fields |

---

## Existing Coverage (No New Work Expected)

These features from the official docs are already represented in the Elixir codebase; verify and keep as-is:

### Structured Output Features

- `response_mime_type` (`lib/gemini/types/common/generation_config.ex`)
- `response_schema` -> `responseSchema` (`lib/gemini/apis/coordinator.ex`)
- `property_ordering` (`lib/gemini/types/common/generation_config.ex`)
- `structured_json/2` helper (`lib/gemini/types/common/generation_config.ex`)

### Thinking Features

- `include_thoughts` and `thinking_budget` (`lib/gemini/types/common/generation_config.ex`)
- Thought summary handling: `thought` boolean and `thought_signature` on `Part`
- Thought signature extraction utility
- Interactions deltas: `DeltaThoughtSummaryDelta`, `DeltaThoughtSignatureDelta`

### API Format Notes

- Official docs show lowercase thinking levels (`"low"`, `"medium"`, `"minimal"`, `"high"`).
- Enums should accept both uppercase and lowercase inputs for compatibility with SDKs/APIs.

---

## References

- Python SDK Repository: `./python-genai`
- Commit Range: `436ca2e1..f16142bc`
- SDK Version: v1.56.0
- Date: December 18, 2025
- Official Thinking Docs: https://ai.google.dev/gemini-api/docs/thinking
