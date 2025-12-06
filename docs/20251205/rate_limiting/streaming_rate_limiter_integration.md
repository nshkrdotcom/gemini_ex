# Streaming Rate Limiter Integration

## Context

This is a follow-up to `gemini_rate_limiting_and_model_aliases.md`. After implementing the rate limiter hardening (atomic budget reservation, ConcurrencyGate race fix, retry-window gating), **streaming requests still bypass all rate limiting**.

## Problem Statement

The streaming path via `UnifiedManager.start_stream()` does not go through the rate limiter at all. This means:

- `max_concurrency_per_model: 1` has no effect on streaming requests
- Atomic budget reservation is never invoked
- Multiple concurrent streaming requests can fire simultaneously, causing 429s
- All the hardening work in 0.7.1 only applies to non-streaming `HTTP.post()` calls

## Current Architecture

### Non-Streaming Path (Rate Limited) ✓

```
Gemini.generate()
  └─> Coordinator.generate_content()
       └─> HTTP.post()
            └─> RateLimiter.execute_with_usage_tracking()  ✓
                 └─> ConcurrencyGate.acquire()
                 └─> State.try_reserve_budget()
                 └─> execute request
                 └─> State.reconcile_reservation()
                 └─> ConcurrencyGate.release()
```

### Streaming Path (Bypasses Rate Limiter) ✗

```
Gemini.start_stream()
  └─> Coordinator.stream_generate_content()
       └─> UnifiedManager.start_stream()
            └─> MultiAuthCoordinator.coordinate_auth()
            └─> HTTPStreaming.stream_to_process()  ✗ NO RATE LIMITER
                 └─> spawn() → stream_sse() → Req.request()
```

## Root Cause Analysis

### UnifiedManager.start_stream_process/1 (lines 550-574)

```elixir
defp start_stream_process(stream_state) do
  case MultiAuthCoordinator.coordinate_auth(...) do
    {:ok, auth_strategy, headers} ->
      case get_streaming_url_and_headers(...) do
        {:ok, url, final_headers} ->
          # PROBLEM: Directly calls HTTPStreaming without rate limiter
          HTTPStreaming.stream_to_process(
            url,
            final_headers,
            stream_state.request_body,
            stream_state.stream_id,
            self()
          )
```

### HTTPStreaming.stream_to_process/6 (lines 147-166)

```elixir
def stream_to_process(url, headers, body, stream_id, target_pid, opts \\ []) do
  callback = fn event -> send(target_pid, {:stream_event, stream_id, event}) end

  # PROBLEM: Spawns directly, no rate limiter gate
  stream_pid = spawn(fn ->
    case stream_sse(url, headers, body, callback, opts) do
      {:ok, :completed} -> send(target_pid, {:stream_complete, stream_id})
      {:error, error} -> send(target_pid, {:stream_error, stream_id, error})
    end
  end)

  {:ok, stream_pid}
end
```

## Proposed Solution

### Option A: Gate at UnifiedManager Level (Recommended)

Wrap the streaming request initiation with rate limiter calls in `UnifiedManager.start_stream_process/1`:

```elixir
defp start_stream_process(stream_state) do
  model = stream_state.model
  opts = stream_state.config

  # Use RateLimiter to gate the stream start
  request_fn = fn ->
    case MultiAuthCoordinator.coordinate_auth(...) do
      {:ok, auth_strategy, headers} ->
        case get_streaming_url_and_headers(...) do
          {:ok, url, final_headers} ->
            HTTPStreaming.stream_to_process(...)
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  # Gate through rate limiter
  case RateLimiter.execute(request_fn, model, opts) do
    {:ok, {:ok, stream_pid}} -> {:ok, stream_pid}
    {:ok, {:error, reason}} -> {:error, reason}
    {:error, rate_limit_error} -> {:error, rate_limit_error}
  end
end
```

**Considerations:**
- Concurrency permit is acquired when stream starts
- Permit must be released when stream completes/errors
- Need to track stream_id → permit association for cleanup

### Option B: Gate at HTTPStreaming Level

Add rate limiter integration directly in `HTTPStreaming.stream_to_process/6`:

```elixir
def stream_to_process(url, headers, body, stream_id, target_pid, opts \\ []) do
  model = Keyword.get(opts, :model, "unknown")

  request_fn = fn ->
    callback = fn event -> send(target_pid, {:stream_event, stream_id, event}) end
    stream_sse(url, headers, body, callback, opts)
  end

  # Wrap in rate limiter
  stream_pid = spawn(fn ->
    case RateLimiter.execute(request_fn, model, opts) do
      {:ok, {:ok, :completed}} -> send(target_pid, {:stream_complete, stream_id})
      {:ok, {:error, error}} -> send(target_pid, {:stream_error, stream_id, error})
      {:error, {:rate_limited, _, _} = error} -> send(target_pid, {:stream_error, stream_id, error})
    end
  end)

  {:ok, stream_pid}
end
```

**Considerations:**
- Simpler change, isolated to one module
- But HTTPStreaming doesn't have model context readily available
- Permit held for entire stream duration (which is correct for concurrency limiting)

### Option C: New Streaming-Specific Rate Limiter Entry Point

Create `RateLimiter.execute_streaming/3` that:
1. Acquires permit before stream starts
2. Returns a release function to be called on stream completion
3. Tracks long-running streams separately from request/response cycles

```elixir
# In RateLimiter
def execute_streaming(model, opts) do
  config = Config.build(opts)

  case reserve_and_acquire(model, config, opts) do
    {:ok, permit_ref} ->
      # Return a release function for the caller to invoke on completion
      release_fn = fn result ->
        release_permit(model, permit_ref)
        reconcile_usage(model, result, opts)
      end
      {:ok, release_fn}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Usage in UnifiedManager:**
```elixir
case RateLimiter.execute_streaming(model, opts) do
  {:ok, release_fn} ->
    case do_start_stream(...) do
      {:ok, stream_pid} ->
        # Store release_fn to call on stream completion
        {:ok, stream_pid, release_fn}
      {:error, reason} ->
        release_fn.(nil)  # Release permit on failure
        {:error, reason}
    end

  {:error, {:rate_limited, _, _} = error} ->
    {:error, error}
end
```

## Implementation Plan

### Phase 1: Basic Integration (Option A)

1. Add `RateLimiter` alias to `UnifiedManager`
2. Wrap `start_stream_process/1` with rate limiter gate
3. Store permit reference in stream state
4. Release permit in `handle_info({:stream_complete, ...})` and `handle_info({:stream_error, ...})`
5. Release permit in `stop_stream_process/1`

### Phase 2: Usage Tracking

1. Extract token usage from final streaming response (usageMetadata)
2. Call `State.reconcile_reservation/4` on stream completion
3. Emit telemetry for streaming budget usage

### Phase 3: Token Estimation for Streaming

Streaming presents a challenge: we don't know output tokens upfront.

Options:
- Reserve only estimated input tokens; reconcile with actual after completion
- Reserve a configurable buffer for expected output (e.g., `estimated_input + 2000`)
- Skip output reservation for streaming; only gate on concurrency

Recommendation: Reserve estimated input tokens only; reconcile actual usage after stream completes.

## Testing Requirements

### Unit Tests

1. **Concurrent streaming respects max_concurrency_per_model=1**
   - Start 5 streams simultaneously with max=1
   - Verify only 1 stream active at a time
   - Verify others queued or rejected (depending on non_blocking setting)

2. **Streaming respects budget reservation**
   - Set token_budget_per_window low
   - Start stream with high estimated_input_tokens
   - Verify rate_limited error returned

3. **Permit released on stream completion**
   - Start stream with max=1
   - Complete stream
   - Verify second stream can start immediately

4. **Permit released on stream error**
   - Start stream with max=1
   - Force stream error
   - Verify permit released

5. **Permit released on manual stop**
   - Start stream with max=1
   - Call stop_stream()
   - Verify permit released

### Integration Tests

1. **Mixed streaming and non-streaming requests**
   - Interleave streaming and regular requests
   - Verify total concurrency respects limit

2. **Long-running streams don't starve other requests**
   - Start long stream
   - Verify other requests can proceed (if concurrency allows)

## Telemetry Events

Add streaming-specific events:

- `[:gemini, :rate_limit, :stream, :started]` - Stream acquired permit
- `[:gemini, :rate_limit, :stream, :completed]` - Stream released permit normally
- `[:gemini, :rate_limit, :stream, :error]` - Stream released permit on error
- `[:gemini, :rate_limit, :stream, :stopped]` - Stream released permit on manual stop

## Migration Notes

- This is a behavioral change: streaming will now block/queue when rate limited
- Existing code using streaming with high concurrency may see different behavior
- Document in CHANGELOG as a **breaking change** if streams can now return `{:error, {:rate_limited, ...}}`

## Version

Target: 0.7.2 (after 0.7.1 rate limiter hardening)

## Files to Modify

1. `lib/gemini/streaming/unified_manager.ex`
   - Add RateLimiter integration in `start_stream_process/1`
   - Track permit references in stream state
   - Release permits on completion/error/stop

2. `lib/gemini/rate_limiter/manager.ex` (optional)
   - Add `execute_streaming/3` if Option C chosen

3. `test/gemini/streaming/unified_manager_test.exs`
   - Add concurrent streaming tests
   - Add rate limit rejection tests

4. `docs/guides/rate_limiting.md`
   - Document streaming rate limiting behavior

## Open Questions

1. Should streaming hold the permit for the entire duration, or acquire/release per-chunk?
   - Recommendation: Hold for entire duration (simpler, prevents interleaving issues)

2. How to handle `auto_execute_tools: true` streams that may make multiple API calls?
   - Each tool call iteration should go through rate limiter separately
   - ToolOrchestrator needs similar integration

3. Should we add a separate `max_concurrent_streams` config independent of `max_concurrency_per_model`?
   - Could be useful for workloads that mix streaming and non-streaming
   - Recommendation: Defer to future version; use shared limit initially
