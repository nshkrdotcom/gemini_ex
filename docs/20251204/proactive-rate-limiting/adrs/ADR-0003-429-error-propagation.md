# ADR 0003: Proper 429 Error Details Propagation

- Status: Proposed
- Date: 2025-12-04

## Context

When Google's Gemini API returns a 429 (Too Many Requests) error, the response includes structured quota information and retry hints in the `details` array:

```json
{
  "error": {
    "code": 429,
    "message": "Resource has been exhausted (e.g. check quota).",
    "status": "RESOURCE_EXHAUSTED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.RetryInfo",
        "retryDelay": "60s"
      },
      {
        "@type": "type.googleapis.com/google.rpc.QuotaFailure",
        "violations": [
          {
            "subject": "...",
            "description": "..."
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.Help",
        "links": [...]
      }
    ]
  }
}
```

**Critical Fields for Rate Limiting:**
- `retryDelay` - How long to wait before retrying (e.g., "60s", "1.5s")
- `quotaMetric` - Which quota was exceeded (e.g., "generateContent")
- `quotaId` - Unique identifier for the quota
- `quotaDimensions` - Additional quota context (model, location)

### Current Implementation

The `RetryManager.extract_retry_info/1` function correctly extracts this information:

```elixir
# From retry_manager.ex:253-274
defp extract_from_error_details(error) when is_map(error) do
  case error do
    %{"details" => [%{"@type" => type} = detail | _]}
    when type == "type.googleapis.com/google.rpc.RetryInfo" or
           type == "google.rpc.RetryInfo" ->
      %{
        "retryDelay" => Map.get(detail, "retryDelay", "60s")
      }

    %{"details" => details} when is_list(details) ->
      Enum.find_value(details, %{}, fn detail ->
        case detail do
          %{"retryDelay" => _} = info -> info
          _ -> nil
        end
      end)

    _ ->
      %{}
  end
end
```

### The Reality

The current code already preserves `details` end-to-end:
- `HTTP.handle_response/1` passes the full body into `Error.api_error/3`.
- `Gemini.Error` stores that body in `details`.
- `RetryManager.extract_retry_info/1` matches on `%{details: details}` (including `Gemini.Error` structs) and extracts `RetryInfo`.

So the critical propagation path works today. Remaining improvements are about richer metadata and test coverage, not fixing a broken chain.

## Decision

Keep the existing propagation path intact, and optionally enrich retry metadata for better diagnostics.

### Implementation

1) **Keep the existing propagation path.** No code change is required; the full body is already stored in `Error.details` and consumed by `RetryManager.extract_retry_info/1`.

2) **Optional enrichment:** Capture additional quota metadata when present.

Enhance `State.set_retry_state/2` to capture more quota details:

```elixir
@spec set_retry_state(state_key(), map()) :: :ok
def set_retry_state(key, retry_info) do
  ensure_table_exists()
  retry_delay_ms = parse_retry_delay(retry_info)
  retry_until = DateTime.add(DateTime.utc_now(), retry_delay_ms, :millisecond)

  state = %{
    retry_until: retry_until,
    quota_metric: extract_quota_metric(retry_info),
    quota_id: Map.get(retry_info, "quotaId"),
    quota_dimensions: Map.get(retry_info, "quotaDimensions"),  # NEW
    quota_value: Map.get(retry_info, "quotaValue"),            # NEW
    last_429_at: DateTime.utc_now()
  }

  :ets.insert(@ets_table, {{:retry, key}, state})
  :ok
end

defp extract_quota_metric(retry_info) do
  # May be directly in retry_info or nested in error.details
  Map.get(retry_info, "quotaMetric") ||
    get_in(retry_info, ["error", "quotaMetric"])
end
```

## Consequences

### Positive

1. **Accurate Wait Times**: Already respects server-provided `retryDelay`.
2. **Better Debugging (optional)**: Capturing quota fields improves telemetry.
3. **Adaptive Behavior**: Metadata can support per-model/location policies later.
4. **API Compliance**: Keeps using server-indicated backoff instead of guessing.

### Negative

1. **Memory Usage**: Storing full error details uses more ETS space
2. **Complexity**: More fields to track in retry state
3. **Google API Changes**: If Google changes error format, extraction may break

### Mitigations

- Fallback to default 60s delay if extraction fails
- Telemetry events for retry info extraction failures
- Periodic cleanup of old retry state entries

## Testing Strategy

Add tests verifying the complete chain:

```elixir
describe "429 retry info propagation" do
  test "extracts retryDelay from Google RPC format" do
    body = %{
      "error" => %{
        "code" => 429,
        "message" => "Resource exhausted",
        "details" => [
          %{
            "@type" => "type.googleapis.com/google.rpc.RetryInfo",
            "retryDelay" => "45s"
          }
        ]
      }
    }

    error = Error.api_error(429, body["error"], body)
    retry_info = RetryManager.extract_retry_info({:error, error})

    assert retry_info["retryDelay"] == "45s"
  end

  test "State parses duration strings correctly" do
    assert State.parse_retry_delay(%{"retryDelay" => "60s"}) == 60_000
    assert State.parse_retry_delay(%{"retryDelay" => "1.5s"}) == 1_500
    assert State.parse_retry_delay(%{"retryDelay" => "500ms"}) == 500
    assert State.parse_retry_delay(%{"retryDelay" => "2m"}) == 120_000
  end

  test "manager waits for server-specified duration" do
    # Use Bypass to return 429 with specific retryDelay
    # Assert that Manager.execute waits approximately that duration
  end
end
```

## Implementation Priority

**LOW** - The critical path already works; only optional enrichment/tests remain.

## Related ADRs

- ADR-0001: Auto Token Estimation
- ADR-0002: Token Budget Configuration Defaults
- ADR-0004: Recommended Configuration Pattern
