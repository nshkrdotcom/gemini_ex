defmodule Gemini do
  @moduledoc """
  # Gemini Elixir Client

  A comprehensive Elixir client for Google's Gemini AI API with dual authentication support,
  advanced streaming capabilities, type safety, and built-in telemetry.

  ## Features

  - **🔐 Dual Authentication**: Seamless support for both Gemini API keys and Vertex AI OAuth/Service Accounts
  - **⚡ Advanced Streaming**: Production-grade Server-Sent Events streaming with real-time processing
  - **🛡️ Type Safety**: Complete type definitions with runtime validation
  - **📊 Built-in Telemetry**: Comprehensive observability and metrics out of the box
  - **💬 Chat Sessions**: Multi-turn conversation management with state persistence
  - **🎭 Multimodal**: Full support for text, image, audio, and video content
  - **🚀 Production Ready**: Robust error handling, retry logic, and performance optimizations

  ## Quick Start

  ### Installation

  Add to your `mix.exs`:

  ```elixir
  def deps do
    [
      {:gemini, "~> 0.0.1"}
    ]
  end
  ```

  ### Basic Configuration

  Configure your API key in `config/runtime.exs`:

  ```elixir
  import Config

  config :gemini,
    api_key: System.get_env("GEMINI_API_KEY")
  ```

  Or set the environment variable:

  ```bash
  export GEMINI_API_KEY="your_api_key_here"
  ```

  ### Simple Usage

  ```elixir
  # Basic text generation
  {:ok, response} = Gemini.generate("Tell me about Elixir programming")
  {:ok, text} = Gemini.extract_text(response)
  IO.puts(text)

  # With options
  {:ok, response} = Gemini.generate("Explain quantum computing", [
    model: "gemini-1.5-pro",
    temperature: 0.7,
    max_output_tokens: 1000
  ])
  ```

  ### Streaming

  ```elixir
  # Start a streaming session
  {:ok, stream_id} = Gemini.stream_generate("Write a long story", [
    on_chunk: fn chunk -> IO.write(chunk) end,
    on_complete: fn -> IO.puts("\\n✅ Complete!") end
  ])
  ```

  ## Authentication

  This client supports two authentication methods:

  ### 1. Gemini API Key (Simple)

  Best for development and simple applications:

  ```elixir
  # Environment variable (recommended)
  export GEMINI_API_KEY="your_api_key"

  # Application config
  config :gemini, api_key: "your_api_key"

  # Per-request override
  Gemini.generate("Hello", api_key: "specific_key")
  ```

  ### 2. Vertex AI (Production)

  Best for production Google Cloud applications:

  ```elixir
  # Service Account JSON file
  export VERTEX_SERVICE_ACCOUNT="/path/to/service-account.json"
  export VERTEX_PROJECT_ID="your-gcp-project"
  export VERTEX_LOCATION="us-central1"

  # Application config
  config :gemini, :auth,
    type: :vertex_ai,
    credentials: %{
      service_account_key: System.get_env("VERTEX_SERVICE_ACCOUNT"),
      project_id: System.get_env("VERTEX_PROJECT_ID"),
      location: "us-central1"
    }
  ```

  ## Error Handling

  The client provides detailed error information with recovery suggestions:

  ```elixir
  case Gemini.generate("Hello world") do
    {:ok, response} ->
      {:ok, text} = Gemini.extract_text(response)

    {:error, %Gemini.Error{type: :rate_limit} = error} ->
      IO.puts("Rate limited. Retry after: \#{error.retry_after}")

    {:error, %Gemini.Error{type: :authentication} = error} ->
      IO.puts("Auth error: \#{error.message}")

    {:error, error} ->
      IO.puts("Unexpected error: \#{inspect(error)}")
  end
  ```

  ## Advanced Features

  ### Multimodal Content

  ```elixir
  content = [
    %{type: "text", text: "What's in this image?"},
    %{type: "image", source: %{type: "base64", data: base64_image}}
  ]

  {:ok, response} = Gemini.generate(content)
  ```

  ### Model Management

  ```elixir
  # List available models
  {:ok, models} = Gemini.list_models()

  # Get model details
  {:ok, model_info} = Gemini.get_model("gemini-1.5-pro")

  # Count tokens
  {:ok, token_count} = Gemini.count_tokens("Your text", model: "gemini-1.5-pro")
  ```

  This module provides backward-compatible access to the Gemini API while routing
  requests through the unified coordinator for maximum flexibility and performance.
  """

  alias Gemini.APIs.Coordinator
  alias Gemini.Error
  alias Gemini.Types.Content
  alias Gemini.Types.Response.GenerateContentResponse

  @typedoc """
  Options for content generation and related API calls.

  - `:model` - Model name (string, defaults to "gemini-2.0-flash")
  - `:generation_config` - GenerationConfig struct (`Gemini.Types.GenerationConfig.t()`)
  - `:safety_settings` - List of SafetySetting structs (`[Gemini.Types.SafetySetting.t()]`)
  - `:system_instruction` - System instruction as Content struct or string (`Gemini.Types.Content.t() | String.t() | nil`)
  - `:tools` - List of tool definitions (`[map()]`)
  - `:tool_config` - Tool configuration (`map() | nil`)
  - `:api_key` - Override API key (string)
  - `:auth` - Authentication strategy (`:gemini | :vertex_ai`)
  - `:temperature` - Generation temperature (float, 0.0-1.0)
  - `:max_output_tokens` - Maximum tokens to generate (non_neg_integer)
  - `:top_p` - Top-p sampling parameter (float)
  - `:top_k` - Top-k sampling parameter (non_neg_integer)
  """
  @type options :: [
          model: String.t(),
          generation_config: Gemini.Types.GenerationConfig.t() | nil,
          safety_settings: [Gemini.Types.SafetySetting.t()],
          system_instruction: Gemini.Types.Content.t() | String.t() | nil,
          tools: [map()],
          tool_config: map() | nil,
          api_key: String.t(),
          auth: :gemini | :vertex_ai,
          temperature: float(),
          max_output_tokens: non_neg_integer(),
          top_p: float(),
          top_k: non_neg_integer()
        ]

  @doc """
  Configure authentication for the client.

  ## Examples

      # Gemini API
      Gemini.configure(:gemini, %{api_key: "your_api_key"})

      # Vertex AI
      Gemini.configure(:vertex_ai, %{
        service_account_key: "/path/to/key.json",
        project_id: "your-project",
        location: "us-central1"
      })
  """
  @spec configure(atom(), map()) :: :ok
  def configure(auth_type, credentials) do
    Application.put_env(:gemini, :auth, %{type: auth_type, credentials: credentials})
    :ok
  end

  @doc """
  Generate content using the configured authentication.

  See `t:Gemini.options/0` for available options.
  """
  @spec generate(String.t() | [Content.t()], options()) ::
          {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  def generate(contents, opts \\ []) do
    Coordinator.generate_content(contents, opts)
  end

  @doc """
  Generate text content and return only the text.

  See `t:Gemini.options/0` for available options.
  """
  @spec text(String.t() | [Content.t()], options()) :: {:ok, String.t()} | {:error, Error.t()}
  def text(contents, opts \\ []) do
    case Coordinator.generate_content(contents, opts) do
      {:ok, response} -> Coordinator.extract_text(response)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  List available models.

  See `t:Gemini.options/0` for available options.
  """
  @spec list_models(options()) :: {:ok, map()} | {:error, Error.t()}
  def list_models(opts \\ []) do
    Coordinator.list_models(opts)
  end

  @doc """
  Get information about a specific model.
  """
  @spec get_model(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_model(model_name) do
    Coordinator.get_model(model_name)
  end

  @doc """
  Count tokens in the given content.

  See `t:Gemini.options/0` for available options.
  """
  @spec count_tokens(String.t() | [Content.t()], options()) :: {:ok, map()} | {:error, Error.t()}
  def count_tokens(contents, opts \\ []) do
    Coordinator.count_tokens(contents, opts)
  end

  @doc """
  Start a new chat session.

  See `t:Gemini.options/0` for available options.
  """
  @spec chat(options()) :: {:ok, map()}
  def chat(opts \\ []) do
    {:ok, %{history: [], opts: opts}}
  end

  @doc """
  Send a message in a chat session.
  """
  @spec send_message(map(), String.t()) ::
          {:ok, GenerateContentResponse.t(), map()} | {:error, Error.t()}
  def send_message(chat, message) do
    contents = [Content.text(message)]

    case generate(contents, chat.opts) do
      {:ok, response} ->
        updated_chat = %{
          chat
          | history:
              chat.history ++
                [
                  %{role: "user", content: message},
                  %{role: "model", content: response}
                ]
        }

        {:ok, response, updated_chat}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Start a managed streaming session.

  See `t:Gemini.options/0` for available options.
  """
  @spec start_stream(String.t() | [Content.t()], options()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def start_stream(contents, opts \\ []) do
    Coordinator.stream_generate_content(contents, opts)
  end

  @doc """
  Subscribe to streaming events.
  """
  @spec subscribe_stream(String.t()) :: :ok | {:error, Error.t()}
  def subscribe_stream(stream_id) do
    Coordinator.subscribe_stream(stream_id, self())
  end

  @doc """
  Get stream status.
  """
  @spec get_stream_status(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_stream_status(stream_id) do
    Coordinator.stream_status(stream_id)
  end

  @doc """
  Extract text from a GenerateContentResponse or raw streaming data.
  """
  @spec extract_text(GenerateContentResponse.t() | map()) ::
          {:ok, String.t()} | {:error, String.t()}
  def extract_text(%GenerateContentResponse{
        candidates: [%{content: %{parts: [%{text: text} | _]}} | _]
      }) do
    {:ok, text}
  end

  def extract_text(%GenerateContentResponse{candidates: []}) do
    {:error, "No candidates in response"}
  end

  def extract_text(%GenerateContentResponse{}) do
    {:error, "No text content found in response"}
  end

  # Handle raw streaming data format
  def extract_text(%{"candidates" => [%{"content" => %{"parts" => parts}} | _]}) do
    text =
      parts
      |> Enum.find(&Map.has_key?(&1, "text"))
      |> case do
        %{"text" => text} -> text
        _ -> ""
      end

    {:ok, text}
  end

  def extract_text(_), do: {:error, "Invalid response format"}

  @doc """
  Check if a model exists.
  """
  @spec model_exists?(String.t()) :: {:ok, boolean()}
  def model_exists?(model_name) do
    case get_model(model_name) do
      {:ok, _model} -> {:ok, true}
      {:error, _} -> {:ok, false}
    end
  end

  @doc """
  Generate content with streaming response (synchronous collection).

  See `t:Gemini.options/0` for available options.
  """
  @spec stream_generate(String.t() | [Content.t()], options()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def stream_generate(contents, opts \\ []) do
    case start_stream(contents, opts) do
      {:ok, stream_id} ->
        :ok = subscribe_stream(stream_id)
        collect_stream_responses(stream_id, [])

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Start the streaming manager (for compatibility).
  """
  @spec start_link() :: {:ok, pid()} | {:error, term()}
  def start_link do
    # The UnifiedManager is started automatically with the application
    # This function is for compatibility with tests
    case Process.whereis(Gemini.Streaming.UnifiedManager) do
      nil -> {:error, :not_started}
      pid -> {:ok, pid}
    end
  end

  # Helper function to collect streaming responses
  defp collect_stream_responses(stream_id, acc) do
    receive do
      {:stream_event, ^stream_id, %{type: :data, data: data}} ->
        collect_stream_responses(stream_id, [data | acc])

      {:stream_complete, ^stream_id} ->
        {:ok, Enum.reverse(acc)}

      {:stream_error, ^stream_id, error} ->
        {:error, error}
    after
      30_000 ->
        {:error, "Stream timeout"}
    end
  end
end
