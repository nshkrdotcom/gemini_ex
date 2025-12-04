# ADR 0001: Gemini rate-limit manager in gemini_ex

- Status: Proposed
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

## Consequences
- Requests will be paced automatically; callers see fewer 429s and cleaner error messaging.
- A blocked/queued request may wait up to the current `retry_until`, so callers should expect possible delays.
- Future: this state enables better scheduling (e.g., prioritization) without API changes.
