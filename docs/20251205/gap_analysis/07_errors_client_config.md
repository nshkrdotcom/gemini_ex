# Gap Analysis: Error Handling & Client Configuration

## Executive Summary

Python has more sophisticated error hierarchies and retry mechanisms. Elixir uses a functional approach with atom-based error types. Both have different but valid patterns.

## Error Type Comparison

| Error Type | Python | Elixir | Notes |
|------------|--------|--------|-------|
| Base Error | `APIError` class | `Gemini.Error` struct | Different paradigms |
| Client Errors (4xx) | `ClientError` subclass | `:http_error` atom | Python has hierarchy |
| Server Errors (5xx) | `ServerError` subclass | `:http_error` atom | Same treatment in Elixir |
| Auth Errors | Part of APIError | `:auth_error` atom | Explicit in Elixir |
| Config Errors | Various | `:config_error` atom | Explicit in Elixir |
| Network Errors | Various | `:network_error` atom | Explicit in Elixir |
| Function Errors | `FunctionInvocationError` | Generic | Missing in Elixir |
| Unknown Args | `UnknownFunctionCallArgumentError` | ❌ Missing | Gap |
| Unsupported Func | `UnsupportedFunctionError` | ❌ Missing | Gap |

### Python Error Hierarchy

```python
class APIError(Exception):
    code: int
    response: Any
    status: str
    message: str
    details: list[dict]

class ClientError(APIError): pass  # 4xx
class ServerError(APIError): pass  # 5xx
class UnknownFunctionCallArgumentError(Exception): pass
class UnsupportedFunctionError(Exception): pass
class FunctionInvocationError(Exception): pass
```

### Elixir Error Types

```elixir
defmodule Gemini.Error do
  typedstruct do
    field(:type, atom())           # :http_error, :api_error, etc.
    field(:message, String.t())
    field(:http_status, integer())
    field(:api_reason, String.t())
    field(:details, map())
    field(:original_error, term())
  end
end
```

## HTTP Error Handling

### Python Approach

```python
class APIError:
  @classmethod
  def raise_for_response(cls, response):
    # Supports multiple response types (httpx, aiohttp)
    # Handles JSON and plain text error bodies
    # Graceful fallback on parse failure
    # Dispatches to appropriate subclass
```

**Features:**
- Multiple HTTP client support
- Detailed error extraction from nested structures
- Sync and async variants

### Elixir Approach

```elixir
defp handle_response({:ok, %Req.Response{status: status}}) when status in 200..299
defp handle_response({:ok, %Req.Response{status: status, body: body}})
defp handle_response({:error, reason})
```

**Features:**
- Pattern matching on status codes
- JSON decoding with fallback
- Unified via Req library

## Retry Logic Comparison

### Python (tenacity library)

```python
_RETRY_ATTEMPTS = 5
_RETRY_INITIAL_DELAY = 1.0
_RETRY_MAX_DELAY = 60.0
_RETRY_EXP_BASE = 2
_RETRY_JITTER = 1
_RETRY_HTTP_STATUS_CODES = (408, 429, 500, 502, 503, 504)

# Per-request configuration
HttpRetryOptions(
    attempts=5,
    initial_delay=1.0,
    max_delay=60.0,
    exp_base=2,
    jitter=1.0,
    retriable_codes=[429, 500, 502, 503, 504]
)
```

**Features:**
- Sophisticated exponential backoff with jitter
- Retries only on specific status codes + error types
- Per-request override
- Before-sleep logging

### Elixir (Manual)

```elixir
defp stream_with_retries(..., attempt, max_retries) do
  case do_stream(...) do
    {:ok, :completed} -> {:ok, :completed}
    {:error, error} when attempt < max_retries ->
      delay = min(1000 * :math.pow(2, attempt), max_backoff_ms)
      Process.sleep(delay)
      stream_with_retries(..., attempt + 1, ...)
  end
end
```

**Features:**
- Manual exponential backoff
- Context-specific (streaming only)
- Simpler but less configurable
- Has separate RateLimiter module

## Client Configuration Comparison

### Python HttpOptions

```python
class HttpOptions:
  base_url: Optional[str]
  api_version: Optional[str]           # v1, v1beta
  headers: Optional[dict[str, str]]
  timeout: Optional[int]               # milliseconds
  client_args: Optional[dict]          # httpx.Client kwargs
  async_client_args: Optional[dict]    # AsyncClient kwargs
  extra_body: Optional[dict]
  retry_options: Optional[HttpRetryOptions]
  httpx_client: Optional[HttpxClient]
  httpx_async_client: Optional[HttpxAsyncClient]
```

### Elixir Config

```elixir
# Application config
config :gemini_ex,
  api_key: "...",
  project_id: "...",
  location: "...",
  model: "gemini-2.5-flash",
  timeout: 120_000

# Runtime config via Gemini.Config
def get do
  %{
    auth_type: detect_auth_type(),
    api_key: ...,
    project_id: ...,
    model: ...
  }
end
```

**Gaps:**
- No explicit HttpOptions struct
- No per-request timeout override
- No custom headers support
- No debug/replay mode

## API Versioning

### Python

```python
if self.vertexai:
  api_version = 'v1beta1'
else:
  api_version = 'v1beta'

versioned_path = f'{api_version}/{path}'
```

### Elixir

- Not explicitly managed
- Handled at auth strategy level
- No override capability

## Recommendations

### High Priority

1. **Add HttpOptions Configuration**
   ```elixir
   defmodule Gemini.HttpOptions do
     typedstruct do
       field :timeout, integer()
       field :headers, map()
       field :retry_options, RetryOptions.t()
     end
   end
   ```

2. **Enhance Retry Logic**
   - Reusable retry abstraction
   - Exponential backoff with jitter
   - Conditional retries by status code

3. **Improve Error Handling**
   - Add function-related error types
   - Better nested error extraction
   - HTTP status classification

4. **Add API Versioning**
   - Configurable version
   - Per-auth-strategy defaults

### Medium Priority

5. **Debug/Replay Mode**
   - Record/replay HTTP interactions
   - Better testing support

6. **Timeout Improvements**
   - X-Server-Timeout header
   - Per-request overrides

7. **Header Management**
   - Library version headers
   - Deduplication logic

### Lower Priority

8. Multiple HTTP client support
9. Credential refresh locking
10. Streaming error semantics alignment

## Conclusion

The Elixir implementation is more elegant and functional but lacks:

1. **Sophisticated retry** - tenacity-like features
2. **HttpOptions struct** - formal configuration
3. **Per-request overrides** - flexibility
4. **API versioning** - explicit control
5. **Debug mode** - testing support

**Estimated effort:** 3-4 weeks for high priority items
