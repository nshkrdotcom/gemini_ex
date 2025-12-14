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
    model: Gemini.Config.get_model(:flash_lite_latest),
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
  {:ok, model_info} = Gemini.get_model(Gemini.Config.get_model(:flash_lite_latest))

  # Count tokens
  {:ok, token_count} = Gemini.count_tokens("Your text", model: Gemini.Config.get_model(:flash_lite_latest))
  ```

  This module provides backward-compatible access to the Gemini API while routing
  requests through the unified coordinator for maximum flexibility and performance.
  """

  alias Gemini.APIs.Coordinator
  alias Gemini.Chat
  alias Gemini.Error
  alias Gemini.Tools
  alias Gemini.Types.Content
  alias Gemini.Types.Response.GenerateContentResponse

  @typedoc """
  Options for content generation and related API calls.

  - `:model` - Model name (string, defaults to configured default model)
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
  Create a cached content resource for reuse across requests.
  """
  @spec create_cache([Content.t()] | [map()] | String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  defdelegate create_cache(contents, opts \\ []), to: Gemini.APIs.ContextCache, as: :create

  @doc "List cached contents."
  @spec list_caches(keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate list_caches(opts \\ []), to: Gemini.APIs.ContextCache, as: :list

  @doc "Get a cached content by name."
  @spec get_cache(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate get_cache(name, opts \\ []), to: Gemini.APIs.ContextCache, as: :get

  @doc "Update cached content TTL/expiry."
  @spec update_cache(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate update_cache(name, opts), to: Gemini.APIs.ContextCache, as: :update

  @doc "Delete cached content."
  @spec delete_cache(String.t(), keyword()) :: :ok | {:error, term()}
  defdelegate delete_cache(name, opts \\ []), to: Gemini.APIs.ContextCache, as: :delete

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
  @spec chat(options()) :: {:ok, Chat.t()}
  def chat(opts \\ []) do
    {:ok, Chat.new(opts)}
  end

  @doc """
  Send a message in a chat session.
  """
  @spec send_message(Chat.t(), String.t()) ::
          {:ok, GenerateContentResponse.t(), Chat.t()} | {:error, Error.t()}
  def send_message(%Chat{} = chat, message) do
    # Add the user's message to the chat history
    updated_chat = Chat.add_turn(chat, "user", message)

    case generate(updated_chat.history, updated_chat.opts) do
      {:ok, response} ->
        # Extract text from response and add model's turn
        case extract_text(response) do
          {:ok, text} ->
            final_chat = Chat.add_turn(updated_chat, "model", text)
            {:ok, response, final_chat}

          {:error, _} ->
            # If we can't extract text, still add the raw response
            final_chat = Chat.add_turn(updated_chat, "model", "")
            {:ok, response, final_chat}
        end

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
  Start a streaming session with automatic tool execution.

  This function provides streaming support for the automatic tool-calling loop.
  When the model returns function calls, they are executed automatically and the
  conversation continues until a final text response is streamed to the subscriber.

  ## Parameters
  - `contents`: String prompt or list of Content structs
  - `opts`: Standard generation options plus:
    - `:turn_limit` - Maximum number of tool-calling turns (default: 10)
    - `:tools` - List of tool declarations (required for tool calling)
    - `:tool_config` - Tool configuration (optional)

  ## Examples

      # Register a tool first
      {:ok, declaration} = Altar.ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Gets weather for a location",
        parameters: %{
          type: "object",
          properties: %{location: %{type: "string"}},
          required: ["location"]
        }
      })
      :ok = Gemini.Tools.register(declaration, &MyApp.get_weather/1)

      # Start streaming with automatic tool execution
      {:ok, stream_id} = Gemini.stream_generate_with_auto_tools(
        "What's the weather in San Francisco?",
        tools: [declaration],
        model: "gemini-flash-lite-latest"
      )

      # Subscribe to receive only the final text response
      :ok = Gemini.subscribe_stream(stream_id)

  ## Returns
  - `{:ok, stream_id}`: Stream started successfully
  - `{:error, term()}`: Error during stream setup
  """
  @spec stream_generate_with_auto_tools(String.t() | [Content.t()], options()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def stream_generate_with_auto_tools(contents, opts \\ []) do
    # Add auto_execute_tools flag to options
    enhanced_opts = Keyword.put(opts, :auto_execute_tools, true)
    Coordinator.stream_generate_content(contents, enhanced_opts)
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
  Generate content with automatic tool execution.

  This function provides a seamless, Python-SDK-like experience by automatically
  handling the tool-calling loop. When the model returns function calls, they are
  executed automatically and the conversation continues until a final text response
  is received.

  ## Parameters
  - `contents`: String prompt or list of Content structs
  - `opts`: Standard generation options plus:
    - `:turn_limit` - Maximum number of tool-calling turns (default: 10)
    - `:tools` - List of tool declarations (required for tool calling)
    - `:tool_config` - Tool configuration (optional)

  ## Examples

      # Register a tool first
      {:ok, declaration} = Altar.ADM.new_function_declaration(%{
        name: "get_weather",
        description: "Gets weather for a location",
        parameters: %{
          type: "object",
          properties: %{location: %{type: "string"}},
          required: ["location"]
        }
      })
      :ok = Gemini.Tools.register(declaration, &MyApp.get_weather/1)

      # Use automatic tool execution
      {:ok, response} = Gemini.generate_content_with_auto_tools(
        "What's the weather in San Francisco?",
        tools: [declaration],
        model: "gemini-flash-lite-latest"
      )

  ## Returns
  - `{:ok, GenerateContentResponse.t()}`: Final text response after all tool calls
  - `{:error, term()}`: Error during generation or tool execution
  """
  @spec generate_content_with_auto_tools(String.t() | [Content.t()], options()) ::
          {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  def generate_content_with_auto_tools(contents, opts \\ []) do
    turn_limit = Keyword.get(opts, :turn_limit, 10)

    # Create initial chat state
    chat = Chat.new(opts)

    # Add user's initial message to chat
    initial_chat =
      case contents do
        text when is_binary(text) -> Chat.add_turn(chat, "user", text)
        content_list when is_list(content_list) -> %{chat | history: content_list}
      end

    # Start the orchestration loop
    orchestrate_tool_loop(initial_chat, turn_limit)
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
  Extract thought signatures from a GenerateContentResponse.

  Gemini 3 models return `thought_signature` fields on parts that must be
  echoed back in subsequent turns to maintain reasoning context.

  ## Parameters
  - `response`: GenerateContentResponse struct

  ## Returns
  - List of thought signature strings found in the response

  ## Examples

      {:ok, response} = Gemini.generate("Complex question", model: "gemini-3-pro-preview")
      signatures = Gemini.extract_thought_signatures(response)
      # => ["sig_abc123", "sig_def456"]

  """
  @spec extract_thought_signatures(GenerateContentResponse.t() | nil) :: [String.t()]
  def extract_thought_signatures(nil), do: []

  def extract_thought_signatures(%GenerateContentResponse{candidates: nil}), do: []

  def extract_thought_signatures(%GenerateContentResponse{candidates: []}), do: []

  def extract_thought_signatures(%GenerateContentResponse{candidates: candidates})
      when is_list(candidates) do
    candidates
    |> Enum.flat_map(fn
      %{content: %{parts: parts}} when is_list(parts) ->
        parts
        |> Enum.filter(&is_map/1)
        |> Enum.map(&Map.get(&1, :thought_signature))
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end)
  end

  def extract_thought_signatures(_), do: []

  # Private orchestrator function that implements the recursive state machine
  @spec orchestrate_tool_loop(Chat.t(), non_neg_integer()) ::
          {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  defp orchestrate_tool_loop(_chat, turn_limit) when turn_limit <= 0 do
    {:error, %Error{type: :turn_limit_exceeded, message: "Maximum tool-calling turns exceeded"}}
  end

  defp orchestrate_tool_loop(chat, turn_limit) do
    # Make API call with current chat history
    case Coordinator.generate_content(chat.history, chat.opts) do
      {:ok, response} ->
        # Check if response contains function calls
        case extract_function_calls_from_response(response) do
          [] ->
            # No function calls - this is the final text response
            {:ok, response}

          function_calls ->
            # Response contains function calls - continue the loop
            # Add model's function call turn to chat history
            updated_chat = Chat.add_turn(chat, "model", function_calls)

            # Execute the function calls
            case Tools.execute_calls(function_calls) do
              {:ok, tool_results} ->
                # Add tool's function response turn to chat history
                final_chat = Chat.add_turn(updated_chat, "tool", tool_results)

                # Recursively continue the loop with decremented turn limit
                orchestrate_tool_loop(final_chat, turn_limit - 1)
            end
        end

      {:error, error} ->
        {:error, error}
    end
  end

  # Helper function to extract function calls from a GenerateContentResponse
  @spec extract_function_calls_from_response(GenerateContentResponse.t()) :: [
          Altar.ADM.FunctionCall.t()
        ]
  defp extract_function_calls_from_response(%GenerateContentResponse{candidates: candidates}) do
    candidates
    |> Enum.flat_map(fn candidate ->
      case candidate do
        %{content: %{parts: parts}} ->
          parts
          |> Enum.filter(fn part ->
            fc = get_value(part, :function_call)
            fc != nil
          end)
          |> Enum.map(fn part ->
            # Convert raw function call data to ADM FunctionCall struct
            # Handle both atom and string keys from API responses
            function_call_data = get_value(part, :function_call)
            name = get_value(function_call_data, :name)
            args = get_value(function_call_data, :args) || %{}

            {:ok, function_call} =
              Altar.ADM.new_function_call(%{
                name: name,
                args: args,
                call_id:
                  name <>
                    "_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
              })

            function_call
          end)

        _ ->
          []
      end
    end)
  end

  # Helper to get value from map with either atom or string key
  defp get_value(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

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

  # Embedding API

  @doc """
  Generate an embedding for the given text content.

  See `t:Gemini.options/0` for available options.

  ## Examples

      {:ok, response} = Gemini.embed_content("What is AI?")
      {:ok, values} = EmbedContentResponse.get_values(response)
  """
  @spec embed_content(String.t(), options()) :: {:ok, map()} | {:error, Error.t()}
  def embed_content(text, opts \\ []) do
    Coordinator.embed_content(text, opts)
  end

  @doc """
  Generate embeddings for multiple texts in a single batch request.

  See `t:Gemini.options/0` for available options.

  ## Examples

      {:ok, response} = Gemini.batch_embed_contents([
        "What is AI?",
        "How does ML work?"
      ])
  """
  @spec batch_embed_contents([String.t()], options()) :: {:ok, map()} | {:error, Error.t()}
  def batch_embed_contents(texts, opts \\ []) do
    Coordinator.batch_embed_contents(texts, opts)
  end

  @doc """
  Submit an asynchronous batch embedding job for production-scale generation.

  Processes large batches with 50% cost savings compared to interactive API.

  See `t:Gemini.options/0` for available options.

  ## Examples

      {:ok, batch} = Gemini.async_batch_embed_contents(
        ["Text 1", "Text 2", "Text 3"],
        display_name: "My Batch",
        task_type: :retrieval_document
      )
  """
  @spec async_batch_embed_contents([String.t()], options()) :: {:ok, map()} | {:error, Error.t()}
  def async_batch_embed_contents(texts, opts \\ []) do
    Coordinator.async_batch_embed_contents(texts, opts)
  end

  @doc """
  Get the current status of an async batch embedding job.

  ## Examples

      {:ok, batch} = Gemini.get_batch_status("batches/abc123")
      IO.puts("State: \#{batch.state}")
  """
  @spec get_batch_status(String.t(), options()) :: {:ok, map()} | {:error, Error.t()}
  def get_batch_status(batch_name, opts \\ []) do
    Coordinator.get_batch_status(batch_name, opts)
  end

  @doc """
  Retrieve embeddings from a completed batch job.

  ## Examples

      {:ok, batch} = Gemini.get_batch_status(batch_id)
      if batch.state == :completed do
        {:ok, embeddings} = Gemini.get_batch_embeddings(batch)
      end
  """
  @spec get_batch_embeddings(map()) :: {:ok, [map()]} | {:error, String.t()}
  def get_batch_embeddings(batch) do
    Coordinator.get_batch_embeddings(batch)
  end

  @doc """
  Poll and wait for batch completion with configurable intervals.

  ## Examples

      {:ok, completed} = Gemini.await_batch_completion(
        batch.name,
        poll_interval: 10_000,
        timeout: 600_000
      )
  """
  @spec await_batch_completion(String.t(), options()) :: {:ok, map()} | {:error, term()}
  def await_batch_completion(batch_name, opts \\ []) do
    Coordinator.await_batch_completion(batch_name, opts)
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
