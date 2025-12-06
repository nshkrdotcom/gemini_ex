# Error Handling and Recovery Gap Analysis

## Executive Summary

The Elixir Gemini implementation has **solid foundational error handling** with modern patterns (structured tuples, rate limit awareness), but the Python genai library has more **granular error categorization** and **comprehensive HTTP retry mechanisms**.

### Key Gaps
1. **Limited error type categorization** - Python has explicit `ClientError` and `ServerError`; Elixir uses generic atom-based types
2. **Missing async error handling patterns** - Python supports both sync and async error recovery
3. **Incomplete HTTP status code classification** - Elixir needs better handling of specific 4xx/5xx scenarios
4. **Streaming-specific error recovery** - Limited recovery mechanisms for stream interruptions
5. **Rate limit header parsing** - Python extracts `Retry-After` headers; Elixir uses generic retry info

---

## Error Types Comparison

### Python Error Hierarchy

| Class | Purpose | Parent | Use Case |
|-------|---------|--------|----------|
| `APIError` | Base API error | `Exception` | Catch-all for API responses |
| `ClientError` | 4xx errors | `APIError` | Invalid requests (400, 401, 403, etc.) |
| `ServerError` | 5xx errors | `APIError` | Server failures (500, 502, 503, 504) |
| `UnknownFunctionCallArgumentError` | Function invocation | `ValueError` | Tool/function parameter conversion |
| `UnsupportedFunctionError` | Function support | `ValueError` | Unsupported tool calls |
| `FunctionInvocationError` | Function execution | `ValueError` | Runtime function failures |
| `UnknownApiResponseError` | JSON parsing | `ValueError` | Malformed API responses |

**Python Error Structure:**
```python
class APIError(Exception):
    code: int                    # HTTP status code
    message: Optional[str]       # Error message from API
    status: Optional[str]        # Error status (e.g., "INVALID_ARGUMENT")
    details: dict               # Full response JSON
    response: HttpResponse      # Original response object
```

### Elixir Error Structure

```elixir
%Gemini.Error{
  type: :http_error | :api_error | :auth_error | :config_error |
        :validation_error | :serialization_error | :network_error |
        :invalid_response,
  message: String.t(),
  http_status: integer() | nil,
  api_reason: term() | nil,
  details: map() | nil,
  original_error: term() | nil
}
```

---

## Missing Error Types and Categories

### 1. Client/Server Error Distinction (HIGH PRIORITY)

**Python:**
- Explicit `ClientError` for 400-499 range
- Explicit `ServerError` for 500-599 range
- Automatic routing via `raise_error()` method

**Elixir Gap:**
- No distinction between client and server errors
- Both are mapped to generic `:http_error` type

**Recommendation:**
```elixir
def client_error(status, message, details \\ %{}) do
  new(:client_error, message, http_status: status, details: details)
end

def server_error(status, message, details \\ %{}) do
  new(:server_error, message, http_status: status, details: details)
end
```

### 2. Specific HTTP Status Code Errors (MEDIUM PRIORITY)

**Python handles explicitly:**
- 408 - Request Timeout
- 429 - Too Many Requests (rate limit)
- 500 - Internal Server Error
- 502 - Bad Gateway
- 503 - Service Unavailable
- 504 - Gateway Timeout

**Elixir Gap:**
- Generic `:http_error` type doesn't distinguish status codes
- Rate limit (429) handled by RateLimiter but not in error type
- No specific timeout error type

**Recommendation:**
```elixir
def timeout_error(message, details \\ %{}) do
  new(:timeout, message, http_status: 408, details: details)
end

def rate_limit_error(retry_after, details \\ %{}) do
  new(:rate_limited, "Rate limit exceeded",
    http_status: 429,
    details: Map.put(details, :retry_after, retry_after)
  )
end

def service_unavailable_error(message, details \\ %{}) do
  new(:service_unavailable, message, http_status: 503, details: details)
end
```

### 3. Function Invocation Errors (MEDIUM PRIORITY)

**Python has dedicated errors:**
- `UnknownFunctionCallArgumentError` - Parameter conversion failures
- `UnsupportedFunctionError` - Function not supported
- `FunctionInvocationError` - Runtime function failures

**Elixir Gap:**
- No specific error types for tool/function calling failures
- Generic `:validation_error` used instead

**Recommendation:**
```elixir
def function_call_error(message, details \\ %{}) do
  new(:function_call_error, message, details: details)
end

def unknown_function_error(function_name, details \\ %{}) do
  new(:unknown_function,
    "Function '#{function_name}' not supported",
    details: details
  )
end
```

### 4. JSON Parsing Errors (LOW PRIORITY)

**Python:**
- Explicit `UnknownApiResponseError` for JSON decode failures
- Catches `json.decoder.JSONDecodeError` and wraps it

**Elixir Gap:**
- Uses generic `:invalid_response` type
- No distinction between malformed JSON and other response issues

---

## Retry Logic Differences

### Python Retry Configuration

**Default Constants:**
```python
_RETRY_ATTEMPTS = 5              # Total attempts including initial
_RETRY_INITIAL_DELAY = 1.0       # seconds
_RETRY_MAX_DELAY = 60.0          # seconds
_RETRY_EXP_BASE = 2              # Exponential base
_RETRY_JITTER = 1                # Jitter range
_RETRY_HTTP_STATUS_CODES = (
    408,  # Request timeout
    429,  # Too many requests
    500,  # Internal server error
    502,  # Bad gateway
    503,  # Service unavailable
    504,  # Gateway timeout
)
```

**Using Tenacity:**
```python
def retry_args(options: Optional[HttpRetryOptions]) -> dict:
    stop = tenacity.stop_after_attempt(options.attempts or _RETRY_ATTEMPTS)
    retriable_codes = options.http_status_codes or _RETRY_HTTP_STATUS_CODES
    retry = tenacity.retry_if_exception(
        lambda e: isinstance(e, errors.APIError) and e.code in retriable_codes,
    )
    wait = tenacity.wait_exponential_jitter(
        initial=options.initial_delay or _RETRY_INITIAL_DELAY,
        max=options.max_delay or _RETRY_MAX_DELAY,
        exp_base=options.exp_base or _RETRY_EXP_BASE,
        jitter=options.jitter or _RETRY_JITTER,
    )
    return {'stop': stop, 'retry': retry, 'reraise': True, 'wait': wait}
```

### Elixir Retry Mechanisms

```elixir
# RateLimiter-based approach
base_backoff_ms: 1000
jitter_factor: 0.25
max_attempts: 3

# Backoff calculation
exponential = base * 2^(attempt-1)
jitter_amount = rand(-exponential*jitter, exponential*jitter)
delay = exponential + jitter_amount
```

### Gap Analysis

| Aspect | Python | Elixir | Gap |
|--------|--------|--------|-----|
| Default attempts | 5 | 3 | Python allows more retries |
| Initial delay | 1.0s | 1000ms (1s) | Match |
| Max delay | 60s | No explicit max | **Elixir missing max cap** |
| Jitter support | Yes (1.0 range) | Yes (±25%) | Different jitter ranges |
| Exponential base | 2 | 2 | Match |
| Configurable codes | Yes | Implicit | **Elixir less control** |
| Retryable status codes | 408,429,500,502,503,504 | Same via RateLimiter | Match |
| Per-request retry override | Yes | No | **Gap** |
| Logging before sleep | Yes | No | **Gap** |

---

## Rate Limit and Quota Handling

### Python Rate Limit Handling

```python
# Automatic 429 detection
if 400 <= status_code < 500:
    raise ClientError(status_code, response_json, response)
elif 500 <= status_code < 600:
    raise ServerError(status_code, response_json, response)
```

### Elixir Rate Limit Handling

**Advanced RateLimiter (Elixir Advantage):**
```elixir
# Per-model rate limit state tracking
# Concurrent permit management
# Token budget tracking
# Retry window management with server-provided delays
```

**Advantages over Python:**
- Structured retry state with explicit delay information
- Token budget forecasting
- Concurrency gating per model
- Adaptive concurrency adjustment

**Disadvantages:**
- No header-based retry delay extraction (e.g., from `Retry-After`)
- Limited support for custom quota headers

---

## Async Error Handling

### Python Async Support

```python
async def raise_for_async_response(response) -> None:
async def raise_error_async(status_code, response_json, response) -> None:

# Handles multiple client types:
# - httpx.AsyncClient
# - aiohttp.ClientResponse
# - ReplayResponse (test replays)
```

### Elixir Async Gap

- All HTTP via `Req` (async-capable)
- Streaming via `Finch` (async)
- No separate async error handling
- Generic error returns via tuples

**Gap:** No separate async error types or handlers

---

## Streaming-Specific Error Handling

### Python Streaming

```python
# Handles during multipart uploads
X-Goog-Upload-Status header checking
Resumable upload retry logic
File seeking and offset tracking
```

### Elixir Streaming

```elixir
# Automatic retry with backoff
stream_with_retries(url, headers, body, callback, timeout, max_retries, max_backoff_ms)

# Error event emission
%{type: :error, error: error}

# Backpressure support - callback can return :stop
```

**Gap:**
- No streaming-specific error classification
- Limited recovery for mid-stream failures
- No resume capability (unlike Python's resumable uploads)
- Connection drop handling could be more explicit

---

## Network Error Handling

### Python Network Errors

Implicitly handled:
- Connection errors from `httpx` or `aiohttp`
- Timeout during `receive_timeout`
- JSON parse errors caught and wrapped

### Elixir Network Errors

**Explicit handling:**
```elixir
def classify_response({:error, :timeout}), do: :transient
def classify_response({:error, :closed}), do: :transient
def classify_response({:error, :econnrefused}), do: :transient
```

**Good coverage of:**
- Connection refused
- Timeout
- Connection closed
- General errors

**Gap:**
- No DNS resolution errors
- Limited Windows-specific error codes
- No SSL/certificate error handling

---

## Error Message Formatting

### Python Error String

```python
f'{self.code} {self.status}. {self.details}'
# Example: "400 INVALID_ARGUMENT. {error JSON}"
```

### Elixir Error Message

```elixir
message: String.t()  # Just the message, no automatic formatting
```

**Gap:**
- Python auto-formats comprehensive error strings
- Elixir requires manual message construction
- No helper for "code status. details" format

---

## Error Response Parsing

### Python Detail Extraction

```python
def _get_status(self, response_json: Any) -> Any:
    return response_json.get('status',
        response_json.get('error', {}).get('status', None))

def _get_message(self, response_json: Any) -> Any:
    return response_json.get('message',
        response_json.get('error', {}).get('message', None))
```

**Handles nested structures:**
```python
{"error": {"code": 400, "message": "...", "status": "INVALID_ARGUMENT"}}
# Or flat:
{"code": 400, "message": "...", "status": "INVALID_ARGUMENT"}
```

### Elixir Detail Extraction

```elixir
# Generic error handling, less sophisticated extraction
case response do
    {:ok, data} -> {:ok, data}
    {:error, details} -> {:error, details}
end
```

**Gap:**
- No fallback chain for nested/flat error structures
- Doesn't attempt multiple error field locations
- No special handling for list-wrapped errors

---

## Recovery Mechanisms Summary

| Feature | Python | Elixir | Status |
|---------|--------|--------|--------|
| Exponential backoff | Yes | Yes | Implemented |
| Jitter | Yes | Yes | Implemented |
| Configurable retries | Full | Limited | Python more flexible |
| Rate limit awareness | Basic | Advanced | **Elixir better** |
| Async errors | Separate types | Unified | Gap |
| Streaming recovery | Resumable | Limited | Python more robust |
| Network error classification | Basic | Good | Similar |
| Timeout handling | Explicit | Basic | Python more comprehensive |
| Header parsing | Partial | Minimal | Gap |
| Error categorization | 3 levels | 1 base type | Gap |

---

## Recommendations for Improvement

### Priority 1: Error Type Hierarchy (HIGH)

**Action:** Add error type functions to match Python's granularity:
```elixir
defmodule Gemini.Error do
  def client_error(status, message, details \\ %{})
  def server_error(status, message, details \\ %{})
  def timeout_error(message, details \\ %{})
  def rate_limit_error(retry_after, details \\ %{})
  def function_call_error(name, message, details \\ %{})
  def parse_error(message, details \\ %{})
end
```

**Impact:** Better type safety and error handling in calling code

### Priority 2: Comprehensive Retry Configuration (MEDIUM)

**Action:** Enhance RateLimiter config:
```elixir
max_retry_attempts: 5          # Currently 3
max_delay_ms: 60_000            # Add missing max cap
configurable_status_codes: [...]  # Allow custom codes
```

**Impact:** Feature parity with Python's retry options

### Priority 3: Response Header Parsing (MEDIUM)

**Action:** Extract and handle standard headers:
- `Retry-After` for 429 responses
- `X-Goog-*` headers for Vertex AI
- `Content-Type` validation

**Impact:** Better automatic retry timing and resource management

### Priority 4: Streaming Error Recovery (MEDIUM)

**Action:** Enhance HTTPStreaming:
- Connection drop detection with auto-reconnect
- Partial response buffering
- Resume capability for seekable streams

**Impact:** More robust real-time streaming

### Priority 5: Error Message Formatting Helper (LOW)

**Action:** Add utility function:
```elixir
def format_error_string(error) do
  "#{error.http_status} #{error.api_reason}. #{inspect(error.details)}"
end
```

**Impact:** Better debug output consistency with Python

---

## Testing Recommendations

### Add Test Coverage For

1. **Error type classification:**
   - 4xx vs 5xx distinction
   - Specific status codes (429, 503, 504)
   - Nested vs flat error responses

2. **Retry scenarios:**
   - Exponential backoff with jitter verification
   - Max attempt limits
   - Transient vs permanent failure handling

3. **Rate limit recovery:**
   - RetryInfo header parsing
   - Concurrent permit exhaustion
   - Budget overage handling

4. **Streaming interruptions:**
   - Mid-stream connection drop
   - Error event emission
   - Callback error propagation

---

## Conclusion

The Elixir implementation has **modern, practical error handling** with particularly strong **rate limiting and concurrency management**. However, it lacks the **granular error categorization** and **detailed HTTP handling** of the Python library.

### Key Actions
1. Add explicit error type constructors (Priority 1)
2. Enhance retry configuration (Priority 2)
3. Implement response header parsing (Priority 3)

The biggest missing piece is **error type hierarchy** - adding explicit error type constructors would significantly improve type safety and enable better error handling patterns in client code.

---

**Document Generated:** 2024-12-06
**Analysis Scope:** Error handling in both codebases
**Methodology:** Code comparison + feature mapping
