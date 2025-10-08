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

  alias Gemini.Client.HTTP
  alias Gemini.Streaming.UnifiedManager
  alias Gemini.Types.Request.GenerateContentRequest
  alias Gemini.Types.Response.{GenerateContentResponse, ListModelsResponse}
  alias Gemini.Types.Content
  alias Gemini.Types.ToolSerialization

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
        model: Gemini.Config.get_model(:flash_2_0_lite),
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
    model = Keyword.get(opts, :model, Gemini.Config.get_model(:default))
    path = "models/#{model}:generateContent"

    with {:ok, request} <- build_generate_request(input, opts),
         {:ok, response} <- HTTP.post(path, request, opts) do
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
        model: Gemini.Config.get_model(:flash_2_0_lite),
        auth: :gemini,
        temperature: 0.8,
        max_output_tokens: 1000
      )
  """
  @spec stream_generate_content(String.t() | GenerateContentRequest.t(), Gemini.options()) ::
          api_result(String.t())
  def stream_generate_content(input, opts \\ []) do
    model = Keyword.get(opts, :model, Gemini.Config.get_model(:default))

    with {:ok, request_body} <- build_generate_request(input, opts) do
      # Pass through the auto_execute_tools option to the UnifiedManager
      UnifiedManager.start_stream(model, request_body, opts)
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

      {:ok, model} = Coordinator.get_model(Gemini.Config.get_model(:flash_2_0_lite))
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
    model = Keyword.get(opts, :model, Gemini.Config.get_model(:default))
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

  # Private Helper Functions

  @doc false
  @spec convert_to_camel_case(atom()) :: String.t()
  defp convert_to_camel_case(atom_key) when is_atom(atom_key) do
    atom_key
    |> Atom.to_string()
    |> String.split("_")
    |> case do
      [first | rest] ->
        first <> Enum.map_join(rest, "", &String.capitalize/1)

      [] ->
        ""
    end
  end

  @doc false
  @spec struct_to_api_map(Gemini.Types.GenerationConfig.t()) :: map()
  defp struct_to_api_map(%Gemini.Types.GenerationConfig{} = config) do
    config
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      camel_key = convert_to_camel_case(key)
      Map.put(acc, camel_key, value)
    end)
    |> filter_nil_values()
  end

  @doc false
  @spec filter_nil_values(map()) :: map()
  defp filter_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} ->
      is_nil(value) or (is_list(value) and value == [])
    end)
    |> Enum.into(%{})
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
    content = %{
      contents: [
        %{
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
    mime_type = Map.get(source, :mime_type) || Map.get(source, "mime_type") || detect_mime_type(data)

    %Content{
      role: "user",
      parts: [Gemini.Types.Part.inline_data(data, mime_type)]
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
    Gemini.Types.Part.inline_data(data, mime_type)
  end

  defp normalize_part(text) when is_binary(text), do: Gemini.Types.Part.text(text)
  defp normalize_part(part), do: part

  # Detect MIME type from base64 data using magic bytes
  defp detect_mime_type(base64_data) when is_binary(base64_data) do
    # Decode first 12 bytes to check magic bytes
    case Base.decode64(String.slice(base64_data, 0, 16)) do
      {:ok, header} -> check_magic_bytes(header)
      :error -> "image/jpeg"  # Default fallback
    end
  end

  defp detect_mime_type(_), do: "image/jpeg"

  # Check magic bytes to determine image format
  defp check_magic_bytes(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: "image/png"
  defp check_magic_bytes(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"
  defp check_magic_bytes(<<0x47, 0x49, 0x46, 0x38, _::binary>>), do: "image/gif"
  defp check_magic_bytes(<<0x52, 0x49, 0x46, 0x46, _::binary>>), do: "image/webp"
  defp check_magic_bytes(_), do: "image/jpeg"  # Default fallback

  # Helper function to format Content structs for API requests
  defp format_content(%Content{role: role, parts: parts}) do
    %{
      role: role,
      parts: Enum.map(parts, &format_part/1)
    }
  end

  # Helper function to format Part structs for API requests
  defp format_part(%{text: text}) when is_binary(text) do
    %{text: text}
  end

  defp format_part(%{inline_data: %{mime_type: mime_type, data: data}}) do
    %{inline_data: %{mime_type: mime_type, data: data}}
  end

  defp format_part(part), do: part

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
  defp parse_generate_response(response) when is_map(response) do
    # Convert string keys to atom keys for struct creation
    atomized_response = atomize_keys(response)
    {:ok, struct(GenerateContentResponse, atomized_response)}
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
