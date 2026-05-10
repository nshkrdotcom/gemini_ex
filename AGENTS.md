# Repository Guidelines

## Project Structure
- `lib/` contains the GeminiEx runtime, client, auth, streaming, Live API, and type modules.
- `test/` contains ExUnit coverage; live tests are tagged and skipped by default unless credentials are explicitly provided.
- `guides/`, `examples/`, `README.md`, and `CHANGELOG.md` must stay aligned with public API and auth behavior.
- `doc/` is generated output and should not be edited.

## Dependency Sources
- Dependency source selection is handled by `build_support/dependency_sources.exs` and `build_support/dependency_sources.config.exs`.
- Local dependency overrides use `.dependency_sources.local.exs`; do not commit that file.
- Repos with no internal dependencies keep an empty manifest.
- Dependency source selection must not use environment variables.
- This repo is not a Weld consumer in this pass and must not receive a blind Weld dependency. Weld verification is limited to discovered Weld consumers.

## Runtime Environment
- Runtime application code under `lib/**` must not call direct OS env APIs such as `System.get_env`, `System.fetch_env`, `System.put_env`, or `System.delete_env`.
- Runtime and deployment env reads belong in `config/runtime.exs` or an explicit `Config.Provider`.
- Runtime modules read materialized values through `Gemini.Env`, application config, or explicit caller options.
- Tests may use `Gemini.Env` to mutate the materialized app-env boundary for SDK compatibility and config-boundary checks.
- Live provider checks must run through `~/scripts/with_bash_secrets <command>` and must not print secrets.

## Build And QC
- Install deps: `mix deps.get`
- Format: `mix format`
- Compile with warnings as errors: `mix compile --warnings-as-errors`
- Test: `mix test`
- Lint: `mix credo --strict`
- Docs: `mix docs --warnings-as-errors`
- Dialyzer: `mix dialyzer`

## Coding Style
- Use idiomatic Elixir with 2-space indentation and pattern-matching-friendly APIs.
- Public modules and functions should have docs when they are part of the supported surface.
- Prefer explicit options/config structs over ambient process state.
