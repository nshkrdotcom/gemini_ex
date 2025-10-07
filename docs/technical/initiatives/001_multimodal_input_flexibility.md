# Initiative 1: Multimodal Content Input Flexibility

**Initiative Number:** 001
**Related GitHub Issue:** [#11](https://github.com/nshkrdotcom/gemini_ex/issues/11)
**Status:** 🔴 CRITICAL - In Design
**Priority:** P0 - Blocking User Functionality
**Estimated Effort:** 4-6 hours
**Created:** 2025-10-07
**Owner:** Core Maintainer
**Cross-Reference:** See also Initiative 002 (Thinking Budget Fix)

---

## 1. Executive Summary

### Problem Statement

Users attempting to use multimodal content (text + images) following the library's documentation encounter a `FunctionClauseError` because the `Gemini.APIs.Coordinator.format_content/1` function only accepts `%Gemini.Types.Content{}` structs, while documentation examples and user expectations suggest plain maps should work.

**User Impact:**
- **Severity:** CRITICAL - Completely blocks multimodal functionality
- **Scope:** All users attempting image/video/audio processing with Gemini
- **Workaround:** Complex - Requires deep understanding of internal type structures

### Proposed Solution

Implement flexible input acceptance in `lib/gemini/apis/coordinator.ex` to normalize various input formats:
1. Plain maps with intuitive structures (user-friendly)
2. `Gemini.Types.Content` structs (current requirement)
3. Lists of mixed content types
4. Automatic MIME type detection for inline data

This maintains backward compatibility while dramatically improving developer experience.

### Success Criteria

1. ✅ All existing tests continue to pass (backward compatibility)
2. ✅ Users can pass plain maps matching official API structure
3. ✅ Automatic MIME type detection for base64 data
4. ✅ Clear error messages for invalid input formats
5. ✅ Comprehensive test coverage for all input variations
6. ✅ Updated documentation with working examples
7. ✅ Zero breaking changes to existing API

### Impact Assessment

**Positive Impacts:**
- **Unblocks users** attempting multimodal content generation
- **Improves DX** - More intuitive API matching official documentation
- **Increases adoption** - Lower barrier to entry for image/video use cases
- **Reduces support burden** - Fewer confused users filing issues

**Risk Assessment:**
- **Technical Risk:** LOW - Additive changes only
- **Breaking Change Risk:** NONE - All changes are backward compatible
- **Performance Impact:** NEGLIGIBLE - Input normalization is O(n) on small lists

---

## 2. Problem Analysis

### Current Behavior

**Location:** `/home/home/p/g/n/gemini_ex/lib/gemini/apis/coordinator.ex`

**Failing Code Pattern:**
```elixir
# User's attempt (from Issue #11):
content = [
  %{type: "text", text: "Describe this image..."},
  %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
]

Gemini.generate(content)
```

**Error:**
```
** (FunctionClauseError) no function clause matching in Gemini.APIs.Coordinator.format_content/1

The following arguments were given to Gemini.APIs.Coordinator.format_content/1:
    # 1
    %{type: "text", text: "Describe this image..."}

Attempted function clauses (showing 1 out of 1):
    defp format_content(%Gemini.Types.Content{role: role, parts: parts})
```

**Current Implementation:**
```elixir
# coordinator.ex:409-442 - Only accepts Content structs
defp build_generate_request(contents, opts) when is_list(contents) do
  # This assumes ALL elements are Content structs
  formatted_contents = Enum.map(contents, &format_content/1)
  # ... rest of implementation
end

# coordinator.ex:447-452 - Pattern match requires Content struct
defp format_content(%Content{role: role, parts: parts}) do
  %{
    role: role,
    parts: Enum.map(parts, &format_part/1)
  }
end
```

### Root Cause Analysis

**Primary Cause:**
The `format_content/1` function uses a **rigid pattern match** that only accepts `%Gemini.Types.Content{}` structs. There is no fallback clause to handle plain maps or alternative input formats.

**Contributing Factors:**
1. **Documentation mismatch** - Examples show map-like structures but don't specify required struct types
2. **No input normalization layer** - Assumes all inputs are pre-formatted structs
3. **Missing convenience functions** - No helper to convert intuitive formats to required structures
4. **Insufficient error messages** - FunctionClauseError doesn't guide user to solution

**Code Flow Analysis:**
```
User Input (plain map)
  ↓
Gemini.generate/2
  ↓
Coordinator.generate_content/2
  ↓
build_generate_request/2 (list branch)
  ↓
Enum.map(contents, &format_content/1)  ← FAILS HERE
  ↓
format_content/1 - expects Content struct, gets plain map
  ↓
FunctionClauseError
```

### User Impact

**Immediate Impact:**
- **Blocks multimodal use cases** - Image analysis, video understanding, audio transcription all fail
- **Frustrates developers** - Intuitive API expectations violated
- **Creates confusion** - Error message doesn't explain what's needed

**Long-term Impact:**
- **Reduces adoption** - Users may abandon library for alternatives
- **Increases support costs** - More GitHub issues, Stack Overflow questions
- **Damages reputation** - "Documentation doesn't match implementation"

### Why It's Critical

1. **Multimodal is a core Gemini feature** - Not supporting it properly undermines library value
2. **Google's official docs emphasize multimodal** - We should match their ease of use
3. **Other SDKs make this easy** - Python SDK accepts flexible input formats
4. **Image analysis is a common entry point** - Many users try this first

**Comparison with Official Python SDK:**
```python
# Python SDK - Accepts flexible input
from google import genai
from google.genai import types

# Simple and intuitive
response = client.models.generate_content(
    model='gemini-2.5-flash',
    contents=[
        types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg'),
        'Caption this image.'  # Plain string works!
    ]
)
```

**What Our Users Expect (Based on Issue #11):**
```elixir
# Should work but doesn't
content = [
  %{type: "text", text: "Describe this image..."},
  %{type: "image", source: %{type: "base64", data: encoded_data}}
]

Gemini.generate(content)
```

---

## 3. Official API Specification

**Reference:** `/home/home/p/g/n/gemini_ex/docs/gemini_api_reference_2025_10_07/IMAGE_UNDERSTANDING.md`

### Exact JSON Format Expected by API

**For Inline Image Data:**
```json
{
  "contents": [{
    "parts": [
      {
        "inline_data": {
          "mime_type": "image/jpeg",
          "data": "<base64-encoded-string>"
        }
      },
      {
        "text": "Caption this image."
      }
    ]
  }]
}
```

**Key Field Names (from official docs):**
- ✅ `inline_data` (snake_case) - NOT `inlineData` (camelCase)
- ✅ `mime_type` (snake_case) - NOT `mimeType` (camelCase)
- ✅ `data` - Base64 encoded string
- ✅ `text` - Plain text string

**Critical Discovery:**
The API uses **snake_case for inline_data fields** but camelCase for other fields like `generationConfig`. This inconsistency must be handled correctly.

### Supported Formats

**Image Formats (from IMAGE_UNDERSTANDING.md):**
- PNG - `image/png`
- JPEG - `image/jpeg`
- WEBP - `image/webp`
- HEIC - `image/heic`
- HEIF - `image/heif`

**Size Limits:**
- **Inline data:** 20MB total request size (including text prompts)
- **File API:** Use for larger files or repeated usage
- **File limit:** 3,600 image files per request (Gemini 2.5/2.0/1.5 models)

### Examples from Official Docs

**REST API Example (Lines 116-142):**
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
-H "x-goog-api-key: $GEMINI_API_KEY" \
-H 'Content-Type: application/json' \
-X POST \
-d '{
    "contents": [{
    "parts":[
        {
            "inline_data": {
            "mime_type":"image/jpeg",
            "data": "'"$(base64 $B64FLAGS $IMG_PATH)"'"
            }
        },
        {"text": "Caption this image."},
    ]
    }]
}'
```

**Python SDK Example (Lines 34-55):**
```python
with open('path/to/small-sample.jpg', 'rb') as f:
    image_bytes = f.read()

client = genai.Client()
response = client.models.generate_content(
  model='gemini-2.5-flash',
  contents=[
    types.Part.from_bytes(
      data=image_bytes,
      mime_type='image/jpeg',
    ),
    'Caption this image.'  # Note: Plain string accepted!
  ]
)
```

**JavaScript SDK Example (Lines 60-85):**
```javascript
const base64ImageFile = fs.readFileSync("path/to/small-sample.jpg", {
  encoding: "base64",
});

const contents = [
  {
    inlineData: {  // Note: JavaScript uses camelCase
      mimeType: "image/jpeg",
      data: base64ImageFile,
    },
  },
  { text: "Caption this image." },
];
```

**Key Observation:**
Official SDKs accept **mixed content types** in a single array:
- Plain strings convert to text parts
- Image objects convert to inline_data parts
- File references convert to file_data parts

---

## 4. Current Implementation Analysis

### Code Walkthrough

**File:** `/home/home/p/g/n/gemini_ex/lib/gemini/apis/coordinator.ex`

#### Function: `build_generate_request/2` (Lines 363-442)

**String Input Branch (Lines 372-407):**
```elixir
defp build_generate_request(text, opts) when is_binary(text) do
  # Works: Converts string to proper API format
  content = %{
    contents: [
      %{
        parts: [%{text: text}]
      }
    ]
  }
  # ... adds generation config and tools
  {:ok, final_content}
end
```
**Status:** ✅ Works well - Simple string input is handled

**Content List Branch (Lines 409-442):**
```elixir
defp build_generate_request(contents, opts) when is_list(contents) do
  # PROBLEM: Assumes all elements are Content structs
  formatted_contents = Enum.map(contents, &format_content/1)  # ← FAILS on plain maps

  content = %{
    contents: formatted_contents
  }

  # ... rest of implementation
  {:ok, final_content}
end
```
**Status:** 🔴 BROKEN - Only accepts Content structs, rejects plain maps

#### Function: `format_content/1` (Lines 447-452)

```elixir
# PROBLEM: Only one clause - requires Content struct
defp format_content(%Content{role: role, parts: parts}) do
  %{
    role: role,
    parts: Enum.map(parts, &format_part/1)
  }
end
# No fallback clause for plain maps!
```
**Status:** 🔴 RIGID - Single pattern match, no flexibility

#### Function: `format_part/1` (Lines 455-463)

```elixir
# These clauses CAN handle plain maps!
defp format_part(%{text: text}) when is_binary(text) do
  %{text: text}
end

defp format_part(%{inline_data: %{mime_type: mime_type, data: data}}) do
  %{inline_data: %{mime_type: mime_type, data: data}}
end

defp format_part(part), do: part  # Passthrough
```
**Status:** ✅ GOOD - Already flexible, just needs to receive plain maps

### Type System Review

**File:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/content.ex`

```elixir
defmodule Gemini.Types.Content do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:role, String.t(), default: "user")
    field(:parts, [Gemini.Types.Part.t()], default: [])
  end

  # Helper functions exist but aren't used by coordinator
  def text(text, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [Gemini.Types.Part.text(text)]
    }
  end

  def multimodal(text, image_data, mime_type, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [
        Gemini.Types.Part.text(text),
        Gemini.Types.Part.inline_data(image_data, mime_type)
      ]
    }
  end
end
```

**File:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/part.ex`

```elixir
defmodule Gemini.Types.Part do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:text, String.t() | nil, default: nil)
    field(:inline_data, Gemini.Types.Blob.t() | nil, default: nil)
    field(:function_call, Altar.ADM.FunctionCall.t() | nil, default: nil)
  end

  # Good helper functions
  def text(text) when is_binary(text) do
    %__MODULE__{text: text}
  end

  def inline_data(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    blob = Gemini.Types.Blob.new(data, mime_type)
    %__MODULE__{inline_data: blob}
  end

  def file(path) when is_binary(path) do
    case Gemini.Types.Blob.from_file(path) do
      {:ok, blob} -> %__MODULE__{inline_data: blob}
      {:error, _error} -> %__MODULE__{text: "Error loading file: #{path}"}
    end
  end
end
```

**File:** `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/blob.ex`

```elixir
defmodule Gemini.Types.Blob do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:data, String.t(), enforce: true)
    field(:mime_type, String.t(), enforce: true)
  end

  # Handles base64 encoding
  def new(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    encoded_data = Base.encode64(data)  # Encodes raw bytes
    %__MODULE__{
      data: encoded_data,
      mime_type: mime_type
    }
  end

  # MIME type detection from file extension
  defp determine_mime_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      # ... more types
      _ -> "application/octet-stream"
    end
  end
end
```

### Where It Fails

**Failure Point:** `coordinator.ex:411` - `Enum.map(contents, &format_content/1)`

**Call Stack:**
```
1. User calls: Gemini.generate([%{type: "text", text: "..."}])
2. Routes to: Coordinator.generate_content/2
3. Calls: build_generate_request([%{type: "text", ...}], opts)
4. Matches: build_generate_request(contents, opts) when is_list(contents)
5. Executes: Enum.map(contents, &format_content/1)
6. Calls: format_content(%{type: "text", text: "..."})
7. FAILS: No clause matches plain map
8. Raises: FunctionClauseError
```

**Why `format_part/1` isn't reached:**
The `format_content/1` function fails before it can call `format_part/1`, even though `format_part/1` could handle plain maps.

**Gap Analysis:**
- ✅ Type system is well-designed
- ✅ Helper functions exist (`Content.multimodal`, `Part.inline_data`, etc.)
- ✅ `format_part/1` can handle plain maps
- 🔴 **Gap:** `format_content/1` blocks all plain map inputs
- 🔴 **Gap:** No automatic conversion from intuitive formats to structs
- 🔴 **Gap:** No MIME type detection for base64 data

---

## 5. Proposed Solution

### High-Level Approach

**Strategy:** Add an **input normalization layer** that converts various intuitive formats into the canonical `Content` struct format, then proceeds with existing processing.

**Design Principles:**
1. **Backward compatibility** - All existing code continues to work
2. **Progressive enhancement** - Add new capabilities without breaking old ones
3. **Fail-fast validation** - Detect and report errors early with helpful messages
4. **MIME type intelligence** - Auto-detect when possible, require when necessary
5. **Consistent with official SDKs** - Match Python/JavaScript flexibility

### Detailed Implementation Plan

#### Phase 1: Add Input Normalization Functions

**New Functions to Add:**

1. **`normalize_content_input/1`** - Main entry point for normalization
2. **`normalize_content_map/1`** - Convert plain maps to Content structs
3. **`normalize_part_map/1`** - Convert plain part maps to Part structs
4. **`detect_mime_type_from_data/1`** - Auto-detect MIME type from base64 data
5. **`validate_multimodal_input/1`** - Validate input before processing

#### Phase 2: Enhance `build_generate_request/2`

**Modify the list branch to normalize inputs first:**

```elixir
defp build_generate_request(contents, opts) when is_list(contents) do
  # NEW: Normalize all inputs to Content structs
  with {:ok, normalized_contents} <- normalize_content_input(contents) do
    formatted_contents = Enum.map(normalized_contents, &format_content/1)

    content = %{
      contents: formatted_contents
    }

    # ... rest remains unchanged
    {:ok, final_content}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

#### Phase 3: Add Flexible Pattern Matching

**Enhance `format_content/1` with additional clauses:**

```elixir
# Existing clause - handles Content structs
defp format_content(%Content{role: role, parts: parts}) do
  %{
    role: role,
    parts: Enum.map(parts, &format_part/1)
  }
end

# NEW: Handle plain maps that look like Content structs
defp format_content(%{role: role, parts: parts}) when is_binary(role) and is_list(parts) do
  %{
    role: role,
    parts: Enum.map(parts, &format_part/1)
  }
end

# NEW: Handle maps without explicit role (default to "user")
defp format_content(%{parts: parts}) when is_list(parts) do
  %{
    role: "user",
    parts: Enum.map(parts, &format_part/1)
  }
end
```

### Code Changes Required

#### File: `lib/gemini/apis/coordinator.ex`

**1. Add normalization helper functions (insert after line 612):**

```elixir
# Input Normalization Functions
# These convert various input formats to canonical Content structs

@doc false
@spec normalize_content_input(list()) :: {:ok, [Content.t()]} | {:error, term()}
defp normalize_content_input(inputs) when is_list(inputs) do
  try do
    normalized = Enum.map(inputs, &normalize_single_content/1)
    {:ok, normalized}
  rescue
    e in [ArgumentError, KeyError] ->
      {:error, {:invalid_content_format, Exception.message(e)}}
  end
end

@doc false
@spec normalize_single_content(term()) :: Content.t()
defp normalize_single_content(%Content{} = content), do: content

# Plain map with role and parts
defp normalize_single_content(%{role: role, parts: parts}) when is_binary(role) and is_list(parts) do
  %Content{
    role: role,
    parts: Enum.map(parts, &normalize_part/1)
  }
end

# Plain map with just parts (default role to "user")
defp normalize_single_content(%{parts: parts}) when is_list(parts) do
  %Content{
    role: "user",
    parts: Enum.map(parts, &normalize_part/1)
  }
end

# Anthropic/Claude-style format: %{type: "text", text: "..."}
defp normalize_single_content(%{type: "text", text: text}) do
  %Content{
    role: "user",
    parts: [Gemini.Types.Part.text(text)]
  }
end

# Anthropic/Claude-style format: %{type: "image", source: %{type: "base64", data: ...}}
defp normalize_single_content(%{type: "image", source: %{type: "base64", data: data}}) do
  # Detect MIME type from data or default to JPEG
  mime_type = detect_mime_type_from_base64(data) || "image/jpeg"

  %Content{
    role: "user",
    parts: [Gemini.Types.Part.inline_data(data, mime_type)]
  }
end

# Anthropic/Claude-style with explicit mime_type
defp normalize_single_content(%{type: "image", source: %{type: "base64", data: data, mime_type: mime_type}}) do
  %Content{
    role: "user",
    parts: [Gemini.Types.Part.inline_data(data, mime_type)]
  }
end

# Gemini-style format: %{inline_data: %{mime_type: ..., data: ...}}
defp normalize_single_content(%{inline_data: inline_data}) do
  %Content{
    role: "user",
    parts: [%Gemini.Types.Part{inline_data: normalize_blob(inline_data)}]
  }
end

# Invalid format
defp normalize_single_content(input) do
  raise ArgumentError, """
  Invalid content format: #{inspect(input)}

  Expected one of:
  - %Gemini.Types.Content{} struct
  - %{role: "user", parts: [...]}
  - %{type: "text", text: "..."}
  - %{type: "image", source: %{type: "base64", data: "...", mime_type: "image/jpeg"}}
  - %{inline_data: %{mime_type: "...", data: "..."}}
  """
end

@doc false
@spec normalize_part(term()) :: Gemini.Types.Part.t()
defp normalize_part(%Gemini.Types.Part{} = part), do: part

# Plain map with text
defp normalize_part(%{text: text}) when is_binary(text) do
  Gemini.Types.Part.text(text)
end

# Plain map with inline_data
defp normalize_part(%{inline_data: inline_data}) do
  %Gemini.Types.Part{inline_data: normalize_blob(inline_data)}
end

# Already normalized part map (from API format)
defp normalize_part(%{"text" => text}), do: Gemini.Types.Part.text(text)
defp normalize_part(%{"inline_data" => inline_data}), do: %Gemini.Types.Part{inline_data: normalize_blob(inline_data)}

# Passthrough for unknown formats (let format_part handle it)
defp normalize_part(part), do: part

@doc false
@spec normalize_blob(map()) :: Gemini.Types.Blob.t()
defp normalize_blob(%Gemini.Types.Blob{} = blob), do: blob

defp normalize_blob(%{mime_type: mime_type, data: data}) do
  %Gemini.Types.Blob{mime_type: mime_type, data: data}
end

defp normalize_blob(%{"mime_type" => mime_type, "data" => data}) do
  %Gemini.Types.Blob{mime_type: mime_type, data: data}
end

defp normalize_blob(%{mimeType: mime_type, data: data}) do
  %Gemini.Types.Blob{mime_type: mime_type, data: data}
end

defp normalize_blob(blob) do
  raise ArgumentError, "Invalid blob format: #{inspect(blob)}"
end

@doc false
@spec detect_mime_type_from_base64(String.t()) :: String.t() | nil
defp detect_mime_type_from_base64(base64_data) when is_binary(base64_data) do
  # Try to decode and check magic bytes
  case Base.decode64(base64_data) do
    {:ok, <<0x89, 0x50, 0x4E, 0x47, _::binary>>} -> "image/png"
    {:ok, <<0xFF, 0xD8, 0xFF, _::binary>>} -> "image/jpeg"
    {:ok, <<0x47, 0x49, 0x46, _::binary>>} -> "image/gif"
    {:ok, <<"RIFF", _::binary-size(4), "WEBP", _::binary>>} -> "image/webp"
    {:ok, _} -> nil  # Unknown format
    :error -> nil  # Not valid base64
  end
end

defp detect_mime_type_from_base64(_), do: nil
```

**2. Update `build_generate_request/2` list branch (line 409):**

```elixir
defp build_generate_request(contents, opts) when is_list(contents) do
  # Normalize inputs to Content structs
  with {:ok, normalized_contents} <- normalize_content_input(contents) do
    formatted_contents = Enum.map(normalized_contents, &format_content/1)

    content = %{
      contents: formatted_contents
    }

    # Add generation config if provided
    config =
      case Keyword.get(opts, :generation_config) do
        %Gemini.Types.GenerationConfig{} = generation_config ->
          struct_to_api_map(generation_config)
        nil ->
          build_generation_config(opts)
      end

    final_content =
      if map_size(config) > 0 do
        Map.put(content, :generationConfig, config)
      else
        content
      end

    # Inject tools and toolConfig if provided
    final_content = maybe_put_tools(final_content, opts)
    final_content = maybe_put_tool_config(final_content, opts)

    {:ok, final_content}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

**3. Enhance `format_content/1` for resilience (line 447):**

```elixir
# Existing - handles Content structs
defp format_content(%Content{role: role, parts: parts}) do
  %{
    role: role,
    parts: Enum.map(parts, &format_part/1)
  }
end

# NEW: Handle plain maps (defense in depth)
defp format_content(%{role: role, parts: parts}) when is_binary(role) and is_list(parts) do
  %{
    role: role,
    parts: Enum.map(parts, &format_part/1)
  }
end

# NEW: Handle maps without role
defp format_content(%{parts: parts}) when is_list(parts) do
  %{
    role: "user",
    parts: Enum.map(parts, &format_part/1)
  }
end
```

### Type System Changes

**No breaking changes to existing types.**

Add new type aliases for documentation:

```elixir
# In lib/gemini.ex or coordinator.ex
@typedoc """
Content input can be:
- A string (converted to text content)
- A Content struct
- A list of Content structs
- A list of plain maps matching the Content/Part structure
"""
@type content_input ::
  String.t()
  | Content.t()
  | [Content.t()]
  | [content_map()]

@typedoc """
Plain map representations of content.

## Examples

    # Text content
    %{type: "text", text: "Hello"}

    # Image content (Anthropic style)
    %{type: "image", source: %{type: "base64", data: "...", mime_type: "image/jpeg"}}

    # Gemini API style
    %{role: "user", parts: [%{text: "Hello"}]}
    %{inline_data: %{mime_type: "image/png", data: "..."}}
"""
@type content_map :: map()
```

### Helper Functions Needed

All helper functions are included in the code section above:

1. ✅ `normalize_content_input/1` - Main normalization entry point
2. ✅ `normalize_single_content/1` - Per-content normalization with pattern matching
3. ✅ `normalize_part/1` - Part normalization
4. ✅ `normalize_blob/1` - Blob format normalization
5. ✅ `detect_mime_type_from_base64/1` - MIME type detection from magic bytes

### Validation Logic

**Error Handling Strategy:**

1. **Early validation** - Check format before processing
2. **Helpful errors** - Include expected formats in error messages
3. **Fail fast** - Don't attempt to process invalid data
4. **Clear messages** - Guide users to correct format

**Validation Points:**

```elixir
# In normalize_single_content/1
defp normalize_single_content(input) do
  raise ArgumentError, """
  Invalid content format: #{inspect(input)}

  Expected one of:
  - %Gemini.Types.Content{} struct
  - %{role: "user", parts: [...]}
  - %{type: "text", text: "..."}
  - %{type: "image", source: %{type: "base64", data: "...", mime_type: "image/jpeg"}}
  - %{inline_data: %{mime_type: "...", data: "..."}}

  See documentation: https://hexdocs.pm/gemini_ex/multimodal-content.html
  """
end
```

**MIME Type Validation:**

```elixir
# Optional: Add validation for supported MIME types
@supported_image_types ~w[image/png image/jpeg image/webp image/heic image/heif]

defp validate_mime_type(mime_type) do
  if mime_type in @supported_image_types do
    :ok
  else
    {:error, {:unsupported_mime_type, mime_type, supported: @supported_image_types}}
  end
end
```

---

## 6. Implementation Details

### File-by-File Changes

#### File 1: `/home/home/p/g/n/gemini_ex/lib/gemini/apis/coordinator.ex`

**Line 409-442:** Modify `build_generate_request/2` list branch
**Line 447-463:** Enhance `format_content/1` and `format_part/1`
**After Line 612:** Add all normalization helper functions

**Total Changes:**
- **Modified functions:** 1 (`build_generate_request/2`)
- **Enhanced functions:** 1 (`format_content/1`)
- **New functions:** 6 (normalization helpers)
- **Lines added:** ~150
- **Lines modified:** ~5

#### File 2: `/home/home/p/g/n/gemini_ex/lib/gemini.ex` (Optional)

**Add type documentation:**

```elixir
@typedoc """
Content input for generate functions.

Accepts multiple formats for maximum flexibility:

## String
    "Hello, world!"

## Content Struct
    %Gemini.Types.Content{
      role: "user",
      parts: [%Gemini.Types.Part{text: "Hello"}]
    }

## Anthropic/Claude Style Maps
    %{type: "text", text: "Hello"}
    %{type: "image", source: %{type: "base64", data: "...", mime_type: "image/jpeg"}}

## Gemini API Style Maps
    %{role: "user", parts: [%{text: "Hello"}]}
    %{inline_data: %{mime_type: "image/png", data: "..."}}

## Mixed Content Lists
    [
      %{type: "text", text: "Describe this image"},
      %{type: "image", source: %{type: "base64", data: image_data, mime_type: "image/jpeg"}}
    ]
"""
@type content_input :: String.t() | Content.t() | [Content.t()] | [map()]
```

**Update function specs:**

```elixir
@spec generate(content_input(), options()) :: api_result(GenerateContentResponse.t())
```

#### File 3: `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/content.ex`

**No changes required** - Existing helper functions remain available

**Optional enhancement - add new convenience constructor:**

```elixir
@doc """
Create multimodal content from file path.

## Examples

    Content.from_file("path/to/image.jpg", "Describe this image")
"""
@spec from_file(String.t(), String.t(), String.t()) :: t()
def from_file(file_path, text \\ "", role \\ "user") do
  parts =
    if text != "" do
      [Gemini.Types.Part.file(file_path), Gemini.Types.Part.text(text)]
    else
      [Gemini.Types.Part.file(file_path)]
    end

  %__MODULE__{role: role, parts: parts}
end
```

### Function Signatures

**New Functions:**

```elixir
@spec normalize_content_input(list()) :: {:ok, [Content.t()]} | {:error, term()}
defp normalize_content_input(inputs)

@spec normalize_single_content(term()) :: Content.t()
defp normalize_single_content(input)

@spec normalize_part(term()) :: Gemini.Types.Part.t()
defp normalize_part(part)

@spec normalize_blob(map()) :: Gemini.Types.Blob.t()
defp normalize_blob(blob)

@spec detect_mime_type_from_base64(String.t()) :: String.t() | nil
defp detect_mime_type_from_base64(base64_data)
```

**Modified Functions:**

```elixir
# Enhanced with normalization
@spec build_generate_request(
        String.t() | [Content.t()] | [map()] | GenerateContentRequest.t(),
        request_opts()
      ) :: {:ok, map()} | {:error, term()}
defp build_generate_request(input, opts)

# Additional clauses added
@spec format_content(Content.t() | map()) :: map()
defp format_content(content)
```

### Pattern Matching Logic

**Normalization Priority Order:**

1. **Content struct** - Pass through unchanged (highest priority)
2. **Role + parts map** - Standard Gemini format
3. **Parts-only map** - Default role to "user"
4. **Anthropic text style** - `%{type: "text", text: "..."}`
5. **Anthropic image style** - `%{type: "image", source: %{...}}`
6. **Gemini inline_data style** - `%{inline_data: %{...}}`
7. **Error** - Invalid format with helpful message

**Magic Byte Detection for MIME Types:**

```elixir
# PNG: First 4 bytes are 0x89504E47
<<0x89, 0x50, 0x4E, 0x47, _::binary>> -> "image/png"

# JPEG: First 3 bytes are 0xFFD8FF
<<0xFF, 0xD8, 0xFF, _::binary>> -> "image/jpeg"

# GIF: First 3 bytes are 0x474946
<<0x47, 0x49, 0x46, _::binary>> -> "image/gif"

# WebP: RIFF header + "WEBP" identifier
<<"RIFF", _::binary-size(4), "WEBP", _::binary>> -> "image/webp"
```

### Conversion Helpers

**All conversion logic is embedded in normalization functions.**

**Key Conversions:**

1. **String → Content:**
   ```elixir
   "Hello" → %Content{role: "user", parts: [%Part{text: "Hello"}]}
   ```

2. **Anthropic text → Content:**
   ```elixir
   %{type: "text", text: "Hello"}
   → %Content{role: "user", parts: [%Part{text: "Hello"}]}
   ```

3. **Anthropic image → Content:**
   ```elixir
   %{type: "image", source: %{type: "base64", data: "...", mime_type: "image/jpeg"}}
   → %Content{role: "user", parts: [%Part{inline_data: %Blob{...}}]}
   ```

4. **Gemini map → Content:**
   ```elixir
   %{role: "user", parts: [%{text: "Hello"}]}
   → %Content{role: "user", parts: [%Part{text: "Hello"}]}
   ```

---

## 7. Backward Compatibility

### How to Maintain Existing Functionality

**All changes are additive and non-breaking:**

1. **Existing Content struct inputs** - Pass through normalization unchanged
2. **Existing string inputs** - Continue working via existing code path
3. **Existing GenerateContentRequest inputs** - Handled by separate clause
4. **Type signatures** - Enhanced but not restricted (union types)

### Migration Path for Users

**No migration required** - All existing code continues to work.

**Users can optionally adopt new patterns:**

**Before (still works):**
```elixir
alias Gemini.Types.{Content, Part}

content = %Content{
  role: "user",
  parts: [
    Part.text("Describe this image"),
    Part.inline_data(Base.encode64(image_data), "image/jpeg")
  ]
}

Gemini.generate(content)
```

**After (now also works):**
```elixir
# Simpler, more intuitive
content = [
  %{type: "text", text: "Describe this image"},
  %{type: "image", source: %{type: "base64", data: Base.encode64(image_data), mime_type: "image/jpeg"}}
]

Gemini.generate(content)
```

### Deprecation Strategy

**No deprecations needed** - This is a pure enhancement.

**Documentation updates:**
1. Mark struct-based approach as "verbose but type-safe"
2. Mark map-based approach as "concise and flexible"
3. Recommend map approach for prototyping, structs for production

---

## 8. Testing Strategy

### Unit Tests Required

**File:** `test/gemini/apis/coordinator_test.exs`

```elixir
defmodule Gemini.APIs.CoordinatorTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.{Content, Part}

  describe "multimodal content input flexibility" do
    test "accepts Content structs (existing behavior)" do
      content = %Content{
        role: "user",
        parts: [Part.text("Hello")]
      }

      assert {:ok, _} = Coordinator.generate_content(content)
    end

    test "accepts plain string (existing behavior)" do
      assert {:ok, _} = Coordinator.generate_content("Hello world")
    end

    test "accepts list of Content structs (existing behavior)" do
      contents = [
        %Content{role: "user", parts: [Part.text("Hello")]},
        %Content{role: "model", parts: [Part.text("Hi there!")]}
      ]

      assert {:ok, _} = Coordinator.generate_content(contents)
    end

    test "accepts Anthropic-style text map" do
      content = [%{type: "text", text: "Hello"}]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{role: "user", parts: [%{text: "Hello"}]}]} = request
    end

    test "accepts Anthropic-style image map with mime_type" do
      content = [
        %{type: "image", source: %{
          type: "base64",
          data: Base.encode64("fake image data"),
          mime_type: "image/png"
        }}
      ]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{role: "user", parts: [%{inline_data: %{mime_type: "image/png"}}]}]} = request
    end

    test "auto-detects PNG mime type from base64 data" do
      # PNG magic bytes: 0x89504E47
      png_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "fake png data">>
      encoded = Base.encode64(png_data)

      content = [
        %{type: "image", source: %{type: "base64", data: encoded}}
      ]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{parts: [%{inline_data: %{mime_type: "image/png"}}]}]} = request
    end

    test "auto-detects JPEG mime type from base64 data" do
      # JPEG magic bytes: 0xFFD8FF
      jpeg_data = <<0xFF, 0xD8, 0xFF, 0xE0, "fake jpeg data">>
      encoded = Base.encode64(jpeg_data)

      content = [
        %{type: "image", source: %{type: "base64", data: encoded}}
      ]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{parts: [%{inline_data: %{mime_type: "image/jpeg"}}]}]} = request
    end

    test "accepts Gemini-style map with role and parts" do
      content = [
        %{role: "user", parts: [%{text: "Hello"}]}
      ]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{role: "user", parts: [%{text: "Hello"}]}]} = request
    end

    test "accepts Gemini-style map with inline_data" do
      content = [
        %{inline_data: %{mime_type: "image/jpeg", data: "base64data"}}
      ]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{role: "user", parts: [%{inline_data: _}]}]} = request
    end

    test "accepts mixed content types in single request" do
      content = [
        %{type: "text", text: "Describe this image"},
        %{type: "image", source: %{type: "base64", data: "base64data", mime_type: "image/jpeg"}}
      ]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: contents} = request
      assert length(contents) == 2
    end

    test "defaults role to 'user' for maps without role" do
      content = [%{parts: [%{text: "Hello"}]}]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{role: "user"}]} = request
    end

    test "preserves explicit role when provided" do
      content = [%{role: "model", parts: [%{text: "Hello"}]}]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{role: "model"}]} = request
    end

    test "returns helpful error for invalid format" do
      content = [%{invalid: "format"}]

      assert {:error, {:invalid_content_format, message}} = Coordinator.generate_content(content)
      assert message =~ "Invalid content format"
      assert message =~ "Expected one of"
    end

    test "handles empty parts list" do
      content = [%{role: "user", parts: []}]

      assert {:ok, request} = Coordinator.generate_content(content)
      assert %{contents: [%{parts: []}]} = request
    end
  end

  describe "MIME type detection" do
    test "detects PNG from magic bytes" do
      png_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      encoded = Base.encode64(png_data)

      # Access private function via apply for testing
      mime_type = apply(Coordinator, :detect_mime_type_from_base64, [encoded])
      assert mime_type == "image/png"
    end

    test "detects JPEG from magic bytes" do
      jpeg_data = <<0xFF, 0xD8, 0xFF, 0xE0>>
      encoded = Base.encode64(jpeg_data)

      mime_type = apply(Coordinator, :detect_mime_type_from_base64, [encoded])
      assert mime_type == "image/jpeg"
    end

    test "detects GIF from magic bytes" do
      gif_data = <<0x47, 0x49, 0x46, 0x38, 0x39, 0x61>>
      encoded = Base.encode64(gif_data)

      mime_type = apply(Coordinator, :detect_mime_type_from_base64, [encoded])
      assert mime_type == "image/gif"
    end

    test "detects WebP from RIFF header" do
      webp_data = <<"RIFF", 0, 0, 0, 0, "WEBP">>
      encoded = Base.encode64(webp_data)

      mime_type = apply(Coordinator, :detect_mime_type_from_base64, [encoded])
      assert mime_type == "image/webp"
    end

    test "returns nil for unknown format" do
      unknown_data = <<0, 1, 2, 3, 4, 5>>
      encoded = Base.encode64(unknown_data)

      mime_type = apply(Coordinator, :detect_mime_type_from_base64, [encoded])
      assert is_nil(mime_type)
    end
  end
end
```

### Integration Tests

**File:** `test/integration/multimodal_test.exs`

```elixir
defmodule GeminiEx.Integration.MultimodalTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "multimodal content generation" do
    test "generates content with text and image using Anthropic-style maps" do
      # Simple 1x1 red PNG
      png_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                   0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
                   8, 2, 0, 0, 0, 144, 119, 83, 222>>

      content = [
        %{type: "text", text: "What color is this pixel?"},
        %{type: "image", source: %{
          type: "base64",
          data: Base.encode64(png_data)
        }}
      ]

      # Note: Mock HTTP client for integration test
      # In real implementation, this would call actual API
      assert {:ok, _response} = Gemini.generate(content)
    end

    test "generates content with multiple images" do
      png1 = create_test_image(:red)
      png2 = create_test_image(:blue)

      content = [
        %{type: "text", text: "Compare these two images"},
        %{type: "image", source: %{type: "base64", data: Base.encode64(png1), mime_type: "image/png"}},
        %{type: "image", source: %{type: "base64", data: Base.encode64(png2), mime_type: "image/png"}}
      ]

      assert {:ok, _response} = Gemini.generate(content)
    end
  end

  defp create_test_image(:red), do: <<0x89, 0x50, 0x4E, 0x47, "...">>
  defp create_test_image(:blue), do: <<0x89, 0x50, 0x4E, 0x47, "...">>
end
```

### Live API Tests

**File:** `test/live_api_test.exs`

```elixir
defmodule GeminiEx.LiveAPITest do
  use ExUnit.Case, async: false

  @moduletag :live_api
  @moduletag timeout: 60_000

  setup do
    unless System.get_env("GEMINI_API_KEY") do
      {:skip, "GEMINI_API_KEY not set"}
    else
      :ok
    end
  end

  describe "multimodal with real API" do
    @tag :expensive
    test "generates caption for image using Anthropic-style input" do
      # Load real test image
      {:ok, image_data} = File.read("test/fixtures/test_image.jpg")

      content = [
        %{type: "text", text: "Describe this image in one sentence."},
        %{type: "image", source: %{
          type: "base64",
          data: Base.encode64(image_data),
          mime_type: "image/jpeg"
        }}
      ]

      assert {:ok, response} = Gemini.generate(content, model: "gemini-2.0-flash-exp")
      assert {:ok, text} = Gemini.extract_text(response)
      assert is_binary(text)
      assert String.length(text) > 0
    end

    @tag :expensive
    test "auto-detects MIME type for PNG" do
      {:ok, image_data} = File.read("test/fixtures/test_image.png")

      content = [
        %{type: "text", text: "What is this?"},
        %{type: "image", source: %{
          type: "base64",
          data: Base.encode64(image_data)
          # No mime_type - should auto-detect
        }}
      ]

      assert {:ok, response} = Gemini.generate(content)
      assert {:ok, _text} = Gemini.extract_text(response)
    end
  end
end
```

### Edge Cases to Cover

1. **Empty content list** - `[]`
2. **Nil values** - `nil`, `%{text: nil}`
3. **Invalid base64** - Corrupted data
4. **Unsupported MIME types** - `image/bmp`, `image/tiff`
5. **Mixed valid and invalid** - Some parts valid, some not
6. **Very large images** - Near 20MB limit
7. **Unicode in text** - Emoji, special characters
8. **Deeply nested maps** - Invalid structure
9. **Missing required fields** - `%{type: "image"}` without data
10. **Wrong field types** - `%{text: 123}` instead of string

### Test Data Examples

**Valid PNG Header:**
```elixir
@png_header <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
```

**Valid JPEG Header:**
```elixir
@jpeg_header <<0xFF, 0xD8, 0xFF, 0xE0>>
```

**Minimal Valid PNG (1x1 pixel):**
```elixir
@minimal_png <<
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
  0x00, 0x00, 0x00, 0x0D,  # IHDR chunk length
  0x49, 0x48, 0x44, 0x52,  # "IHDR"
  0x00, 0x00, 0x00, 0x01,  # Width: 1
  0x00, 0x00, 0x00, 0x01,  # Height: 1
  0x08, 0x02, 0x00, 0x00, 0x00,  # Bit depth, color type, etc.
  0x90, 0x77, 0x53, 0xDE,  # CRC
  # ... IDAT and IEND chunks
>>
```

---

## 9. Documentation Updates

### README Examples

**Add to README.md:**

```markdown
### Multimodal Content (Images, Video, Audio)

Gemini excels at multimodal understanding. You can include images, videos, and audio alongside text prompts.

#### Simple Image Analysis

```elixir
{:ok, image_data} = File.read("path/to/image.jpg")

# Easy, intuitive format
content = [
  %{type: "text", text: "Describe this image in detail."},
  %{type: "image", source: %{
    type: "base64",
    data: Base.encode64(image_data),
    mime_type: "image/jpeg"
  }}
]

{:ok, response} = Gemini.generate(content)
{:ok, description} = Gemini.extract_text(response)
```

#### Auto-Detect MIME Type

The library can automatically detect image formats from the data:

```elixir
# MIME type auto-detected from magic bytes
content = [
  %{type: "text", text: "What's in this image?"},
  %{type: "image", source: %{
    type: "base64",
    data: Base.encode64(image_data)
    # mime_type automatically detected!
  }}
]
```

Supported auto-detection: PNG, JPEG, GIF, WebP

#### Multiple Images

```elixir
{:ok, image1} = File.read("screenshot1.png")
{:ok, image2} = File.read("screenshot2.png")

content = [
  %{type: "text", text: "What changed between these screenshots?"},
  %{type: "image", source: %{type: "base64", data: Base.encode64(image1)}},
  %{type: "image", source: %{type: "base64", data: Base.encode64(image2)}}
]

{:ok, response} = Gemini.generate(content)
```

#### Using Type-Safe Structs (Recommended for Production)

For maximum type safety, use the provided struct types:

```elixir
alias Gemini.Types.{Content, Part}

{:ok, image_data} = File.read("image.png")

content = %Content{
  role: "user",
  parts: [
    Part.text("Analyze this chart"),
    Part.inline_data(Base.encode64(image_data), "image/png")
  ]
}

{:ok, response} = Gemini.generate(content)
```

#### Convenience Helpers

```elixir
# Load image from file path directly
content = %Content{
  role: "user",
  parts: [
    Part.text("What's in this photo?"),
    Part.file("vacation_photo.jpg")  # Auto-loads and encodes
  ]
}
```

#### Supported Formats

- **Images:** PNG, JPEG, WebP, HEIC, HEIF
- **Size Limit:** 20MB for inline data (use File API for larger files)
- **File Limit:** Up to 3,600 images per request (Gemini 2.5/2.0/1.5)
```

### HexDocs Updates

**Create new guide:** `guides/multimodal_content.md`

```markdown
# Multimodal Content Guide

This guide covers working with images, videos, and audio in Gemini.

## Input Formats

Gemini accepts multiple input formats for maximum flexibility:

### Recommended: Anthropic-Style Maps

Most intuitive for quick prototyping:

```elixir
content = [
  %{type: "text", text: "Describe this"},
  %{type: "image", source: %{
    type: "base64",
    data: Base.encode64(image_bytes),
    mime_type: "image/jpeg"  # Optional - auto-detected if omitted
  }}
]
```

### Type-Safe: Content Structs

Best for production code with compile-time checks:

```elixir
alias Gemini.Types.{Content, Part}

content = %Content{
  role: "user",
  parts: [
    Part.text("Describe this"),
    Part.inline_data(Base.encode64(image_bytes), "image/jpeg")
  ]
}
```

### Mixed: Gemini API Format

Direct mapping to official API structure:

```elixir
content = [
  %{role: "user", parts: [
    %{text: "Describe this"},
    %{inline_data: %{
      mime_type: "image/jpeg",
      data: Base.encode64(image_bytes)
    }}
  ]}
]
```

All three formats are equivalent and produce the same API request.

## MIME Type Detection

The library automatically detects image formats by analyzing the file header:

| Format | Magic Bytes | Auto-Detected |
|--------|-------------|---------------|
| PNG    | `89 50 4E 47` | ✅ Yes |
| JPEG   | `FF D8 FF`    | ✅ Yes |
| GIF    | `47 49 46`    | ✅ Yes |
| WebP   | `RIFF...WEBP` | ✅ Yes |
| HEIC   | -             | ❌ Specify manually |
| HEIF   | -             | ❌ Specify manually |

## Common Patterns

### Image from URL

```elixir
{:ok, %{body: image_data}} = HTTPoison.get("https://example.com/image.jpg")

content = [
  %{type: "text", text: "What is this?"},
  %{type: "image", source: %{
    type: "base64",
    data: Base.encode64(image_data),
    mime_type: "image/jpeg"
  }}
]
```

### Image from File System

```elixir
{:ok, image_data} = File.read("/path/to/image.png")

content = [
  %{type: "text", text: "Describe this"},
  %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
]
# MIME type auto-detected from PNG header
```

### Multiple Images

```elixir
images = ["img1.jpg", "img2.jpg", "img3.jpg"]

content = [%{type: "text", text: "Compare these images"}] ++
  Enum.map(images, fn path ->
    {:ok, data} = File.read(path)
    %{type: "image", source: %{type: "base64", data: Base.encode64(data)}}
  end)
```

## Error Handling

```elixir
case Gemini.generate(content) do
  {:ok, response} ->
    {:ok, text} = Gemini.extract_text(response)
    IO.puts(text)

  {:error, {:invalid_content_format, message}} ->
    IO.puts("Invalid format: #{message}")

  {:error, {:unsupported_mime_type, type, opts}} ->
    supported = Keyword.get(opts, :supported)
    IO.puts("Unsupported type #{type}. Supported: #{inspect(supported)}")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Best Practices

1. **Use structs in production** - Better type safety and compile-time checks
2. **Use maps for prototyping** - Faster iteration and clearer intent
3. **Always specify MIME type for HEIC/HEIF** - Cannot be auto-detected
4. **Keep inline data < 20MB** - Use File API for larger files
5. **Batch multiple images** - More efficient than separate requests
6. **Handle errors gracefully** - Check for invalid formats and unsupported types

## Performance Considerations

- **Inline data** adds ~33% overhead due to base64 encoding
- **File API** is more efficient for repeated image usage
- **Token costs** vary by image size (see official docs for calculation)
- **Auto-detection** adds negligible overhead (~1μs per image)
```

### Migration Guide

**Add to CHANGELOG.md:**

```markdown
## [Unreleased]

### Added
- Flexible multimodal content input support (#11)
  - Accept Anthropic-style content maps (`%{type: "text", text: "..."}`)
  - Accept Gemini API-style maps (`%{role: "user", parts: [...]}`)
  - Auto-detect image MIME types from base64 data (PNG, JPEG, GIF, WebP)
  - Comprehensive error messages for invalid input formats

### Enhanced
- `Gemini.generate/2` now accepts multiple input format variations
- `Gemini.APIs.Coordinator.generate_content/2` input normalization
- Better error messages with examples of valid formats

### Documentation
- Added multimodal content guide
- Updated README with image examples
- Added MIME type detection reference

### Migration
No breaking changes. All existing code continues to work.
New input formats are optional convenience features.
```

### Example Code

**Add to `examples/` directory:**

**File:** `examples/multimodal_demo.exs`

```elixir
# Multimodal Content Demo
# Run with: mix run examples/multimodal_demo.exs
# Requires GEMINI_API_KEY environment variable

defmodule MultimodalDemo do
  def run do
    IO.puts("🖼️  Multimodal Content Demo")
    IO.puts("=" <> String.duplicate("=", 50))

    demo_simple_image()
    demo_auto_detection()
    demo_multiple_images()
    demo_struct_format()
  end

  defp demo_simple_image do
    section("Simple Image Analysis")

    # Create a simple 1x1 red PNG for demo
    png_data = create_test_png(:red)

    content = [
      %{type: "text", text: "What color is this pixel? Answer in one word."},
      %{type: "image", source: %{
        type: "base64",
        data: Base.encode64(png_data),
        mime_type: "image/png"
      }}
    ]

    case Gemini.generate(content) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("🤖 Gemini: #{text}")
      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end

  defp demo_auto_detection do
    section("Auto MIME Type Detection")

    png_data = create_test_png(:blue)

    content = [
      %{type: "text", text: "Describe this color"},
      %{type: "image", source: %{
        type: "base64",
        data: Base.encode64(png_data)
        # No mime_type - will auto-detect PNG!
      }}
    ]

    IO.puts("Note: MIME type auto-detected from PNG header")

    case Gemini.generate(content) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("🤖 #{text}")
      {:error, error} ->
        IO.puts("❌ #{inspect(error)}")
    end
  end

  defp demo_multiple_images do
    section("Multiple Images")

    red_png = create_test_png(:red)
    blue_png = create_test_png(:blue)

    content = [
      %{type: "text", text: "Compare these two colors. What are they?"},
      %{type: "image", source: %{type: "base64", data: Base.encode64(red_png)}},
      %{type: "image", source: %{type: "base64", data: Base.encode64(blue_png)}}
    ]

    case Gemini.generate(content) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("🤖 #{text}")
      {:error, error} ->
        IO.puts("❌ #{inspect(error)}")
    end
  end

  defp demo_struct_format do
    section("Using Type-Safe Structs")

    alias Gemini.Types.{Content, Part}

    png_data = create_test_png(:green)

    content = %Content{
      role: "user",
      parts: [
        Part.text("What color is this?"),
        Part.inline_data(Base.encode64(png_data), "image/png")
      ]
    }

    IO.puts("Using Content and Part structs for type safety")

    case Gemini.generate(content) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("🤖 #{text}")
      {:error, error} ->
        IO.puts("❌ #{inspect(error)}")
    end
  end

  defp section(title) do
    IO.puts("\n#{title}")
    IO.puts(String.duplicate("-", String.length(title)))
  end

  # Create minimal valid PNG images for testing
  defp create_test_png(:red), do: minimal_png(255, 0, 0)
  defp create_test_png(:blue), do: minimal_png(0, 0, 255)
  defp create_test_png(:green), do: minimal_png(0, 255, 0)

  defp minimal_png(_r, _g, _b) do
    # Simplified - actual implementation would create valid PNG
    # For demo purposes, just create PNG header
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "...">>
  end
end

MultimodalDemo.run()
```

---

## 10. Implementation Checklist

### Step-by-Step Tasks

**Total Estimated Time: 4-6 hours**

#### Phase 1: Core Implementation (2-3 hours)

- [ ] **Task 1.1:** Add normalization helper functions to coordinator.ex (60 min)
  - [ ] `normalize_content_input/1`
  - [ ] `normalize_single_content/1` with all pattern matches
  - [ ] `normalize_part/1`
  - [ ] `normalize_blob/1`
  - [ ] `detect_mime_type_from_base64/1`
  - [ ] Test locally with `iex -S mix`

- [ ] **Task 1.2:** Update `build_generate_request/2` list branch (15 min)
  - [ ] Add normalization call with error handling
  - [ ] Test with simple map input

- [ ] **Task 1.3:** Enhance `format_content/1` with new clauses (15 min)
  - [ ] Add plain map clause
  - [ ] Add parts-only map clause
  - [ ] Test pattern matching priority

- [ ] **Task 1.4:** Add type documentation to `lib/gemini.ex` (30 min)
  - [ ] `@type content_input`
  - [ ] Update `@spec` for `generate/2`
  - [ ] Add examples in moduledoc

#### Phase 2: Testing (1.5-2 hours)

- [ ] **Task 2.1:** Write unit tests (60 min)
  - [ ] Test all input format variations
  - [ ] Test MIME type detection
  - [ ] Test error cases
  - [ ] Run: `mix test test/gemini/apis/coordinator_test.exs`

- [ ] **Task 2.2:** Write integration tests (30 min)
  - [ ] Test with mock HTTP client
  - [ ] Test multiple images
  - [ ] Verify API request format

- [ ] **Task 2.3:** Create live API test (15 min)
  - [ ] Test with real image file
  - [ ] Verify auto-detection works
  - [ ] Run: `mix test --only live_api`

- [ ] **Task 2.4:** Test backward compatibility (15 min)
  - [ ] Run full test suite: `mix test`
  - [ ] Verify 0 regressions
  - [ ] Test existing examples still work

#### Phase 3: Documentation (45-60 min)

- [ ] **Task 3.1:** Update README.md (20 min)
  - [ ] Add multimodal section
  - [ ] Add code examples
  - [ ] Add format comparison

- [ ] **Task 3.2:** Create multimodal guide (20 min)
  - [ ] Write `guides/multimodal_content.md`
  - [ ] Add to HexDocs config
  - [ ] Build docs: `mix docs`

- [ ] **Task 3.3:** Create example script (10 min)
  - [ ] Write `examples/multimodal_demo.exs`
  - [ ] Test: `mix run examples/multimodal_demo.exs`

- [ ] **Task 3.4:** Update CHANGELOG.md (5 min)
  - [ ] Add to Unreleased section
  - [ ] List all new features

#### Phase 4: Review & Polish (30 min)

- [ ] **Task 4.1:** Code review (15 min)
  - [ ] Check CODE_QUALITY.md compliance
  - [ ] Verify all `@spec` annotations
  - [ ] Check for TODOs or FIXMEs

- [ ] **Task 4.2:** Final testing (10 min)
  - [ ] Run full suite: `mix test`
  - [ ] Run live tests: `mix test --only live_api`
  - [ ] Check coverage: `mix test --cover`

- [ ] **Task 4.3:** Documentation review (5 min)
  - [ ] Build and review docs: `mix docs && open doc/index.html`
  - [ ] Check for broken links
  - [ ] Verify examples are correct

### Dependencies

**Task Dependencies:**
- 1.2 depends on 1.1 (need normalization functions)
- 1.3 depends on 1.2 (need updated request builder)
- Phase 2 depends on Phase 1 complete
- Phase 3 can start after Phase 1 (parallel with Phase 2)
- Phase 4 requires all previous phases

**External Dependencies:**
- None - All changes are self-contained
- No new library dependencies required

### Review Criteria

**Code Quality:**
- [ ] All public functions have `@doc`
- [ ] All public functions have `@spec`
- [ ] Private functions have `@doc false` where appropriate
- [ ] Pattern matching is clear and well-ordered
- [ ] Error messages are helpful and actionable
- [ ] No compiler warnings
- [ ] Follows existing code style

**Testing:**
- [ ] All new code paths covered by tests
- [ ] Edge cases tested
- [ ] Error cases tested
- [ ] Backward compatibility verified
- [ ] Test coverage >90% for new code

**Documentation:**
- [ ] README updated with examples
- [ ] HexDocs guide created
- [ ] Example script works end-to-end
- [ ] CHANGELOG updated
- [ ] Type documentation complete

**Functionality:**
- [ ] All existing tests pass
- [ ] New input formats work as expected
- [ ] MIME detection works correctly
- [ ] Error handling is robust
- [ ] Performance is acceptable

---

## 11. Risk Analysis

### Potential Issues

1. **Base64 Decoding Performance**
   - **Risk:** Decoding large images for MIME detection could be slow
   - **Probability:** LOW
   - **Impact:** LOW
   - **Mitigation:** Only decode first 12 bytes for magic byte check

2. **Ambiguous Input Formats**
   - **Risk:** User provides map that matches multiple patterns
   - **Probability:** MEDIUM
   - **Impact:** LOW
   - **Mitigation:** Well-defined pattern matching order with priority

3. **MIME Type Detection Failures**
   - **Risk:** Unknown format or corrupted data
   - **Probability:** MEDIUM
   - **Impact:** MEDIUM
   - **Mitigation:** Return `nil` and let user provide explicit MIME type

4. **Memory Usage with Large Images**
   - **Risk:** Base64 decoding allocates memory
   - **Probability:** LOW (API limits to 20MB)
   - **Impact:** LOW
   - **Mitigation:** Check size before decoding, fail fast on invalid data

5. **Breaking Existing Code**
   - **Risk:** New pattern matches interfere with existing behavior
   - **Probability:** VERY LOW
   - **Impact:** CRITICAL
   - **Mitigation:** Comprehensive backward compatibility tests

### Mitigation Strategies

**For Performance (Issue #1):**
```elixir
defp detect_mime_type_from_base64(base64_data) when is_binary(base64_data) do
  # Only decode first 12 bytes (enough for all magic bytes)
  case Base.decode64(String.slice(base64_data, 0, 16)) do  # ~12 decoded bytes
    {:ok, header} -> check_magic_bytes(header)
    :error -> nil
  end
end
```

**For Ambiguity (Issue #2):**
```elixir
# Clear priority order in pattern matching:
# 1. Exact struct match (highest priority)
# 2. Map with explicit role + parts
# 3. Anthropic-style with type field
# 4. Gemini-style with inline_data
# 5. Error with helpful message (lowest priority)
```

**For MIME Detection (Issue #3):**
```elixir
# Graceful degradation
mime_type = detect_mime_type_from_base64(data) || explicit_mime_type || "image/jpeg"

# Or require explicit for unknown:
defp normalize_single_content(%{type: "image", source: %{type: "base64", data: data}}) do
  case detect_mime_type_from_base64(data) do
    nil ->
      raise ArgumentError, """
      Could not detect MIME type. Please specify explicitly:
      %{type: "image", source: %{type: "base64", data: "...", mime_type: "image/jpeg"}}
      """
    mime_type ->
      # Proceed with detected type
  end
end
```

**For Memory (Issue #4):**
```elixir
defp validate_base64_size(base64_data) do
  # Base64 encoding increases size by ~33%
  # So 20MB limit = ~15MB decoded
  # Base64 string of 15MB decoded = ~20MB string
  max_size = 20 * 1024 * 1024  # 20MB

  if byte_size(base64_data) > max_size do
    {:error, {:image_too_large, byte_size(base64_data), max: max_size}}
  else
    :ok
  end
end
```

**For Backward Compatibility (Issue #5):**
```elixir
# Extensive test suite covering existing behavior
describe "backward compatibility" do
  test "existing Content struct inputs still work" do
    # All existing test cases
  end

  test "existing string inputs still work" do
    # All existing test cases
  end

  test "existing GenerateContentRequest inputs still work" do
    # All existing test cases
  end
end
```

### Rollback Plan

**If issues are discovered after deployment:**

1. **Immediate Rollback:**
   ```bash
   git revert <commit-hash>
   mix hex.publish
   ```

2. **Partial Rollback (if only some patterns fail):**
   - Comment out problematic pattern matches
   - Keep working patterns enabled
   - Add warning in documentation

3. **Feature Flag Approach:**
   ```elixir
   # Add configuration option
   config :gemini_ex, flexible_input: false  # Disable if needed

   # In code:
   defp build_generate_request(contents, opts) when is_list(contents) do
     if Application.get_env(:gemini_ex, :flexible_input, true) do
       with {:ok, normalized} <- normalize_content_input(contents) do
         # New behavior
       end
     else
       # Old behavior
       formatted_contents = Enum.map(contents, &format_content/1)
       # ...
     end
   end
   ```

4. **Communication Plan:**
   - Post GitHub issue explaining rollback
   - Update README with known issues
   - Provide workaround instructions
   - Set timeline for fix

**Rollback Triggers:**
- Test suite failures >5%
- User-reported bugs >3 in first 24 hours
- Performance degradation >10%
- Memory leaks detected
- Breaking changes discovered

---

## 12. References

### Links

- **GitHub Issue:** https://github.com/nshkrdotcom/gemini_ex/issues/11
- **Issue Analysis:** `/home/home/p/g/n/gemini_ex/docs/issues/ISSUE_ANALYSIS.md`
- **Initiative Analysis:** `/home/home/p/g/n/gemini_ex/docs/technical/INITIATIVE_ANALYSIS.md`

### Official API Documentation

- **Main Reference:** `/home/home/p/g/n/gemini_ex/docs/gemini_api_reference_2025_10_07/IMAGE_UNDERSTANDING.md`
- **Online Docs:** https://ai.google.dev/gemini-api/docs/image-understanding
- **API Reference:** https://ai.google.dev/api/rest

### Code References

**Modified Files:**
- `/home/home/p/g/n/gemini_ex/lib/gemini/apis/coordinator.ex`
- `/home/home/p/g/n/gemini_ex/lib/gemini.ex`

**Referenced Files:**
- `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/content.ex`
- `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/part.ex`
- `/home/home/p/g/n/gemini_ex/lib/gemini/types/common/blob.ex`

**Test Files:**
- `/home/home/p/g/n/gemini_ex/test/gemini/apis/coordinator_test.exs` (to be enhanced)
- `/home/home/p/g/n/gemini_ex/test/live_api_test.exs` (to be enhanced)

### Related Issues

- **Issue #7:** Tool calling support (resolved, shows good issue handling)
- **PR #10:** Thinking budget config (separate initiative, same coordinator file)

### Standards Documents

- `/home/home/p/g/n/gemini_ex/CODE_QUALITY.md` - Elixir code quality standards
- `/home/home/p/g/n/gemini_ex/CLAUDE.md` - Project context and guidelines

---

## Appendix A: User's Original Error

**From Issue #11:**

```elixir
# User's code:
defmodule GeminiEx.Image do
  def test(img_path) do
    {:ok, image_data} = File.read(img_path)

    content = [
      %{type: "text", text: "Describe this image. If you can't see it, say so."},
      %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
    ]

    Gemini.generate(content)
  end
end
```

**Error:**
```
** (FunctionClauseError) no function clause matching in Gemini.APIs.Coordinator.format_content/1

    The following arguments were given to Gemini.APIs.Coordinator.format_content/1:

        # 1
        %{type: "text", text: "Describe this image. If you can't see it, say so."}

    Attempted function clauses (showing 1 out of 1):

        defp format_content(%Gemini.Types.Content{role: role, parts: parts})
```

**After This Fix:**
```elixir
# Same code will work!
{:ok, response} = Gemini.generate(content)
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)
# => "I see a [detailed description of the image]..."
```

---

## Appendix B: Supported Input Format Matrix

| Format | Example | Auto MIME? | Status |
|--------|---------|------------|--------|
| **String** | `"Hello"` | N/A | ✅ Existing |
| **Content Struct** | `%Content{role: "user", parts: [...]}` | N/A | ✅ Existing |
| **Anthropic Text** | `%{type: "text", text: "..."}` | N/A | 🆕 Added |
| **Anthropic Image + MIME** | `%{type: "image", source: %{type: "base64", data: "...", mime_type: "..."}}` | No | 🆕 Added |
| **Anthropic Image - MIME** | `%{type: "image", source: %{type: "base64", data: "..."}}` | Yes | 🆕 Added |
| **Gemini Map Full** | `%{role: "user", parts: [%{text: "..."}]}` | N/A | 🆕 Added |
| **Gemini Map Partial** | `%{parts: [%{text: "..."}]}` | N/A | 🆕 Added |
| **Gemini inline_data** | `%{inline_data: %{mime_type: "...", data: "..."}}` | No | 🆕 Added |
| **Mixed List** | `[%{type: "text",...}, %Content{...}]` | Mixed | 🆕 Added |

---

**Document Version:** 1.0
**Last Updated:** 2025-10-07
**Status:** Ready for Implementation
**Next Review:** After Phase 1 completion
