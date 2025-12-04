# ADR 0003: Concurrency gating and token budgeting

- Status: Accepted
- Date: 2025-12-04

## Context
- Thundering herd: many section requests launch simultaneously, multiplying token usage and tripping per-minute limits.
- Gemini exposes no “remaining” header, so we must infer safe pacing from recent usage and 429 signals.

## Decision
- Introduce per-model concurrency permits (configurable, small defaults like 2–4) in gemini_ex to throttle bursts; allow `nil`/0 to disable. Ship enabled by default; document in migration notes.
- Optional adaptive mode: start low, increase concurrency until a 429 is observed, then back off; cap via a configured ceiling.
- Profiles: support `:dev | :prod | :custom` presets for defaults; custom overrides always win.
- Maintain lightweight token budgets using:
  - Estimated tokens from prompt size preflight (to decide if we should wait when near a known retry window).
  - Actual `usage` returned by Gemini to update rolling windows.
- When a request would violate a live retry window, enqueue or return a structured “retry_at” response.
- Testing strategy:
  - Concurrency gate: set max_concurrency=1, fire N parallel requests at fake server; assert serialized hits (with Supertester harness, no sleeps).
  - Adaptive: configure fake to switch to 429 after K hits; assert gate backs off, then raises when 200 resumes.
  - Token budgeting: feed fake `usage` data; assert preflight blocks when budget exceeded.
  - Verify defaults ON; opt-outs (nil/0 concurrency) skip gating.

## Consequences
- Reduces simultaneous token spikes, cutting 429 frequency.
- Adds minimal latency under load; single calls stay fast.
- Creates the foundation for smarter scheduling (priority queues) later without changing app code.
