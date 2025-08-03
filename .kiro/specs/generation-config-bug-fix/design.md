# Design Document

## Overview

The bug exists because `Gemini.APIs.Coordinator.build_generation_config/1` only handles a hardcoded whitelist of 4 generation config options (`temperature`, `max_output_tokens`, `top_p`, `top_k`) while ignoring all other valid options like `response_schema`, `response_mime_type`, `stop_sequences`, etc. Additionally, the coordinator doesn't properly handle complete `GenerationConfig` structs passed via the `:generation_config` option.

In contrast, `Gemini.Generate.build_generate_request/2` correctly handles complete `GenerationConfig` structs by passing them through directly to the API request.

## Architecture

The fix involves modifying the `Gemini.APIs.Coordinator` module to:

1. **Prioritize complete GenerationConfig structs**: When a `:generation_config` option is provided, use it directly instead of building from individual options
2. **Support all GenerationConfig fields**: Expand the individual option handling to support all fields defined in `Gemini.Types.GenerationConfig`
3. **Maintain backward compatibility**: Ensure existing code using individual options continues to work
4. **Proper key conversion**: Convert snake_case Elixir keys to camelCase JSON keys for the API

## Components and Interfaces

### Modified Components

#### `Gemini.APIs.Coordinator.build_generate_request/2`
- **Current behavior**: Calls `build_generation_config/1` for all requests
- **New behavior**: Check for `:generation_config` option first, fall back to building from individual options
- **Interface**: No change to public interface

#### `Gemini.APIs.Coordinator.build_generation_config/1`
- **Current behavior**: Only handles 4 hardcoded options
- **New behavior**: Handle all valid GenerationConfig fields
- **Interface**: No change to function signature

### New Helper Functions

#### `convert_to_camel_case/1`
- **Purpose**: Convert snake_case atoms to camelCase strings for API compatibility
- **Input**: Atom (e.g., `:response_mime_type`)
- **Output**: String (e.g., `"responseMimeType"`)

#### `struct_to_api_map/1`
- **Purpose**: Convert GenerationConfig struct to API-ready map with camelCase keys
- **Input**: `%GenerationConfig{}`
- **Output**: Map with camelCase string keys and nil values filtered out

## Data Models

### Request Flow Comparison

#### Current (Broken) Flow
```
Gemini.generate/2 with response_schema
  ↓
Coordinator.generate_content/2
  ↓
build_generate_request/2
  ↓
build_generation_config/1 (ignores response_schema)
  ↓
API request missing response_schema
```

#### Fixed Flow
```
Gemini.generate/2 with response_schema
  ↓
Coordinator.generate_content/2
  ↓
build_generate_request/2
  ↓
Check for :generation_config option first
  ↓ (if not found)
build_generation_config/1 (handles all options)
  ↓
API request includes response_schema
```

### GenerationConfig Field Mapping

| Elixir Field (snake_case) | API Field (camelCase) | Type |
|---------------------------|----------------------|------|
| `stop_sequences` | `stopSequences` | `[String.t()]` |
| `response_mime_type` | `responseMimeType` | `String.t()` |
| `response_schema` | `responseSchema` | `map()` |
| `candidate_count` | `candidateCount` | `integer()` |
| `max_output_tokens` | `maxOutputTokens` | `integer()` |
| `temperature` | `temperature` | `float()` |
| `top_p` | `topP` | `float()` |
| `top_k` | `topK` | `integer()` |
| `presence_penalty` | `presencePenalty` | `float()` |
| `frequency_penalty` | `frequencyPenalty` | `float()` |
| `response_logprobs` | `responseLogprobs` | `boolean()` |
| `logprobs` | `logprobs` | `integer()` |

## Error Handling

### Validation Strategy
- **Struct validation**: `GenerationConfig` structs are already validated by TypedStruct
- **Individual options**: Validate types when building from individual options
- **Nil handling**: Filter out nil values before sending to API
- **Unknown options**: Ignore unknown options to maintain forward compatibility

### Error Scenarios
1. **Invalid GenerationConfig struct**: Return existing struct validation errors
2. **Invalid individual option types**: Log warning and skip invalid options
3. **API rejection**: Existing HTTP error handling covers API-level validation

## Testing Strategy

### Test Structure
Create `test/gemini/apis/coordinator_generation_config_test.exs` with:

1. **Bug demonstration tests**: Tests that fail with current implementation
2. **Fix verification tests**: Same tests that pass after fix
3. **Comprehensive coverage**: All GenerationConfig fields
4. **Integration tests**: End-to-end testing with mocked HTTP client

### Test Categories

#### Unit Tests
- `build_generation_config/1` with individual options
- `build_generate_request/2` with GenerationConfig struct
- Key conversion functions
- Nil value filtering

#### Integration Tests  
- `Gemini.generate/2` with response_schema
- `Gemini.chat/1` with GenerationConfig struct
- `Coordinator.generate_content/2` with mixed options

#### Regression Tests
- Ensure existing functionality continues to work
- Verify backward compatibility with current API usage

### Mock Strategy
- Mock `Gemini.Client.HTTP.post/3` to capture request bodies
- Verify request structure without making actual API calls
- Use pattern matching to assert on specific fields in request body

## Implementation Phases

### Phase 1: Core Fix
1. Modify `build_generate_request/2` to prioritize `:generation_config` option
2. Expand `build_generation_config/1` to handle all fields
3. Add key conversion helper functions

### Phase 2: Testing
1. Create comprehensive test suite
2. Verify bug reproduction and fix
3. Add regression tests

### Phase 3: Validation
1. Run existing test suite to ensure no regressions
2. Test with real API calls (integration tests)
3. Verify consistent behavior between Generate and Coordinator modules