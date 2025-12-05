# ADR 0001: Automatic Token Estimation for Proactive Rate Limiting

- Status: Proposed
- Date: 2025-12-04

## Context

**Current behavior:** `Gemini.RateLimiter.Manager.check_token_budget/3` runs before the request, but defaults `estimated_input_tokens` to `0` and only reads `token_budget_per_window` from per-call opts. With those defaults, the budget check is effectively bypassed unless callers remember to provide both values.

**Estimator constraints:** `Gemini.APIs.Tokens.estimate/2` only accepts raw text or a list of `Gemini.Types.Content` structs. By the time the HTTP client sees the request, the payload has been transformed into an API map (`%{contents: [...]}`), which the estimator does **not** handle. Calling `estimate/2` on that map raises and is rescued to `{:error, ...}` → `nil`, so the fallback remains `0`.

**Key gaps today:**
- No automatic estimation on the original input (string or `Content` list).
- No default budget pulled from config, so `budget` is often `nil`.
- Budget window length is fixed at 60s in `State`, so even if we estimate tokens, the window cannot be tuned yet (see ADR-0002).

## Decision

Estimate **before** the request body is transformed, pass the result to the rate limiter, and fall back to config defaults for the token budget. This keeps the estimator on supported input types and makes proactive blocking actually work.

### Implementation

1) **Estimate at the Coordinator boundary (supported input types).**

- In `Gemini.APIs.Coordinator.generate_content/2` (and streaming entry points), run `Tokens.estimate/1` on the original `input` (string or `Content` list) **before** it is normalized into the API map.
- If estimation succeeds, inject `:estimated_input_tokens` into the rate-limiter options passed to HTTP/RateLimiter.
- If it fails (unsupported shape or error), skip and let the fallback be `0`.

Illustrative sketch:

```elixir
with {:ok, request_body} <- build_generate_request(input, opts) do
  rate_limiter_opts =
    case Tokens.estimate(input) do
      {:ok, count} -> Keyword.put(opts, :estimated_input_tokens, count)
      _ -> opts
    end

  HTTP.post(path, request_body, rate_limiter_opts)
end
```

2) **Use config defaults when callers don’t pass budgets.**

In `Gemini.RateLimiter.Manager.check_token_budget/3`, prefer:

```elixir
estimated_tokens =
  Keyword.get(opts, :estimated_input_tokens, 0)

budget =
  Keyword.get(opts, :token_budget_per_window, config.token_budget_per_window)
```

3) **(Optional, if desired) Extend the estimator to support API maps.**

If we want to estimate after normalization, add a safe clause in `Tokens.estimate/1` to accept `%{contents: [...]}` and walk parts, but keep it defensive so it never raises.

## Consequences

### Positive

1. **Proactive Protection**: Heavy requests are blocked locally before hitting Google's TPM limit
2. **Zero Caller Changes**: Existing code continues to work; estimation is automatic
3. **Explicit Override**: Callers can still pass `:estimated_input_tokens` for precise control
4. **Better UX**: Fewer 429 errors surfacing to application code

### Negative

1. **Estimation Overhead**: Adds computation to every request (mitigated: heuristic is O(n) on content length)
2. **Estimation Inaccuracy**: Heuristic may under/over-estimate by ~20-30% compared to actual tokenization
3. **False Positives**: Conservative estimates may block requests that would have succeeded

### Mitigations

- Callers needing precision can pre-calculate with `Tokens.count/2` (API call) and pass `:estimated_input_tokens`
- Configuration allows tuning: set higher `token_budget_per_window` to reduce false positives
- Telemetry events will track estimation accuracy for future tuning

## Alternatives Considered

### 1. Require Explicit Token Estimates
- **Rejected**: Poor developer experience; most users won't bother
- Current behavior effectively does this with the 0 default

### 2. Use countTokens API Call
- **Rejected**: Adds network round-trip latency to every request
- Could be offered as opt-in for applications needing precision

### 3. Cache Token Counts by Content Hash
- **Deferred**: Add caching layer if estimation overhead becomes measurable
- Current heuristic is fast enough for most use cases

## Implementation Priority

**HIGH** - This is the missing link that makes token budgeting effective. Without it, the existing rate limiter infrastructure is underutilized.

## Related ADRs

- ADR-0002: Token Budget Configuration Defaults
- ADR-0003: Proper 429 Error Details Propagation
- ADR-0004: Recommended Configuration Pattern
