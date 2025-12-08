Gemini 3 image preview – gap analysis (Elixir vs python-genai)
==============================================================

Scope
-----
- Focus: why `model: "gemini-3-pro-image-preview:generateContent"` silently falls back to the default model in `gemini_ex`, and what parity gaps exist versus `./python-genai` for the same flow.
- Sources reviewed: `lib/gemini/apis/coordinator.ex`, `lib/gemini/client/http.ex`, `lib/gemini/auth/vertex_strategy.ex`, `lib/gemini/types/common/generation_config.ex`, `python-genai/google/genai/_transformers.py`, `python-genai/google/genai/models.py`, `python-genai/google/genai/types.py`, and relevant python tests/docs.

Broken behavior in gemini_ex
----------------------------
- Model suffix handling drops the caller’s model and silently uses the default: `Coordinator.generate_content/2` always builds `"models/#{model}:generateContent"` (`lib/gemini/apis/coordinator.ex:85-88`). When `model` already contains `:generateContent`, the path becomes `models/gemini-3-pro-image-preview:generateContent:generateContent`.
- `Client.HTTP.extract_model_from_path/1` splits on `:` and only handles the two-part case; any extra segment falls through to `Config.default_model/0` (`lib/gemini/client/http.ex:325-334`). This is what causes the silent fallback to `gemini-flash-lite-latest` instead of raising or using the provided model.
- The same code also double-prefixes if the caller supplies `models/...` or a fully qualified Vertex resource. For example, `model: "models/gemini-3-pro-image-preview"` yields `models/models/gemini-3-pro-image-preview:generateContent`, which then normalizes to `models/gemini-3-pro-image-preview` after a single prefix strip in the Vertex strategy but still leaves an extra `models/` segment in the path (`lib/gemini/auth/vertex_strategy.ex:172-183`).
- No validation guards against invalid model strings (e.g., embedded path traversal, query params, or duplicate endpoints), so malformed input is mutated instead of rejected, leading to confusing behavior rather than an explicit error.

What python-genai does
----------------------
- Explicit model normalization and validation: `t_model/2` (`python-genai/google/genai/_transformers.py:199-222`) prefixes models with `models/` (AI Studio) or `publishers/google/models/` (Vertex) when missing, preserves already-prefixed resource names, and rejects models containing `..`, `?`, or `&` (python tests enforce this).
- Request paths always use the caller’s model; `_generate_content` builds `{model}:generateContent` from the normalized `_url` field without substituting a default (`python-genai/google/genai/models.py:3964-3984`). If the caller incorrectly includes `:generateContent` in the model, the request path double-suffixes and the API will error, making the failure explicit instead of silently falling back.
- Image configuration parity: `ImageConfig` supports `output_mime_type` and `output_compression_quality` in addition to `aspect_ratio` and `image_size` (`python-genai/google/genai/types.py:4467-4498`). `GenerateContentConfig` also carries `http_options` and `should_return_http_response` to control transport-level behavior (`python-genai/google/genai/models.py:3990-3999`).

Gaps and missing implementations (Elixir)
-----------------------------------------
1) Model normalization/validation parity  
- Missing: validation that rejects clearly invalid model strings (`..`, `?`, `&`, duplicate endpoint suffix).  
- Missing: normalization that tolerates already-prefixed resources (`models/...`, `tunedModels/...`, `publishers/...`) and strips a pre-attached `:generateContent` instead of defaulting away from the user’s value.  
- Impact: Requests with a `model` that includes `:generateContent` (or an extra prefix) silently hit `gemini-flash-lite-latest`, reproducing the reported bug.

2) Request path construction robustness  
- `extract_model_from_path/1` cannot parse paths with more than one `:` and falls back to the default model; `extract_endpoint_from_path/1` similarly defaults on extra segments (`lib/gemini/client/http.ex:325-343`).  
- Missing: a safe branch that either (a) parses the leftmost `model` and last `endpoint`, or (b) rejects ambiguous paths. Python’s failure mode is an explicit API error; ours is a silent fallback.

3) Image config feature completeness  
- Missing fields relative to python: `output_mime_type` and `output_compression_quality` in `Gemini.Types.GenerationConfig.ImageConfig` (`lib/gemini/types/common/generation_config.ex`). These are exposed in python for Vertex (documented as unsupported in Gemini API), so callers cannot express them through the Elixir client today.

4) Transport-level per-request controls  
- Python allows `http_options`/`should_return_http_response` via `GenerateContentConfig`; Elixir only exposes top-level opts like `:timeout` and cannot surface raw HTTP responses from a content call. This is a lesser gap but worth noting for parity.

Recommended fixes (ordering mirrors impact)
-------------------------------------------
1) Model handling: normalize or reject  
- Strip any trailing `:generateContent` (and other known endpoints) from the user’s `model` before composing the path, or raise when a model contains an endpoint suffix.  
- Accept already-prefixed resource names without double-prefixing (`models/...`, `tunedModels/...`, `publishers/...`, `projects/.../locations/.../publishers/...`).  
- Add validation akin to python’s `t_model/2` to reject `..`, `?`, `&`, and other obviously bad inputs.

2) Path parsing: stop defaulting on ambiguity  
- Update `extract_model_from_path/1` and `extract_endpoint_from_path/1` to either correctly parse multi-colon paths (use first segment as model, last as endpoint) or return a clear error instead of `Config.default_model/0`.

3) Image config parity  
- Add `output_mime_type` and `output_compression_quality` to `GenerationConfig.ImageConfig`, and include them in request serialization so Vertex users can reach feature parity with python-genai.

4) Optional parity niceties  
- Consider exposing a `http_options`/raw-response flag on `Gemini.generate/2` (or via `GenerationConfig`) if we want full feature alignment with python-genai’s transport controls.
