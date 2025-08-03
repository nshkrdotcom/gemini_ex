# Implementation Plan

- [x] 1. Create comprehensive test suite that demonstrates the bug





  - Create test file `test/gemini/apis/coordinator_generation_config_test.exs`
  - Write failing tests that show `response_schema` and other options being dropped
  - Mock HTTP client to capture and verify request bodies
  - Test both individual keyword arguments and complete GenerationConfig structs
  - _Requirements: 3.1, 3.2_

- [x] 1.1 Create HTTP client mock setup


  - Set up Mox-based HTTP client mocking in the test file
  - Create helper functions to capture and inspect request bodies
  - Verify mock can intercept `Gemini.Client.HTTP.post/3` calls
  - _Requirements: 3.1, 3.4_

- [x] 1.2 Write bug demonstration test for individual options


  - Create test that calls `Coordinator.generate_content/2` with `response_schema` option
  - Assert that request body contains `responseSchema` field (this will fail initially)
  - Test other missing options like `response_mime_type`, `stop_sequences`
  - _Requirements: 1.1, 1.4, 3.1_

- [x] 1.3 Write bug demonstration test for GenerationConfig struct


  - Create test that calls `Coordinator.generate_content/2` with complete GenerationConfig
  - Assert that all struct fields are preserved in request body (this will fail initially)
  - Test with `Gemini.chat/1` to verify chat session bug
  - _Requirements: 1.2, 1.3, 3.1_

- [x] 1.4 Write comparison test with working Generate module


  - Create test that compares request bodies from `Generate.content/2` vs `Coordinator.generate_content/2`
  - Demonstrate that Generate works while Coordinator fails with same inputs
  - _Requirements: 2.1, 2.2, 3.1_
-

- [x] 2. Implement key conversion helper functions




  - Add `convert_to_camel_case/1` function to convert snake_case atoms to camelCase strings
  - Add `struct_to_api_map/1` function to convert GenerationConfig struct to API map
  - Add `filter_nil_values/1` function to remove nil values from maps
  - Write unit tests for these helper functions
  - _Requirements: 1.4, 2.4_

- [x] 3. Fix build_generation_config function to handle all options





  - Modify `build_generation_config/1` in `Gemini.APIs.Coordinator`
  - Add support for all GenerationConfig fields: `response_schema`, `response_mime_type`, `stop_sequences`, etc.
  - Use pattern matching to handle each valid option type
  - Convert snake_case keys to camelCase for API compatibility
  - _Requirements: 1.1, 1.4, 2.4_

- [x] 4. Fix build_generate_request to prioritize GenerationConfig struct





  - Modify `build_generate_request/2` in `Gemini.APIs.Coordinator`
  - Check for `:generation_config` option first before building from individual options
  - When GenerationConfig struct is provided, convert it directly to API format
  - Maintain backward compatibility with individual keyword arguments
  - _Requirements: 1.2, 1.3, 2.1, 2.3_

- [x] 5. Verify all tests pass after implementation





  - Run the bug demonstration tests to confirm they now pass
  - Verify that previously failing assertions now succeed
  - Ensure no existing functionality is broken
  - _Requirements: 3.2, 3.3_

- [x] 6. Add comprehensive test coverage for all GenerationConfig fields





  - Test each field individually: `temperature`, `max_output_tokens`, `top_p`, `top_k`, etc.
  - Test complex fields like `response_schema` with actual JSON schema objects
  - Test edge cases like empty arrays and nil values
  - _Requirements: 3.4_

- [x] 7. Create integration tests with real API structure





  - Test end-to-end flow from `Gemini.generate/2` through to HTTP request
  - Test chat session flow with GenerationConfig preservation
  - Verify request structure matches Google Gemini API specification
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 8. Run regression tests to ensure no breaking changes










  - Execute existing test suite to verify no functionality is broken
  - Test backward compatibility with current usage patterns
  - Verify that simple cases (temperature, max_tokens) still work as before
  - _Requirements: 2.1, 2.2, 2.3_