# ADR 0001: Gemini rate-limit manager in gemini_ex

- Status: Accepted
- Date: 2025-12-04

## Context
- Gemini returns 429 with structured quota details (quotaMetric, quotaId, quotaDimensions, quotaValue, RetryInfo.retryDelay) but no remaining counters.
- Lumainus fires multiple section requests in parallel and regularly trips the per-minute token cap, causing failed sections.
- Rate-limit handling belongs inside gemini_ex so every consumer benefits without bespoke app code.

## Decision
- Add a first-class `GeminiEx.RateLimiter` that wraps outbound requests.
- Track per-model/location/metric state: sliding windows of token usage (input/output) and `retry_until` timestamps derived from 429 RetryInfo.
- Before sending, consult `retry_until`; if in the future, block/queue until then (or return a structured rate-limit error when `non_blocking: true` is set).
- After responses, record usage to refine the local budget model.
- Store state in ETS/Agent keyed by `{model, location, metric}` for lightweight, shared visibility across processes.
- Enabled by default (breaking change vs prior “fire and pray”); provide `disable_rate_limiter: true` opt-out and document in README/CHANGELOG/migration notes.
- Concurrency defaults are conservative (e.g., 4 per model) but configurable; `nil`/0 disables concurrency gating.
- Optional adaptive mode: start low, raise concurrency until 429 is observed, then back off; cap with a configured ceiling. Provide simple profiles (`:dev | :prod | :custom`) to seed defaults.
- Scope: rate limiter wraps request submission only; once a stream/response is open, it does not interfere.
- Testing strategy (Supertester-first, no sleeps):
  - Use a local fake Gemini endpoint (Bypass/Plug) that can emit 200, 429 with RetryInfo body, and 5xx.
  - Assert retry_until state updates, gating behavior, structured errors, and telemetry events.
  - Concurrency/adaptive: set max_concurrency=1 in tests, fire N requests, assert serialized hits; for adaptive, have fake flip to 429 after K hits and back to 200 to verify backoff/raise.
  - Token budgeting: stub usage in responses, assert preflight blocks when over budget.
  - non_blocking: ensure requests return immediately with {:rate_limited, retry_at} when gating is active.
  - Keep all tests isolated/async via Supertester; no Process.sleep.

## Consequences
- Requests will be paced automatically; callers see fewer 429s and cleaner error messaging.
- A blocked/queued request may wait up to the current `retry_until`, so callers should expect possible delays.
- Future: this state enables better scheduling (e.g., prioritization) without API changes.
