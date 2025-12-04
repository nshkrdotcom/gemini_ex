# ADR 0002: Retries and backoff for Gemini calls

- Status: Accepted
- Date: 2025-12-04

## Context
- Gemini 429 responses include RetryInfo; transient network/5xx failures also occur.
- Current callers fail fast on 429, producing broken report sections when many calls launch together.

## Decision
- Implement retry policy inside gemini_ex client wrapper:
  - On 429, parse RetryInfo.retryDelay and back off exactly that duration; fall back to exponential backoff with jitter when missing.
  - On transient network/5xx, use exponential backoff with jitter (configurable attempts).
  - On non-retriable 4xx (except 429), fail fast.
- Cap retries (configurable `max_attempts`) and return structured error `{:error, {:rate_limited, retry_at, details}}` or `{:error, {:transient_failure, attempts, last_reason}}` when exhausted.
- Coordinate with the rate limiter to avoid stacked/double retries; 429 handling lives in the rate-limit layer, transient network/5xx in the generic retry layer.
- Per-call override: `non_blocking: true` returns immediately with structured rate-limit info instead of sleeping.

## Consequences
- Sections/jobs become resilient to temporary quota spikes and flaky transports.
- Callers can choose to block until retry or opt out via `non_blocking: true`.
- Error surfaces are consistent, enabling UI messaging and logging without ad-hoc parsing.
