# Codebase Alignment - Grounding in Existing gemini_ex

**Purpose:** Reconcile the Interactions API docs/plan with what actually exists in gemini_ex today.

---

## Executive Summary

gemini_ex has strong reusable infrastructure (HTTP, SSE parsing, multi-auth), but **does not currently implement the Interactions API** and **cannot reuse the existing generateContent type system directly**:

- Interactions request/response JSON is mostly **snake_case** and content blocks are discriminated by `type` (not `role/parts`).
- Interactions streaming is SSE, but streaming is enabled via `stream` (body/query), not `?alt=sse`.
- Vertex Interactions uses a different URL shape and (in Python) adds `x-goog-user-project` when available.

Net: reuse is meaningful for transport/auth, but **most types + serialization + streaming plumbing are new work**.

---

## What Already Exists (High-Value Reuse)

### 1. SSE Parser (Reusable as-is)

`Gemini.SSE.Parser` already:
- Parses SSE frames and JSON payloads (`lib/gemini/sse/parser.ex:37`).
- Recognizes `[DONE]` (`lib/gemini/sse/parser.ex:160`) and exposes `stream_done?/1` (`lib/gemini/sse/parser.ex:172`).

This matches Python’s stream termination behavior (`python-genai/google/genai/_interactions/_streaming.py:72`).

### 2. HTTP + Streaming Transport (Reusable with a key tweak)

`Gemini.Client.HTTPStreaming` provides the stream loop and SSE headers. Historically it appended `alt=sse` by default; Interactions needs a variant that:
- Sends SSE headers
- **Does not** inject `alt=sse`

In gemini_ex this is implemented via an `:add_sse_params` option (default `true`) on the streaming transport.

### 3. Multi-auth System (Reusable with one missing header)

Vertex auth already sends `Authorization: Bearer ...` (`lib/gemini/auth/vertex_strategy.ex:59`) and Gemini API key auth uses `x-goog-api-key` (`lib/gemini/auth/gemini_strategy.ex:37`).

Python additionally injects `x-goog-user-project` when quota project is present (`python-genai/google/genai/client.py:509`). gemini_ex does not currently do this.

### 4. Existing patterns: TypedStruct + Jason

The existing `Gemini.Types.*` approach (TypedStruct + `Jason.Encoder`) is a good fit for implementing Interactions types, but the schemas themselves are different.

---

## What Cannot Be Reused Directly (Key Mismatches)

### 1. `Gemini.Types.Content` / `Gemini.Types.Part`

These types are designed around `GenerateContent` (`role` + `parts`) and are serialized with generateContent conventions (`lib/gemini/types/common/content.ex:1`, `lib/gemini/types/common/part.ex:1`).

Interactions content blocks are a different model:
- Discriminated by `type`
- Fields like `text`, `mime_type`, `signature`, tool call/result structures, etc.

Result: **not drop-in compatible** for Interactions input/output.

### 2. GenerationConfig & Usage types

Interactions uses different config/usage schemas (example: `thinking_level` is `"low" | "high"` in Interactions, not the generateContent thinking config).

### 3. Coordinator request formatting

`Gemini.Apis.Coordinator` contains generateContent-specific normalization and formatting logic. Interactions should avoid reusing these encoders to prevent accidental camelCase/shape drift.

---

## Concrete Gaps to Close (Implementation Alignment)

1. **New public API module:** `Gemini.APIs.Interactions` (location: `lib/gemini/apis/interactions.ex`).
2. **New types namespace:** `Gemini.Types.Interactions.*` (recommended location: `lib/gemini/types/interactions/`).
3. **Streaming without `alt=sse`:** add a safe streaming transport path for Interactions while preserving existing generateContent behavior.
4. **Vertex URL building:** add a path builder equivalent to Python’s `_build_maybe_vertex_path` (`python-genai/google/genai/_interactions/_base_client.py:413`) and ensure Vertex base host is location-specific (Python tests: `python-genai/google/genai/tests/interactions/test_auth.py:175`).
5. **Vertex quota project header:** add `x-goog-user-project` support for Vertex when configured (Python behavior: `python-genai/google/genai/client.py:509`).
6. **Event model support:** implement Interactions SSE events (`interaction.start`, `interaction.complete`, etc.) and delta accumulation rules; see `docs/20251213/interactions-api-update/04-STREAMING-EVENTS.md`.

---

## Revised Reuse Assessment

| Area | Reuse Level | Notes |
|---|---:|---|
| SSE parsing | High | `[DONE]` already supported |
| Streaming loop | Medium | Needs opt-out of `alt=sse` |
| HTTP client | Medium | Needs new endpoints + Vertex path building |
| Auth | Medium | Vertex quota project header missing |
| Types | Low | Interactions types are largely new |
| Request serialization | Low | Interactions is snake_case; avoid generateContent encoders |

---

## Revision Notes

- Corrected earlier overstatement of direct type reuse: `Gemini.Types.Content`/`Part` are generateContent-specific and do not match Interactions `type`-discriminated content blocks.
- Added specific transport/auth blockers discovered in code: `alt=sse` injection by default in `Gemini.Client.HTTPStreaming` and missing `x-goog-user-project` injection vs Python (`python-genai/google/genai/client.py:509`).
- Anchored Vertex Interactions routing guidance in Python sources/tests (`python-genai/google/genai/_interactions/_base_client.py:413`, `python-genai/google/genai/tests/interactions/test_auth.py:175`).
- Aligned planned module naming with the implemented API surface: `Gemini.APIs.Interactions`.
