# Context Caching Execution Plan (v0.6.0)

**Goal:** Achieve full parity with Python `google-genai` caching while fixing current gaps (Vertex paths, config mismatch, formatting) and shipping tested Elixir APIs.

## Scope (Implement)
- Cache creation: `system_instruction`, `tools`, `tool_config`, `kms_key_name` (Vertex only), `fileData`/`file_uri`.
- Resource normalization: cache names + model names for Vertex/Gemini.
- Top-level `Gemini.*cache*` delegations.
- Usage metadata struct expansion.
- Model validation warning for cache-capable models.
- Config alignment for `Gemini.configure/2` vs `Gemini.Config.auth_config/0`.
- Robust part formatting (tool/function/response/thought/file).

## Test Strategy (TDD)
- Unit: format/normalization helpers, request bodies, model validation warning path, config alignment. Use deterministic assertions; no sleeps; isolate side effects (per Supertester principles).
- Live (tag `:live_api`): create cache with `system_instruction` + `file_uri`; use cache in generate; Vertex name normalization path (skip-friendly when env missing).
- No external network in unit tests; live tests guard on env like existing suite.

## Steps
1) Add failing unit tests for new features and normalization helpers.
2) Add/extend live tests (skip-aware) covering `system_instruction` + `file_uri` usage.
3) Implement features/fixes to satisfy tests.
4) Update docs (README, plan docs) and bump version to 0.6.0 with changelog.
5) Run unit tests; provide command to run only new live tests.

## Deliverables
- Updated code + tests with all unit tests passing.
- New/updated docs and changelog entry for 0.6.0 (2025-12-04).
