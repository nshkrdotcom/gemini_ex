# Model catalog and availability

Use `Gemini.list_models/1` with `auth: :gemini` for the Gemini Developer API
used by AI Studio, or `auth: :vertex_ai` for the Vertex publisher catalog.
Follow the response's `next_page_token` until it is absent. Listing a model
does not establish that a project has quota, billing, regional availability,
or permission to invoke it. A Vertex publisher response with no method list
leaves the methods unknown.

The bundled `Gemini.ModelRegistry` provides offline model IDs and capability
metadata. It includes Gemini 4 Neon, Carbon, Hydrogen, and Argon and documented
specialized models. Google may expose a model on just one backend. Review
the [Gemini API catalog](https://aistudio.google.com/docs/models) and
[Vertex model locations](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/locations)
for the backend you use.

Use `gemini-4-neon` or `gemini-4-hydrogen` with `thinking_level: :xhigh` on
supported generation requests. Use the base API ID in GeminiEx. Antigravity
CLI effort suffixes and Orchestrator slugs belong to the separate CLI catalog.
Gemini 4 uses implicit caching. Extended output depends on the API and its
continuation support.

Gemini API generation defaults to `gemini-flash-lite-latest`. Vertex generation
defaults to `gemini-3.5-flash-lite`. Choose a supported location such as
`global` for that model, or explicitly select a supported model for your
configured location. GeminiEx preserves the location you configure.

The November 18, 2026 inventory check found 65 Developer API model IDs.
The configured key completed Flash-Lite and Hydrogen XHigh generation requests.
Neon, Carbon,
and Argon returned quota errors for that key. The configured Vertex project
returned `BILLING_DISABLED`. Model metadata and Vertex geography are backed
by the published catalogs, with live invocation verified per credential.
