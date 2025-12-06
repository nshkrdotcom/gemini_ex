# Gap Analysis: Function Calling & AFC (Automatic Function Calling)

## Executive Summary

The Python genai SDK has **significantly more mature AFC capabilities** compared to Elixir. While Elixir has foundational tool orchestration using the ALTAR runtime, it lacks automatic function invocation, async tool support, MCP protocol integration, and streaming AFC with thoughts.

## Feature Comparison Table

| Feature | Python genai | Elixir | Status |
|---------|--------------|--------|--------|
| **Tool Definition** | ✅ Comprehensive | ✅ Basic | Parity |
| Tool from Functions | ✅ Auto-introspection | ❌ Manual | **Gap** |
| Tool from Pydantic Models | ✅ Full support | ❌ Not implemented | **Gap** |
| Tool from Dictionaries | ✅ Supported | ✅ Supported | Parity |
| **Function Calling** | | | |
| Function call detection | ✅ Yes | ✅ Yes | Parity |
| Function response handling | ✅ Complete | ✅ Partial | **Gap** |
| Sync function execution | ✅ Yes | ✅ Yes | Parity |
| Async function execution | ✅ Yes | ❌ No | **Gap** |
| **AFC (Automatic Function Calling)** | | | |
| AFC enabled by default | ✅ Yes | ✅ Yes | Parity |
| AFC can be disabled | ✅ Yes | ✅ Yes | Parity |
| Maximum remote calls limit | ✅ Configurable | ❌ Fixed (10) | **Gap** |
| AFC history tracking | ✅ Full tracking | ❌ Partial | **Gap** |
| AFC thoughts support | ✅ Yes | ❌ No | **Gap** |
| Type conversion (float→int) | ✅ Yes | ❌ No | **Gap** |
| Streaming AFC | ✅ Yes | ✅ Yes | Parity |
| **Error Handling** | | | |
| Function invocation errors | ✅ Comprehensive | ✅ Basic | **Gap** |
| Argument type validation | ✅ Strict | ✅ Basic | **Gap** |
| Unknown argument errors | ✅ Yes | ❌ No | **Gap** |
| **MCP Integration** | | | |
| MCP tool support | ✅ Full | ❌ None | **Gap** |
| MCP session support | ✅ Yes | ❌ None | **Gap** |
| MCP-to-Gemini conversion | ✅ Yes | ❌ None | **Gap** |

## Python AFC Architecture

### Function Introspection & Schema Generation

```python
# Python automatically generates schema from function signature
def get_weather(location: str, units: Literal["C", "F"] = "F") -> str:
    """Get weather for a location."""
    pass

# SDK auto-generates FunctionDeclaration with:
# - Parameter types from type hints
# - Required fields detection
# - Default value handling
# - Docstring as description
```

### Function Invocation Pipeline

```python
convert_argument_from_function()        # Argument conversion
invoke_function_from_dict_args()        # Sync invocation
invoke_function_from_dict_args_async()  # Async invocation
convert_number_values_for_function_call_args()  # Type coercion
get_function_response_parts()           # Response generation
```

### Configuration Management

```python
AutomaticFunctionCallingConfig(
    disable=False,              # Can disable AFC
    maximum_remote_calls=5,     # Configurable limit
    ignore_call_history=False   # Track history
)
```

## Elixir AFC Architecture

### Tool Registration (ALTAR)

```elixir
Gemini.Tools.register(declaration, fun)  # Register function
Gemini.Tools.execute_calls(function_calls)  # Execute in parallel
```

### Tool Orchestration (GenServer)

- Phase 1: Buffer initial stream for function calls
- Phase 2: Execute detected functions in parallel
- Phase 3: Stream final response with full history

### Current Limitations

- Tools must be pre-registered with ALTAR
- No automatic function introspection
- No async tool support
- Fixed 10-turn limit (hardcoded)
- No type coercion/validation
- No history configuration option

## Critical Gaps

### 1. Missing Function Introspection (CRITICAL)

**Python:**
```python
def get_weather(location: str, units: Literal["C", "F"] = "F") -> str:
    """Get weather for a location."""
    pass
# Schema automatically generated
```

**Elixir:** Must manually define `FunctionDeclaration`

### 2. Missing Async Tool Support (CRITICAL)

**Python:**
```python
async def get_current_weather_async(location: str) -> str:
    return 'windy'
# Automatically detects and awaits async functions
```

**Elixir:** No async support - all tools must be synchronous

### 3. Missing Type Coercion (HIGH)

**Python:**
```python
# Converts float 1.0 → int 1 for int parameters
# Validates Pydantic models
```

**Elixir:** Raw args passed to function without validation

### 4. Missing AFC Configuration (MEDIUM)

**Python:** Full configuration options
**Elixir:** Fixed configuration only

### 5. Missing MCP Integration (HIGH)

**Python:**
```python
from mcp import ClientSession

async with ClientSession(transport) as session:
    tools = session.list_tools()
    config = GenerateContentConfig(tools=[session])
```

**Elixir:** No MCP support at all

## Recommendations

### Phase 1: Foundational (Medium Priority)

1. **Add Configuration Options**
   ```elixir
   auto_execute_tools_config: %{
     disabled: false,
     max_turns: 10,
     track_history: true
   }
   ```

2. **Implement Type Coercion**
   - Float→int conversion
   - Basic type validation
   - `Gemini.Types.FunctionCall.ArgumentValidator`

3. **Add Error Types**
   - `Gemini.Error.FunctionInvocationError`
   - `Gemini.Error.InvalidArgumentType`
   - `Gemini.Error.FunctionNotFound`

### Phase 2: High Value Features (High Priority)

4. **Add Async Tool Support**
   - Support both sync and async functions
   - Execute with `Task.async_stream/3`

5. **Implement Type Validation**
   - Parse function type signatures
   - Validate before execution

6. **Add Struct Schema Support**
   - Auto-generate schemas from structs
   - Similar to Pydantic

### Phase 3: Advanced Features (Lower Priority)

7. **MCP Integration**
   - `Gemini.MCP.Client` module
   - MCP server connections
   - Tool format conversion

8. **Function Introspection**
   - Reflect on Elixir function signatures
   - Auto-generate FunctionDeclaration

9. **AFC History & Thoughts**
   - Track full execution history
   - Support thinking configuration

## Implementation Effort

| Feature | Priority | Effort |
|---------|----------|--------|
| Config options | HIGH | Minimal |
| Type coercion | HIGH | Minor |
| Async support | HIGH | Moderate |
| Schema generation | MEDIUM | Moderate |
| MCP integration | MEDIUM | Significant |
| Function introspection | LOW | Moderate |
| Thoughts support | LOW | Moderate |

## Conclusion

The Elixir implementation has a **solid foundation with ALTAR integration** but lacks sophisticated AFC orchestration. Primary gaps:

1. **Function introspection** (auto-generate schemas)
2. **Async tool support** (blocking operations)
3. **Type validation** (argument compatibility)
4. **MCP integration** (external tool protocol)
5. **Configuration options** (limited AFC control)

**Estimated Effort:** 3-6 weeks for full feature parity
