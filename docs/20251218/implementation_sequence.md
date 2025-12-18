# Implementation Sequence - December 18, 2025

## Goals

Deliver full parity with:
- Python SDK changes in commits 436ca2e1..f16142bc (v1.56.0)
- Official Gemini docs captured in docs/20251218/
- Additional official docs: Computer Use API and Deep Research Agent

This plan is ordered to minimize breakage, keep high-visibility features first, and reduce churn.

## Inputs

- docs/20251218/porting_spec.md
- docs/20251218/docs_models.md
- docs/20251218/docs_thinking.md
- docs/20251218/docs_structured_outputs.md
- Official docs for Computer Use and Deep Research (not yet in docs/20251218)

## Sequence (Concrete Steps)

1. Model registry expansion (foundational)
   - Update lib/gemini/config.ex to include all model IDs from docs_models.md and new preview models:
     - gemini-3-flash-preview
     - gemini-2.0-flash-001
     - gemini-2.0-flash-exp
     - gemini-2.0-flash-lite-001
     - gemini-2.5-flash-image
     - gemini-2.5-flash-image-preview
     - gemini-2.5-flash-preview-09-2025
     - gemini-2.5-flash-lite-preview-09-2025
     - gemini-2.5-flash-native-audio-preview-09-2025
     - gemini-2.5-flash-native-audio-preview-12-2025
     - gemini-2.5-computer-use-preview-10-2025
     - deep-research-pro-preview-12-2025
   - Update lib/gemini/apis/context_cache.ex model list if it uses a hardcoded allowlist.

2. Usage token rename (breaking change)
   - Update lib/gemini/types/interactions/usage.ex:
     - total_reasoning_tokens -> total_thought_tokens
     - from_api and to_api field mapping
   - Add unit test for parsing and serialization.

3. Thinking levels (Gemini 3)
   - Update lib/gemini/types/enums.ex ThinkingLevel:
     - Add :minimal and :unspecified support
     - Ensure from_api accepts both upper and lower case forms
   - Update lib/gemini/types/common/generation_config.ex ThinkingConfig type
   - Update lib/gemini/validation/thinking_config.ex validation for :minimal and :medium
   - Update lib/gemini/apis/coordinator.ex convert_thinking_level/1 and map handling
   - Update lib/gemini/types/interactions/config.ex docs for ThinkingLevel values
   - Add unit tests for new levels and conversion.

4. Media resolution ULTRA_HIGH
   - Update lib/gemini/types/common/media_resolution.ex to include media_resolution_ultra_high
   - Ensure to_api/from_api mappings cover MEDIA_RESOLUTION_ULTRA_HIGH
   - Interactions content already accepts string values; no change required unless you want a typed union.
   - Add unit tests for the enum.

5. Interactions schema cleanup
   - Remove object field from lib/gemini/types/interactions/interaction.ex
   - Update from_api/to_api accordingly
   - Add unit test to ensure object is not present

6. Structured outputs: response_json_schema
   - Add response_json_schema to lib/gemini/types/common/generation_config.ex
   - Update lib/gemini/apis/coordinator.ex build_generation_config/1 to map to responseJsonSchema
   - Update structured_json/2 helper to optionally target response_json_schema if desired
   - Add tests that assert responseJsonSchema mapping

7. Built-in tools for GenerateContent
   - Extend lib/gemini/types/tool_serialization.ex to support:
     - googleSearch
     - urlContext
     - codeExecution
     - atom shorthand (optional)
   - Ensure output shape matches docs_structured_outputs.md examples
   - Add tests for built-in tool serialization

8. Interactions Vertex path fix
   - Update lib/gemini/apis/interactions.ex to build get/cancel/delete paths with project/location
     for Vertex AI, mirroring Python commit 3472650
   - Add tests for Vertex Interactions path building

9. PersonGeneration alignment
   - Align values with Python: ALLOW_ALL, ALLOW_ADULT, ALLOW_NONE
   - Update lib/gemini/types/generation/image.ex type and conversion helpers
   - Ensure Gemini API converter rejects person_generation, Vertex converter maps it

10. Veo 3.x video generation
    - Update lib/gemini/apis/videos.ex with Veo 3.x model IDs
    - Add fields in lib/gemini/types/generation/video.ex:
      - image (image-to-video)
      - last_frame
      - reference_images (VideoGenerationReferenceImage)
      - video (extension)
      - resolution (720p, 1080p)
    - Add Gemini API predictLongRunning endpoint support alongside Vertex
    - Add tests for request payload mapping

11. Computer Use API (OUT OF SCOPE)
    - No implementation work planned.

12. Deep Research Agent (VERIFY ONLY)
    - Confirm existing models/types/examples align with official docs.
    - If discrepancies exist, document and fix.

## Testing Sequence

- Unit tests for:
  - Usage token rename
  - ThinkingLevel conversion
  - MediaResolution ULTRA_HIGH
  - response_json_schema conversion
  - Built-in tool serialization
  - Interactions Vertex path builder
- Integration tests (if present) for:
  - GenerateContent with built-in tools + structured outputs
  - Interactions create/get/cancel/delete on Vertex path format
  - Video generation payload construction

## Order Rationale

- Models and enums first to unblock downstream validation.
- GenerateContent changes before Interactions path fixes and video, to unblock core features.
- Deep Research verification last, pending official schemas.

## Open Inputs Needed

- Official Computer Use API spec (fields, payload examples)
- Official Deep Research Agent spec (fields, output schema)

## Short Checklist

- [ ] Models updated per docs_models.md
- [ ] Token rename + thinking levels + media resolution done with tests
- [ ] Structured outputs + built-in tools done with tests
- [ ] Interactions path fix tested
- [ ] Veo 3.x updates + Gemini API support tested
- [ ] Deep Research verified (no Computer Use changes)
- [ ] README/guides/examples updated
- [ ] Version bump + CHANGELOG entry (2025-12-18)
- [ ] All tests pass, no warnings, no dialyzer issues
