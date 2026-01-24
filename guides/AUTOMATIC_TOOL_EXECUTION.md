# Automatic Tool Execution Implementation

This document describes the implementation of the automatic tool execution feature for the Gemini Elixir client, providing Python-SDK-like functionality that hides the complexity of multi-turn tool-calling from end users.

> **Note:** This document covers tool execution for HTTP-based `generateContent` requests. For real-time tool calling via WebSocket, see the [Live API Guide](docs/guides/live_api.md#tool-use-and-function-calling) which uses callback-based tool handling via `on_tool_call`.

## Overview

The automatic tool execution feature implements a high-level orchestration system that:

1. **Standard Mode**: Automatically handles the tool-calling loop in blocking requests
2. **Streaming Mode**: Manages complex multi-stage streaming with tool execution
3. **Error Handling**: Provides robust error handling and turn limits
4. **Type Safety**: Maintains full type safety throughout the process

## Architecture

### Core Components

#### 1. Standard (Non-Streaming) Loop - `Gemini.generate_content_with_auto_tools/2`

**Location**: `lib/gemini.ex`

The standard automatic loop is implemented as a recursive state machine:

```elixir
def generate_content_with_auto_tools(contents, opts \\ []) do
  turn_limit = Keyword.get(opts, :turn_limit, 10)
  chat = Chat.new(opts)
  initial_chat = case contents do
    text when is_binary(text) -> Chat.add_turn(chat, "user", text)
    content_list when is_list(content_list) -> %{chat | history: content_list}
  end
  orchestrate_tool_loop(initial_chat, turn_limit)
end
```

**State Machine Flow**:
1. Make API call with current chat history
2. Check response for function calls
3. If no function calls → return final response (base case)
4. If function calls found:
   - Add model's function call turn to history
   - Execute tools using `Gemini.Tools.execute_calls/1`
   - Add user's function response turn to history
   - Recursively continue with decremented turn limit

#### 2. Streaming Loop - `Gemini.Streaming.ToolOrchestrator`

**Location**: `lib/gemini/streaming/tool_orchestrator.ex`

The streaming implementation uses a dedicated GenServer to manage the complex multi-stage process:

**Phases**:
- `:awaiting_model_call` - Buffering first stream, looking for function calls
- `:executing_tools` - Running tool execution asynchronously
- `:awaiting_final_response` - Proxying second stream to subscriber

**Process Flow**:
1. Start first HTTP stream to Gemini API
2. Buffer incoming chunks and inspect for function calls
3. When function calls detected:
   - Stop first stream
   - Execute tools asynchronously
   - Start second HTTP stream with complete history
   - Proxy second stream events to original subscriber

#### 3. UnifiedManager Integration

**Location**: `lib/gemini/streaming/unified_manager.ex`

The UnifiedManager was extended to detect automatic tool calling requests and delegate to the ToolOrchestrator:

```elixir
case Keyword.get(opts, :auto_execute_tools, false) do
  true -> start_auto_tool_stream(stream_state)
  false -> start_stream_process(stream_state)
end
```

### Data Flow

#### Standard Mode Data Flow

```
User Request
    ↓
Chat.new() + add_turn()
    ↓
orchestrate_tool_loop()
    ↓
API Call (generate_content)
    ↓
Response Analysis
    ↓
Function Calls? → No → Return Final Response
    ↓ Yes
Execute Tools
    ↓
Add Tool Results to History
    ↓
Recursive Call (turn_limit - 1)
```

#### Streaming Mode Data Flow

```
User Request
    ↓
ToolOrchestrator.start_link()
    ↓
Start First HTTP Stream
    ↓
Buffer & Analyze Chunks
    ↓
Function Calls Detected?
    ↓ Yes
Stop First Stream
    ↓
Execute Tools Async
    ↓
Start Second HTTP Stream
    ↓
Proxy Events to Subscriber
```

## Key Implementation Details

### 1. Function Call Detection

Function calls are detected by examining the response structure:

```elixir
defp extract_function_calls_from_response(%GenerateContentResponse{candidates: candidates}) do
  candidates
  |> Enum.flat_map(fn candidate ->
    case candidate do
      %{content: %{parts: parts}} ->
        parts
        |> Enum.filter(fn part -> part.function_call != nil end)
        |> Enum.map(fn part -> part.function_call end)
      _ -> []
    end
  end)
end
```

### 2. Chat History Management

The `Gemini.Chat` module was enhanced to handle different content types:

```elixir
def add_turn(chat, "model", function_calls) when is_list(function_calls) do
  # Creates parts with function_call data
end

def add_turn(chat, "user", tool_results) when is_list(tool_results) do
  # Uses Content.from_tool_results/1 to create function_response parts
end
```

### 3. Tool Result Serialization

Tool results are converted to the proper API format:

```elixir
def from_tool_results(results) when is_list(results) do
  parts = Enum.map(results, fn result ->
    %{
      function_response: %{
        name: result.call_id,
        response: %{content: result.content}
      }
    }
  end)
  %Content{role: "user", parts: parts}
end
```

### 4. Error Handling and Turn Limits

Both implementations include robust error handling:

- **Turn Limits**: Prevent infinite loops with configurable limits (default: 10)
- **Tool Execution Errors**: Captured and reported without crashing the system
- **Stream Errors**: Properly propagated to subscribers
- **Process Cleanup**: Streams are properly cleaned up on errors

## API Usage

### Standard Automatic Tool Execution

```elixir
# Register tools first
{:ok, declaration} = Altar.ADM.new_function_declaration(%{
  name: "get_weather",
  description: "Gets weather for a location",
  parameters: %{
    type: "object",
    properties: %{location: %{type: "string"}},
    required: ["location"]
  }
})
:ok = Gemini.Tools.register(declaration, &MyApp.get_weather/1)

# Use automatic execution
{:ok, response} = Gemini.generate_content_with_auto_tools(
  "What's the weather in San Francisco?",
  tools: [declaration],
  model: "gemini-flash-lite-latest",
  turn_limit: 5
)

{:ok, text} = Gemini.extract_text(response)
```

### Streaming Automatic Tool Execution

```elixir
# Start streaming with automatic tool execution
{:ok, stream_id} = Gemini.stream_generate_with_auto_tools(
  "What's the weather in Tokyo?",
  tools: [declaration],
  model: "gemini-flash-lite-latest"
)

# Subscribe to receive only final text response
:ok = Gemini.subscribe_stream(stream_id)

# Handle events
receive do
  {:stream_event, ^stream_id, event} -> 
    # Only final text chunks, no function calls visible
  {:stream_complete, ^stream_id} -> 
    # Stream completed
  {:stream_error, ^stream_id, error} -> 
    # Handle errors
end
```

## Testing

### Unit Tests

**Location**: `test/gemini_auto_tools_unit_test.exs`

Tests cover:
- Chat structure creation and manipulation
- Function call and tool result handling
- Content serialization and deserialization
- Basic API structure validation

### Integration Tests

**Location**: `test/gemini_auto_tools_test.exs`

Tests cover (require API key):
- End-to-end automatic tool execution
- Turn limit functionality
- Streaming automatic execution
- Multiple tool calls in sequence
- Error handling scenarios

### Example Demonstrations

**Location**: `examples/auto_tool_calling_demo.exs`

Provides working examples of:
- Tool registration
- Standard automatic execution
- Streaming automatic execution
- Multiple tool types (weather, time, calculator)

## Performance Considerations

### Memory Usage
- Chat history grows with each turn but is bounded by turn limits
- Streaming buffers are cleared after function call detection
- Tool results are processed and released promptly

### Concurrency
- Tool execution uses `Task.async_stream` for parallel execution
- Streaming orchestrator runs in dedicated GenServer
- Multiple streams can run concurrently

### Error Recovery
- Individual tool failures don't crash the entire system
- Stream processes are supervised and cleaned up properly
- Turn limits prevent runaway execution

## Future Enhancements

### Potential Improvements
1. **Tool Result Caching**: Cache tool results for identical calls
2. **Parallel Tool Execution**: Execute independent tools in parallel
3. **Tool Dependency Management**: Handle tool dependencies automatically
4. **Enhanced Error Recovery**: Retry failed tool calls with backoff
5. **Metrics and Observability**: Add telemetry for tool execution performance

### Compatibility
- Maintains full backward compatibility with existing APIs
- Optional feature that doesn't affect non-tool-calling usage
- Follows existing patterns and conventions in the codebase

## Conclusion

The automatic tool execution implementation provides a seamless, Python-SDK-like experience while maintaining the robustness and type safety expected in Elixir applications. The dual implementation (standard and streaming) ensures that users can choose the appropriate mode for their use case while getting the same high-level abstraction over the complex tool-calling protocol.