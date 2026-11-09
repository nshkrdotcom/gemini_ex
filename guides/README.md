# GeminiEx Guides

GeminiEx 0.19.0 requires Elixir 1.17 or later. See the
[release notes](../CHANGELOG.md#0190---2026-11-09) for model, dependency, and compatibility changes.

This folder contains the primary guides for running GeminiEx in production:

- `interactions.md` – stateful interactions (CRUD), streaming, and resumption
- `rate_limiting.md` – atomic token reservations, jittered retry windows, and concurrency gating defaults
- `structured_outputs.md` – structured JSON responses
- `files.md`, `batches.md`, `operations.md` – working with Files, Batch jobs, and long-running operations

Rate limiting highlights (v0.7.1):
- Atomic budget reservation with safety multipliers and reconciliation after responses
- Shared retry windows with jittered release (`retry_window_set/hit/release` telemetry)
- Telemetry for budget reservations (`budget_reserved`/`budget_rejected`) and concurrency gate hardening

For model selection, use `Gemini.Config.model_for_use_case/2` to resolve the built-in use-case aliases (`:cache_context`, `:report_section`, `:fast_path`) to the registered model strings.
The current stable model aliases include `:argon_4`, `:flash_3_8`, `:flash_3_6`,
`:flash_3_5`, `:flash_3_5_lite`, `:flash_3_1_lite`, `:flash_3_1_image`,
`:flash_3_1_lite_image`, and `:pro_3_image`. Argon and Gemini 3.8 Flash support
`:low`, `:medium`, and `:high` thinking levels, but not `:minimal`. Argon supports
implicit caching only. Gemini 3.7 Flash is deprecated on the Gemini API and
requests are routed to 3.8 Flash.

Vertex retains `gemini-2.5-flash-lite` as its regional generation default;
select a supported location explicitly when choosing newer models. See the
[Live API guide](live_api.md) for the new 3.8 Live defaults and setup differences.
