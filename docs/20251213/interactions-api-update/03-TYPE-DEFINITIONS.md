# Interactions API - Type Definitions

**Source:** `python-genai/google/genai/_interactions/types/`

This document aligns the proposed Elixir types with the *actual* Python Interactions schemas.
For a complete per-type inventory/mapping, see `docs/20251213/interactions-api-update/TYPE-MAPPING.md`.

---

## Core Types

### Interaction

Python source: `python-genai/google/genai/_interactions/types/interaction.py:123`.

Key fields (snake_case in JSON):

| Field | Type | Notes |
|------|------|-------|
| `id` | string | Required |
| `status` | `"in_progress" \| "requires_action" \| "completed" \| "failed" \| "cancelled"` | Required |
| `agent` | string \| null | Agent name (e.g. `"deep-research-pro-preview-12-2025"`) |
| `model` | string \| null | Model name (see `python-genai/google/genai/_interactions/types/model.py:23`) |
| `outputs` | list(content) \| null | Output content blocks (discriminated by `type`) |
| `previous_interaction_id` | string \| null | Chain pointer |
| `role` | string \| null | Typically `"model"` on output |
| `created` / `updated` | ISO8601 datetime \| null | Parsed as DateTime in Elixir |
| `usage` | usage \| null | Token stats (see below) |

### Turn

Python source: `python-genai/google/genai/_interactions/types/turn.py:67`.

| Field | Type | Notes |
|------|------|-------|
| `role` | string \| null | `"user"` for input, `"model"` for output |
| `content` | string \| list(content) \| null | Each list item is a content block |

### Annotation

Python source: `python-genai/google/genai/_interactions/types/annotation.py:25`.

| Field | Type | Notes |
|------|------|-------|
| `start_index` | integer \| null | Byte index |
| `end_index` | integer \| null | Byte index (exclusive) |
| `source` | string \| null | URL/title/identifier |

### Usage

Python source: `python-genai/google/genai/_interactions/types/usage.py:72`.

The Interactions `Usage` schema is *not* identical to existing `GenerateContentResponse.UsageMetadata` in Elixir:
- Interactions uses per-modality arrays with `{modality, tokens}`.
- GenerateContent uses `{modality, tokenCount}` and Gemini-style modality enums.

---

## Content Types (17 variants)

Python source union: `python-genai/google/genai/_interactions/types/interaction.py:53` (`InputContentList` / `Output`).

All content blocks are discriminated by the JSON field `type` (string).

| `type` | Fields | Notes |
|--------|--------|------|
| `text` | `text`, `annotations` | `annotations` is a list of `Annotation` (`python-genai/google/genai/_interactions/types/text_content.py:27`) |
| `image` | `data`, `uri`, `mime_type`, `resolution` | `mime_type` is a string (known values in `python-genai/google/genai/_interactions/types/image_mime_type.py:23`) |
| `audio` | `data`, `uri`, `mime_type` | Known values in `python-genai/google/genai/_interactions/types/audio_mime_type.py:23` |
| `document` | `data`, `uri`, `mime_type` | `mime_type` is a free-form string (`python-genai/google/genai/_interactions/types/document_content.py:26`) |
| `video` | `data`, `uri`, `mime_type`, `resolution` | Known values in `python-genai/google/genai/_interactions/types/video_mime_type.py:23` |
| `thought` | `signature`, `summary` | `summary` is a list of `TextContent \| ImageContent` (`python-genai/google/genai/_interactions/types/thought_content.py:31`) |
| `function_call` | `id`, `name`, `arguments` | All required (`python-genai/google/genai/_interactions/types/function_call_content.py:26`) |
| `function_result` | `call_id`, `result`, `is_error`, `name` | `call_id` + `result` required; `result` is `{items:[string\|ImageContent]} \| string \| any JSON` (`python-genai/google/genai/_interactions/types/function_result_content.py:36`) |
| `code_execution_call` | `id`, `arguments` | `arguments` is `{code, language}` (`python-genai/google/genai/_interactions/types/code_execution_call_content.py:27`) |
| `code_execution_result` | `call_id`, `result`, `is_error`, `signature` | All optional (`python-genai/google/genai/_interactions/types/code_execution_result_content.py:26`) |
| `url_context_call` | `id`, `arguments` | `arguments` is `{urls:[...]}` (`python-genai/google/genai/_interactions/types/url_context_call_content.py:27`) |
| `url_context_result` | `call_id`, `result`, `is_error`, `signature` | `result` is a list of `{status, url}` (`python-genai/google/genai/_interactions/types/url_context_result.py:26`) |
| `google_search_call` | `id`, `arguments` | `arguments` is `{queries:[...]}` (`python-genai/google/genai/_interactions/types/google_search_call_arguments.py:25`) |
| `google_search_result` | `call_id`, `result`, `is_error`, `signature` | `result` list items have `rendered_content`, `title`, `url` (`python-genai/google/genai/_interactions/types/google_search_result.py:25`) |
| `mcp_server_tool_call` | `id`, `name`, `server_name`, `arguments` | All required (`python-genai/google/genai/_interactions/types/mcp_server_tool_call_content.py:26`) |
| `mcp_server_tool_result` | `call_id`, `result`, `name`, `server_name` | `call_id` + `result` required; `result` is `{items:[string\|ImageContent]} \| string \| any JSON` (`python-genai/google/genai/_interactions/types/mcp_server_tool_result_content.py:36`) |
| `file_search_result` | `result` | `result` list items have `file_search_store`, `text`, `title` (`python-genai/google/genai/_interactions/types/file_search_result_content.py:26`) |

---

## Tool Types (7 variants)

Tools are discriminated by `type` (string).

Python source union: `python-genai/google/genai/_interactions/types/tool.py:97` and `python-genai/google/genai/_interactions/types/tool_param.py:97`.

| `type` | Fields | Notes |
|--------|--------|------|
| `function` | `name`, `description`, `parameters` | JSON Schema parameters (`python-genai/google/genai/_interactions/types/function_param.py:25`) |
| `google_search` | *(none)* | |
| `code_execution` | *(none)* | |
| `url_context` | *(none)* | |
| `computer_use` | `environment`, `excludedPredefinedFunctions` | **API key is camelCase**; Python maps `excluded_predefined_functions` → `excludedPredefinedFunctions` (`python-genai/google/genai/_interactions/types/tool_param.py:57`) |
| `mcp_server` | `name`, `url`, `headers`, `allowed_tools` | `allowed_tools` entries are `{mode, tools}` (`python-genai/google/genai/_interactions/types/allowed_tools_param.py:28`) |
| `file_search` | `file_search_store_names`, `metadata_filter`, `top_k` | |

---

## GenerationConfig

Python source: `python-genai/google/genai/_interactions/types/generation_config_param.py:31`.

Key differences vs Gemini `GenerationConfig` already in Elixir:
- Interactions uses `thinking_level: "low" | "high"` (`python-genai/google/genai/_interactions/types/thinking_level.py:22`).
- Interactions `speech_config` schema is `{language, speaker, voice}` (`python-genai/google/genai/_interactions/types/speech_config.py:25`).
- Interactions tool choice is `ToolChoiceType | ToolChoiceConfig` (`python-genai/google/genai/_interactions/types/tool_choice.py:26`).

---

## Request Parameter Types

### Create Params (Model vs Agent)

Python source: `python-genai/google/genai/_interactions/types/interaction_create_params.py:60`.

Required variants (enforced at runtime by `required_args`):
- `input` + `model` (model interaction), or
- `input` + `agent` (agent interaction)

Validation rule: do not send both `model` and `agent_config` (and do not send both `agent` and `generation_config`) — `python-genai/google/genai/_interactions/resources/interactions.py:412`.

### Get Params

Python source: `python-genai/google/genai/_interactions/types/interaction_get_params.py:26`.

`last_event_id` is only meaningful when `stream=true` (enforced by API contract; Python docstring notes this).

---

## Revision Notes

- Corrected multiple schema mismatches discovered by reading the Python type sources directly (notably `ThinkingLevel`, Deep Research discriminator, URL/Google Search result shapes, MCP server fields, and `ThoughtContent.summary` vs `content`). Key references: `python-genai/google/genai/_interactions/types/thinking_level.py:22`, `python-genai/google/genai/_interactions/types/thought_content.py:31`, `python-genai/google/genai/_interactions/types/url_context_result.py:26`, `python-genai/google/genai/_interactions/types/google_search_result.py:25`, `python-genai/google/genai/_interactions/types/mcp_server_tool_call_content.py:26`.
