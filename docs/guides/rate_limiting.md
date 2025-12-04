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
```

## Profiles

The rate limiter supports configuration profiles:

### Development Profile (`:dev`)

Lower concurrency, longer backoff, ideal for testing:

```elixir
config :gemini_ex, :rate_limiter, profile: :dev

# Equivalent to:
# max_concurrency_per_model: 2
# max_attempts: 5
# base_backoff_ms: 2000
# adaptive_ceiling: 4
```

### Production Profile (`:prod`)

Higher concurrency, optimized for throughput (default):

```elixir
config :gemini_ex, :rate_limiter, profile: :prod

# Equivalent to:
# max_concurrency_per_model: 4
# max_attempts: 3
# base_backoff_ms: 1000
# adaptive_ceiling: 8
```

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

You can set token budgets to preemptively avoid rate limits:

```elixir
# Estimate input tokens and set a budget
opts = [
  estimated_input_tokens: 100,
  token_budget_per_window: 10_000
]

case Gemini.generate("Hello", opts) do
  {:ok, response} ->
    # Success

  {:error, {:rate_limited, _, %{reason: :over_budget}}} ->
    # Would exceed budget, wait for window to reset
end
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
