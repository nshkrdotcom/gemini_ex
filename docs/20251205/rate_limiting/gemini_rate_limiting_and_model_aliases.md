# Gemini Rate Limiting & Model Alias Design

## Context (gemini_ex focus)
- Observed 429s when multiple concurrent requests launched together; a single-minute token window (e.g., 1M TPM) was exhausted before backoff could help.
- gemini_ex limiter today: `would_exceed_budget?/3` just checks ETS; `record_usage/4` writes later. Multiple requests can all pass the check and launch together (classic check-then-act race). Retry state is only set after 429 responses, so the initial herd still hits the API.
- ConcurrencyGate also uses non-atomic ETS read/insert, so `max_concurrency_per_model` can be oversubscribed under simultaneous calls (TOCTOU race).

## Goals
- Prevent thundering-herd launches when token budget is tight (429s).
- Stagger retries based on shared retry window (anti-herd).
- Centralize model references via use-case aliases (no scattered string literals).
- Keep config simple; allow safe increase of concurrency after fix.

## Current Behavior (Problems)
1) **Non-atomic budget check**: `RateLimiter.State.would_exceed_budget?/3` reads ETS usage; `record_usage/4` writes later. Multiple workers see “budget available” and all launch.
2) **Retry window set after the fact**: RetryManager sets `retry_until` after 429 responses arrive; initial batch has already failed. Retries may re-fire together without coordination.
3) **max_concurrency_per_model is not enforced atomically**: ConcurrencyGate does ETS lookup + insert (TOCTOU). Simultaneous callers can all see `current=0` and each set `current=1`, oversubscribing even when max is 1 (e.g., 5 workers all acquire when max=1).
4) **No central source for model aliases**: Model strings must be hardcoded by adopters; prefer gemini_ex-provided alias mapping to avoid drift.

## Proposed Changes (gemini_ex)

### A. gemini_ex Rate Limiter Hardening
1) **Atomic budget reservation**  
   - Add `try_reserve_budget/3` that atomically check-and-decrements available tokens per window (ETS `update_counter/4` with floor) or serialize via GenServer.  
   - If over budget, return `{:error, {:rate_limited, retry_at, %{reason: :over_budget}}}` before firing the HTTP request.
   - **Estimation policy**: reserve on `estimated_total_tokens` with an optional safety multiplier (e.g., 1.2×). After response, reconcile actual vs reserved: return any surplus, and deduct any shortfall. This prevents simultaneous launches from collectively exceeding budget and reduces “under-estimate then spike” risk.
   - Only record actual usage after response for telemetry; reservation is the gate.

2) **Shared retry window gating**  
   - On 429 (or `{rate_limited, retry_window}`), set `retry_until` per model key. New requests arriving before that time should either block (if `non_blocking: false`) or immediately return rate_limited with jittered retry_after.
   - Add jittered release so queued requests don’t re-fire in unison.

3) **Config behaviors**  
   - Default `non_blocking: false` for server workloads so limiter waits instead of bubbling errors immediately.  
   - Keep adaptive_concurrency but cap at configured ceiling; decrease immediately on 429.
   - Preserve `max_concurrency_per_model`, but it becomes secondary once atomic budget gating exists.

4) **Telemetry & logging**  
   - Emit events for `:budget_reserved`, `:budget_rejected`, `:retry_window_set`, `:retry_window_hit`, and `:retry_window_release` with model key, estimated tokens, remaining budget.
   - Surface local over-budget as distinct from API 429.

5) **Gate implementation choice**  
   - **GenServer gate**: serialize budget checks and reservations; natural backpressure; simpler correctness; single process per model/location. If it crashes, state resets (tolerable because window is time-based).  
   - **ETS atomics + sleep**: fastest and distributed; needs explicit wait-queue policy and jitter to avoid synchronized wake-ups; must cap waiters to avoid unbounded sleepers.  
   - Recommendation: start with a supervised GenServer gate for robustness; optionally optimize to ETS atomics later if contention becomes measurable.

### B. Model aliasing in gemini_ex
1) Provide a use-case → atom map in gemini_ex (e.g., `:cache_context`, `:report_section`, `:fast_path`) that resolves to registered model strings via `Gemini.Config.get_model/1`.  
2) Expose helpers for adopters to fetch use-case keys and resolved model strings; avoid scattering raw model literals.
3) Document expected token minima per alias (from model registry) for cache-compatible scenarios.

## Rollout Plan
1) Implement atomic budget reservation + reconciliation and retry-window gating; unit tests for concurrent over-budget scenarios and staggered retries.  
2) Fix ConcurrencyGate race with atomic counter or GenServer serialization; test simultaneous acquisitions at max=1 to ensure only one succeeds.  
3) Add aliasing helpers and document use-case mapping in guides/README.  
4) Run concurrency/load tests (multi-request bursts) to verify no oversubscription and no 429s from thundering herd; verify telemetry.  
5) Publish version bump (0.7.1) with changelog/readme updates.

## Risks / Mitigations
- **Atomic gate correctness**: Ensure reservation is reconciled after response; log discrepancies when actual deviates from estimate.  
- **Throughput drop**: Adaptive concurrency + jittered release should keep throughput reasonable; can tune token budgets per tier.

## Open Questions
- Should reservation use estimated tokens or include a safety multiplier?  
- Should we queue centrally (GenServer) or rely on ETS atomics + caller sleep?  
- Do we want per-tenant/per-scope budgeting layered on top of per-model budgeting?
