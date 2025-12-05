# Context Caching Plan QA

- Quick take: Missing-features table is directionally right, but the current implementation has a few additional gaps/bugs that the plan does not call out.

## Confirmed
- CRUD helpers exist in `lib/gemini/apis/context_cache.ex` and responses surface `cachedContentTokenCount` via `UsageMetadata` (`lib/gemini/types/response/generate_content_response.ex:117-130`).
- Generate requests already accept `cached_content` (`lib/gemini/apis/coordinator.ex:788-858`).
- PATCH/DELETE plumbing is present in `lib/gemini/client/http.ex`.

## Corrections / Issues
- Vertex AI paths are currently broken: non-model requests are just appended to the Vertex base URL (`lib/gemini/client/http.ex:266-285`), so `create/list/get/update/delete` hit `https://<location>-aiplatform.googleapis.com/v1/cachedContents` without the required `projects/{project}/locations/{location}` segment from `Gemini.Auth.VertexStrategy` (`lib/gemini/auth/vertex_strategy.ex:86-115`). The existing code is Gemini-only until resource-name expansion is added.
- `create/2` only matches lists (`lib/gemini/apis/context_cache.ex:80-110`); the README example uses a bare string and will raise a function-clause error (`README.md:236-246`).
- Model handling needs normalization: `full_model_name = "models/#{model}"` double-prefixes if callers pass `models/...` or a Vertex resource, and the default model is the alias `gemini-flash-lite-latest` (not an explicit cache-supported version) (`lib/gemini/apis/context_cache.ex:87-103`, `lib/gemini/config.ex:15-44`).
- Content formatting is narrow: `format_parts/1` only converts text/inlineData and leaves tool/function/response/thought/file parts in snake_case structs that won’t serialize to the cache API (`lib/gemini/apis/context_cache.ex:292-309`). Parity work needs to cover those shapes, not just `fileData`.
- Usage metadata normalization only keeps total/cached token counts; any Vertex-only fields called out in the plan do not exist yet (`lib/gemini/apis/context_cache.ex:311-329`).
- Tests don’t exercise payload shaping or name normalization; unit tests only check argument validation and don’t mock HTTP, so coverage for the proposed features is essentially absent (`test/gemini/apis/context_cache_test.exs`).
- Runtime config helper mismatch: `Gemini.configure/2` writes to the `:gemini` app env (`lib/gemini.ex:217-220`), while `Gemini.Config.auth_config/0` reads `:gemini_ex` (`lib/gemini/config.ex:124-170`), so configure/2 won’t affect cache calls unless env vars are set.

## Additional Gaps Not Listed in the Plan
- No per-request auth override for cache endpoints: `Gemini.Client.HTTP` always uses the global config and ignores `:auth`, so multi-auth parity is incomplete.
- Ergonomics differ from Python: there’s no single-content overload (everything must be wrapped in a list), and content formatting is not shared with the generate pipeline.

## Test Status
- Not run (review only).
