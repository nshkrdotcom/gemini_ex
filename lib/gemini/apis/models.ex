defmodule Gemini.Models do
  @moduledoc """
  API for managing and querying Gemini models.
  """

  alias Gemini.Client.HTTP
  alias Gemini.Error
  alias Gemini.Types.Request.ListModelsRequest
  alias Gemini.Types.Response.{ListModelsResponse, Model}

  @doc """
  List available Gemini models.

  ## Options
    - `:page_size` - Maximum number of models to return (default: 50)
    - `:page_token` - Token for pagination

  ## Examples

      iex> Gemini.Models.list()
      {:ok, %ListModelsResponse{models: [%Model{...}], next_page_token: nil}}

      iex> Gemini.Models.list(page_size: 10)
      {:ok, %ListModelsResponse{...}}

  """
  def list(opts \\ []) do
    request = struct(ListModelsRequest, opts)
    query_params = build_query_params(request)
    path = "models#{query_params}"

    case HTTP.get(path) do
      {:ok, response} -> parse_list_models_response(response)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get information about a specific model.

  ## Parameters
    - `model_name` - Name of the model (e.g., "gemini-flash-lite-latest")

  ## Examples

      iex> Gemini.Models.get("gemini-flash-lite-latest")
      {:ok, %Model{name: "models/gemini-flash-lite-latest", ...}}

      iex> Gemini.Models.get("invalid-model")
      {:error, %Gemini.Error{type: :api_error, ...}}

  """
  def get(model_name) when is_binary(model_name) do
    # Ensure the model name has the proper format
    full_name =
      if String.starts_with?(model_name, "models/") do
        model_name
      else
        "models/#{model_name}"
      end

    case HTTP.get(full_name) do
      {:ok, response} -> parse_model_response(response)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  List all available model names.

  ## Examples

      iex> Gemini.Models.list_names()
      {:ok, ["gemini-flash-lite-latest", "gemini-3-pro-preview", "gemini-2.5-flash"]}

  """
  def list_names do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        names =
          models
          |> Enum.map(& &1.name)
          |> Enum.map(&String.replace_prefix(&1, "models/", ""))

        {:ok, names}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Check if a model exists and is available.

  ## Examples

      iex> Gemini.Models.exists?("gemini-flash-lite-latest")
      {:ok, true}

      iex> Gemini.Models.exists?("invalid-model")
      {:ok, false}

  """
  def exists?(model_name) when is_binary(model_name) do
    case get(model_name) do
      {:ok, _model} -> {:ok, true}
      {:error, %Error{type: :api_error, http_status: 404}} -> {:ok, false}
      {:error, %Error{type: :api_error, api_reason: 404}} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get models that support a specific generation method.

  ## Parameters
    - `method` - Generation method (e.g., "generateContent", "streamGenerateContent")

  ## Examples

      iex> Gemini.Models.supporting_method("generateContent")
      {:ok, [%Model{...}, ...]}

  """
  def supporting_method(method) when is_binary(method) do
    case list() do
      {:ok, %ListModelsResponse{models: models}} ->
        supporting_models =
          models
          |> Enum.filter(fn model ->
            method in model.supported_generation_methods
          end)

        {:ok, supporting_models}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private functions

  defp build_query_params(%ListModelsRequest{page_size: nil, page_token: nil}), do: ""

  defp build_query_params(%ListModelsRequest{page_size: page_size, page_token: page_token}) do
    params = []
    params = if page_size, do: [{"pageSize", page_size} | params], else: params
    params = if page_token, do: [{"pageToken", page_token} | params], else: params

    case params do
      [] -> ""
      _ -> "?" <> URI.encode_query(params)
    end
  end

  defp parse_list_models_response(response) do
    models =
      response
      |> Map.get("models", [])
      |> Enum.map(&parse_model/1)

    list_response = %ListModelsResponse{
      models: models,
      next_page_token: Map.get(response, "nextPageToken")
    }

    {:ok, list_response}
  rescue
    e -> {:error, Error.invalid_response("Failed to parse models response: #{inspect(e)}")}
  end

  defp parse_model_response(response) do
    model = parse_model(response)
    {:ok, model}
  rescue
    e -> {:error, Error.invalid_response("Failed to parse model response: #{inspect(e)}")}
  end

  defp parse_model(model_data) do
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
end
