# ADR 0004: Recommended Configuration Pattern

- Status: Proposed
- Date: 2025-12-04

## Context

The existing rate limiter architecture in `gemini_ex` is sophisticated and well-designed:

- **ETS-based State** (`state.ex`): Cross-process visibility for retry windows and token usage
- **Concurrency Gating** (`concurrency_gate.ex`): Semaphore-based request limiting
- **Retry Management** (`retry_manager.ex`): Exponential backoff with jitter and 429 handling
- **Adaptive Mode**: Dynamic concurrency adjustment based on server responses

However, **users don't know how to configure it** for their specific tier and use case. The library should provide clear guidance on optimal configuration patterns.

### Current Configuration Interface

Configuration is done via application environment:

```elixir
config :gemini_ex, :rate_limiter,
  max_concurrency_per_model: 4,
  max_attempts: 3,
  base_backoff_ms: 1000,
  profile: :prod
```

Or per-request:

```elixir
Gemini.generate("Hello", [
  max_concurrency_per_model: 8,
  token_budget_per_window: 1_000_000
])
```

**The Problem**: Users don't know what values to use. Google's tier limits are documented but mapping them to configuration is non-obvious. Also, the current `Config` only recognizes `:dev | :prod | :custom`, so any new profile names (e.g., `:free_tier`) will be ignored until `Config.profile` and `@profiles` are expanded.

## Decision

Establish and document recommended configuration patterns for common use cases.

### Recommended Configurations

#### Free Tier (Development)

```elixir
# config/runtime.exs
config :gemini_ex, :rate_limiter,
  # Concurrency: Low to stay under 15 RPM
  max_concurrency_per_model: 2,

  # Token Budget: Conservative (~3% of 1M TPM)
  token_budget_per_window: 32_000,

  # Retries: More attempts with longer backoff for development
  max_attempts: 5,
  base_backoff_ms: 2000,

  # Mode: Let it back off gracefully
  adaptive_concurrency: true,
  adaptive_ceiling: 4,

  # Profile shortcut (alternative to explicit settings)
  profile: :free_tier
```

**Rationale:**
- 15 RPM means at most 0.25 requests/second
- With 2 concurrent slots, burst capacity is limited
- Token budget of 32K allows ~15 requests of ~2K tokens each
- Generous retries help with quota exhaustion

#### Paid Tier 1 (Production - Standard)

```elixir
config :gemini_ex, :rate_limiter,
  # Concurrency: Higher for 500 RPM
  max_concurrency_per_model: 10,

  # Token Budget: 25% of 4M TPM for safety margin
  token_budget_per_window: 1_000_000,

  # Retries: Faster recovery for production
  max_attempts: 3,
  base_backoff_ms: 500,

  # Mode: Start conservative, adapt upward
  adaptive_concurrency: true,
  adaptive_ceiling: 15,

  profile: :paid_tier_1
```

**Rationale:**
- 500 RPM allows ~8 requests/second
- 10 concurrent slots with adaptive mode can scale to 15
- 1M token budget is conservative but avoids all 429s
- Faster backoff for better latency

#### Paid Tier 2 (Production - High Throughput)

```elixir
config :gemini_ex, :rate_limiter,
  # Concurrency: Aggressive for 1000 RPM
  max_concurrency_per_model: 20,

  # Token Budget: 25% of 8M TPM
  token_budget_per_window: 2_000_000,

  # Retries: Minimal for high throughput
  max_attempts: 2,
  base_backoff_ms: 250,

  # Mode: High ceiling for adaptive scaling
  adaptive_concurrency: true,
  adaptive_ceiling: 30,

  profile: :paid_tier_2
```

#### Batch Processing (Background Jobs)

```elixir
config :gemini_ex, :rate_limiter,
  # Concurrency: Limited to leave headroom for interactive requests
  max_concurrency_per_model: 3,

  # Token Budget: Use more of the budget (batch can tolerate delays)
  token_budget_per_window: 800_000,

  # Retries: More patient for background work
  max_attempts: 5,
  base_backoff_ms: 5000,

  # Mode: Non-blocking returns immediately if rate limited
  non_blocking: false,  # Block and wait for batch processing

  profile: :custom
```

#### Real-Time Applications (Chat/Streaming)

```elixir
config :gemini_ex, :rate_limiter,
  # Concurrency: Higher for responsiveness
  max_concurrency_per_model: 15,

  # Token Budget: Leave headroom for bursts
  token_budget_per_window: 500_000,

  # Retries: Minimal - fail fast for UX
  max_attempts: 2,
  base_backoff_ms: 100,

  # Mode: Non-blocking for immediate feedback
  non_blocking: true,

  profile: :custom
```

### Configuration by Model

Different models may have different limits. Support per-model configuration:

```elixir
config :gemini_ex, :rate_limiter,
  # Global defaults
  max_concurrency_per_model: 4,
  token_budget_per_window: 500_000,

  # Per-model overrides
  model_overrides: %{
    "gemini-1.5-pro" => %{
      max_concurrency_per_model: 3,
      token_budget_per_window: 1_000_000
    },
    "gemini-1.5-flash" => %{
      max_concurrency_per_model: 10,
      token_budget_per_window: 2_000_000
    }
  }
```

### Dynamic Configuration

Not implemented today. If runtime changes are needed, add a small API (e.g., `Config.update/1`) that safely refreshes ETS-backed state or rebuilds config for new calls. Until then, these examples are aspirational.

## Implementation

### Profile Enumeration and Wiring

The current code only supports `:dev | :prod | :custom`. To make these recommendations actionable:
- Expand the `Config.profile` type to include `:free_tier`, `:paid_tier_1`, `:paid_tier_2`, and any other recommended profiles.
- Add those profiles to `@profiles` in `config.ex` with the values below.
- Keep precedence order in `Config.build/1` (defaults → profile → app config → overrides).
- Ensure `token_budget_per_window` defaults exist per ADR-0002 so the budgets below are honored.

Then populate `@profiles`:

```elixir
@profiles %{
  # Development
  dev: %{
    max_concurrency_per_model: 2,
    max_attempts: 5,
    base_backoff_ms: 2000,
    token_budget_per_window: 16_000,
    adaptive_concurrency: false
  },

  # Free tier
  free_tier: %{
    max_concurrency_per_model: 2,
    max_attempts: 5,
    base_backoff_ms: 2000,
    token_budget_per_window: 32_000,
    adaptive_concurrency: true,
    adaptive_ceiling: 4
  },

  # Paid Tier 1
  paid_tier_1: %{
    max_concurrency_per_model: 10,
    max_attempts: 3,
    base_backoff_ms: 500,
    token_budget_per_window: 1_000_000,
    adaptive_concurrency: true,
    adaptive_ceiling: 15
  },

  # Paid Tier 2
  paid_tier_2: %{
    max_concurrency_per_model: 20,
    max_attempts: 2,
    base_backoff_ms: 250,
    token_budget_per_window: 2_000_000,
    adaptive_concurrency: true,
    adaptive_ceiling: 30
  },

  # Production default
  prod: %{
    max_concurrency_per_model: 4,
    max_attempts: 3,
    base_backoff_ms: 1000,
    token_budget_per_window: 500_000,
    adaptive_concurrency: false
  },

  # Custom - uses only explicit settings
  custom: %{}
}
```

### Documentation Update

Add to `docs/guides/rate_limiting.md`:

```markdown
## Quick Start

Choose a profile matching your Google Cloud tier:

| Profile | Best For | RPM | TPM |
|---------|----------|-----|-----|
| `:free_tier` | Development, testing | 15 | 1M |
| `:paid_tier_1` | Standard production | 500 | 4M |
| `:paid_tier_2` | High throughput | 1000 | 8M |

\```elixir
config :gemini_ex, :rate_limiter, profile: :paid_tier_1
\```

## Fine-Tuning

### Concurrency vs Token Budget

- **Concurrency** limits parallel requests (affects RPM)
- **Token Budget** limits total tokens per window (affects TPM)

For most applications, start with a profile and adjust:
- Seeing 429s? Lower both concurrency and budget
- Underutilizing quota? Raise budget, enable adaptive concurrency
```

## Consequences

### Positive

1. **Easy Onboarding**: Users pick a profile and it just works
2. **Best Practices**: Profiles encode knowledge about Google's limits
3. **Flexibility**: Per-model and runtime configuration for advanced use
4. **Documentation**: Profiles serve as executable documentation

### Negative

1. **Maintenance Burden**: Profiles must be updated if Google changes limits
2. **Complexity**: More profiles = more choices for users
3. **Assumptions**: Profiles assume typical usage patterns

### Mitigations

- Document when profiles were last updated
- Provide `:custom` profile for users who need full control
- Telemetry to detect when configuration is suboptimal

## Migration Guide

For existing users:

```elixir
# Before (implicit unlimited)
config :gemini_ex, :rate_limiter, []

# After (explicit tier selection)
config :gemini_ex, :rate_limiter, profile: :paid_tier_1

# Or restore previous behavior
config :gemini_ex, :rate_limiter,
  token_budget_per_window: nil,  # Disable budget checking
  disable_rate_limiter: false    # Keep concurrency gating
```

## Implementation Priority

**HIGH** - This is the user-facing documentation that makes ADR-0001 and ADR-0002 usable. Without clear guidance, users won't know how to configure the rate limiter effectively.

## Related ADRs

- ADR-0001: Auto Token Estimation
- ADR-0002: Token Budget Configuration Defaults
- ADR-0003: Proper 429 Error Details Propagation
