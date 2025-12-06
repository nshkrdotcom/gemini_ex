# GeminiEx Guides

This folder contains the primary guides for running GeminiEx in production:

- `rate_limiting.md` – atomic token reservations, jittered retry windows, and concurrency gating defaults
- `structured_outputs.md` – structured JSON responses
- `files.md`, `batches.md`, `operations.md` – working with Files, Batch jobs, and long-running operations

Rate limiting highlights (v0.7.1):
- Atomic budget reservation with safety multipliers and reconciliation after responses
- Shared retry windows with jittered release (`retry_window_set/hit/release` telemetry)
- Telemetry for budget reservations (`budget_reserved`/`budget_rejected`) and concurrency gate hardening

For model selection, use `Gemini.Config.model_for_use_case/2` to resolve the built-in use-case aliases (`:cache_context`, `:report_section`, `:fast_path`) to the registered model strings.
