# Python GenAI SDK Update Analysis (v1.54.0 → v1.55.0)

**Date:** 2025-12-13
**Python SDK Versions:** v1.54.0 → v1.55.0
**Purpose:** Gap analysis to bring Elixir gemini_ex client to parity

---

## Executive Summary

The Python GenAI SDK introduced a major new feature: the **Interactions API**. This is a fundamentally new approach to conversational AI that provides:

1. **Stateful multi-turn conversations** - Server-managed interaction state
2. **Background processing** - Long-running interactions that can be polled
3. **Agent support** - Built-in agent patterns including Deep Research
4. **Enhanced streaming** - Fine-grained content deltas with resumption
5. **Rich tool ecosystem** - MCP servers, file search, URL context, Google Search

---

## Key Changes Summary

### 1. New Interactions API (MAJOR - v1.55.0)

A completely new API layer that differs from `generate_content`:

| Feature | generate_content | Interactions API |
|---------|-----------------|------------------|
| State management | Client-side | Server-side |
| Conversation chaining | Manual history | `previous_interaction_id` |
| Background execution | Not supported | `background: true` |
| Agent support | Not built-in | `agent: "deep-research-pro-preview-12-2025"` |
| Streaming events | Simple chunks | Typed delta events |
| Resumption | Not supported | `last_event_id` |

### 2. Enhanced Generation Features (v1.54.0-v1.55.0)

- `enableEnhancedCivicAnswers` - New GenerateContentConfig option
- `IMAGE_RECITATION` and `IMAGE_OTHER` - New FinishReason enum values
- Voice activity detection signal for Live API
- `ReplicatedVoiceConfig` support

### 3. Tool Enhancements

New tool types in Interactions API:
- **MCP Servers** - Model Context Protocol integration
- **File Search** - FileSearchStore-based retrieval
- **URL Context** - Web content fetching
- **Computer Use** - Browser automation (browser environment)

---

## Feature Gap Analysis: Elixir Client

### Currently Implemented in Elixir

- [x] Content generation (`generate_content`)
- [x] Streaming with SSE parsing
- [x] Function calling
- [x] Multi-auth (Gemini API + Vertex AI)
- [x] Chat sessions
- [x] Token counting
- [x] Model management

### Missing Features (Requires Implementation)

#### HIGH PRIORITY - Core Interactions API

| Component | Python Reference | Priority |
|-----------|-----------------|----------|
| `client.interactions.create()` | `_interactions/resources/interactions.py` | P0 |
| `client.interactions.get()` | Same file | P0 |
| `client.interactions.cancel()` | Same file | P1 |
| `client.interactions.delete()` | Same file | P2 |
| Interaction streaming | `_interactions/_streaming.py` | P0 |
| SSE event types | `types/content_delta.py`, `content_start.py` | P0 |

#### MEDIUM PRIORITY - Types & Agents

| Component | Python Reference | Priority |
|-----------|-----------------|----------|
| `Interaction` type | `types/interaction.py` | P0 |
| `Turn` type | `types/turn.py` | P0 |
| Content types (17 variants) | `types/text_content.py`, etc. | P1 |
| `DynamicAgentConfig` | `types/dynamic_agent_config.py` | P1 |
| `DeepResearchAgentConfig` | `types/deep_research_agent_config.py` | P1 |
| Tool definitions | `types/tool.py` | P1 |

#### LOWER PRIORITY - Enhanced Features

| Component | Python Reference | Priority |
|-----------|-----------------|----------|
| MCP Server tools | `types/mcp_server_tool_*.py` | P2 |
| File Search tools | `types/file_search_*.py` | P2 |
| URL Context tools | `types/url_context_*.py` | P2 |
| Computer Use tools | `types/tool.py` (ComputerUse) | P3 |

---

## Python SDK Architecture Changes

### New Module Structure

```
google/genai/
├── _interactions/              # NEW - Complete subpackage
│   ├── __init__.py
│   ├── _base_client.py        # HTTP client foundation
│   ├── _client.py             # GeminiNextGenAPIClient
│   ├── _streaming.py          # Stream/AsyncStream
│   ├── _response.py           # Response handling
│   ├── resources/
│   │   └── interactions.py    # InteractionsResource
│   └── types/                 # 80+ type definitions
│       ├── interaction.py
│       ├── turn.py
│       ├── content_delta.py
│       └── ...
├── interactions.py            # Public re-export
└── client.py                  # Updated with interactions property
```

### Client Integration Pattern

```python
# Python SDK Pattern
from google import genai

client = genai.Client(api_key='...')

# Access via property (lazy initialization)
result = client.interactions.create(
    model='gemini-2.5-flash',
    input='Hello world',
    stream=True
)
```

Note: The SDK logs an experimental warning on first access:
```
UserWarning: Interactions usage is experimental and may change in future versions.
```

---

## API Endpoints

### Interactions Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/{api_version}/interactions` | Create interaction |
| GET | `/{api_version}/interactions/{id}` | Get interaction (with optional streaming) |
| POST | `/{api_version}/interactions/{id}/cancel` | Cancel background interaction |
| DELETE | `/{api_version}/interactions/{id}` | Delete interaction |

### Vertex AI Support

Vertex behavior is slightly asymmetric (per Python):

- **Create** is project/location-scoped:
  - `/{api_version}/projects/{project}/locations/{location}/interactions`
  - Built via `_build_maybe_vertex_path()` (`python-genai/google/genai/_interactions/_base_client.py:413`)
- **Get/cancel/delete** use unscoped interaction ids:
  - `/{api_version}/interactions/{id}`

---

## Streaming Event Protocol

The Interactions API uses a rich event-based streaming model:

### Event Types

| Event Type | Purpose |
|------------|---------|
| `interaction.start` | Interaction created / stream begins |
| `interaction.complete` | Interaction finished / terminal event |
| `content.start` | Beginning of new content block |
| `content.delta` | Incremental content update |
| `content.stop` | End of content block |
| `interaction.status_update` | Status change notification |
| `error` | Error event |

### Delta Types (18 variants)

```elixir
# Types to implement
delta_types = [
  :text_delta,
  :image_delta,
  :audio_delta,
  :document_delta,
  :video_delta,
  :thought_summary_delta,
  :thought_signature_delta,
  :function_call_delta,
  :function_result_delta,
  :code_execution_call_delta,
  :code_execution_result_delta,
  :url_context_call_delta,
  :url_context_result_delta,
  :google_search_call_delta,
  :google_search_result_delta,
  :mcp_server_tool_call_delta,
  :mcp_server_tool_result_delta,
  :file_search_result_delta
]
```

---

## Other SDK Changes (v1.54.0-v1.55.0)

### New in v1.55.0
- `enableEnhancedCivicAnswers` in GenerateContentConfig
- `IMAGE_RECITATION` and `IMAGE_OTHER` enum values for FinishReason
- Voice activity detection signal for Live API

### New in v1.54.0
- `ReplicatedVoiceConfig` support
- Fixed timeout handling for aiohttp
- Made `APIError` class picklable

### Breaking Changes
- None identified

---

## Recommended Implementation Order

### Phase 1: Core Interactions (Immediate)
1. Interactions module structure
2. Create/Get interaction endpoints
3. Basic streaming with content deltas
4. Interaction type definitions

### Phase 2: Agent Support
1. Agent configuration types
2. Deep Research agent support
3. Background interaction handling
4. Cancel/Delete operations

### Phase 3: Advanced Tools
1. MCP Server integration
2. File Search support
3. URL Context support
4. Enhanced streaming resumption

### Phase 4: Parity Features
1. Computer Use tools
2. All remaining content types
3. Full streaming event coverage
4. Edge case handling

---

## Next Steps

1. **Read:** `02-INTERACTIONS-API.md` for detailed API documentation
2. **Read:** `03-TYPE-DEFINITIONS.md` for complete type specifications
3. **Read:** `04-STREAMING-EVENTS.md` for streaming implementation details
4. **Read:** `05-IMPLEMENTATION-PLAN.md` for Elixir implementation roadmap

## Revision Notes

- Corrected agent example to match Python overload literal (`"deep-research-pro-preview-12-2025"`) from `python-genai/google/genai/_interactions/resources/interactions.py:399` and `python-genai/google/genai/_interactions/types/interaction_create_params.py:145`.
- Added missing SSE `interaction.start` / `interaction.complete` event types from `python-genai/google/genai/_interactions/types/interaction_event.py:34` and `python-genai/google/genai/_interactions/types/interaction_sse_event.py:30`.
- Fixed delta variant count to 18 based on `python-genai/google/genai/_interactions/types/content_delta.py:322`.
- Updated model examples to `gemini-2.5-flash` to reflect that Interactions model availability can vary and some `gemini-2.0-*` families may be rejected.
- Clarified Vertex path shape per Python: create uses project/location-scoped paths via `_build_maybe_vertex_path`, while get/cancel/delete use `/ {api_version}/interactions/{id}` (`python-genai/google/genai/_interactions/resources/interactions.py`).
