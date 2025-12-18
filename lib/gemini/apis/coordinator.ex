defmodule Gemini.APIs.Coordinator do
  @moduledoc """
  Coordinates API calls across different authentication strategies and endpoints.

  Provides a unified interface that can route requests to either Gemini API or Vertex AI
  based on configuration, while maintaining the same interface.

  This module acts as the main entry point for all Gemini API operations,
  automatically handling authentication strategy selection and request routing.

  ## Features

  - Unified API for content generation across auth strategies
  - Automatic auth strategy selection based on configuration
  - Per-request auth strategy override capability
  - Consistent error handling and response format
  - Support for both streaming and non-streaming operations
  - Model listing and token counting functionality

  ## Usage

      # Use default auth strategy
      {:ok, response} = Coordinator.generate_content("Hello world")

      # Override auth strategy for specific request
      {:ok, response} = Coordinator.generate_content("Hello world", auth: :vertex_ai)

      # Start streaming with specific auth
      {:ok, stream_id} = Coordinator.stream_generate_content("Tell me a story", auth: :gemini)

  See `t:Gemini.options/0` in `Gemini` for the canonical list of options.
  """

  alias Gemini.Config
  alias Gemini.Client.HTTP
  alias Gemini.Error
  alias Gemini.Streaming.UnifiedManager
  alias Gemini.Types.Request.GenerateContentRequest
  alias Gemini.Types.Request.{EmbedContentRequest, BatchEmbedContentsRequest}
  alias Gemini.Types.Request.{InlinedEmbedContentRequest, InlinedEmbedContentRequests}
  alias Gemini.Types.Request.{InputEmbedContentConfig, EmbedContentBatch}
  alias Gemini.Types.Response.{GenerateContentResponse, ListModelsResponse}
  alias Gemini.Types.Response.{EmbedContentResponse, BatchEmbedContentsResponse}
  alias Gemini.Types.Response.{InlinedEmbedContentResponses, ContentEmbedding}
  alias Gemini.Types.Content
  alias Gemini.Types.ToolSerialization
  alias Gemini.Types.{FileData, FunctionResponse, MediaResolution, Modality, SpeechConfig}
  alias Gemini.Validation.ThinkingConfig, as: ThinkingConfigValidation

  @type auth_strategy :: :gemini | :vertex_ai
  @type request_opts :: keyword()
  @type api_result(t) :: {:ok, t} | {:error, term()}

  # Content Generation API

  @doc """
  Generate content using the specified model and input.

  See `t:Gemini.options/0` for available options.

  ## Parameters
  - `input`: String prompt or GenerateContentRequest struct
  - `opts`: Options including model, auth strategy, and generation config

  ## Examples

      # Simple text generation
      {:ok, response} = Coordinator.generate_content("What is AI?")

      # With specific model and auth
      {:ok, response} = Coordinator.generate_content(
        "Explain quantum computing",
        model: Gemini.Config.get_model(:flash_lite_latest),
        auth: :vertex_ai,
        temperature: 0.7
      )

      # Using request struct
      request = %GenerateContentRequest{...}
      {:ok, response} = Coordinator.generate_content(request)
  """
  @spec generate_content(
          String.t() | [Content.t()] | GenerateContentRequest.t(),
          Gemini.options()
        ) ::
          api_result(GenerateContentResponse.t())
  def generate_content(input, opts \\ []) do
    model = opts |> Keyword.get(:model, Config.default_model()) |> normalize_model_option()
    path = "#{model}:generateContent"

    # ADR-0001: Estimate tokens on original input BEFORE building the request
    # This runs on supported input types (string, Content list) before normalization
    opts_with_estimation = inject_token_estimation(input, opts)

    with :ok <- validate_thinking_config_opts(opts_with_estimation, model),
         {:ok, request} <- build_generate_request(input, opts_with_estimation),
         {:ok, response} <- HTTP.post(path, request, opts_with_estimation) do
      parse_generate_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stream content generation with real-time response chunks.

  See `t:Gemini.options/0` for available options.

  ## Parameters
  - `input`: String prompt or GenerateContentRequest struct
  - `opts`: Options including model, auth strategy, and generation config

  ## Returns
  - `{:ok, stream_id}`: Stream started successfully
  - `{:error, reason}`: Failed to start stream

  After starting the stream, subscribe to receive events:

      {:ok, stream_id} = Coordinator.stream_generate_content("Tell me a story")
      :ok = Coordinator.subscribe_stream(stream_id)

      # Handle incoming messages
      receive do
        {:stream_event, ^stream_id, event} ->
          IO.inspect(event, label: "Stream Event")
        {:stream_complete, ^stream_id} ->
          IO.puts("Stream completed")
        {:stream_error, ^stream_id, stream_error} ->
          IO.puts("Stream error: \#{inspect(stream_error)}")
      end

  ## Examples

      # Basic streaming
      {:ok, stream_id} = Coordinator.stream_generate_content("Write a poem")

      # With specific configuration
      {:ok, stream_id} = Coordinator.stream_generate_content(
        "Explain machine learning",
        model: Gemini.Config.get_model(:flash_lite_latest),
        auth: :gemini,
        temperature: 0.8,
        max_output_tokens: 1000
      )
  """
  @spec stream_generate_content(String.t() | GenerateContentRequest.t(), Gemini.options()) ::
          api_result(String.t())
  def stream_generate_content(input, opts \\ []) do
    model = opts |> Keyword.get(:model, Config.default_model()) |> normalize_model_option()

    # ADR-0001: Estimate tokens on original input BEFORE building the request
    opts_with_estimation = inject_token_estimation(input, opts)

    with :ok <- validate_thinking_config_opts(opts_with_estimation, model),
         {:ok, request_body} <- build_generate_request(input, opts_with_estimation) do
      # Pass through the auto_execute_tools option to the UnifiedManager
      UnifiedManager.start_stream(model, request_body, opts_with_estimation)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Subscribe to a streaming content generation.

  ## Parameters
  - `stream_id`: ID of the stream to subscribe to
  - `subscriber_pid`: Process to receive stream events (defaults to current process)

  ## Examples

      {:ok, stream_id} = Coordinator.stream_generate_content("Hello")
      :ok = Coordinator.subscribe_stream(stream_id)

      # In a different process
      :ok = Coordinator.subscribe_stream(stream_id, target_pid)
  """
  @spec subscribe_stream(String.t(), pid()) :: :ok | {:error, term()}
  def subscribe_stream(stream_id, subscriber_pid \\ self()) do
    UnifiedManager.subscribe(stream_id, subscriber_pid)
  end

  @doc """
  Unsubscribe from a streaming content generation.
  """
  @spec unsubscribe_stream(String.t(), pid()) :: :ok | {:error, term()}
  def unsubscribe_stream(stream_id, subscriber_pid \\ self()) do
    UnifiedManager.unsubscribe(stream_id, subscriber_pid)
  end

  @doc """
  Stop a streaming content generation.
  """
  @spec stop_stream(String.t()) :: :ok | {:error, term()}
  def stop_stream(stream_id) do
    UnifiedManager.stop_stream(stream_id)
  end

  @doc """
  Get the status of a streaming content generation.
  """
  @spec stream_status(String.t()) :: {:ok, atom()} | {:error, term()}
  def stream_status(stream_id) do
    UnifiedManager.stream_status(stream_id)
  end

  # Model Management API

  @doc """
  List available models for the specified authentication strategy.

  See `t:Gemini.options/0` for available options.

  ## Parameters
  - `opts`: Options including auth strategy and pagination

  ## Options
  - `:auth`: Authentication strategy (`:gemini` or `:vertex_ai`)
  - `:page_size`: Number of models per page
  - `:page_token`: Pagination token for next page

  ## Examples

      # List models with default auth
      {:ok, models_response} = Coordinator.list_models()

      # List models with specific auth strategy
      {:ok, models_response} = Coordinator.list_models(auth: :vertex_ai)

      # With pagination
      {:ok, models_response} = Coordinator.list_models(
        auth: :gemini,
        page_size: 50,
        page_token: "next_page_token"
      )
  """
  @spec list_models(Gemini.options()) :: api_result(ListModelsResponse.t())
  def list_models(opts \\ []) do
    path = "models"

    with {:ok, response} <- HTTP.get(path, opts) do
      parse_models_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get information about a specific model.

  See `t:Gemini.options/0` for available options.

  ## Parameters
  - `model_name`: Name of the model to retrieve
  - `opts`: Options including auth strategy

  ## Examples

      {:ok, model} = Coordinator.get_model(Gemini.Config.get_model(:flash_lite_latest))
      {:ok, model} = Coordinator.get_model("gemini-2.5-pro", auth: :vertex_ai)
  """
  @spec get_model(String.t(), Gemini.options()) :: api_result(map())
  def get_model(model_name, opts \\ []) do
    path = "models/#{model_name}"

    case HTTP.get(path, opts) do
      {:ok, response} ->
        # Normalize response to use atom keys for common fields
        normalized_response = normalize_model_response(response)
        {:ok, normalized_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Embedding API

  @doc """
  Generate an embedding for the given text content.

  Uses the appropriate embedding model based on detected authentication:
  - **Gemini API**: `gemini-embedding-001` (3072 dimensions, task type parameter)
  - **Vertex AI**: `embeddinggemma` (768 dimensions, prompt prefix formatting)

  See `t:Gemini.options/0` for available options.

  ## Parameters

  - `text`: String content to embed
  - `opts`: Options including model, auth strategy, and embedding-specific parameters

  ## Options

  - `:model`: Embedding model to use (default: auto-detected based on auth)
  - `:auth`: Authentication strategy (`:gemini` or `:vertex_ai`)
  - `:task_type`: Optional task type for optimized embeddings
    - `:retrieval_query` - Text is a search query
    - `:retrieval_document` - Text is a document being searched
    - `:semantic_similarity` - For semantic similarity tasks
    - `:classification` - For classification tasks
    - `:clustering` - For clustering tasks
    - `:question_answering` - For Q&A tasks
    - `:fact_verification` - For fact verification
    - `:code_retrieval_query` - For code retrieval
  - `:title`: Optional title (only for `:retrieval_document` task type)
  - `:output_dimensionality`: Optional dimension reduction

  ## API-Specific Behavior

  For **Gemini API** (`gemini-embedding-001`):
  - Task type is passed as `taskType` parameter
  - Default dimensions: 3072 (supports MRL: 768, 1536, 3072)
  - Dimensions below 3072 need manual normalization

  For **Vertex AI** (`embeddinggemma`):
  - Task type is embedded as prompt prefix in the text
  - Default dimensions: 768 (supports MRL: 128, 256, 512, 768)
  - All dimensions are pre-normalized

  ## Examples

      # Simple embedding (auto-detects model)
      {:ok, response} = Coordinator.embed_content("What is the meaning of life?")
      {:ok, values} = EmbedContentResponse.get_values(response)

      # With task type (works with both APIs transparently)
      {:ok, response} = Coordinator.embed_content(
        "This is a document about AI",
        task_type: :retrieval_document,
        title: "AI Overview"
      )

      # With explicit dimensionality
      {:ok, response} = Coordinator.embed_content(
        "Query text",
        task_type: :retrieval_query,
        output_dimensionality: 768
      )
  """
  @spec embed_content(String.t(), Gemini.options()) :: api_result(EmbedContentResponse.t())
  def embed_content(text, opts \\ []) when is_binary(text) do
    model = Keyword.get(opts, :model, Config.default_embedding_model())
    path = "models/#{model}:embedContent"

    request = EmbedContentRequest.new(text, Keyword.put(opts, :model, model))
    request_body = EmbedContentRequest.to_api_map(request)

    with {:ok, response} <- HTTP.post(path, request_body, opts) do
      {:ok, EmbedContentResponse.from_api_response(response)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generate embeddings for multiple text inputs in a single batch request.

  More efficient than individual requests when embedding multiple texts.

  See `t:Gemini.options/0` for available options.

  ## Parameters

  - `texts`: List of text strings to embed
  - `opts`: Options including model, auth strategy, and embedding-specific parameters

  ## Options

  Same as `embed_content/2`, applied to all texts in the batch.

  ## Examples

      # Batch embedding
      {:ok, response} = Coordinator.batch_embed_contents([
        "What is AI?",
        "How does machine learning work?",
        "Explain neural networks"
      ])

      {:ok, all_values} = BatchEmbedContentsResponse.get_all_values(response)

      # With task type
      {:ok, response} = Coordinator.batch_embed_contents(
        ["Doc 1 content", "Doc 2 content", "Doc 3 content"],
        task_type: :retrieval_document,
        output_dimensionality: 256
      )
  """
  @spec batch_embed_contents([String.t()], Gemini.options()) ::
          api_result(BatchEmbedContentsResponse.t())
  def batch_embed_contents(texts, opts \\ []) when is_list(texts) do
    model = Keyword.get(opts, :model, Config.default_embedding_model())
    path = "models/#{model}:batchEmbedContents"

    request = BatchEmbedContentsRequest.new(texts, Keyword.put(opts, :model, model))
    request_body = BatchEmbedContentsRequest.to_api_map(request)

    with {:ok, response} <- HTTP.post(path, request_body, opts) do
      {:ok, BatchEmbedContentsResponse.from_api_response(response)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Async Batch Embedding API

  @doc """
  Submit an asynchronous batch embedding job for production-scale embedding generation.

  Processes large batches of embeddings at 50% cost compared to interactive API.
  Returns immediately with a batch ID for polling. Suitable for embedding thousands
  to millions of texts for RAG systems, knowledge bases, and large-scale retrieval.

  See `t:Gemini.options/0` for available options.

  ## Parameters

  - `texts_or_requests`: List of strings OR list of EmbedContentRequest structs
  - `opts`: Options including model, display_name, priority, task_type, etc.

  ## Options

  - `:model`: Model to use (default: auto-detected based on auth)
  - `:display_name`: Human-readable batch name (required)
  - `:priority`: Processing priority (default: 0, higher = more urgent)
  - `:task_type`: Task type applied to all requests
  - `:output_dimensionality`: Dimension for all embeddings
  - `:auth`: Authentication strategy

  ## Returns

  - `{:ok, batch}` - EmbedContentBatch with `:name` for polling
  - `{:error, reason}` - Failed to submit batch

  ## Examples

      # Simple batch
      {:ok, batch} = Coordinator.async_batch_embed_contents(
        ["Text 1", "Text 2", "Text 3"],
        display_name: "My Knowledge Base",
        task_type: :retrieval_document
      )

      # Poll for completion
      {:ok, updated_batch} = Coordinator.get_batch_status(batch.name)

      case updated_batch.state do
        :completed ->
          {:ok, embeddings} = Coordinator.get_batch_embeddings(updated_batch)
          IO.puts("Retrieved \#{length(embeddings)} embeddings")
        :processing ->
          progress = updated_batch.batch_stats.successful_request_count
          IO.puts("Progress: \#{progress} completed")
        :failed ->
          IO.puts("Batch failed")
      end
  """
  @spec async_batch_embed_contents(
          [String.t()] | [EmbedContentRequest.t()],
          Gemini.options()
        ) :: api_result(Gemini.Types.Response.EmbedContentBatch.t())
  def async_batch_embed_contents(texts_or_requests, opts \\ [])

  def async_batch_embed_contents(texts, opts) when is_list(texts) do
    display_name =
      Keyword.get(opts, :display_name) ||
        raise ArgumentError, "display_name is required for async batch operations"

    model = Keyword.get(opts, :model, Config.default_embedding_model())
    opts_with_model = Keyword.put(opts, :model, model)

    # Build inlined requests from texts
    inlined_requests =
      Enum.map(texts, fn text ->
        request = EmbedContentRequest.new(text, opts_with_model)
        InlinedEmbedContentRequest.new(request)
      end)

    requests_container = InlinedEmbedContentRequests.new(inlined_requests)
    input_config = InputEmbedContentConfig.new_from_requests(requests_container)

    batch_request =
      EmbedContentBatch.new(model, input_config,
        display_name: display_name,
        priority: Keyword.get(opts, :priority, 0)
      )

    # API endpoint: models/{model}:asyncBatchEmbedContent (singular, not plural)
    path = "models/#{model}:asyncBatchEmbedContent"
    request_body = EmbedContentBatch.to_api_map(batch_request)

    with {:ok, response} <- HTTP.post(path, request_body, opts) do
      {:ok, Gemini.Types.Response.EmbedContentBatch.from_api_response(response)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the current status of an async batch embedding job.

  Polls the batch status to check progress, completion, or failures.

  See `t:Gemini.options/0` for available options.

  ## Parameters

  - `batch_name`: Batch identifier (format: "batches/{batchId}")
  - `opts`: Optional auth and other options

  ## Returns

  - `{:ok, batch}` - Current batch status with stats
  - `{:error, reason}` - Failed to retrieve status

  ## Examples

      {:ok, batch} = Coordinator.get_batch_status("batches/abc123")

      IO.puts("State: \#{batch.state}")

      if batch.batch_stats do
        completed = batch.batch_stats.successful_request_count + batch.batch_stats.failed_request_count
        total = batch.batch_stats.request_count
        IO.puts("Progress: \#{completed}/\#{total}")
      end
  """
  @spec get_batch_status(String.t(), Gemini.options()) ::
          api_result(Gemini.Types.Response.EmbedContentBatch.t())
  def get_batch_status(batch_name, opts \\ []) when is_binary(batch_name) do
    path = batch_name

    with {:ok, response} <- HTTP.get(path, opts) do
      {:ok, Gemini.Types.Response.EmbedContentBatch.from_api_response(response)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Retrieve embeddings from a completed batch job.

  Only works for batches in `:completed` state with inline responses.
  For file-based outputs, use file download APIs.

  ## Parameters

  - `batch`: Completed EmbedContentBatch

  ## Returns

  - `{:ok, embeddings}` - List of ContentEmbedding results
  - `{:error, reason}` - Batch not complete or file-based

  ## Examples

      {:ok, batch} = Coordinator.get_batch_status("batches/abc123")

      if batch.state == :completed do
        {:ok, embeddings} = Coordinator.get_batch_embeddings(batch)
        IO.puts("Retrieved \#{length(embeddings)} embeddings")
      end
  """
  @spec get_batch_embeddings(Gemini.Types.Response.EmbedContentBatch.t()) ::
          api_result([ContentEmbedding.t()])
  def get_batch_embeddings(%Gemini.Types.Response.EmbedContentBatch{} = batch) do
    cond do
      batch.state != :completed ->
        {:error, "Batch not yet completed (current state: #{batch.state})"}

      is_nil(batch.output) ->
        {:error, "No output available in batch"}

      batch.output.responses_file ->
        {:error, "Batch uses file-based output. Use file download APIs to retrieve results."}

      batch.output.inlined_responses ->
        embeddings =
          batch.output.inlined_responses
          |> InlinedEmbedContentResponses.successful_responses()
          |> Enum.map(& &1.embedding)

        {:ok, embeddings}

      true ->
        {:error, "Invalid batch output format"}
    end
  end

  @doc """
  Poll and wait for batch completion with configurable intervals.

  Convenience function that polls get_batch_status until completion
  or timeout. Useful for synchronous workflows or testing.

  See `t:Gemini.options/0` for available options.

  ## Options

  - `:poll_interval`: Milliseconds between polls (default: 5000)
  - `:timeout`: Max wait time in milliseconds (default: 600000 = 10 min)
  - `:on_progress`: Callback function called on each poll with batch

  ## Returns

  - `{:ok, batch}` - Completed batch (succeeded or failed)
  - `{:error, :timeout}` - Timed out waiting for completion
  - `{:error, reason}` - Failed to poll status

  ## Examples

      {:ok, batch} = Coordinator.async_batch_embed_contents(texts,
        display_name: "Batch 1"
      )

      {:ok, completed_batch} = Coordinator.await_batch_completion(
        batch.name,
        poll_interval: 10_000,  # 10 seconds
        timeout: 1_800_000,     # 30 minutes
        on_progress: fn b ->
          if b.batch_stats do
            progress = (b.batch_stats.successful_request_count || 0) / b.batch_stats.request_count * 100
            IO.puts("Progress: \#{Float.round(progress, 1)}%")
          end
        end
      )
  """
  @spec await_batch_completion(String.t(), keyword()) ::
          api_result(Gemini.Types.Response.EmbedContentBatch.t())
  def await_batch_completion(batch_name, opts \\ []) when is_binary(batch_name) do
    poll_interval = Keyword.get(opts, :poll_interval, 5_000)
    timeout = Keyword.get(opts, :timeout, 600_000)
    on_progress = Keyword.get(opts, :on_progress)
    auth_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)

    poll_until_complete(batch_name, auth_opts, poll_interval, timeout, start_time, on_progress)
  end

  # Private helper for polling
  defp poll_until_complete(batch_name, auth_opts, poll_interval, timeout, start_time, on_progress) do
    case get_batch_status(batch_name, auth_opts) do
      {:ok, batch} ->
        # Call progress callback if provided
        if on_progress, do: on_progress.(batch)

        # Check if complete
        if Gemini.Types.Response.EmbedContentBatch.is_complete?(batch) do
          {:ok, batch}
        else
          # Check timeout
          elapsed = System.monotonic_time(:millisecond) - start_time

          if elapsed >= timeout do
            {:error, :timeout}
          else
            # Wait and poll again
            Process.sleep(poll_interval)

            poll_until_complete(
              batch_name,
              auth_opts,
              poll_interval,
              timeout,
              start_time,
              on_progress
            )
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Token Counting API

  @doc """
  Count tokens in the given input.

  See `t:Gemini.options/0` for available options.

  ## Parameters
  - `input`: String or GenerateContentRequest to count tokens for
  - `opts`: Options including model and auth strategy

  ## Options
  - `:model`: Model to use for token counting (defaults to configured default model)
  - `:auth`: Authentication strategy (`:gemini` or `:vertex_ai`)

  ## Examples

      {:ok, count} = Coordinator.count_tokens("Hello world")
      {:ok, count} = Coordinator.count_tokens("Complex text", model: "gemini-2.5-pro", auth: :vertex_ai)
  """
  @spec count_tokens(String.t() | GenerateContentRequest.t(), Gemini.options()) ::
          api_result(%{total_tokens: integer()})
  def count_tokens(input, opts \\ []) do
    model = Keyword.get(opts, :model, Config.default_model())
    path = "models/#{model}:countTokens"

    with {:ok, request} <- build_count_tokens_request(input, opts),
         {:ok, response} <- HTTP.post(path, request, opts) do
      # Convert raw response to structured format
      total_tokens = Map.get(response, "totalTokens", 0)
      formatted_response = %{total_tokens: total_tokens}
      {:ok, formatted_response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Utility Functions

  @doc """
  Extract text content from a GenerateContentResponse.

  ## Examples

      {:ok, response} = Coordinator.generate_content("Hello")
      {:ok, text} = Coordinator.extract_text(response)
  """
  @spec extract_text(GenerateContentResponse.t()) :: {:ok, String.t()} | {:error, term()}
  def extract_text(%GenerateContentResponse{candidates: [first_candidate | _]}) do
    case first_candidate do
      %{content: %{parts: [_ | _] = parts}} ->
        text =
          parts
          |> Enum.filter(&Map.has_key?(&1, :text))
          |> Enum.map_join("", & &1.text)

        {:ok, text}

      _ ->
        {:error, "No text content found in response"}
    end
  end

  def extract_text(_), do: {:error, "No candidates found in response"}

  @doc """
  Extract function calls from a GenerateContentResponse.

  Returns a list of `Altar.ADM.FunctionCall` structs if the response contains
  function calls, or an empty list if none are found.

  ## Examples

      {:ok, response} = Coordinator.generate_content("What's the weather?", tools: tools)

      case Coordinator.extract_function_calls(response) do
        [] ->
          # No function calls, extract text normally
          {:ok, text} = Coordinator.extract_text(response)

        calls ->
          # Execute function calls and continue conversation
          results = Executor.execute_all(calls, registry)
      end
  """
  @spec extract_function_calls(GenerateContentResponse.t() | map()) :: [
          Altar.ADM.FunctionCall.t()
        ]
  def extract_function_calls(response) do
    Gemini.Tools.AutomaticFunctionCalling.extract_function_calls(response)
  end

  @doc """
  Check if a response contains function calls.

  ## Examples

      {:ok, response} = Coordinator.generate_content("Calculate 2+2", tools: tools)

      if Coordinator.has_function_calls?(response) do
        calls = Coordinator.extract_function_calls(response)
        # Handle function calls
      else
        {:ok, text} = Coordinator.extract_text(response)
      end
  """
  @spec has_function_calls?(GenerateContentResponse.t() | map()) :: boolean()
  def has_function_calls?(response) do
    Gemini.Tools.AutomaticFunctionCalling.has_function_calls?(response)
  end

  # Private Helper Functions

  # ADR-0001: Inject token estimation into opts if not already provided
  # Runs on the original input BEFORE request normalization
  @spec inject_token_estimation(term(), keyword()) :: keyword()
  defp inject_token_estimation(input, opts) do
    # Skip if caller already provided an estimate
    if Keyword.has_key?(opts, :estimated_input_tokens) do
      opts
    else
      case Gemini.APIs.Tokens.estimate(input) do
        {:ok, count} when count > 0 ->
          Keyword.put(opts, :estimated_input_tokens, count)

        _ ->
          # Estimation failed or returned 0, proceed without estimate
          opts
      end
    end
  end

  # Normalize and validate model strings to avoid silent fallbacks when callers
  # pass values that already contain an endpoint suffix (e.g. "...:generateContent").
  @doc false
  defp normalize_model_option(model) when is_binary(model) do
    model
    |> strip_endpoint_suffix()
    |> validate_model!()
    |> ensure_model_prefix()
  end

  defp normalize_model_option(model) do
    raise ArgumentError, "Invalid model parameter: #{inspect(model)}"
  end

  defp strip_endpoint_suffix(model) do
    model
    |> String.split(":", parts: 2)
    |> hd()
  end

  defp validate_model!(model) do
    invalid? = String.contains?(model, ["..", "?", "&"])

    if invalid? do
      raise ArgumentError, "Invalid model parameter: #{model}"
    end

    model
  end

  defp ensure_model_prefix(model) do
    cond do
      String.starts_with?(model, "models/") -> model
      String.starts_with?(model, "tunedModels/") -> model
      String.starts_with?(model, "projects/") -> model
      String.starts_with?(model, "publishers/") -> model
      true -> "models/#{model}"
    end
  end

  defp validate_thinking_config_opts(opts, model) when is_list(opts) and is_binary(model) do
    config =
      case Keyword.get(opts, :generation_config) do
        %Gemini.Types.GenerationConfig{} = generation_config -> generation_config.thinking_config
        _ -> Keyword.get(opts, :thinking_config)
      end

    case config do
      nil ->
        :ok

      %{} = config ->
        case ThinkingConfigValidation.validate(config, model) do
          :ok -> :ok
          {:error, message} -> {:error, Error.validation_error(message, %{model: model})}
        end

      other ->
        {:error,
         Error.validation_error("Invalid thinking_config: #{inspect(other)}", %{model: model})}
    end
  end

  @doc false
  @spec struct_to_api_map(Gemini.Types.GenerationConfig.t()) :: map()
  defp struct_to_api_map(%Gemini.Types.GenerationConfig{} = config) do
    config
    |> Map.from_struct()
    |> Map.to_list()
    |> build_generation_config()
  end

  @spec build_generate_request(
          String.t() | [Content.t()] | GenerateContentRequest.t(),
          request_opts()
        ) ::
          {:ok, map()} | {:error, term()}
  defp build_generate_request(%GenerateContentRequest{} = request, _opts) do
    {:ok, request}
  end

  defp build_generate_request(text, opts) when is_binary(text) do
    # Build a basic content request from text
    # Include role: "user" for Vertex AI compatibility
    content = %{
      contents: [
        %{
          role: "user",
          parts: [%{text: text}]
        }
      ]
    }

    # Add generation config if provided
    # Check for :generation_config option first, then fall back to individual options
    config =
      case Keyword.get(opts, :generation_config) do
        %Gemini.Types.GenerationConfig{} = generation_config ->
          # Convert GenerationConfig struct directly to API format
          struct_to_api_map(generation_config)

        nil ->
          # Build from individual options for backward compatibility
          build_generation_config(opts)
      end

    final_content =
      if map_size(config) > 0 do
        Map.put(content, :generationConfig, config)
      else
        content
      end

    # Inject tools and toolConfig if provided
    final_content = maybe_put_tools(final_content, opts)
    final_content = maybe_put_tool_config(final_content, opts)

    # Add cached_content reference if provided
    final_content = maybe_put_cached_content(final_content, opts)

    # Add system_instruction if provided
    final_content = maybe_put_system_instruction(final_content, opts)

    {:ok, final_content}
  end

  defp build_generate_request(contents, opts) when is_list(contents) do
    # Build content request from Content structs or normalize from flexible input
    formatted_contents =
      contents
      |> normalize_content_list()
      |> Enum.map(&format_content/1)

    content = %{
      contents: formatted_contents
    }

    # Add generation config if provided
    # Check for :generation_config option first, then fall back to individual options
    config =
      case Keyword.get(opts, :generation_config) do
        %Gemini.Types.GenerationConfig{} = generation_config ->
          # Convert GenerationConfig struct directly to API format
          struct_to_api_map(generation_config)

        nil ->
          # Build from individual options for backward compatibility
          build_generation_config(opts)
      end

    final_content =
      if map_size(config) > 0 do
        Map.put(content, :generationConfig, config)
      else
        content
      end

    # Inject tools and toolConfig if provided
    final_content = maybe_put_tools(final_content, opts)
    final_content = maybe_put_tool_config(final_content, opts)

    # Add cached_content reference if provided
    final_content = maybe_put_cached_content(final_content, opts)

    # Add system_instruction if provided
    final_content = maybe_put_system_instruction(final_content, opts)

    {:ok, final_content}
  end

  defp build_generate_request(_, _), do: {:error, "Invalid input type"}

  # Normalize flexible content input formats to Content structs
  defp normalize_content_list(contents) when is_list(contents) do
    Enum.map(contents, &normalize_single_content/1)
  end

  # Test helper - expose normalization for testing
  @doc false
  def __test_normalize_content__(input), do: normalize_single_content(input)

  @doc false
  def __test_detect_mime__(data), do: detect_mime_type(data)

  @doc false
  def __test_format_part__(part), do: format_part(part)

  @doc false
  def __test_build_generation_config__(opts), do: build_generation_config(opts)

  @doc false
  def __test_struct_to_api_map__(config), do: struct_to_api_map(config)

  @doc false
  def __test_parse_generate_response__(response), do: parse_generate_response(response)

  @doc false
  def __test_build_request__(input, opts), do: build_generate_request(input, opts)

  @doc false
  def __test_format_system_instruction__(instruction), do: format_system_instruction(instruction)

  # Already a Content struct - pass through
  defp normalize_single_content(%Content{} = content), do: content

  # Map with explicit role and parts (Gemini SDK style)
  defp normalize_single_content(%{role: role, parts: parts}) when is_list(parts) do
    normalized_parts = Enum.map(parts, &normalize_part/1)
    %Content{role: role || "user", parts: normalized_parts}
  end

  # Anthropic-style: list of mixed text/image maps with type field
  defp normalize_single_content(%{type: "text", text: text}) do
    %Content{role: "user", parts: [Gemini.Types.Part.text(text)]}
  end

  defp normalize_single_content(%{type: "image", source: %{type: "base64", data: data} = source}) do
    # Extract MIME type or detect from data
    mime_type =
      Map.get(source, :mime_type) || Map.get(source, "mime_type") || detect_mime_type(data)

    # When source type is "base64", treat data as already base64-encoded
    # Don't call Part.inline_data which would encode it again (Issue #11 fix)
    blob = %Gemini.Types.Blob{data: data, mime_type: mime_type}

    %Content{
      role: "user",
      parts: [%Gemini.Types.Part{inline_data: blob}]
    }
  end

  # Simple string - convert to text content
  defp normalize_single_content(text) when is_binary(text) do
    %Content{role: "user", parts: [Gemini.Types.Part.text(text)]}
  end

  # Fallback for unrecognized format
  defp normalize_single_content(other) do
    raise ArgumentError, """
    Invalid content format: #{inspect(other)}

    Expected one of:
    - Content struct: %Content{role: "user", parts: [...]}
    - String: "text message"
    - Map with role and parts: %{role: "user", parts: [...]}
    - Map with type: %{type: "text", text: "..."}
    - Map with image: %{type: "image", source: %{type: "base64", data: "..."}}
    """
  end

  # Normalize part formats
  defp normalize_part(%Gemini.Types.Part{} = part), do: part
  defp normalize_part(%{text: text}) when is_binary(text), do: Gemini.Types.Part.text(text)

  defp normalize_part(%{inline_data: %{mime_type: mime_type, data: data}}) do
    # When inline_data is provided in map format, treat data as already base64-encoded
    # (consistent with Anthropic-style format fix for Issue #11)
    blob = %Gemini.Types.Blob{data: data, mime_type: mime_type}
    %Gemini.Types.Part{inline_data: blob}
  end

  defp normalize_part(text) when is_binary(text), do: Gemini.Types.Part.text(text)
  defp normalize_part(part), do: part

  # Detect MIME type from base64 data using magic bytes
  defp detect_mime_type(base64_data) when is_binary(base64_data) do
    # Decode first 12 bytes to check magic bytes
    case Base.decode64(String.slice(base64_data, 0, 16)) do
      {:ok, header} -> check_magic_bytes(header)
      # Default fallback
      :error -> "image/jpeg"
    end
  end

  defp detect_mime_type(_), do: "image/jpeg"

  # Check magic bytes to determine image format
  defp check_magic_bytes(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: "image/png"
  defp check_magic_bytes(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"
  defp check_magic_bytes(<<0x47, 0x49, 0x46, 0x38, _::binary>>), do: "image/gif"
  defp check_magic_bytes(<<0x52, 0x49, 0x46, 0x46, _::binary>>), do: "image/webp"
  # Default fallback
  defp check_magic_bytes(_), do: "image/jpeg"

  # Helper function to format Content structs for API requests
  defp format_content(%Content{role: role, parts: parts}) do
    %{
      role: role,
      parts: Enum.map(parts, &format_part/1)
    }
  end

  # Helper function to format Part structs for API requests
  # Format part for API, handling Gemini.Types.Part structs and maps
  defp format_part(%Gemini.Types.Part{} = part) do
    base = %{}

    base =
      if part.text do
        Map.put(base, :text, part.text)
      else
        base
      end

    base =
      if part.inline_data do
        Map.put(base, :inlineData, %{
          mimeType: part.inline_data.mime_type,
          data: part.inline_data.data
        })
      else
        base
      end

    base =
      if part.file_data do
        Map.put(base, :fileData, FileData.to_api(part.file_data))
      else
        base
      end

    base =
      if part.function_response do
        Map.put(base, :functionResponse, FunctionResponse.to_api(part.function_response))
      else
        base
      end

    # Include thought_signature for Gemini 3 context preservation
    base =
      if part.thought_signature do
        Map.put(base, :thoughtSignature, part.thought_signature)
      else
        base
      end

    # Include media_resolution for Gemini 3 vision processing
    base =
      case media_resolution_to_api(part.media_resolution) do
        nil -> base
        level_str -> Map.put(base, :mediaResolution, level_str)
      end

    base =
      if is_nil(part.thought) do
        base
      else
        Map.put(base, :thought, part.thought)
      end

    base
  end

  defp format_part(%{text: text} = part) when is_binary(text) do
    base = %{text: text}

    # Handle thought_signature in map format as well
    if Map.get(part, :thought_signature) do
      Map.put(base, :thoughtSignature, part.thought_signature)
    else
      base
    end
  end

  defp format_part(%{inline_data: %{mime_type: mime_type, data: data}}) do
    %{inlineData: %{mimeType: mime_type, data: data}}
  end

  defp format_part(part), do: part

  defp media_resolution_to_api(%Gemini.Types.Part.MediaResolution{level: level}),
    do: media_resolution_to_api(level)

  defp media_resolution_to_api(value) when is_atom(value), do: MediaResolution.to_api(value)

  defp media_resolution_to_api(value) when is_binary(value) do
    value
    |> MediaResolution.from_api()
    |> MediaResolution.to_api()
  end

  defp media_resolution_to_api(_), do: nil

  # Tools serialization helpers
  defp maybe_put_tools(map, opts) do
    case Keyword.get(opts, :tools) do
      tools when is_list(tools) and length(tools) > 0 ->
        api_tools = ToolSerialization.to_api_tool_list(tools)
        Map.put(map, :tools, api_tools)

      _ ->
        map
    end
  end

  defp maybe_put_tool_config(map, opts) do
    case Keyword.get(opts, :tool_config) do
      %Altar.ADM.ToolConfig{} = tool_config ->
        api_tool_config = ToolSerialization.to_api_tool_config(tool_config)
        Map.put(map, :toolConfig, api_tool_config)

      _ ->
        map
    end
  end

  # Add cached_content reference if provided
  defp maybe_put_cached_content(map, opts) do
    case Keyword.get(opts, :cached_content) do
      nil ->
        map

      cache_name when is_binary(cache_name) ->
        Map.put(map, :cachedContent, cache_name)

      %{name: cache_name} when is_binary(cache_name) ->
        Map.put(map, :cachedContent, cache_name)

      _ ->
        map
    end
  end

  # Add system_instruction to request if provided
  defp maybe_put_system_instruction(map, opts) do
    case Keyword.get(opts, :system_instruction) do
      nil ->
        map

      instruction ->
        formatted = format_system_instruction(instruction)

        if formatted do
          Map.put(map, :systemInstruction, formatted)
        else
          map
        end
    end
  end

  # Format system instruction for API request.
  # Supports multiple input formats:
  # - String: Converted to `%{parts: [%{text: "..."}]}`
  # - Content struct: Converted to API format with role and parts
  # - Map with parts: Passed through with formatting
  @spec format_system_instruction(String.t() | Content.t() | map() | nil) :: map() | nil
  defp format_system_instruction(nil), do: nil

  defp format_system_instruction(text) when is_binary(text) do
    %{parts: [%{text: text}]}
  end

  defp format_system_instruction(%Content{} = content) do
    %{
      role: content.role,
      parts: Enum.map(content.parts, &format_part/1)
    }
  end

  defp format_system_instruction(%{parts: parts} = instruction) when is_list(parts) do
    formatted_parts = Enum.map(parts, &format_system_instruction_part/1)

    instruction
    |> Map.put(:parts, formatted_parts)
  end

  defp format_system_instruction(_), do: nil

  # Helper to format parts within system instruction maps
  defp format_system_instruction_part(%{text: _} = part), do: part
  defp format_system_instruction_part(%Gemini.Types.Part{} = part), do: format_part(part)
  defp format_system_instruction_part(part), do: part

  # Convert ThinkingConfig to API format with camelCase keys
  @doc false
  defp convert_thinking_config_to_api(%Gemini.Types.GenerationConfig.ThinkingConfig{} = config) do
    %{}
    |> maybe_put_if_not_nil("thinkingBudget", config.thinking_budget)
    |> maybe_put_if_not_nil("thinkingLevel", convert_thinking_level(config.thinking_level))
    |> maybe_put_if_not_nil("includeThoughts", config.include_thoughts)
  end

  defp convert_thinking_config_to_api(config) when is_map(config) do
    # Support plain maps for backward compatibility
    config
    |> Enum.reduce(%{}, fn
      {:thinking_budget, budget}, acc when is_integer(budget) ->
        Map.put(acc, "thinkingBudget", budget)

      {:thinking_level, level}, acc when level in [:minimal, :low, :medium, :high] ->
        Map.put(acc, "thinkingLevel", convert_thinking_level(level))

      {:include_thoughts, include}, acc when is_boolean(include) ->
        Map.put(acc, "includeThoughts", include)

      # Support both snake_case and camelCase input
      {"thinkingBudget", budget}, acc ->
        Map.put(acc, "thinkingBudget", budget)

      {"thinkingLevel", level}, acc ->
        Map.put(acc, "thinkingLevel", level)

      {"includeThoughts", include}, acc ->
        Map.put(acc, "includeThoughts", include)

      _, acc ->
        acc
    end)
  end

  defp convert_thinking_config_to_api(nil), do: %{}

  # Convert thinking level atom to API string
  defp convert_thinking_level(:minimal), do: "minimal"
  defp convert_thinking_level(:low), do: "low"
  defp convert_thinking_level(:medium), do: "medium"
  defp convert_thinking_level(:high), do: "high"
  defp convert_thinking_level(nil), do: nil

  # Convert ImageConfig to API format with camelCase keys
  @doc false
  defp convert_image_config_to_api(%Gemini.Types.GenerationConfig.ImageConfig{} = config) do
    %{}
    |> maybe_put_if_not_nil("aspectRatio", config.aspect_ratio)
    |> maybe_put_if_not_nil("imageSize", config.image_size)
    |> maybe_put_if_not_nil("outputMimeType", config.output_mime_type)
    |> maybe_put_if_not_nil("outputCompressionQuality", config.output_compression_quality)
  end

  defp convert_image_config_to_api(config) when is_map(config) do
    config
    |> Enum.reduce(%{}, fn
      {:aspect_ratio, ratio}, acc when is_binary(ratio) ->
        Map.put(acc, "aspectRatio", ratio)

      {:image_size, size}, acc when is_binary(size) ->
        Map.put(acc, "imageSize", size)

      {:output_mime_type, mime}, acc when is_binary(mime) ->
        Map.put(acc, "outputMimeType", mime)

      {:output_compression_quality, quality}, acc when is_integer(quality) ->
        Map.put(acc, "outputCompressionQuality", quality)

      {"aspectRatio", ratio}, acc ->
        Map.put(acc, "aspectRatio", ratio)

      {"imageSize", size}, acc ->
        Map.put(acc, "imageSize", size)

      {"outputMimeType", mime}, acc ->
        Map.put(acc, "outputMimeType", mime)

      {"outputCompressionQuality", quality}, acc ->
        Map.put(acc, "outputCompressionQuality", quality)

      _, acc ->
        acc
    end)
  end

  defp convert_image_config_to_api(nil), do: %{}

  # Helper to put value only if not nil
  @doc false
  defp maybe_put_if_not_nil(map, _key, nil), do: map
  defp maybe_put_if_not_nil(map, key, value), do: Map.put(map, key, value)

  # Helper function to normalize model response keys
  defp normalize_model_response(response) when is_map(response) do
    response
    |> Map.new(fn {key, value} ->
      atom_key =
        case key do
          "displayName" -> :display_name
          "name" -> :name
          "description" -> :description
          "inputTokenLimit" -> :input_token_limit
          "outputTokenLimit" -> :output_token_limit
          "supportedGenerationMethods" -> :supported_generation_methods
          _ -> key
        end

      {atom_key, value}
    end)
  end

  @spec build_generation_config(request_opts()) :: map()
  defp build_generation_config(opts) do
    opts
    |> Enum.reduce(%{}, fn
      # Basic generation parameters
      {:temperature, temp}, acc when is_number(temp) ->
        Map.put(acc, :temperature, temp)

      {:max_output_tokens, max}, acc when is_integer(max) ->
        Map.put(acc, :maxOutputTokens, max)

      {:top_p, top_p}, acc when is_number(top_p) ->
        Map.put(acc, :topP, top_p)

      {:top_k, top_k}, acc when is_integer(top_k) ->
        Map.put(acc, :topK, top_k)

      # Advanced generation parameters
      {:response_schema, schema}, acc when is_map(schema) ->
        Map.put(acc, :responseSchema, schema)

      {:response_mime_type, mime_type}, acc when is_binary(mime_type) ->
        Map.put(acc, :responseMimeType, mime_type)

      {:stop_sequences, sequences}, acc when is_list(sequences) ->
        Map.put(acc, :stopSequences, sequences)

      {:candidate_count, count}, acc when is_integer(count) and count > 0 ->
        Map.put(acc, :candidateCount, count)

      {:presence_penalty, penalty}, acc when is_number(penalty) ->
        Map.put(acc, :presencePenalty, penalty)

      {:frequency_penalty, penalty}, acc when is_number(penalty) ->
        Map.put(acc, :frequencyPenalty, penalty)

      {:response_logprobs, logprobs}, acc when is_boolean(logprobs) ->
        Map.put(acc, :responseLogprobs, logprobs)

      {:logprobs, logprobs}, acc when is_integer(logprobs) ->
        Map.put(acc, :logprobs, logprobs)

      {:seed, seed}, acc when is_integer(seed) ->
        Map.put(acc, :seed, seed)

      {:response_modalities, modalities}, acc when is_list(modalities) ->
        api_modalities =
          modalities
          |> Enum.map(&Modality.to_api/1)
          |> Enum.reject(&is_nil/1)

        if api_modalities == [] do
          acc
        else
          Map.put(acc, :responseModalities, api_modalities)
        end

      {:speech_config, %SpeechConfig{} = speech_config}, acc ->
        api_speech = SpeechConfig.to_api(speech_config)

        if api_speech && map_size(api_speech) > 0 do
          Map.put(acc, "speechConfig", api_speech)
        else
          acc
        end

      {:speech_config, speech_config}, acc when is_map(speech_config) ->
        api_speech =
          speech_config
          |> SpeechConfig.from_api()
          |> SpeechConfig.to_api()

        if api_speech && map_size(api_speech) > 0 do
          Map.put(acc, "speechConfig", api_speech)
        else
          acc
        end

      {:media_resolution, resolution}, acc ->
        case media_resolution_to_api(resolution) do
          nil -> acc
          api_value -> Map.put(acc, :mediaResolution, api_value)
        end

      # Property ordering for Gemini 2.0 models (structured outputs)
      {:property_ordering, ordering}, acc when is_list(ordering) and ordering != [] ->
        Map.put(acc, :propertyOrdering, ordering)

      # Thinking config support - FIXED: Now converts field names properly
      {:thinking_config, thinking_config}, acc when not is_nil(thinking_config) ->
        api_format = convert_thinking_config_to_api(thinking_config)

        if map_size(api_format) > 0 do
          Map.put(acc, "thinkingConfig", api_format)
        else
          acc
        end

      # Image config support for Gemini 3 Pro Image
      {:image_config, image_config}, acc when not is_nil(image_config) ->
        api_format = convert_image_config_to_api(image_config)

        if map_size(api_format) > 0 do
          Map.put(acc, "imageConfig", api_format)
        else
          acc
        end

      # Ignore unknown options
      _, acc ->
        acc
    end)
  end

  @spec build_count_tokens_request(String.t() | GenerateContentRequest.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  defp build_count_tokens_request(%GenerateContentRequest{} = request, _opts) do
    {:ok, %{generateContentRequest: request}}
  end

  defp build_count_tokens_request(text, _opts) when is_binary(text) do
    {:ok,
     %{
       contents: [
         %{
           parts: [%{text: text}]
         }
       ]
     }}
  end

  defp build_count_tokens_request(_, _), do: {:error, "Invalid input type"}

  @spec parse_generate_response(map()) :: {:ok, GenerateContentResponse.t()} | {:error, term()}
  defp parse_generate_response(%GenerateContentResponse{} = response), do: {:ok, response}

  defp parse_generate_response(response) when is_map(response) do
    {:ok, GenerateContentResponse.from_api(response)}
  end

  @spec parse_models_response(map()) :: {:ok, ListModelsResponse.t()} | {:error, term()}
  defp parse_models_response(response) when is_map(response) do
    atomized_response = atomize_keys(response)
    {:ok, struct(ListModelsResponse, atomized_response)}
  end

  # Helper function to recursively convert string keys to atom keys
  @spec atomize_keys(term()) :: term()
  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {atomize_key(k), atomize_keys(v)} end)
    |> Enum.into(%{})
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  @spec atomize_key(String.t() | atom()) :: atom()
  defp atomize_key(key) when is_binary(key) do
    # Convert camelCase to snake_case
    key
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
    |> String.to_atom()
  end

  defp atomize_key(key) when is_atom(key), do: key
end
