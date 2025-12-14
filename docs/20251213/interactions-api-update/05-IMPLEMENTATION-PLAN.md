# Elixir Implementation Plan - Interactions API

**Target:** Bring gemini_ex to parity with Python Interactions (Python GenAI SDK `python-genai`, v1.55.x)
**Primary Focus:** Add Interactions CRUD + SSE streaming + type system alignment

---

## Constraints & Non-Negotiables

1. **JSON shape is Interactions-specific.** Interactions uses snake_case keys (with at least one known camelCase key: `excludedPredefinedFunctions` for `computer_use` tools).
2. **Streaming enablement differs from `GenerateContent`.** Interactions uses `stream` in the request body (POST) or query (GET), not `?alt=sse`.
3. **Vertex routing differs from existing model-centric endpoints.** Python builds a Vertex path of the form `v1beta1/projects/{project}/locations/{location}/interactions` (`python-genai/google/genai/_interactions/_base_client.py:413`; `python-genai/google/genai/tests/interactions/test_auth.py:175`).
4. **Vertex auth needs quota project propagation.** Python injects `x-goog-user-project` when a quota project is present (`python-genai/google/genai/client.py:509`).

---

## Recommended Module Layout (gemini_ex)

Follow existing conventions (`Gemini.Generate` lives in `lib/gemini/apis/generate.ex`):

### Public API

- `lib/gemini/apis/interactions.ex` → `Gemini.APIs.Interactions`
  - `create/2` (streaming + non-streaming)
  - `get/2` (streaming + non-streaming, supports `last_event_id`)
  - `cancel/2`
  - `delete/2`
  - `wait_for_completion/2` (polling helper)

### Types (new)

Create a new namespace under `lib/gemini/types/interactions/`:

- `Gemini.Types.Interactions.Interaction`
- `Gemini.Types.Interactions.Turn`
- `Gemini.Types.Interactions.Content` (17 variants)
- `Gemini.Types.Interactions.Tool` (7 variants)
- `Gemini.Types.Interactions.GenerationConfig` (Interactions variant)
- `Gemini.Types.Interactions.Events.*` (`InteractionSSEEvent` union: 6 variants)
- `Gemini.Types.Interactions.Delta` (18 variants)
- `Gemini.Types.Interactions.Params.*` (create/get parameter structs)

### HTTP / Streaming plumbing (existing files to adjust)

- `lib/gemini/client/http_streaming.ex`
  - Add an Interactions-friendly streaming mode that **does not** append `alt=sse` (`lib/gemini/client/http_streaming.ex:404`).
- `lib/gemini/auth/vertex_strategy.ex`
  - Optionally add `x-goog-user-project` header support (parity with Python).

---

## Phase 1: Endpoints & Transport

### 1.1 Implement endpoint routing

Match Python `InteractionsResource`:
- `POST /{api_version}/interactions` (Gemini) or Vertex path via `_build_maybe_vertex_path` (`python-genai/google/genai/_interactions/resources/interactions.py:416`).
- `GET /{api_version}/interactions/{id}` with query `stream`, `last_event_id` (`python-genai/google/genai/_interactions/resources/interactions.py:623`).
- `POST /{api_version}/interactions/{id}/cancel` (`python-genai/google/genai/_interactions/resources/interactions.py:516`).
- `DELETE /{api_version}/interactions/{id}` (`python-genai/google/genai/_interactions/resources/interactions.py:477`).

**Vertex caveat:** Python only uses `_build_maybe_vertex_path` for `create`, not for `get/cancel/delete`. This may indicate an upstream inconsistency. Implementations should verify Vertex behavior against the live API.

### 1.2 Add SSE streaming without `alt=sse`

Interactions streaming is SSE, but not enabled via query `alt=sse`.

- Keep SSE headers: `Accept: text/event-stream`, `Cache-Control: no-cache` (existing behavior in `lib/gemini/client/http_streaming.ex:410`).
- Do not mutate query params to inject `alt=sse` for Interactions.

### 1.3 Preserve resumption data

Elixir should treat JSON `event_id` as the canonical resumption token:
- `InteractionEvent.event_id`, `ContentDelta.event_id`, etc. (`python-genai/google/genai/_interactions/types/*:event_id`).
- `last_event_id` is a query param on `get` (`python-genai/google/genai/_interactions/resources/interactions.py:623`).

---

## Phase 2: Core Types & Serialization

### 2.1 Implement core response types

Implement:
- `Interaction` (`python-genai/google/genai/_interactions/types/interaction.py:123`)
- `Turn` (`python-genai/google/genai/_interactions/types/turn.py:67`)
- `Usage` (`python-genai/google/genai/_interactions/types/usage.py:72`)

### 2.2 Implement content union (17 variants)

Use discriminator `type` (string) and snake_case keys. See `docs/20251213/interactions-api-update/03-TYPE-DEFINITIONS.md`.

### 2.3 Implement tool union (7 variants)

Key correctness points:
- `computer_use` uses `excludedPredefinedFunctions` in JSON (`python-genai/google/genai/_interactions/types/tool_param.py:57`).
- MCP `allowed_tools` is `{mode, tools}` entries (`python-genai/google/genai/_interactions/types/allowed_tools_param.py:28`).

### 2.4 Implement Interactions GenerationConfig

Do not reuse Gemini `GenerationConfig` blindly:
- `thinking_level` is `"low" | "high"` (`python-genai/google/genai/_interactions/types/thinking_level.py:22`).

---

## Phase 3: Streaming Events & Deltas

### 3.1 Implement `InteractionSSEEvent` union (6 variants)

Python union: `python-genai/google/genai/_interactions/types/interaction_sse_event.py:30`.

Event types include:
- `interaction.start`, `interaction.complete` (`python-genai/google/genai/_interactions/types/interaction_event.py:34`)
- `interaction.status_update`
- `content.start`, `content.delta`, `content.stop`
- `error`

### 3.2 Implement `Delta` union (18 variants)

Python delta union: `python-genai/google/genai/_interactions/types/content_delta.py:322`.

Schema correctness fixes to carry over:
- Google Search call args: `queries: [string]` (`python-genai/google/genai/_interactions/types/google_search_call_arguments.py:25`).
- Google Search result items: `rendered_content`, `title`, `url` (`python-genai/google/genai/_interactions/types/google_search_result.py:25`).
- URL context result items: `{status, url}` (`python-genai/google/genai/_interactions/types/url_context_result.py:26`).

### 3.3 Stream termination semantics

Python stops on `[DONE]` sentinel in SSE `data` (`python-genai/google/genai/_interactions/_streaming.py:72`). Elixir should mirror this, independent of `interaction.complete`.

---

## Phase 4: Public API & Ergonomics

### 4.1 `Gemini.APIs.Interactions` surface

Recommended shape (mirrors `Gemini.Generate` conventions, not Python’s method overloads):

- `create(input, opts)` where `opts` includes either:
  - `model: "...", generation_config: ...` **or**
  - `agent: "...", agent_config: ...`
- `get(id, opts)` with optional `stream: true` and `last_event_id: "..."`
- `cancel(id, opts)`
- `delete(id, opts)`

### 4.2 Client option integration

Re-use `t:Gemini.options/0` and existing auth coordinator patterns, but keep the request encoding separate from `Gemini.Apis.Coordinator`’s `generateContent` serialization (Interactions content blocks are not `role/parts`).

---

## Phase 5: Agents, Background, and Advanced Tools

### 5.1 Agent config union

Implement `DynamicAgentConfig` and `DeepResearchAgentConfig`:
- Deep research discriminator is `"deep-research"` (`python-genai/google/genai/_interactions/types/deep_research_agent_config_param.py:31`).

### 5.2 Background interactions

Implement `background: true` + polling via `get` and cancellation via `cancel`.

---

## Phase 6: Testing Strategy

Mirror Python tests and add Elixir-focused coverage:

1. **URL building**
   - Gemini: ends with `/{api_version}/interactions`.
   - Vertex: equals `https://{location}-aiplatform.googleapis.com/v1beta1/projects/{project}/locations/{location}/interactions` (Python expectation: `python-genai/google/genai/tests/interactions/test_auth.py:175`).
2. **Vertex auth headers**
   - `Authorization: Bearer ...` always.
   - `x-goog-user-project` when quota project is configured (Python behavior: `python-genai/google/genai/client.py:509`).
3. **Streaming parsing**
   - Sample SSE chunks → decoded `InteractionSSEEvent` dispatch.
   - `[DONE]` detection.
4. **Serialization**
   - Ensure snake_case payloads match Python types; verify `excludedPredefinedFunctions` alias.

---

## Risk Assessment

- **Vertex endpoint uncertainty for get/cancel/delete:** Python code paths don’t use `_build_maybe_vertex_path` for these; validate with live API before locking in behavior.
- **Case conversion pitfalls:** Interactions payloads are mostly snake_case; existing gemini_ex serializers are generateContent-centric and camelCase-heavy.
- **Streaming transport mismatch:** Interactions should not force `alt=sse`; requires careful API plumbing to avoid breaking existing streaming.

---

## Revision Notes

- Replaced the prior module layout recommendation with one that matches gemini_ex conventions (`Gemini.Generate` style) and isolates Interactions types under `Gemini.Types.Interactions.*`.
- Corrected streaming enablement: Interactions uses `stream` field/query, not `?alt=sse`, and requires a streaming transport that does not append `alt=sse` (`lib/gemini/client/http_streaming.ex:404`).
- Updated plan to include missing `interaction.start` / `interaction.complete` SSE events and `[DONE]` termination behavior per Python sources.
- Incorporated corrected schemas: `thinking_level` values, Deep Research discriminator (`deep-research`), MCP `allowed_tools`, Google Search args/results, URL context results.
- Aligned the planned public surface with the implemented module name: `Gemini.APIs.Interactions`.
