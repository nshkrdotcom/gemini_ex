# Proactive Rate Limiting ADRs

This directory contains Architecture Decision Records (ADRs) for enhancing the `gemini_ex` rate limiter from **passive** to **proactive** token budget enforcement.

## Background

The current rate limiter in `lib/gemini/rate_limiter/` is architecturally sound with:
- ETS-based state management
- Concurrency gating (semaphores)
- Retry handling with exponential backoff
- 429 RetryInfo parsing

However, the **token budgeting logic is passive**: it relies on callers explicitly passing `:estimated_input_tokens`. Without this, requests default to 0 tokens, bypassing budget checks entirely and hitting Google's API where 429s occur.

## The Fix

These ADRs propose making token budgeting proactive by:

1. **Auto-estimating tokens** using existing heuristics
2. **Providing sensible defaults** based on Google's tier limits
3. **Ensuring 429 retry info propagates** correctly through the error chain
4. **Documenting configuration patterns** for different use cases

## ADR Index

| ADR | Title | Status | Priority |
|-----|-------|--------|----------|
| [0001](ADR-0001-auto-token-estimation.md) | Auto Token Estimation | Proposed | HIGH |
| [0002](ADR-0002-token-budget-configuration.md) | Token Budget Configuration Defaults | Proposed | HIGH |
| [0003](ADR-0003-429-error-propagation.md) | Proper 429 Error Details Propagation | Proposed | MEDIUM |
| [0004](ADR-0004-recommended-configuration.md) | Recommended Configuration Pattern | Proposed | HIGH |

## Implementation Order

```
1. ADR-0002 (Config defaults)     ← Foundation: add fields to Config struct
     ↓
2. ADR-0001 (Auto estimation)     ← Core fix: integrate Tokens.estimate into Manager
     ↓
3. ADR-0003 (429 propagation)     ← Hardening: ensure retry info flows correctly
     ↓
4. ADR-0004 (Documentation)       ← User-facing: profiles and guides
```

## Quick Summary

### Current Behavior

```elixir
# Token budget checking defaults to 0, allowing all requests through
estimated_tokens = Keyword.get(opts, :estimated_input_tokens, 0)  # Always 0!

# Result: Heavy requests hit Google, get 429, usage recorded after the fact
```

### Proposed Behavior

```elixir
# Token budget auto-estimated from request contents
estimated_tokens =
  Keyword.get(opts, :estimated_input_tokens) ||
  estimate_from_contents(opts) ||                 # NEW: automatic estimation
  0

# With sensible defaults in Config:
token_budget_per_window: 32_000  # Conservative default for Free tier

# Result: Heavy requests blocked locally before hitting Google
```

## Files Affected

```
lib/gemini/rate_limiter/
├── config.ex        ← Add token_budget_per_window, window_duration_ms, profiles
├── manager.ex       ← Add estimate_from_contents/1, update check_token_budget/3
├── state.ex         ← Minor: make window duration configurable
└── retry_manager.ex ← Minor: strengthen extract_retry_info/1

lib/gemini/client/
└── http.ex          ← Pass contents to rate limiter opts

lib/gemini/
└── error.ex         ← Verify details field stores full error body
```

## Expected Outcomes

After implementation:

1. **Zero 429s from TPM exhaustion** for properly configured apps
2. **Works out of box** with conservative defaults
3. **Easy tier selection** via `:profile` config
4. **Existing code unchanged** - automatic estimation is transparent

## Related Work

- [ADR-0001 to ADR-0004](../gemini_rate_limits/adrs/) from 2025-12-03: Original rate limiter architecture
- `docs/guides/rate_limiting.md`: User-facing documentation
