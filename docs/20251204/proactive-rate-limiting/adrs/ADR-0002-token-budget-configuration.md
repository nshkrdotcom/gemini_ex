# ADR 0002: Token Budget Configuration Defaults

- Status: Proposed
- Date: 2025-12-04

## Context

The current `Gemini.RateLimiter.Config` struct manages concurrency settings effectively but lacks proper token budget configuration:

```elixir
# Current config.ex struct
defstruct max_concurrency_per_model: 4,
          max_attempts: 3,
          base_backoff_ms: 1000,
          jitter_factor: 0.25,
          non_blocking: false,
          disable_rate_limiter: false,
          adaptive_concurrency: false,
          adaptive_ceiling: 8,
          profile: :prod
```

**What's Missing:**
- `token_budget_per_window` - Maximum tokens allowed per time window
- `window_duration_ms` - Duration of the budget window
- Wiring: `Manager.check_token_budget/3` only reads budgets from per-call opts (nil by default), and `State.record_usage/3` always uses a hard-coded 60s window. Even if defaults are added to `Config`, they do nothing until Manager/State consume them.

When `budget` is `nil`, `State.would_exceed_budget?/3` returns `false`, so **token budgeting is effectively disabled by default**.

### Google API Rate Limits

Google's Gemini API enforces tiered rate limits:

| Tier | RPM | TPM | RPD |
|------|-----|-----|-----|
| Free | 15 | 1,000,000 | 1,500 |
| Paid Tier 1 | 500 | 4,000,000 | 10,000 |
| Paid Tier 2 | 1,000 | 8,000,000 | 50,000 |

**Key Insight**: The Free tier's 15 RPM is very restrictive, but 1M TPM is generous. For paid tiers, both are higher.

## Decision

Add `token_budget_per_window` and `window_duration_ms` to the Config struct with sensible defaults, and plumb them through Manager/State so global config works without per-call overrides.

### Implementation

Update `lib/gemini/rate_limiter/config.ex`:

```elixir
defmodule Gemini.RateLimiter.Config do
  @type t :: %__MODULE__{
          max_concurrency_per_model: non_neg_integer() | nil,
          max_attempts: pos_integer(),
          base_backoff_ms: pos_integer(),
          jitter_factor: float(),
          non_blocking: boolean(),
          disable_rate_limiter: boolean(),
          adaptive_concurrency: boolean(),
          adaptive_ceiling: pos_integer(),
          profile: profile(),
          # NEW: Token budget settings
          token_budget_per_window: non_neg_integer() | nil,
          window_duration_ms: pos_integer()
        }

  defstruct max_concurrency_per_model: 4,
            max_attempts: 3,
            base_backoff_ms: 1000,
            jitter_factor: 0.25,
            non_blocking: false,
            disable_rate_limiter: false,
            adaptive_concurrency: false,
            adaptive_ceiling: 8,
            profile: :prod,
            # NEW: Conservative defaults for Free tier
            token_budget_per_window: 32_000,  # ~3% of Free tier's 1M TPM
            window_duration_ms: 60_000        # 1 minute window

  @profiles %{
    dev: %{
      max_concurrency_per_model: 2,
      max_attempts: 5,
      base_backoff_ms: 2000,
      adaptive_ceiling: 4,
      # Dev: More conservative budget
      token_budget_per_window: 16_000
    },
    prod: %{
      max_concurrency_per_model: 4,
      max_attempts: 3,
      base_backoff_ms: 1000,
      adaptive_ceiling: 8,
      # Prod: Higher budget, assumes paid tier
      token_budget_per_window: 500_000
    },
    # NEW: Explicit tier profiles
    free_tier: %{
      max_concurrency_per_model: 2,
      max_attempts: 5,
      base_backoff_ms: 2000,
      token_budget_per_window: 32_000  # Conservative for 15 RPM limit
    },
    paid_tier_1: %{
      max_concurrency_per_model: 8,
      max_attempts: 3,
      base_backoff_ms: 500,
      token_budget_per_window: 1_000_000  # 25% of 4M TPM
    },
    paid_tier_2: %{
      max_concurrency_per_model: 16,
      max_attempts: 3,
      base_backoff_ms: 500,
      token_budget_per_window: 2_000_000  # 25% of 8M TPM
    }
  }
end
```

### Why 32,000 Tokens Default?

The default of 32,000 tokens per minute is intentionally conservative:

1. **Free Tier Protection**: At 15 RPM, if each request averages 2,000 tokens, you'd use 30,000 tokens/minute
2. **Burst Buffer**: Leaves headroom for the occasional larger request
3. **Safe Fallback**: Better to under-utilize than hit 429s continuously
4. **Easy Override**: Users with paid tiers simply configure higher budgets

### Profile Selection

Users select profiles based on their Google Cloud tier:

```elixir
# In config/runtime.exs
config :gemini_ex, :rate_limiter,
  profile: :paid_tier_1  # Or :free_tier, :paid_tier_2
```

Or override directly:

```elixir
config :gemini_ex, :rate_limiter,
  token_budget_per_window: 1_000_000,  # Your tier's limit
  window_duration_ms: 60_000
```

## Consequences

### Positive

1. **Works Out of Box**: New users get reasonable defaults without configuration
2. **Tier Alignment**: Profiles match Google's actual tier structure
3. **Gradual Adoption**: Conservative default won't break existing apps
4. **Documentation Opportunity**: Profiles serve as documentation of tier limits

### Negative

1. **Default May Be Too Low**: Users with paid tiers need to configure higher budgets
2. **Profile Maintenance**: Google may change tier limits over time
3. **Breaking Change**: Apps relying on unlimited default may see new budget errors

### Migration Path

For existing users:

```elixir
# To restore previous unlimited behavior
config :gemini_ex, :rate_limiter,
  token_budget_per_window: nil  # Disables budget checking
```

## Alternatives Considered

### 1. No Default Budget (Current Behavior)
- **Rejected**: Makes token budgeting opt-in, reducing its effectiveness
- Users must understand and configure it explicitly

### 2. Very High Default (e.g., 10M tokens)
- **Rejected**: Effectively disables budgeting for most users
- Doesn't protect Free tier users

### 3. Auto-Detect Tier from API Key
- **Deferred**: Requires API call to determine tier
- Could be added as optional "adaptive" mode in future

### 4. Per-Model Budgets
- **Deferred**: Different models have different costs/limits
- Current implementation tracks per-model, but uses global budget
- Could be enhanced: `token_budget_per_model: %{"gemini-pro" => 500_000}`

## Manager/State Wiring

- In `Manager.check_token_budget/3`, prefer the budget from opts but fall back to `config.token_budget_per_window` so app config is honored.
- In `State.record_usage/3`, accept an optional `config` (or `window_duration_ms` argument) and pass it from Manager when recording usage, so the window length is actually configurable instead of fixed at 60s.

## Implementation Priority

**HIGH** - Works in tandem with ADR-0001 (Auto Token Estimation). Without defaults, users must configure both estimation AND budgets for protection.

## Related ADRs

- ADR-0001: Auto Token Estimation
- ADR-0003: Proper 429 Error Details Propagation
- ADR-0004: Recommended Configuration Pattern
