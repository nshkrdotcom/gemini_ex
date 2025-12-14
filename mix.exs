defmodule Gemini.MixProject do
  use Mix.Project

  @version "0.8.4"
  @source_url "https://github.com/nshkrdotcom/gemini_ex"

  def project do
    [
      app: :gemini_ex,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      name: "GeminiEx",
      source_url: @source_url,
      homepage_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Gemini.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:req, "~> 0.5.10"},
      {:jason, "~> 1.4.4"},
      {:typed_struct, "~> 0.3.0"},
      {:joken, "~> 2.6.2"},
      {:telemetry, "~> 1.3.0"},
      {:gun, "~> 2.1"},

      # ALTAR ADM - tool contract dependency
      {:altar, "~> 0.1.2"},

      # Development and testing
      {:ex_doc, "~> 0.38.2", only: :dev, runtime: false},
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev], runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:meck, "~> 0.9", only: :test},
      {:supertester, "~> 0.3.1", only: :test},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp description do
    """
    Comprehensive Elixir client for Google's Gemini AI API with dual authentication,
    embeddings with MRL, streaming, type safety, and built-in telemetry for production applications.
    """
  end

  defp docs do
    [
      main: "readme",
      name: "Gemini",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/logo.svg",
      extras: [
        "README.md",
        "ALTAR_INTEGRATION.md",
        "ARCHITECTURE.md",
        "AUTHENTICATION_SYSTEM.md",
        "STREAMING.md",
        "STREAMING_ARCHITECTURE.md",
        "TELEMETRY_IMPLEMENTATION.md",
        "AUTOMATIC_TOOL_EXECUTION.md",
        "examples/EMBEDDINGS.md",
        "examples/ASYNC_BATCH_EMBEDDINGS.md",
        "docs/guides/interactions.md",
        "docs/guides/structured_outputs.md",
        "docs/guides/rate_limiting.md",
        "docs/guides/files.md",
        "docs/guides/batches.md",
        "docs/guides/operations.md",
        "docs/guides/function_calling.md",
        "docs/guides/system_instructions.md",
        "docs/guides/live_api.md",
        "docs/guides/tunings.md",
        "docs/guides/file_search_stores.md",
        "docs/guides/adc.md",
        "docs/guides/image_generation.md",
        "docs/guides/video_generation.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Guides: ["README.md", "ALTAR_INTEGRATION.md"],
        Features: [
          "AUTOMATIC_TOOL_EXECUTION.md",
          "examples/EMBEDDINGS.md",
          "examples/ASYNC_BATCH_EMBEDDINGS.md",
          "docs/guides/interactions.md",
          "docs/guides/structured_outputs.md",
          "docs/guides/rate_limiting.md",
          "docs/guides/files.md",
          "docs/guides/batches.md",
          "docs/guides/operations.md",
          "docs/guides/function_calling.md",
          "docs/guides/system_instructions.md",
          "docs/guides/live_api.md",
          "docs/guides/tunings.md",
          "docs/guides/file_search_stores.md",
          "docs/guides/adc.md",
          "docs/guides/image_generation.md",
          "docs/guides/video_generation.md"
        ],
        Architecture: [
          "ARCHITECTURE.md",
          "AUTHENTICATION_SYSTEM.md",
          "STREAMING_ARCHITECTURE.md"
        ],
        Implementation: [
          "STREAMING.md",
          "TELEMETRY_IMPLEMENTATION.md"
        ],
        "Release Notes": ["CHANGELOG.md"]
      ],
      groups_for_modules: [
        "Core API": [Gemini, Gemini.APIs.Coordinator],
        Authentication: [
          Gemini.Auth,
          Gemini.Auth.MultiAuthCoordinator,
          Gemini.Auth.GeminiStrategy,
          Gemini.Auth.VertexStrategy
        ],
        Streaming: [
          Gemini.Streaming.UnifiedManager,
          Gemini.Streaming.StateManager,
          Gemini.SSE.Parser,
          Gemini.SSE.EventDispatcher
        ],
        "HTTP Client": [
          Gemini.Client,
          Gemini.Client.HTTP,
          Gemini.Client.HTTPStreaming
        ],
        "Types & Schemas": [
          Gemini.Types.Content,
          Gemini.Types.Response,
          Gemini.Types.Model,
          Gemini.Types.Request
        ],
        Configuration: [Gemini.Config],
        "Error Handling": [Gemini.Error],
        Utilities: [Gemini.Utils, Gemini.Telemetry]
      ],
      before_closing_head_tag: fn
        :html ->
          """
          <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
          <script>
            let initialized = false;

            window.addEventListener("exdoc:loaded", () => {
              if (!initialized) {
                mermaid.initialize({
                  startOnLoad: false,
                  theme: document.body.className.includes("dark") ? "dark" : "default"
                });
                initialized = true;
              }

              let id = 0;
              for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
                const preEl = codeEl.parentElement;
                const graphDefinition = codeEl.textContent;
                const graphEl = document.createElement("div");
                const graphId = "mermaid-graph-" + id++;
                mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
                  graphEl.innerHTML = svg;
                  bindFunctions?.(graphEl);
                  preEl.insertAdjacentElement("afterend", graphEl);
                  preEl.remove();
                });
              }
            });
          </script>
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("data-domain", "hexdocs.pm");
              document.head.appendChild(script);
            }
          </script>
          """

        _ ->
          ""
      end
    ]
  end

  defp package do
    [
      name: "gemini_ex",
      description: description(),
      files:
        ~w(lib mix.exs README.md ALTAR_INTEGRATION.md ARCHITECTURE.md AUTHENTICATION_SYSTEM.md STREAMING.md STREAMING_ARCHITECTURE.md TELEMETRY_IMPLEMENTATION.md CHANGELOG.md LICENSE assets docs/guides),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Online documentation" => "https://hexdocs.pm/gemini_ex",
        "ALTAR Integration Story" => "https://hexdocs.pm/gemini_ex/altar_integration.html",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["nshkrdotcom"],
      exclude_patterns: [
        "priv/plts",
        ".DS_Store"
      ]
    ]
  end
end
