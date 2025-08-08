defmodule Gemini.APIs.Tokens do
  @moduledoc """
  Token counting functionality for Gemini API.

  Provides comprehensive token counting capabilities including:
  - Counting tokens for simple text content
  - Counting tokens for multimodal content (text + images)
  - Counting tokens for complete GenerateContentRequest structures
  - Batch token counting operations

  Token counting helps with:
  - Request planning and validation
  - Cost estimation and budgeting
  - Content chunking and splitting
  - Model selection based on token limits

  ## Examples

      # Simple text counting
      {:ok, response} = Tokens.count("Hello, world!")
      total_tokens = response.total_tokens

      # Multimodal content counting
      contents = [
        Content.text("What's in this image?"),
        Content.image("path/to/image.jpg")
      ]
      {:ok, response} = Tokens.count(contents)

      # Count tokens for a complete generation request
      {:ok, gen_request} = GenerateContentRequest.new("Hello", generation_config: config)
      {:ok, response} = Tokens.count_for_request(gen_request)

      # Batch counting for multiple inputs
      inputs = ["Text 1", "Text 2", "Text 3"]
      {:ok, results} = Tokens.count_batch(inputs)
  """

  alias Gemini.Client
  alias Gemini.Config
  alias Gemini.Types.Content
  alias Gemini.Types.Request.{CountTokensRequest, GenerateContentRequest}
  alias Gemini.Types.Response.CountTokensResponse
  alias Gemini.{Error, Telemetry}

  require Logger

  @doc """
  Count tokens in the given content.

  ## Parameters
  - `contents` - Content to count (string, list of Content structs, or GenerateContentRequest)
  - `opts` - Options:
    - `:model` - Model name (default: from config)
    - `:generate_content_request` - Use full GenerateContentRequest for counting

  ## Returns
  - `{:ok, CountTokensResponse.t()}` - Success with token count
  - `{:error, Error.t()}` - Validation error, API error, or network failure

  ## Examples

      # Simple text
      {:ok, response} = Tokens.count("Hello, world!")
      # => %CountTokensResponse{total_tokens: 3}

      # Multiple contents
      contents = [
        Content.text("Hello"),
        Content.text("World")
      ]
      {:ok, response} = Tokens.count(contents)

      # With specific model
      {:ok, response} = Tokens.count("Hello", model: "gemini-2.5-pro")

      # Using GenerateContentRequest
      {:ok, gen_request} = GenerateContentRequest.new("Hello", generation_config: config)
      {:ok, response} = Tokens.count(gen_request)
  """
  @spec count(String.t() | [Content.t()] | GenerateContentRequest.t(), keyword()) ::
          {:ok, CountTokensResponse.t()} | {:error, Error.t()}
  def count(contents, opts \\ []) do
    model = Keyword.get(opts, :model, Config.default_model())
    start_time = System.monotonic_time()

    with {:ok, request} <- CountTokensRequest.new(contents, opts),
         request_map = CountTokensRequest.to_json_map(request),
         path = "models/#{model}:countTokens",
         telemetry_opts = build_telemetry_opts(:count_tokens, model, opts),
         {:ok, response} <- Client.post(path, request_map, telemetry_opts),
         {:ok, parsed_response} <- parse_count_tokens_response(response) do
      # Emit success telemetry
      emit_tokens_telemetry(:count, :success, start_time, model, %{
        total_tokens: parsed_response.total_tokens,
        content_type: classify_content_type(contents)
      })

      {:ok, parsed_response}
    else
      {:error, %Error{} = error} ->
        emit_tokens_telemetry(:count, :error, start_time, model, %{error_type: error.type})
        {:error, error}

      {:error, reason} when is_binary(reason) ->
        error = Error.validation_error(reason)
        emit_tokens_telemetry(:count, :error, start_time, model, %{error_type: :validation_error})
        {:error, error}
    end
  end

  @doc """
  Count tokens for a GenerateContentRequest.

  This is useful when you want to know the token count for a complete
  generation request including all parameters, system instructions, etc.

  ## Parameters
  - `generate_request` - A GenerateContentRequest struct
  - `opts` - Options (model, etc.)

  ## Returns
  - `{:ok, CountTokensResponse.t()}` - Token count for the complete request
  - `{:error, Error.t()}` - Error details

  ## Examples

      # Create a generation request
      {:ok, gen_request} = GenerateContentRequest.new(
        "Explain quantum physics",
        generation_config: GenerationConfig.creative(),
        system_instruction: "You are a physics professor"
      )

      # Count tokens and use in your application code
  """
  @spec count_for_request(GenerateContentRequest.t(), keyword()) ::
          {:ok, CountTokensResponse.t()} | {:error, Error.t()}
  def count_for_request(%GenerateContentRequest{} = generate_request, opts \\ []) do
    count(generate_request, opts)
  end

  @doc """
  Count tokens for multiple inputs in batch.

  Efficiently counts tokens for multiple separate inputs, returning
  results in the same order as the inputs.

  ## Parameters
  - `inputs` - List of content inputs (strings or Content lists)
  - `opts` - Options applied to all requests

  ## Returns
  - `{:ok, [CountTokensResponse.t()]}` - List of token counts
  - `{:error, Error.t()}` - Error details

  ## Examples

      inputs = [
        "Hello world",
        "How are you?",
        "Tell me a story about dragons"
      ]

      {:ok, results} = Tokens.count_batch(inputs)

      # Process results in your application code

      # With options
      {:ok, results} = Tokens.count_batch(inputs, model: "gemini-2.5-pro")
  """
  @spec count_batch([String.t() | [Content.t()]], keyword()) ::
          {:ok, [CountTokensResponse.t()]} | {:error, Error.t()}
  def count_batch(inputs, opts \\ []) when is_list(inputs) do
    # Use Task.async_stream for parallel processing
    max_concurrency = Keyword.get(opts, :max_concurrency, 5)
    timeout = Keyword.get(opts, :timeout, 30_000)

    try do
      results =
        inputs
        |> Task.async_stream(
          fn input -> count(input, opts) end,
          max_concurrency: max_concurrency,
          timeout: timeout,
          on_timeout: :kill_task
        )
        |> Enum.map(fn
          {:ok, {:ok, result}} ->
            result

          {:ok, {:error, error}} ->
            throw({:batch_error, error})

          {:exit, reason} ->
            throw({:batch_error, Error.network_error("Task failed: #{inspect(reason)}")})
        end)

      {:ok, results}
    catch
      {:batch_error, error} -> {:error, error}
    end
  end

  @doc """
  Estimate tokens for content without making an API call.

  Provides a rough estimate of token count using heuristics.
  Useful for quick validation and pre-filtering before actual counting.

  ## Parameters
  - `content` - Content to estimate (string or Content list)
  - `opts` - Options (currently unused, for future expansion)

  ## Returns
  - `{:ok, integer()}` - Estimated token count
  - `{:error, Error.t()}` - Error if content is invalid

  ## Examples

      {:ok, estimate} = Tokens.estimate("Hello, world!")
      # => {:ok, 3}

      # For longer text
      text = "This is a longer piece of text that we want to estimate..."
      {:ok, estimate} = Tokens.estimate(text)

  ## Note

  This is a heuristic estimate and may not match the actual token count
  from the API. Use `count/2` for accurate token counting.
  """
  @spec estimate(String.t() | [Content.t()], keyword()) :: {:ok, integer()} | {:error, Error.t()}
  def estimate(content, _opts \\ []) do
    try do
      estimated_tokens = estimate_tokens_heuristic(content)
      {:ok, estimated_tokens}
    rescue
      error -> {:error, Error.validation_error("Failed to estimate tokens: #{inspect(error)}")}
    end
  end

  @doc """
  Check if content fits within a model's token limit.

  ## Parameters
  - `content` - Content to check
  - `model_name` - Model to check against (optional, uses default if not provided)
  - `opts` - Options including:
    - `:buffer` - Safety buffer to subtract from limit (default: 100)
    - `:include_output` - Reserve space for output tokens (default: 1000)

  ## Returns
  - `{:ok, %{fits: boolean(), tokens: integer(), limit: integer()}}` - Fit analysis
  - `{:error, Error.t()}` - Error details

  ## Examples

      {:ok, analysis} = Tokens.check_fit("Hello world", "gemini-2.0-flash-lite")
      # => {:ok, %{fits: true, tokens: 3, limit: 1000000, remaining: 999997}}

      # With output buffer
      {:ok, analysis} = Tokens.check_fit(long_text, include_output: 2000)
  """
  @spec check_fit(String.t() | [Content.t()], String.t() | nil, keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def check_fit(content, model_name \\ nil, opts \\ []) do
    model = model_name || Config.default_model()
    buffer = Keyword.get(opts, :buffer, 100)
    output_reserve = Keyword.get(opts, :include_output, 1000)

    with {:ok, token_response} <- count(content, model: model),
         {:ok, model_info} <- get_model_info(model) do
      tokens = token_response.total_tokens
      limit = model_info.input_token_limit
      effective_limit = limit - buffer - output_reserve
      fits = tokens <= effective_limit

      analysis = %{
        fits: fits,
        tokens: tokens,
        limit: limit,
        effective_limit: effective_limit,
        remaining: max(0, effective_limit - tokens),
        buffer: buffer,
        output_reserve: output_reserve
      }

      {:ok, analysis}
    end
  end

  # Private implementation functions

  @spec build_telemetry_opts(atom(), String.t(), keyword()) :: keyword()
  defp build_telemetry_opts(function, model, opts) do
    telemetry_metadata = %{
      function: function,
      api: :tokens,
      model: model,
      content_type: classify_content_type(Keyword.get(opts, :contents, []))
    }

    [telemetry_metadata: telemetry_metadata]
  end

  @spec emit_tokens_telemetry(atom(), atom(), integer(), String.t(), map()) :: :ok
  defp emit_tokens_telemetry(operation, status, start_time, model, additional_metadata) do
    duration = Telemetry.calculate_duration(start_time)

    measurements = %{duration: duration}

    measurements =
      case Map.get(additional_metadata, :total_tokens) do
        nil -> measurements
        tokens -> Map.put(measurements, :total_tokens, tokens)
      end

    metadata = %{
      api: :tokens,
      operation: operation,
      model: model
    }

    metadata = Map.merge(metadata, Map.drop(additional_metadata, [:total_tokens]))

    Telemetry.execute([:gemini, :tokens, operation, status], measurements, metadata)
  end

  @spec parse_count_tokens_response(map()) :: {:ok, CountTokensResponse.t()} | {:error, Error.t()}
  defp parse_count_tokens_response(response) do
    try do
      count_response = %CountTokensResponse{
        total_tokens: Map.get(response, "totalTokens", 0)
      }

      {:ok, count_response}
    rescue
      error ->
        Logger.error("Failed to parse count tokens response: #{inspect(error)}")

        {:error,
         Error.invalid_response("Failed to parse count tokens response: #{inspect(error)}")}
    end
  end

  @spec classify_content_type(term()) :: atom()
  defp classify_content_type(%GenerateContentRequest{}), do: :generate_request
  defp classify_content_type(content) when is_binary(content), do: :text

  defp classify_content_type(contents) when is_list(contents) do
    if Enum.any?(contents, &has_non_text_parts?/1) do
      :multimodal
    else
      :text
    end
  end

  defp classify_content_type(_), do: :unknown

  @spec has_non_text_parts?(Content.t()) :: boolean()
  defp has_non_text_parts?(%Content{parts: parts}) when is_list(parts) do
    Enum.any?(parts, fn
      %{text: _} -> false
      _ -> true
    end)
  end

  defp has_non_text_parts?(_), do: false

  @spec estimate_tokens_heuristic(String.t() | [Content.t()]) :: integer()
  defp estimate_tokens_heuristic(content) when is_binary(content) do
    # Rough heuristic: ~4 characters per token for English text
    # This is a very rough estimate and actual tokenization will vary
    word_count = content |> String.split() |> length()
    char_count = String.length(content)

    # Use the higher of word-based or character-based estimates
    # ~1.3 tokens per word
    word_estimate = round(word_count * 1.3)
    # ~4 chars per token
    char_estimate = round(char_count / 4.0)

    max(word_estimate, char_estimate)
  end

  defp estimate_tokens_heuristic(contents) when is_list(contents) do
    contents
    |> Enum.map(&estimate_content_tokens/1)
    |> Enum.sum()
  end

  @spec estimate_content_tokens(Content.t()) :: integer()
  defp estimate_content_tokens(%Content{parts: parts}) do
    parts
    |> Enum.map(&estimate_part_tokens/1)
    |> Enum.sum()
  end

  @spec estimate_part_tokens(map()) :: integer()
  defp estimate_part_tokens(%{text: text}) when is_binary(text) do
    estimate_tokens_heuristic(text)
  end

  defp estimate_part_tokens(%{inline_data: _}) do
    # Rough estimate for image tokens (varies widely by image)
    200
  end

  defp estimate_part_tokens(_), do: 0

  @spec get_model_info(String.t()) :: {:ok, map()} | {:error, Error.t()}
  defp get_model_info(model_name) do
    # This would typically call the Models API, but for now we'll use a simple cache
    # In a real implementation, this should cache model info to avoid repeated API calls
    case Gemini.APIs.Models.get(model_name) do
      {:ok, model} -> {:ok, model}
      {:error, error} -> {:error, error}
    end
  end
end
