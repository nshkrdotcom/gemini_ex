# Rate Limiting Guide

GeminiEx includes an **automatic rate limiting system** that is **enabled by default**. This system helps you stay within Gemini API quotas and handles rate limit errors gracefully.

## Overview

The rate limiter provides:

- **Automatic rate limit enforcement** - Waits when rate limited (429 responses)
- **Concurrency gating** - Limits concurrent requests per model (default: 4)
- **Token budgeting** - Tracks usage to preemptively avoid rate limits
- **Adaptive mode** - Optionally adjusts concurrency based on 429 responses
- **Structured errors** - Returns `{:error, {:rate_limited, retry_at, details}}`
- **Telemetry events** - Observable rate limit wait/error events

## Default Behavior

When you make requests through the Gemini API, they automatically:

1. Check against the current retry window (from previous 429s)
2. Get gated by concurrency permits (default 4 per model)
3. Optionally get checked against token budget
4. Retry with backoff on transient failures

```elixir
# Rate limiting is automatic - no changes needed!
{:ok, response} = Gemini.generate("Hello")

# This works even under heavy load
results = 1..100
  |> Task.async_stream(fn _ -> Gemini.generate("Hello") end)
  |> Enum.to_list()
```

## Configuration

### Application Config

Configure globally via application environment:

```elixir
config :gemini_ex, :rate_limiter,
  max_concurrency_per_model: 4,    # nil or 0 disables concurrency gating
  permit_timeout_ms: :infinity,     # default: no cap on queue wait; set a number to cap
  max_attempts: 3,                  # Retry attempts for transient errors
  base_backoff_ms: 1000,           # Base backoff duration
  jitter_factor: 0.25,             # Jitter range (±25%)
  adaptive_concurrency: false,      # Enable adaptive mode
  adaptive_ceiling: 8,              # Max concurrency in adaptive mode
  profile: :prod                    # :dev, :prod, or :custom
```

### Per-Request Options

Override behavior on individual requests:

```elixir
# Bypass rate limiting entirely
{:ok, response} = Gemini.generate("Hello", disable_rate_limiter: true)

# Return immediately if rate limited
case Gemini.generate("Hello", non_blocking: true) do
  {:ok, response} ->
    handle_response(response)

  {:error, {:rate_limited, retry_at, details}} ->
    # Schedule retry for later
    schedule_retry(retry_at)
end

# Override concurrency limit
{:ok, response} = Gemini.generate("Hello", max_concurrency_per_model: 8)

# Override permit wait timeout (defaults to :infinity)
{:ok, response} = Gemini.generate("Hello", permit_timeout_ms: 600_000)

# Partition the concurrency gate (e.g., by tenant/location)
{:ok, response} = Gemini.generate("Hello", concurrency_key: "tenant_a")

# Fail fast instead of waiting
{:error, {:rate_limited, nil, %{reason: :no_permit_available}}} =
  Gemini.generate("Hello", non_blocking: true)
```

## Quick Start

Choose a profile matching your Google Cloud tier:

| Profile | Best For | RPM | TPM | Token Budget |
|---------|----------|-----|-----|--------------|
| `:free_tier` | Development, testing | 15 | 1M | 32,000 |
| `:paid_tier_1` | Standard production | 500 | 4M | 1,000,000 |
| `:paid_tier_2` | High throughput | 1000 | 8M | 2,000,000 |

```elixir
# Select your tier
config :gemini_ex, :rate_limiter, profile: :paid_tier_1
```

> **Default behavior:** If you don’t choose a profile, `:prod` is used (`token_budget_per_window: 500_000`, `window_duration_ms: 60_000`). The base fallback defaults are 32,000/60s and are used by `:custom` unless overridden. Set `token_budget_per_window: nil` if you need the pre-0.6.1 “unlimited” budgeting behavior.

## Profiles

The rate limiter supports tier-based configuration profiles that automatically set
appropriate limits for your Google Cloud plan.

### Tier Profiles

#### Free Tier (`:free_tier`)

Conservative settings for Google's free tier (15 RPM / 1M TPM):

```elixir
config :gemini_ex, :rate_limiter, profile: :free_tier

# Equivalent to:
# max_concurrency_per_model: 2
# max_attempts: 5
# base_backoff_ms: 2000
# token_budget_per_window: 32_000
# adaptive_concurrency: true
# adaptive_ceiling: 4
```

#### Paid Tier 1 (`:paid_tier_1`)

Standard production settings for Tier 1 plans (500 RPM / 4M TPM):

```elixir
config :gemini_ex, :rate_limiter, profile: :paid_tier_1

# Equivalent to:
# max_concurrency_per_model: 10
# max_attempts: 3
# base_backoff_ms: 500
# token_budget_per_window: 1_000_000
# adaptive_concurrency: true
# adaptive_ceiling: 15
```

#### Paid Tier 2 (`:paid_tier_2`)

High throughput settings for Tier 2 plans (1000 RPM / 8M TPM):

```elixir
config :gemini_ex, :rate_limiter, profile: :paid_tier_2

# Equivalent to:
# max_concurrency_per_model: 20
# max_attempts: 2
# base_backoff_ms: 250
# token_budget_per_window: 2_000_000
# adaptive_concurrency: true
# adaptive_ceiling: 30
```

### Legacy Profiles

#### Development Profile (`:dev`)

Lower concurrency, longer backoff, ideal for local development:

```elixir
config :gemini_ex, :rate_limiter, profile: :dev

# Equivalent to:
# max_concurrency_per_model: 2
# max_attempts: 5
# base_backoff_ms: 2000
# token_budget_per_window: 16_000
# adaptive_ceiling: 4
```

#### Production Profile (`:prod`)

Balanced settings for typical production usage (default):

```elixir
config :gemini_ex, :rate_limiter, profile: :prod

# Equivalent to:
# max_concurrency_per_model: 4
# max_attempts: 3
# base_backoff_ms: 1000
# token_budget_per_window: 500_000
# adaptive_ceiling: 8
```

## Fine-Tuning

### Concurrency vs Token Budget

- **Concurrency** limits parallel requests (affects RPM)
- **Token Budget** limits total tokens per window (affects TPM)

For most applications, start with a profile and adjust:
- Seeing 429s? Lower both concurrency and budget
- Underutilizing quota? Raise budget, enable adaptive concurrency

### Concurrency semantics

The concurrency gate is per model by default (all callers to the same model share a queue). Use `concurrency_key:` to partition by tenant/location. `permit_timeout_ms` defaults to `:infinity`; a waiter only errors if you explicitly set a finite cap and it expires. Use `non_blocking: true` to fail fast instead of queueing.
## Structured Errors

Rate limit errors include retry information:

```elixir
case Gemini.generate("Hello") do
  {:ok, response} ->
    # Handle success

  {:error, {:rate_limited, retry_at, details}} ->
    # retry_at is a DateTime when you can retry
    # details contains quota information
    IO.puts("Rate limited until #{retry_at}")
    IO.puts("Quota: #{details.quota_metric}")

  {:error, {:transient_failure, attempts, original_error}} ->
    # Transient error after max retry attempts
    IO.puts("Failed after #{attempts} attempts")

  {:error, reason} ->
    # Other errors
    IO.puts("Error: #{inspect(reason)}")
end
```

## Non-Blocking Mode

For applications that need to handle rate limits without waiting:

```elixir
defmodule MyApp.GeminiWorker do
  def generate_with_queue(prompt) do
    case Gemini.generate(prompt, non_blocking: true) do
      {:ok, response} ->
        {:ok, response}

      {:error, {:rate_limited, retry_at, _details}} ->
        # Queue for later
        schedule_retry(prompt, retry_at)
        {:queued, retry_at}
    end
  end

  defp schedule_retry(prompt, retry_at) do
    delay_ms = DateTime.diff(retry_at, DateTime.utc_now(), :millisecond)
    Process.send_after(self(), {:retry, prompt}, max(0, delay_ms))
  end
end
```

## Adaptive Concurrency Mode

Adaptive mode starts with lower concurrency and adjusts based on API responses:

```elixir
config :gemini_ex, :rate_limiter,
  adaptive_concurrency: true,
  adaptive_ceiling: 8  # Maximum concurrency to reach
```

In adaptive mode:
- Starts at the configured `max_concurrency_per_model`
- Increases by 1 on each success (up to `adaptive_ceiling`)
- Decreases by 25% on each 429 response

This is useful when you're unsure of your quota limits.

## Token Budgeting

Token budgeting helps you stay within TPM (tokens per minute) limits by tracking
token usage and preemptively blocking requests that would exceed your budget.

### Automatic Token Estimation

By default, the rate limiter automatically estimates input tokens for each request
before it's sent. This estimation happens on the original input (string or Content list)
and is used for proactive budget checking.

```elixir
# Token estimation happens automatically - no code changes needed!
{:ok, response} = Gemini.generate("Hello world")

# The estimated tokens are passed to the rate limiter internally
# If the estimate would exceed your budget, the request is blocked locally
```

### Default Token Budgets

Each profile includes a default token budget:

- `:free_tier` - 32,000 tokens per minute (~3% of 1M TPM)
- `:paid_tier_1` - 1,000,000 tokens per minute (25% of 4M TPM)
- `:paid_tier_2` - 2,000,000 tokens per minute (25% of 8M TPM)
- `:prod` - 500,000 tokens per minute
- `:dev` - 16,000 tokens per minute

### Cached context tokens

Cached contexts still consume tokens (returned as `cachedContentTokenCount` in responses) and are counted toward the budget. The rate limiter records these tokens automatically on success. If you pre-compute cache size and want proactive blocking before first use, supply both:

```elixir
Gemini.generate("Run on cached context",
  cached_content: cache_name,
  estimated_input_tokens: 200,      # prompt size
  estimated_cached_tokens: 50_000,  # precomputed cache size
  token_budget_per_window: 1_000_000
)
```

### Over-budget behavior

- **Request too large**: If `estimated_input_tokens + estimated_cached_tokens > token_budget_per_window`, the limiter returns `{:error, {:rate_limited, nil, %{reason: :over_budget, request_too_large: true}}}` immediately (no retries).
- **Window full**: If the current window is full but the request fits the budget, blocking mode waits until the window ends once, then retries; non-blocking mode returns `retry_at` set to that window end.

### Limiting wait time

Blocking calls can cap their wait with `max_budget_wait_ms` (default: `nil` = no cap). If the cap is reached and the window is still full, the limiter returns `{:error, {:rate_limited, retry_at, details}}` where `retry_at` is the actual window end:

```elixir
Gemini.generate("...", [
  token_budget_per_window: 500_000,
  estimated_input_tokens: 20_000,
  max_budget_wait_ms: 5_000  # block at most 5 seconds on budget waits
])
```

### Manual Token Estimation

You can override the automatic estimate if you have a more accurate count:

```elixir
# Use your own token estimate (e.g., from countTokens API)
{:ok, token_count} = Gemini.count_tokens("Your long prompt here...")

opts = [
  estimated_input_tokens: token_count.total_tokens,
  token_budget_per_window: 500_000
]

case Gemini.generate("Your long prompt here...", opts) do
  {:ok, response} ->
    # Success

  {:error, {:rate_limited, _, %{reason: :over_budget}}} ->
    # Would exceed budget, wait for window to reset
end
```

### Disabling Token Budgeting

To disable token budget checking:

```elixir
# Disable for a single request
{:ok, response} = Gemini.generate("Hello", token_budget_per_window: nil)

# Disable globally
config :gemini_ex, :rate_limiter,
  token_budget_per_window: nil
```

## Telemetry Events

The rate limiter emits telemetry events for monitoring:

```elixir
:telemetry.attach_many(
  "rate-limit-monitor",
  [
    [:gemini, :rate_limit, :request, :start],
    [:gemini, :rate_limit, :request, :stop],
    [:gemini, :rate_limit, :wait],
    [:gemini, :rate_limit, :error]
  ],
  fn event, measurements, metadata, _config ->
    IO.puts("Event: #{inspect(event)}")
    IO.puts("Model: #{metadata.model}")
    IO.puts("Duration: #{measurements[:duration]}ms")
  end,
  nil
)
```

### Available Events

| Event | Description |
|-------|-------------|
| `[:gemini, :rate_limit, :request, :start]` | Request submitted to rate limiter |
| `[:gemini, :rate_limit, :request, :stop]` | Request completed |
| `[:gemini, :rate_limit, :wait]` | Waiting for retry window |
| `[:gemini, :rate_limit, :error]` | Rate limit error occurred |

## Checking Status

You can check rate limit status before making requests:

```elixir
case Gemini.RateLimiter.check_status("gemini-flash-lite-latest") do
  :ok ->
    IO.puts("Ready to make requests")

  {:rate_limited, retry_at, details} ->
    IO.puts("Rate limited until #{retry_at}")

  {:over_budget, usage} ->
    IO.puts("Over token budget: #{inspect(usage)}")

  {:no_permits, 0} ->
    IO.puts("No concurrency permits available")
end
```

## Disabling Rate Limiting

While not recommended, you can disable rate limiting:

```elixir
# Per-request
{:ok, response} = Gemini.generate("Hello", disable_rate_limiter: true)

# Globally (not recommended)
config :gemini_ex, :rate_limiter, disable_rate_limiter: true
```

## Best Practices

1. **Use default settings in production** - They're tuned for typical usage patterns
2. **Use adaptive mode when unsure of quotas** - It will find the right concurrency
3. **Handle rate limit errors gracefully** - Use `non_blocking: true` with queuing for high-throughput apps
4. **Monitor telemetry events** - Track rate limit events to optimize your usage
5. **Set token budgets for predictable costs** - Prevents unexpected overages
6. **Use the `:dev` profile during development** - Lower concurrency helps avoid rate limits while testing

## Streaming

The rate limiter only gates request submission. Once a stream is opened, it is not interrupted. This ensures streaming responses complete even if you hit rate limits during the stream.

```elixir
# Rate limiter gates this initial request
{:ok, stream} = Gemini.stream_generate("Tell me a long story")

# Once streaming starts, it continues uninterrupted
Enum.each(stream, fn chunk ->
  IO.write(chunk.text)
end)
```
