# Gap Analysis Report: Python Interactions API vs Elixir gemini_ex

**Scope:** Compare Python GenAI SDK Interactions API (`python-genai/google/genai/_interactions`) to the current Elixir gemini_ex client, and update the Interactions parity docs accordingly.

---

## Executive Summary

- **Python provides a full Interactions API surface**: `create`, `get`, `cancel`, `delete`, plus SSE streaming with resumable event streams and a large Interactions-specific schema surface area (content blocks, deltas, tools, agent configs).
- **gemini_ex does not currently implement Interactions**. While it has strong reusable infrastructure (HTTP, SSE parsing, multi-auth), its request/response type system and streaming plumbing are generateContent-centric and do not match Interactions semantics.
- **Main blockers for parity** are (1) Interactions-specific types/serialization (mostly snake_case), (2) streaming enablement/transport differences (no `alt=sse`), and (3) Vertex routing + quota project header parity.

---

## Python SDK Analysis (Ground Truth)

### Endpoints & Parameters

Python `InteractionsResource` defines:
- `create`: POST `/{api_version}/interactions` (Gemini) and uses `_build_maybe_vertex_path(..., 'interactions')` for Vertex routing (`python-genai/google/genai/_interactions/resources/interactions.py:416`).
- `get`: GET `/{api_version}/interactions/{id}` with query params `stream` and optional `last_event_id` (`python-genai/google/genai/_interactions/resources/interactions.py:623`).
- `cancel`: POST `/{api_version}/interactions/{id}/cancel` (`python-genai/google/genai/_interactions/resources/interactions.py:516`).
- `delete`: DELETE `/{api_version}/interactions/{id}` (`python-genai/google/genai/_interactions/resources/interactions.py:477`).

Validation enforced at runtime:
- Rejects `model` + `agent_config` and `agent` + `generation_config` (`python-genai/google/genai/_interactions/resources/interactions.py:412`).

### Streaming Model

- Streaming returns SSE events typed as `InteractionSSEEvent` (a 6-variant union) (`python-genai/google/genai/_interactions/types/interaction_sse_event.py:30`).
- Python stops streaming when SSE `data` begins with `[DONE]` (`python-genai/google/genai/_interactions/_streaming.py:72`).
- Stream resumption uses JSON `event_id` tokens and the `last_event_id` query param on `get` (`python-genai/google/genai/_interactions/resources/interactions.py:542`).

### Schema Surface Area

Key counts (Python unions):
- **17 content types** (`python-genai/google/genai/_interactions/types/interaction.py:53`).
- **18 delta types** (`python-genai/google/genai/_interactions/types/content_delta.py:322`).
- **7 tool types** (`python-genai/google/genai/_interactions/types/tool.py:28`).

Schema correctness items that affected docs:
- `ThinkingLevel` is only `"low" | "high"` (`python-genai/google/genai/_interactions/types/thinking_level.py:22`).
- Deep Research agent config discriminator is `"deep-research"` (`python-genai/google/genai/_interactions/types/deep_research_agent_config_param.py:31`).
- MCP `allowed_tools` entries are `{mode, tools}` (`python-genai/google/genai/_interactions/types/allowed_tools_param.py:28`).
- Google Search call args uses `queries: [string]` (`python-genai/google/genai/_interactions/types/google_search_call_arguments.py:25`).
- Google Search result items use `rendered_content` (not `snippet`) (`python-genai/google/genai/_interactions/types/google_search_result.py:25`).
- URL context result items are `{status, url}` only (`python-genai/google/genai/_interactions/types/url_context_result.py:26`).
- `computer_use` tool uses camelCase JSON key `excludedPredefinedFunctions` via aliasing (`python-genai/google/genai/_interactions/types/tool.py:57`).

### Vertex-specific Behavior

- Path builder: for Vertex, `_build_maybe_vertex_path` returns `v1beta1/projects/{project}/locations/{location}/{path}` (`python-genai/google/genai/_interactions/_base_client.py:413`).
- Tests assert the Vertex create URL is `https://{location}-aiplatform.googleapis.com/v1beta1/projects/{project}/locations/{location}/interactions` (`python-genai/google/genai/tests/interactions/test_auth.py:175`).
- Python injects `x-goog-user-project` when quota project is present (`python-genai/google/genai/client.py:509`).

---

## Elixir gemini_ex Analysis (Current State)

### Interactions API Coverage

- No Interactions endpoints are implemented (no `interactions.create/get/cancel/delete` equivalent).

### Streaming Infrastructure

- `Gemini.SSE.Parser` is already compatible with Interactions SSE framing and `[DONE]` termination (`lib/gemini/sse/parser.ex:160`).
- `Gemini.Client.HTTPStreaming` currently appends `alt=sse` unconditionally (`lib/gemini/client/http_streaming.ex:404`), which is not how Python enables Interactions streaming.

### Types & Serialization

- Existing request/response types (`Gemini.Types.Content`, `Gemini.Types.Part`, `Gemini.Types.Request.*`, `Gemini.Types.Response.*`) are structured for `GenerateContent` (role/parts, camelCase API keys). Interactions uses a different model (type-discriminated content blocks, mostly snake_case keys).

### Auth & Vertex

- Vertex auth sets `Authorization: Bearer ...` (`lib/gemini/auth/vertex_strategy.ex:59`) but does not include `x-goog-user-project`.
- Existing routing patterns are model-centric (`models/{model}:generateContent`) and do not cover the Interactions path shapes used by Python on Vertex.

---

## Feature Parity Matrix

| Python Feature | gemini_ex Status | Notes |
|---|---|---|
| `interactions.create()` | Missing | New endpoint + request encoding required |
| `interactions.get()` | Missing | Needs `stream` + `last_event_id` query support |
| `interactions.cancel()` | Missing | New endpoint |
| `interactions.delete()` | Missing | New endpoint |
| SSE event union (6 types) | Missing | Must implement event decoding + dispatch |
| Streaming deltas (18 variants) | Missing | Must implement delta decoding + accumulation |
| Resumable streams (`last_event_id`) | Missing | Must plumb event_id tracking and GET resume |
| `previous_interaction_id` chaining | Missing | Requires request support; storage is recommended (not required) |
| Background interactions (`background`) | Missing | Requires create option + polling/cancel path |
| Agent support (`agent`, `agent_config`) | Missing | Includes Deep Research (`deep-research`) |
| Tools (7 variants) | Missing | Includes MCP, computer_use alias field, file_search |
| Vertex routing parity | Partial | Auth exists, but URL building + `x-goog-user-project` missing; streaming query handling differs |

---

## Type Gaps (Quantified)

- Python exports **144 unique Interactions types** across **89** generated type files.
- The largest implementation surface is:
  - Content variants (17) and their param forms
  - Streaming deltas (18) and their helper result types
  - Tool variants (7) and their config/param forms
  - Event types (6 union members + helpers)

Complete per-type mapping and recommended Elixir destinations: `docs/20251213/interactions-api-update/TYPE-MAPPING.md`.

---

## Documentation Changes Made

Updated for accuracy and evidence-based grounding:
- `docs/20251213/interactions-api-update/01-OVERVIEW.md`
- `docs/20251213/interactions-api-update/02-INTERACTIONS-API.md`
- `docs/20251213/interactions-api-update/03-TYPE-DEFINITIONS.md`
- `docs/20251213/interactions-api-update/04-STREAMING-EVENTS.md`
- `docs/20251213/interactions-api-update/05-IMPLEMENTATION-PLAN.md`
- `docs/20251213/interactions-api-update/06-CODEBASE-ALIGNMENT.md`

New deliverables:
- `docs/20251213/interactions-api-update/TYPE-MAPPING.md` (complete inventory + mapping)
- `docs/20251213/interactions-api-update/07-GAP-ANALYSIS-REPORT.md` (this report)

Each updated doc includes a `## Revision Notes` section documenting what was corrected and where in Python/Elixir source the correction came from.

---

## Implementation Recommendations (Updated Priorities)

1. **Transport correctness first**
   - Add an Interactions streaming mode that does not append `alt=sse` (keep SSE headers).
   - Implement endpoint routing for Gemini + Vertex; validate Vertex paths against Python tests.
2. **Types + serialization**
   - Implement `Gemini.Types.Interactions.*` types and ensure snake_case request encoding (with the `excludedPredefinedFunctions` exception).
3. **Streaming event decoding**
   - Implement the 6-event SSE union and 18 delta variants; confirm `[DONE]` handling matches Python.
4. **Public API + ergonomics**
   - Add `Gemini.APIs.Interactions` API module (mirroring gemini_ex conventions like `Gemini.Generate`).
5. **Parity tests**
   - Add URL/auth parity tests (including quota project header) and streaming parser tests with sample SSE frames.

---

## Open Questions / Risks

- **Vertex get/cancel/delete path shape:** Python uses Vertex path building for `create`, but `get/cancel/delete` in `InteractionsResource` do not call `_build_maybe_vertex_path`. Verify live Vertex behavior before locking in Elixir routing for those endpoints.
