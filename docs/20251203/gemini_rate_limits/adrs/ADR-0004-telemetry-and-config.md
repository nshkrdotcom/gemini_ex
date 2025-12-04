# ADR 0004: Telemetry, configuration, and surfacing rate-limit state

- Status: Proposed
- Date: 2025-12-04

## Context
- Operators need visibility into pacing, retries, and quotas without inspecting logs manually.
- Applications (e.g., Lumainus) should not duplicate configuration; they should tune a few knobs and consume consistent signals.

## Decision
- Emit telemetry events:
  - `[:gemini_ex, :request, :start|:stop|:error]` with model, location, usage, duration.
  - `[:gemini_ex, :rate_limit, :wait]` when blocking, with `retry_at` and reason (quota metric/id).
  - `[:gemini_ex, :rate_limit, :error]` when retries exhausted.
- Configuration surface (with sane defaults):
  - `max_concurrency_per_model`
  - `max_attempts`
  - `base_backoff_ms` and `jitter`
  - `non_blocking` (return early vs. wait)
  - `logging` toggles (debug vs. quiet)
- Return structured errors to callers (`{:error, {:rate_limited, retry_at, details}}`) instead of ad-hoc strings.

## Consequences
- Observability is standardized; ops can alert on telemetry instead of scraping logs.
- Apps get a small, clear set of knobs; defaults protect most workloads automatically.
- Future UX improvements (e.g., “please retry after Xs”) become trivial with the structured error surface.
