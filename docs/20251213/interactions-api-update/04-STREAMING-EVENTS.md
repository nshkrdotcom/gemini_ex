# Interactions API - Streaming Events

**Python Source:** `python-genai/google/genai/_interactions/_streaming.py`, `python-genai/google/genai/_interactions/resources/interactions.py`, `python-genai/google/genai/_interactions/types/`

---

## Overview

When `stream=true`, the Interactions API returns a **Server-Sent Events (SSE)** stream where each `data:` line is a JSON object with an `event_type` discriminator (and usually an `event_id`).

Key differences vs `GenerateContent` streaming in gemini_ex:
- Interactions enables streaming via a **request field/query param** (`stream`), not via `?alt=sse`.
- Interactions can be resumed via `last_event_id` (GET only), using the `event_id` found inside each JSON event.

---

## How Streaming Is Enabled

From Python’s `InteractionsResource`:
- `create`: POST `/{api_version}/interactions` with request body field `stream: true` (`python-genai/google/genai/_interactions/resources/interactions.py:416`).
- `get`: GET `/{api_version}/interactions/{id}` with query `stream=true` and optional `last_event_id` (`python-genai/google/genai/_interactions/resources/interactions.py:623`).

---

## SSE Framing & Stream Termination

Python’s stream iterator stops when the SSE `data` begins with `[DONE]`:
- `python-genai/google/genai/_interactions/_streaming.py:72`

This is separate from `interaction.complete` (which may be present before `[DONE]`).

---

## Event Types (InteractionSSEEvent)

Python defines the union as 6 variants:
- `InteractionEvent` (`interaction.start`, `interaction.complete`)
- `InteractionStatusUpdate` (`interaction.status_update`)
- `ContentStart` (`content.start`)
- `ContentDelta` (`content.delta`)
- `ContentStop` (`content.stop`)
- `ErrorEvent` (`error`)

Source: `python-genai/google/genai/_interactions/types/interaction_sse_event.py:30`.

### Common Fields

All event objects are JSON maps with:
- `event_type` (string discriminator)
- `event_id` (string token used for resumption; optional in schema, expected in practice)

### Event Payload Shapes

| `event_type` | Extra fields | Source |
|---|---|---|
| `interaction.start` / `interaction.complete` | `interaction` (full `Interaction`) | `python-genai/google/genai/_interactions/types/interaction_event.py:27` |
| `interaction.status_update` | `interaction_id`, `status` | `python-genai/google/genai/_interactions/types/interaction_status_update.py:26` |
| `content.start` | `index`, `content` | `python-genai/google/genai/_interactions/types/content_start.py:67` |
| `content.delta` | `index`, `delta` | `python-genai/google/genai/_interactions/types/content_delta.py:347` |
| `content.stop` | `index` | `python-genai/google/genai/_interactions/types/content_stop.py:26` |
| `error` | `error: {code, message}` | `python-genai/google/genai/_interactions/types/error_event.py:26` |

### Index Semantics

`index` is the output content block index (0-based) within the final `interaction.outputs` list. A typical stream emits:
- `content.start` (index N)
- `content.delta` (index N) repeated
- `content.stop` (index N)

---

## Delta Types (18 variants)

The `content.delta.delta` payload is a discriminated union by `type`.

Python source union: `python-genai/google/genai/_interactions/types/content_delta.py:322`.

| `delta.type` | Fields (delta) | Notes / Source |
|---|---|---|
| `text` | `text`, `annotations` | `python-genai/google/genai/_interactions/types/content_delta.py:67` |
| `image` | `data`, `uri`, `mime_type`, `resolution` | `python-genai/google/genai/_interactions/types/content_delta.py:77` |
| `audio` | `data`, `uri`, `mime_type` | `python-genai/google/genai/_interactions/types/content_delta.py:92` |
| `document` | `data`, `uri`, `mime_type` | `python-genai/google/genai/_interactions/types/content_delta.py:104` |
| `video` | `data`, `uri`, `mime_type`, `resolution` | `python-genai/google/genai/_interactions/types/content_delta.py:115` |
| `thought_summary` | `summary` | `python-genai/google/genai/_interactions/types/content_delta.py:137` |
| `thought_signature` | `signature` | `python-genai/google/genai/_interactions/types/content_delta.py:160` |
| `function_call` | `id`, `name`, `arguments` | `python-genai/google/genai/_interactions/types/content_delta.py:168` |
| `function_result` | `call_id`, `result`, `is_error`, `name` | `python-genai/google/genai/_interactions/types/content_delta.py:190` |
| `code_execution_call` | `id`, `arguments` | `python-genai/google/genai/_interactions/types/content_delta.py:211` |
| `code_execution_result` | `call_id`, `result`, `is_error`, `signature` | `python-genai/google/genai/_interactions/types/content_delta.py:228` |
| `url_context_call` | `id`, `arguments` | `python-genai/google/genai/_interactions/types/content_delta.py:241` |
| `url_context_result` | `call_id`, `result`, `is_error`, `signature` | `result` items are `{status, url}` (`python-genai/google/genai/_interactions/types/url_context_result.py:26`) |
| `google_search_call` | `id`, `arguments` | `arguments.queries: [string]` (`python-genai/google/genai/_interactions/types/google_search_call_arguments.py:25`) |
| `google_search_result` | `call_id`, `result`, `is_error`, `signature` | `result` items are `{rendered_content, title, url}` (`python-genai/google/genai/_interactions/types/google_search_result.py:25`) |
| `mcp_server_tool_call` | `id`, `name`, `server_name`, `arguments` | `python-genai/google/genai/_interactions/types/content_delta.py:263` |
| `mcp_server_tool_result` | `call_id`, `result`, `name`, `server_name` | `python-genai/google/genai/_interactions/types/content_delta.py:287` |
| `file_search_result` | `result` | `result` items are `{file_search_store, text, title}` (`python-genai/google/genai/_interactions/types/content_delta.py:302`) |

---

## Stream Resumption (GET only)

To resume a dropped stream:
1. Track the latest `event_id` from any received event.
2. Call `interactions.get(id, stream=true, last_event_id=...)`.

Python docstring: `last_event_id` “resumes the interaction stream from the next chunk after the event marked by the event id” and “can only be used if `stream` is true” (`python-genai/google/genai/_interactions/resources/interactions.py:542`).

---

## Elixir Integration Notes (gemini_ex)

### SSE parsing

`Gemini.SSE.Parser` already decodes SSE and emits decoded JSON payloads. Interactions resumption uses the JSON `event_id`, so dropping the SSE `id:` field is not a blocker.

### Streaming transport

`Gemini.Client.HTTPStreaming` currently forces `?alt=sse` (`lib/gemini/client/http_streaming.ex:404`). Interactions streaming should not append `alt=sse`; implement a variant that only sets SSE headers (`Accept: text/event-stream`) and leaves query params untouched.

---

## Typical Event Sequences

### Simple content stream

1. `interaction.start` (includes `interaction.id`)
2. `content.start` (index 0)
3. `content.delta` (index 0) repeated
4. `content.stop` (index 0)
5. `interaction.complete`
6. `[DONE]` sentinel

### Status updates interleaved

Status updates (`interaction.status_update`) may appear between content lifecycle events (especially for background interactions).

---

## Revision Notes

- Added missing SSE `InteractionEvent` variants (`interaction.start`, `interaction.complete`) and corrected the union to 6 variants per `python-genai/google/genai/_interactions/types/interaction_sse_event.py:30`.
- Corrected streaming enablement semantics: Interactions uses request `stream` (POST body / GET query) rather than `?alt=sse` per `python-genai/google/genai/_interactions/resources/interactions.py:416` and `python-genai/google/genai/_interactions/resources/interactions.py:623`.
- Fixed Google Search call argument shape to `queries: [string]` and result shape to `rendered_content/title/url` per `python-genai/google/genai/_interactions/types/google_search_call_arguments.py:25` and `python-genai/google/genai/_interactions/types/google_search_result.py:25`.
- Fixed URL context result item shape to `{status, url}` per `python-genai/google/genai/_interactions/types/url_context_result.py:26`.
- Documented `[DONE]` termination behavior per `python-genai/google/genai/_interactions/_streaming.py:72`.
