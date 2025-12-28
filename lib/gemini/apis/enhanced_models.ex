defmodule Gemini.APIs.Models do
  @moduledoc """
  Complete Models API implementation following the unified architecture.

  Provides comprehensive access to Gemini model information including:
  - Listing available models with pagination
  - Getting detailed model information
  - Querying model capabilities and features
  - Statistical analysis and filtering

  ## Examples

      # List all available models
      {:ok, response} = Models.list()
      models = response.models

      # Get specific model information
      {:ok, model} = Models.get("gemini-3-pro-preview")

      # Check if model exists
      {:ok, true} = Models.exists?("gemini-flash-lite-latest")

      # Filter models by capabilities
      {:ok, streaming_models} = Models.supporting_method("streamGenerateContent")

  """

  alias Gemini.Client
  alias Gemini.Types.Request.{GetModelRequest, ListModelsRequest}
  alias Gemini.Types.Response.{ListModelsResponse, Model}
  alias Gemini.{Error, Telemetry}

  require Logger

  @doc """
  List available Gemini models with optional pagination.

  ## Parameters
  - `opts` - Keyword list of options:
    - `:page_size` - Maximum number of models per page (1-1000, default: 50)
    - `:page_token` - Token for retrieving the next page of results

  ## Returns
  - `{:ok, ListModelsResponse.t()}` - Success with models and pagination info
  - `{:error, Error.t()}` - Validation error, API error, or network failure

  ## Examples

      # List first 50 models (default)
      {:ok, response} = Models.list()
      models = response.models
      next_token = response.next_page_token

      # Custom page size
      {:ok, response} = Models.list(page_size: 10)

      # Pagination
      {:ok, page1} = Models.list(page_size: 10)
      {:ok, page2} = Models.list(page_size: 10, page_token: page1.next_page_token)

  ## API Reference
  Corresponds to: `GET https://generativelanguage.googleapis.com/v1beta/models`
  """
  @spec list(keyword()) :: {:ok, ListModelsResponse.t()} | {:error, Error.t()}
  def list(opts \\ []) do
    start_time = System.monotonic_time()

    with {:ok, request} <- ListModelsRequest.new(opts),
         query_params = ListModelsRequest.to_query_params(request),
         path = "models#{query_params}",
         telemetry_opts = build_telemetry_opts(:list_models, opts),
         {:ok, response} <- Client.get(path, telemetry_opts),
         {:ok, parsed_response} <- parse_list_models_response(response) do
      # Emit success telemetry
      emit_models_telemetry(:list, :success, start_time, %{
        model_count: length(parsed_response.models),
        page_size: Keyword.get(opts, :page_size)
      })

      {:ok, parsed_response}
    else
      {:error, %Error{} = error} ->
        emit_models_telemetry(:list, :error, start_time, %{error_type: error.type})
        {:error, error}

      {:error, reason} when is_binary(reason) ->
        error = Error.validation_error(reason)
        emit_models_telemetry(:list, :error, start_time, %{error_type: :validation_error})
        {:error, error}
    end
  end

  @doc """
  Get detailed information about a specific model.

  ## Parameters
  - `model_name` - The model identifier, with or without "models/" prefix
    Examples: "gemini-flash-lite-latest", "models/gemini-3-pro-preview"

  ## Returns
  - `{:ok, Model.t()}` - Success with model details
  - `{:error, Error.t()}` - Model not found, validation error, or API error

  ## Examples

      # Get model by base ID
      {:ok, model} = Models.get("gemini-flash-lite-latest")

      # Get model by full resource name
      {:ok, model} = Models.get("models/gemini-2.5-pro")

      # Handle not found cases properly in your application code

  ## API Reference
  Corresponds to: `GET https://generativelanguage.googleapis.com/v1beta/{name=models/*}`
  """
  @spec get(String.t()) :: {:ok, Model.t()} | {:error, Error.t()}
  def get(model_name) do
    start_time = System.monotonic_time()

    with {:ok, request} <- GetModelRequest.new(model_name),
         telemetry_opts =
           build_telemetry_opts(:get_model, model: extract_base_model_id(request.name)),
         {:ok, response} <- Client.get(request.name, telemetry_opts),
         {:ok, parsed_model} <- parse_model_response(response) do
      # Emit success telemetry
      emit_models_telemetry(:get, :success, start_time, %{
        model: extract_base_model_id(request.name)
      })

      {:ok, parsed_model}
    else
      {:error, %Error{} = error} ->
        model_id = extract_base_model_id_safe(model_name)

        emit_models_telemetry(:get, :error, start_time, %{
          model: model_id,
          error_type: error.type
        })

        {:error, error}

      {:error, reason} when is_binary(reason) ->
        error = Error.validation_error(reason)
        model_id = extract_base_model_id_safe(model_name)

        emit_models_telemetry(:get, :error, start_time, %{
          model: model_id,
          error_type: :validation_error
        })

        {:error, error}
    end
  end

  @doc """
  List all available model names as simple strings.

  This is a convenience function that extracts just the base model IDs
  from the full models list response.

  ## Returns
  - `{:ok, [String.t()]}` - List of base model IDs
  - `{:error, Error.t()}` - API error

  ## Examples

      {:ok, names} = Models.list_names()
      # => ["gemini-flash-lite-latest", "gemini-2.5-pro", "gemini-2.5-flash"]

      # Use with enum functions
      {:ok, names} = Models.list_names()
      flash_models = Enum.filter(names, &String.contains?(&1, "flash"))
  """
  @spec list_names() :: {:ok, [String.t()]} | {:error, Error.t()}
  def list_names do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        names =
          models
          |> Enum.map(&Model.effective_base_id/1)
          |> Enum.uniq()
          |> Enum.sort()

        {:ok, names}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Check if a specific model exists and is available.

  ## Parameters
  - `model_name` - The model identifier to check

  ## Returns
  - `{:ok, true}` - Model exists and is available
  - `{:ok, false}` - Model does not exist
  - `{:error, Error.t()}` - Network or other API error

  ## Examples

      {:ok, true} = Models.exists?("gemini-flash-lite-latest")
      {:ok, false} = Models.exists?("nonexistent-model")

      # Use in conditional logic
      case Models.exists?("gemini-flash-lite-latest") do
        {:ok, true} -> generate_with_model("gemini-flash-lite-latest")
        {:ok, false} -> use_fallback_model()
        {:error, _} -> handle_api_error()
      end
  """
  @spec exists?(String.t()) :: {:ok, boolean()} | {:error, Error.t()}
  def exists?(model_name) when is_binary(model_name) do
    case get(model_name) do
      {:ok, _model} ->
        {:ok, true}

      {:error, %Error{type: :api_error, http_status: 404}} ->
        {:ok, false}

      {:error, %Error{api_reason: 404}} ->
        {:ok, false}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get models that support a specific generation method.

  ## Parameters
  - `method` - The generation method to filter by
    Examples: "generateContent", "streamGenerateContent", "countTokens"

  ## Returns
  - `{:ok, [Model.t()]}` - List of models supporting the method
  - `{:error, Error.t()}` - API error

  ## Examples

      # Find streaming-capable models
      {:ok, streaming_models} = Models.supporting_method("streamGenerateContent")

      # Find models that support content generation
      {:ok, generation_models} = Models.supporting_method("generateContent")

      # Check capabilities
      {:ok, models} = Models.supporting_method("countTokens")
      token_counting_available = length(models) > 0
  """
  @spec supporting_method(String.t()) :: {:ok, [Model.t()]} | {:error, Error.t()}
  def supporting_method(method) when is_binary(method) and method != "" do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        supporting_models =
          models
          |> Enum.filter(&Model.supports_method?(&1, method))

        {:ok, supporting_models}

      {:error, error} ->
        {:error, error}
    end
  end

  def supporting_method("") do
    {:error, Error.validation_error("Generation method cannot be empty")}
  end

  def supporting_method(_) do
    {:error, Error.validation_error("Generation method must be a string")}
  end

  @doc """
  Get models filtered by capabilities or parameters.

  ## Parameters
  - `filter_opts` - Keyword list of filter criteria:
    - `:min_input_tokens` - Minimum input token limit
    - `:min_output_tokens` - Minimum output token limit
    - `:supports_methods` - List of required methods
    - `:has_temperature` - Boolean, requires temperature parameter
    - `:has_top_k` - Boolean, requires top_k parameter
    - `:has_top_p` - Boolean, requires top_p parameter
    - `:production_ready` - Boolean, filter for production-ready models
    - `:model_family` - String, filter by model family (e.g., "gemini")

  ## Returns
  - `{:ok, [Model.t()]}` - Filtered list of models
  - `{:error, Error.t()}` - API error

  ## Examples

      # High-capacity models
      {:ok, large_models} = Models.filter(min_input_tokens: 100_000)

      # Models with advanced parameters
      {:ok, tunable_models} = Models.filter(has_temperature: true, has_top_k: true)

      # Multi-method support
      {:ok, versatile_models} = Models.filter(
        supports_methods: ["generateContent", "streamGenerateContent"]
      )

      # Production-ready models only
      {:ok, production_models} = Models.filter(production_ready: true)
  """
  @spec filter(keyword()) :: {:ok, [Model.t()]} | {:error, Error.t()}
  def filter(filter_opts \\ []) do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        filtered_models =
          models
          |> Enum.filter(&model_matches_filter?(&1, filter_opts))

        {:ok, filtered_models}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get comprehensive model statistics and summary.

  ## Returns
  - `{:ok, map()}` - Statistics about available models
  - `{:error, Error.t()}` - API error

  ## Example Response

      {:ok, stats} = Models.get_stats()
      # =>
      # %{
      #   total_models: 5,
      #   by_version: %{"1.5" => 3, "2.0" => 2},
      #   by_method: %{
      #     "generateContent" => 5,
      #     "streamGenerateContent" => 4,
      #     "countTokens" => 5
      #   },
      #   token_limits: %{
      #     max_input: 2_000_000,
      #     max_output: 8192,
      #     avg_input: 800_000,
      #     avg_output: 4096
      #   },
      #   capabilities: %{
      #     with_temperature: 5,
      #     with_top_k: 3,
      #     with_top_p: 5,
      #     production_ready: 4
      #   },
      #   by_family: %{"gemini" => 4, "text" => 1}
      # }
  """
  @spec get_stats() :: {:ok, map()} | {:error, Error.t()}
  def get_stats do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        stats = %{
          total_models: length(models),
          by_version: count_by_version(models),
          by_method: count_by_methods(models),
          by_family: count_by_family(models),
          token_limits: calculate_token_stats(models),
          capabilities: count_capabilities(models),
          capacity_distribution: analyze_capacity_distribution(models),
          models_by_name: Enum.map(models, &{Model.effective_base_id(&1), &1.display_name})
        }

        {:ok, stats}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private implementation functions

  @spec build_telemetry_opts(atom(), keyword()) :: keyword()
  defp build_telemetry_opts(function, opts) do
    telemetry_metadata = %{
      function: function,
      api: :models
    }

    # Add function-specific metadata
    telemetry_metadata =
      case function do
        :get_model ->
          Map.put(telemetry_metadata, :model, Keyword.get(opts, :model, "unknown"))

        _ ->
          telemetry_metadata
      end

    [telemetry_metadata: telemetry_metadata]
  end

  @spec emit_models_telemetry(atom(), atom(), integer(), map()) :: :ok
  defp emit_models_telemetry(operation, status, start_time, additional_metadata) do
    duration = Telemetry.calculate_duration(start_time)

    measurements = %{duration: duration}
    measurements = Map.merge(measurements, Map.take(additional_metadata, [:model_count]))

    metadata = %{
      api: :models,
      operation: operation
    }

    metadata = Map.merge(metadata, Map.drop(additional_metadata, [:model_count]))

    Telemetry.execute([:gemini, :models, operation, status], measurements, metadata)
  end

  @spec parse_list_models_response(map()) :: {:ok, ListModelsResponse.t()} | {:error, Error.t()}
  defp parse_list_models_response(response) do
    models =
      response
      |> Map.get("models", [])
      |> Enum.map(&parse_model_data/1)

    list_response = %ListModelsResponse{
      models: models,
      next_page_token: Map.get(response, "nextPageToken")
    }

    {:ok, list_response}
  rescue
    error ->
      Logger.error("Failed to parse models list response: #{inspect(error)}")
      {:error, Error.invalid_response("Failed to parse models response: #{inspect(error)}")}
  end

  @spec parse_model_response(map()) :: {:ok, Model.t()} | {:error, Error.t()}
  defp parse_model_response(response) do
    model = parse_model_data(response)
    {:ok, model}
  rescue
    error ->
      Logger.error("Failed to parse model response: #{inspect(error)}")
      {:error, Error.invalid_response("Failed to parse model response: #{inspect(error)}")}
  end

  @spec parse_model_data(map()) :: Model.t()
  defp parse_model_data(model_data) do
    %Model{
      name: Map.get(model_data, "name", ""),
      base_model_id: Map.get(model_data, "baseModelId"),
      version: Map.get(model_data, "version", ""),
      display_name: Map.get(model_data, "displayName", ""),
      description: Map.get(model_data, "description", ""),
      input_token_limit: Map.get(model_data, "inputTokenLimit", 0),
      output_token_limit: Map.get(model_data, "outputTokenLimit", 0),
      supported_generation_methods: Map.get(model_data, "supportedGenerationMethods", []),
      temperature: Map.get(model_data, "temperature"),
      max_temperature: Map.get(model_data, "maxTemperature"),
      top_p: Map.get(model_data, "topP"),
      top_k: Map.get(model_data, "topK")
    }
  end

  @spec extract_base_model_id(String.t()) :: String.t()
  defp extract_base_model_id("models/" <> base_id), do: base_id
  defp extract_base_model_id(name), do: name

  @spec extract_base_model_id_safe(String.t()) :: String.t()
  defp extract_base_model_id_safe(model_name) when is_binary(model_name) do
    extract_base_model_id(model_name)
  end

  defp extract_base_model_id_safe(_), do: "unknown"

  @spec model_matches_filter?(Model.t(), keyword()) :: boolean()
  defp model_matches_filter?(model, filter_opts) do
    Enum.all?(filter_opts, &filter_match?(model, &1))
  end

  defp filter_match?(model, {:min_input_tokens, value}),
    do: model.input_token_limit >= value

  defp filter_match?(model, {:min_output_tokens, value}),
    do: model.output_token_limit >= value

  defp filter_match?(model, {:supports_methods, value}) when is_list(value),
    do: Enum.all?(value, &Model.supports_method?(model, &1))

  defp filter_match?(model, {:has_temperature, value}),
    do: (value and not is_nil(model.temperature)) or not value

  defp filter_match?(model, {:has_top_k, value}),
    do: (value and not is_nil(model.top_k)) or not value

  defp filter_match?(model, {:has_top_p, value}),
    do: (value and not is_nil(model.top_p)) or not value

  defp filter_match?(model, {:production_ready, value}),
    do: (value and Model.production_ready?(model)) or not value

  defp filter_match?(model, {:model_family, value}),
    do: Model.model_family(model) == value

  defp filter_match?(model, {:latest_version, value}),
    do: (value and Model.latest_version?(model)) or not value

  defp filter_match?(_model, _filter), do: true

  @spec count_by_version([Model.t()]) :: map()
  defp count_by_version(models) do
    models
    |> Enum.group_by(& &1.version)
    |> Enum.map(fn {version, models_list} -> {version, length(models_list)} end)
    |> Enum.into(%{})
  end

  @spec count_by_methods([Model.t()]) :: map()
  defp count_by_methods(models) do
    models
    |> Enum.flat_map(& &1.supported_generation_methods)
    |> Enum.frequencies()
  end

  @spec count_by_family([Model.t()]) :: map()
  defp count_by_family(models) do
    models
    |> Enum.group_by(&Model.model_family/1)
    |> Enum.map(fn {family, models_list} -> {family, length(models_list)} end)
    |> Enum.into(%{})
  end

  @spec calculate_token_stats([Model.t()]) :: map()
  defp calculate_token_stats([]), do: %{max_input: 0, max_output: 0, avg_input: 0, avg_output: 0}

  defp calculate_token_stats(models) do
    input_limits = Enum.map(models, & &1.input_token_limit)
    output_limits = Enum.map(models, & &1.output_token_limit)

    %{
      max_input: Enum.max(input_limits),
      max_output: Enum.max(output_limits),
      min_input: Enum.min(input_limits),
      min_output: Enum.min(output_limits),
      avg_input: round(Enum.sum(input_limits) / length(input_limits)),
      avg_output: round(Enum.sum(output_limits) / length(output_limits))
    }
  end

  @spec count_capabilities([Model.t()]) :: map()
  defp count_capabilities(models) do
    %{
      with_temperature: Enum.count(models, &(not is_nil(&1.temperature))),
      with_top_k: Enum.count(models, &(not is_nil(&1.top_k))),
      with_top_p: Enum.count(models, &(not is_nil(&1.top_p))),
      with_max_temperature: Enum.count(models, &(not is_nil(&1.max_temperature))),
      supports_streaming: Enum.count(models, &Model.supports_streaming?/1),
      supports_token_counting: Enum.count(models, &Model.supports_token_counting?/1),
      supports_embeddings: Enum.count(models, &Model.supports_embeddings?/1),
      production_ready: Enum.count(models, &Model.production_ready?/1),
      latest_versions: Enum.count(models, &Model.latest_version?/1)
    }
  end

  @spec analyze_capacity_distribution([Model.t()]) :: map()
  defp analyze_capacity_distribution(models) do
    input_distribution =
      models
      |> Enum.group_by(&Model.input_capacity_tier/1)
      |> Enum.map(fn {tier, models_list} -> {tier, length(models_list)} end)
      |> Enum.into(%{})

    output_distribution =
      models
      |> Enum.group_by(&Model.output_capacity_tier/1)
      |> Enum.map(fn {tier, models_list} -> {tier, length(models_list)} end)
      |> Enum.into(%{})

    %{
      input_capacity: input_distribution,
      output_capacity: output_distribution
    }
  end
end
