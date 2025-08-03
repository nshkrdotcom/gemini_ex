# Requirements Document

## Introduction

This feature addresses a critical bug in the Gemini Elixir client where `generation_config` options (specifically `response_schema`, `response_mime_type`, and other advanced configuration options) are being dropped when using the main `Gemini` module functions and `Gemini.APIs.Coordinator`. The bug occurs because there are two different code paths for building generation requests: the working `Gemini.Generate` module and the broken `Gemini.APIs.Coordinator` module that only whitelists a few basic configuration keys.

## Requirements

### Requirement 1

**User Story:** As a developer using the Gemini client, I want all generation configuration options to work consistently across all API entry points, so that I can use advanced features like structured output with response schemas regardless of which module I call.

#### Acceptance Criteria

1. WHEN I call `Gemini.generate/2` with `response_schema` option THEN the system SHALL include the response schema in the API request
2. WHEN I call `Gemini.chat/1` with a `GenerationConfig` struct containing `response_schema` THEN the system SHALL preserve and use the response schema
3. WHEN I call `Gemini.APIs.Coordinator.generate_content/2` with any valid generation config option THEN the system SHALL include all provided options in the API request
4. WHEN I use individual keyword arguments for generation config THEN the system SHALL convert them to proper camelCase API format (e.g., `response_mime_type` becomes `responseMimeType`)

### Requirement 2

**User Story:** As a developer, I want the same generation configuration behavior whether I use `Gemini.Generate` or `Gemini.APIs.Coordinator`, so that I can switch between modules without losing functionality.

#### Acceptance Criteria

1. WHEN I call `Gemini.Generate.content/2` with generation config options THEN the system SHALL work correctly (existing behavior)
2. WHEN I call `Gemini.APIs.Coordinator.generate_content/2` with the same generation config options THEN the system SHALL produce identical API requests
3. WHEN I provide a complete `GenerationConfig` struct THEN both modules SHALL handle it identically
4. WHEN I provide individual keyword arguments THEN both modules SHALL convert them to the same API format

### Requirement 3

**User Story:** As a developer, I want comprehensive test coverage that prevents regression of this bug, so that future changes don't break generation configuration handling.

#### Acceptance Criteria

1. WHEN tests are run THEN there SHALL be a test that demonstrates the bug by failing with the current implementation
2. WHEN the fix is implemented THEN the same test SHALL pass
3. WHEN tests are run THEN there SHALL be tests covering both individual keyword arguments and complete GenerationConfig structs
4. WHEN tests are run THEN there SHALL be tests covering all major generation config options including `response_schema`, `response_mime_type`, `temperature`, `max_output_tokens`, `top_p`, and `top_k`