# ADR 0001: Automatic Token Estimation for Proactive Rate Limiting

- Status: Proposed
- Date: 2025-12-04

## Context

The current `Gemini.RateLimiter.Manager` implements token budget checking in `check_token_budget/3`, but this logic is **passive** rather than proactive:

```elixir
# Current implementation in manager.ex:298-306
defp check_token_budget(state_key, opts, _config) do
  estimated_tokens = Keyword.get(opts, :estimated_input_tokens, 0)  # Defaults to 0!
  budget = Keyword.get(opts, :token_budget_per_window)

  if State.would_exceed_budget?(state_key, estimated_tokens, budget) do
    :over_budget
  else
    :ok
  end
end
```

**The Problem:**
- If callers don't pass `:estimated_input_tokens`, the manager defaults to `0`
- With an estimate of 0 tokens, requests always pass the budget check
- Heavy requests proceed to Google's API, hit the TPM limit, and receive 429s
- Token usage is only recorded *after* the response, not prevented proactively

**Existing Capability:**
The library already has `Gemini.APIs.Tokens.estimate/2` which provides heuristic-based token estimation:

```elixir
# From lib/gemini/apis/tokens.ex:233-239
@spec estimate(String.t() | [Content.t()], keyword()) :: {:ok, integer()} | {:error, Error.t()}
def estimate(content, _opts \\ []) do
  try do
    estimated_tokens = estimate_tokens_heuristic(content)
    {:ok, estimated_tokens}
  rescue
    error -> {:error, Error.validation_error("Failed to estimate tokens: #{inspect(error)}")}
  end
end
```

This estimation uses:
- Word-based estimate: `word_count * 1.3`
- Character-based estimate: `char_count / 4.0`
- Takes the maximum of both for safety

## Decision

Integrate `Gemini.APIs.Tokens.estimate/2` directly into `check_token_budget/3` to enable **proactive** token budget enforcement without requiring explicit caller input.

### Implementation

Modify `lib/gemini/rate_limiter/manager.ex`:

```elixir
defp check_token_budget(state_key, opts, config) do
  # Priority order for token estimation:
  # 1. Explicit estimate from opts (caller knows best)
  # 2. Heuristic estimate from request contents
  # 3. Default to 0 only if neither available
  estimated_tokens =
    Keyword.get(opts, :estimated_input_tokens) ||
    estimate_from_contents(opts) ||
    0

  budget = Keyword.get(opts, :token_budget_per_window, config.token_budget_per_window)

  if State.would_exceed_budget?(state_key, estimated_tokens, budget) do
    :over_budget
  else
    :ok
  end
end

@spec estimate_from_contents(keyword()) :: non_neg_integer() | nil
defp estimate_from_contents(opts) do
  case Keyword.get(opts, :contents) do
    nil ->
      nil

    contents ->
      case Gemini.APIs.Tokens.estimate(contents) do
        {:ok, count} -> count
        {:error, _} -> nil
      end
  end
end
```

### Content Propagation

For the estimation to work, request contents must be available in the options passed to the rate limiter. This requires updating the call chain in `lib/gemini/client/http.ex`:

```elixir
# In request/5, extract and pass contents to rate limiter
def request(method, path, body, auth_config, opts \\ []) do
  # ... existing code ...

  # Extract contents from body for rate limiter estimation
  rate_limiter_opts =
    opts
    |> Keyword.put_new(:contents, extract_contents_from_body(body))

  RateLimiter.execute_with_usage_tracking(request_fn, model, rate_limiter_opts)
end

defp extract_contents_from_body(%{"contents" => contents}), do: contents
defp extract_contents_from_body(%{contents: contents}), do: contents
defp extract_contents_from_body(_), do: nil
```

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
