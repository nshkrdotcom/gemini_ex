defmodule Gemini.MixProject do
  use Mix.Project

  @version "0.9.1"
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
      {:altar, "~> 0.2.0"},

      # Development and testing
      {:ex_doc, "~> 0.40.0", only: :dev, runtime: false},
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev], runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:meck, "~> 1.1.0", only: :test},
      {:supertester, "~> 0.5.1", only: :test},
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
        # Getting Started
        "README.md",

        # Core Features
        "guides/live_api.md",
        "guides/STREAMING.md",
        "guides/function_calling.md",
        "guides/structured_outputs.md",
        "guides/system_instructions.md",
        "guides/interactions.md",

        # Content Generation
        "guides/image_generation.md",
        "guides/video_generation.md",
        "guides/EMBEDDINGS.md",
        "guides/ASYNC_BATCH_EMBEDDINGS.md",

        # File & Data Management
        "guides/files.md",
        "guides/file_search_stores.md",
        "guides/batches.md",
        "guides/operations.md",

        # Authentication & Configuration
        "guides/AUTHENTICATION_SYSTEM.md",
        "guides/adc.md",

        # Advanced Topics
        "guides/rate_limiting.md",
        "guides/tunings.md",
        "guides/AUTOMATIC_TOOL_EXECUTION.md",

        # Architecture & Internals
        "guides/ARCHITECTURE.md",
        "guides/STREAMING_ARCHITECTURE.md",
        "guides/TELEMETRY_IMPLEMENTATION.md",

        # Integration
        "guides/ALTAR_INTEGRATION.md",

        # About
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md"
        ],
        "Core Features": [
          "guides/live_api.md",
          "guides/STREAMING.md",
          "guides/function_calling.md",
          "guides/structured_outputs.md",
          "guides/system_instructions.md",
          "guides/interactions.md"
        ],
        "Content Generation": [
          "guides/image_generation.md",
          "guides/video_generation.md",
          "guides/EMBEDDINGS.md",
          "guides/ASYNC_BATCH_EMBEDDINGS.md"
        ],
        "File & Data Management": [
          "guides/files.md",
          "guides/file_search_stores.md",
          "guides/batches.md",
          "guides/operations.md"
        ],
        "Authentication & Configuration": [
          "guides/AUTHENTICATION_SYSTEM.md",
          "guides/adc.md"
        ],
        "Advanced Topics": [
          "guides/rate_limiting.md",
          "guides/tunings.md",
          "guides/AUTOMATIC_TOOL_EXECUTION.md"
        ],
        "Architecture & Internals": [
          "guides/ARCHITECTURE.md",
          "guides/STREAMING_ARCHITECTURE.md",
          "guides/TELEMETRY_IMPLEMENTATION.md"
        ],
        Integration: [
          "guides/ALTAR_INTEGRATION.md"
        ],
        About: [
          "CHANGELOG.md",
          "LICENSE"
        ]
      ],
      groups_for_modules: [
        "Core API": [Gemini, Gemini.APIs.Coordinator],
        Authentication: [
          Gemini.Auth,
          Gemini.Auth.MultiAuthCoordinator,
          Gemini.Auth.GeminiStrategy,
          Gemini.Auth.VertexStrategy
        ],
        "Live API": [
          Gemini.Live.Session,
          Gemini.Live.Audio,
          Gemini.Live.EphemeralToken
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
          Gemini.Client.HTTPStreaming,
          Gemini.Client.WebSocket
        ],
        "Types - Live": ~r/Gemini\.Types\.Live\..*/,
        "Types & Schemas": [
          Gemini.Types.Content,
          Gemini.Types.Response,
          Gemini.Types.Model,
          Gemini.Types.Request,
          Gemini.Types.ModelArmorConfig,
          Gemini.Types.RegisterFilesConfig,
          Gemini.Types.RegisterFilesResponse
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
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
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
