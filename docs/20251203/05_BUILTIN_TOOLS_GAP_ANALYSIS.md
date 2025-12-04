# Built-in Tools Gap Analysis

**Date:** 2025-12-03
**Status:** FUTURE - Deferred for later implementation

## Summary

The GeminiEx library **does not implement any built-in tools** from the Gemini API. This is a significant feature gap. The library only supports custom function calling through the ALTAR ADM integration.

## Built-in Tools Overview

Gemini provides several built-in tools that require no external implementation:

| Tool | Description | Our Status |
|------|-------------|------------|
| Google Search | Real-time web search grounding | NOT IMPLEMENTED |
| URL Context | Fetch and analyze URL content | NOT IMPLEMENTED |
| Code Execution | Execute Python code | NOT IMPLEMENTED |
| Google Maps | Location and mapping services | NOT IMPLEMENTED |
| File Search | Search uploaded files | NOT IMPLEMENTED |
| Computer Use | Desktop automation (preview) | NOT IMPLEMENTED |

## Detailed Gap Analysis

### 1. Google Search Grounding (HIGH PRIORITY)

**Purpose:** Ground model responses in real-time web search results.

**API Configuration:**
```json
{
  "tools": [{
    "googleSearch": {}
  }]
}
```

**With Dynamic Retrieval:**
```json
{
  "tools": [{
    "googleSearch": {
      "dynamicRetrievalConfig": {
        "mode": "MODE_DYNAMIC",
        "dynamicThreshold": 0.6
      }
    }
  }]
}
```

**Response includes:**
- `groundingMetadata.webSearchQueries` - Queries used
- `groundingMetadata.searchEntryPoint.renderedContent` - Search widget HTML
- `groundingMetadata.groundingSupports` - Source citations

**Implementation Needed:**
1. `GoogleSearch` tool struct
2. `DynamicRetrievalConfig` struct
3. Response parsing for `groundingMetadata`
4. Support for `groundingChunks` and `groundingSupports`

### 2. URL Context (HIGH PRIORITY)

**Purpose:** Analyze content from specified URLs.

**API Configuration:**
```json
{
  "tools": [{
    "urlContext": {}
  }]
}
```

**Response includes:**
- `urlContextMetadata.urlMetadata` - List of analyzed URLs
- URL content integrated into model context

**Implementation Needed:**
1. `UrlContext` tool struct
2. Response parsing for `urlContextMetadata`

### 3. Code Execution (MEDIUM PRIORITY)

**Purpose:** Execute Python code and return results.

**API Configuration:**
```json
{
  "tools": [{
    "codeExecution": {}
  }]
}
```

**Response includes:**
- `executableCode` - Python code blocks
- `codeExecutionResult` - Execution output
- Support for file I/O, data analysis, visualization

**Implementation Needed:**
1. `CodeExecution` tool struct
2. Response parsing for `executableCode` and `codeExecutionResult`
3. Handling of generated files (images, data)

### 4. Google Maps (MEDIUM PRIORITY)

**Purpose:** Location lookup, directions, reviews, photos.

**API Configuration:**
```json
{
  "tools": [{
    "googleMaps": {}
  }]
}
```

**Implementation Needed:**
1. `GoogleMaps` tool struct
2. Response parsing for maps-specific metadata

### 5. File Search (LOW PRIORITY - Vertex AI)

**Purpose:** Search through uploaded files in a corpus.

**Note:** Primarily a Vertex AI feature requiring file upload and corpus management.

**Implementation Needed:**
1. File upload API support
2. Corpus management
3. `fileSearch` tool configuration

### 6. Computer Use (PREVIEW - LOW PRIORITY)

**Purpose:** Automated desktop control with screenshots.

**Note:** Currently in preview, requires special access.

**Implementation Needed:**
1. Computer use tool struct
2. Screenshot handling
3. Action result processing

## Current Implementation State

### What We Have

The `ToolSerialization` module only handles custom function declarations:

```elixir
# lib/gemini/types/tool_serialization.ex:31-43
def to_api_tool_list(declarations) when is_list(declarations) do
  if declarations == [] do
    []
  else
    [%{"functionDeclarations" => Enum.map(declarations, &function_declaration_to_map/1)}]
  end
end
```

### What We Need

Support for built-in tool configurations:

```elixir
defmodule Gemini.Types.BuiltinTools do
  @moduledoc """
  Built-in tool configurations for Gemini API.
  """

  defmodule GoogleSearch do
    defstruct dynamic_retrieval_config: nil

    @type t :: %__MODULE__{
      dynamic_retrieval_config: DynamicRetrievalConfig.t() | nil
    }
  end

  defmodule UrlContext do
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule CodeExecution do
    defstruct []
    @type t :: %__MODULE__{}
  end

  # etc.
end
```

## Recommendations

### Priority 1: Implement Google Search (HIGH)

This is the most commonly needed built-in tool. Implementation steps:

1. Create `Gemini.Types.BuiltinTools.GoogleSearch` struct
2. Create `Gemini.Types.BuiltinTools.DynamicRetrievalConfig` struct
3. Update `ToolSerialization` to handle built-in tools
4. Parse `groundingMetadata` in responses
5. Add grounding attribution rendering helpers
6. Create example and documentation

**Estimated effort:** 2-3 hours

### Priority 2: Implement URL Context (HIGH)

Simple tool that provides significant value. Implementation steps:

1. Create `Gemini.Types.BuiltinTools.UrlContext` struct
2. Update `ToolSerialization`
3. Parse `urlContextMetadata` in responses
4. Create example and documentation

**Estimated effort:** 1-2 hours

### Priority 3: Implement Code Execution (MEDIUM)

Useful for data analysis and computational tasks. Implementation steps:

1. Create `Gemini.Types.BuiltinTools.CodeExecution` struct
2. Update `ToolSerialization`
3. Parse `executableCode` and `codeExecutionResult` in responses
4. Handle file outputs (images, data files)
5. Create example and documentation

**Estimated effort:** 2-3 hours

### Priority 4: Google Maps (MEDIUM)

Useful for location-based applications.

**Estimated effort:** 1-2 hours

### Priority 5: File Search and Computer Use (LOW)

These require additional infrastructure (file upload API, special access) and are lower priority.

## Implementation Architecture

### Proposed Module Structure

```
lib/gemini/types/
├── builtin_tools/
│   ├── google_search.ex
│   ├── url_context.ex
│   ├── code_execution.ex
│   ├── google_maps.ex
│   └── dynamic_retrieval_config.ex
├── grounding/
│   ├── grounding_metadata.ex
│   ├── grounding_chunk.ex
│   ├── grounding_support.ex
│   └── search_entry_point.ex
└── tool_serialization.ex  # Updated to handle all tool types
```

### Updated ToolSerialization

```elixir
def to_api_tool_list(tools) when is_list(tools) do
  tools
  |> Enum.group_by(&tool_type/1)
  |> Enum.map(&serialize_tool_group/1)
end

defp tool_type(%FunctionDeclaration{}), do: :function_declarations
defp tool_type(%GoogleSearch{}), do: :google_search
defp tool_type(%UrlContext{}), do: :url_context
defp tool_type(%CodeExecution{}), do: :code_execution

defp serialize_tool_group({:google_search, [config | _]}) do
  %{"googleSearch" => serialize_google_search(config)}
end
# etc.
```

## Conclusion

**Overall Grade: F (for this feature area)**

Built-in tools are completely missing from the library. This is a significant gap that limits the library's usefulness for applications requiring:
- Real-time information grounding
- URL content analysis
- Code execution capabilities
- Location-based services

**Immediate Recommendation:** Implement Google Search and URL Context as they provide the highest value with relatively low implementation effort.

## Usage Examples (Target API)

Once implemented, the API should look like:

```elixir
# Google Search grounding
alias Gemini.Types.BuiltinTools.{GoogleSearch, DynamicRetrievalConfig}

tools = [
  %GoogleSearch{
    dynamic_retrieval_config: %DynamicRetrievalConfig{
      mode: :dynamic,
      threshold: 0.6
    }
  }
]

{:ok, response} = Gemini.generate(
  "What happened in the news today?",
  tools: tools
)

# Access grounding metadata
grounding = response.grounding_metadata
IO.puts("Search queries: #{inspect(grounding.web_search_queries)}")

# URL Context
tools = [%UrlContext{}]

{:ok, response} = Gemini.generate(
  "Summarize this article: https://example.com/article",
  tools: tools
)

# Code Execution
tools = [%CodeExecution{}]

{:ok, response} = Gemini.generate(
  "Calculate the first 20 prime numbers using Python",
  tools: tools
)

# Access execution results
case get_code_execution_result(response) do
  {:ok, %{output: output}} -> IO.puts("Result: #{output}")
  {:error, reason} -> IO.puts("Error: #{reason}")
end
```
