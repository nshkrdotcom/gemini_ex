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

### The Problem

In `lib/gemini/client/http.ex`, the `handle_response/1` function creates an error but **may not preserve the full `details` array** needed by `RetryManager`:

```elixir
# From http.ex:338-358
defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
  {error_info, error_details} =
    case body do
      %{"error" => error} = decoded ->
        {error, decoded}  # error_info = error map, error_details = full response
      # ...
    end

  {:error, Error.api_error(status, error_info, error_details)}
end
```

The `Error.api_error/3` function must then preserve these details in a structure that `RetryManager.classify_response/1` can access:

```elixir
# From retry_manager.ex:116-118
def extract_retry_info({:error, %{details: details}}) when is_map(details) do
  extract_retry_info_from_details(details)
end
```

**Verification Needed**: Ensure `Error.api_error/3` stores `error_details` (the full body) in a `details` field accessible to `RetryManager`.

## Decision

Audit and strengthen the error propagation chain to guarantee `RetryInfo` reaches the rate limiter state management.

### 1. Error Struct Verification

Verify `lib/gemini/error.ex` includes proper details storage:

```elixir
defmodule Gemini.Error do
  defstruct [
    :type,
    :message,
    :http_status,
    :details,      # Must contain full error body for retry extraction
    :code,
    :raw_response
  ]

  @spec api_error(integer(), map(), map()) :: t()
  def api_error(status, error_info, full_body) do
    %__MODULE__{
      type: :api_error,
      message: Map.get(error_info, "message", "API error"),
      http_status: status,
      code: Map.get(error_info, "code"),
      details: full_body,  # CRITICAL: Store full body here
      raw_response: full_body
    }
  end
end
```

### 2. HTTP Client Update

Ensure `handle_response/1` passes the complete body:

```elixir
defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
  {error_info, full_body} =
    case body do
      %{"error" => error} = decoded ->
        {error, decoded}

      json_string when is_binary(json_string) ->
        case Jason.decode(json_string) do
          {:ok, %{"error" => error} = decoded} -> {error, decoded}
          {:ok, decoded} when is_map(decoded) -> {decoded, %{"error" => decoded}}
          _ -> build_default_error(status)
        end

      decoded when is_map(decoded) ->
        {decoded, %{"error" => decoded}}

      _ ->
        build_default_error(status)
    end

  # CRITICAL: Pass full_body as third argument for retry info extraction
  {:error, Error.api_error(status, error_info, full_body)}
end
```

### 3. RetryManager Enhancement

Add explicit handling for the Error struct:

```elixir
@spec extract_retry_info({:error, term()}) :: map()
def extract_retry_info({:error, %Gemini.Error{details: details}}) when is_map(details) do
  extract_retry_info_from_details(details)
end

def extract_retry_info({:error, %{details: details}}) when is_map(details) do
  extract_retry_info_from_details(details)
end

def extract_retry_info({:error, {:http_error, 429, body}}) when is_map(body) do
  extract_retry_info_from_details(body)
end

def extract_retry_info(_), do: %{}
```

### 4. State Update with Full Quota Info

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

1. **Accurate Wait Times**: Rate limiter waits exactly as long as Google specifies
2. **Better Debugging**: Full quota info available for logging/telemetry
3. **Adaptive Behavior**: Quota dimensions allow per-model/location rate limiting
4. **API Compliance**: Respects server-indicated backoff instead of guessing

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

**MEDIUM** - The current implementation mostly works, but strengthening it prevents subtle bugs where retry info is lost and the rate limiter uses default 60s delays instead of server-specified ones.

## Related ADRs

- ADR-0001: Auto Token Estimation
- ADR-0002: Token Budget Configuration Defaults
- ADR-0004: Recommended Configuration Pattern
