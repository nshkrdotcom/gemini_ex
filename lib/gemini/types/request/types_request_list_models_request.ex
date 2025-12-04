defmodule Gemini.Types.Request.ListModelsRequest do
  @moduledoc """
  Request structure for listing models with pagination support.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:page_size, integer() | nil, default: nil)
    field(:page_token, String.t() | nil, default: nil)
  end

  @doc """
  Create a new ListModelsRequest with validation.

  ## Parameters
  - `opts` - Keyword list of options:
    - `:page_size` - Number of models per page (1-1000)
    - `:page_token` - Token for pagination

  ## Examples

      iex> ListModelsRequest.new(page_size: 50)
      {:ok, %ListModelsRequest{page_size: 50}}

      iex> ListModelsRequest.new(page_size: 2000)
      {:error, "Page size must be between 1 and 1000"}
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    page_size = Keyword.get(opts, :page_size)
    page_token = Keyword.get(opts, :page_token)

    with :ok <- validate_page_size(page_size),
         :ok <- validate_page_token(page_token) do
      {:ok, %__MODULE__{page_size: page_size, page_token: page_token}}
    end
  end

  @doc """
  Build query parameters string from request.
  """
  @spec to_query_params(t()) :: String.t()
  def to_query_params(%__MODULE__{page_size: nil, page_token: nil}), do: ""

  def to_query_params(%__MODULE__{page_size: page_size, page_token: page_token}) do
    params = []
    params = if page_size, do: [{"pageSize", page_size} | params], else: params
    params = if page_token, do: [{"pageToken", page_token} | params], else: params

    case params do
      [] -> ""
      _ -> "?" <> URI.encode_query(params)
    end
  end

  # Private validation functions

  defp validate_page_size(nil), do: :ok
  defp validate_page_size(size) when is_integer(size) and size >= 1 and size <= 1000, do: :ok

  defp validate_page_size(size) when is_integer(size) do
    {:error, "Page size must be between 1 and 1000, got: #{size}"}
  end

  defp validate_page_size(_) do
    {:error, "Page size must be an integer"}
  end

  defp validate_page_token(nil), do: :ok
  defp validate_page_token(token) when is_binary(token) and token != "", do: :ok

  defp validate_page_token("") do
    {:error, "Page token cannot be empty string"}
  end

  defp validate_page_token(_) do
    {:error, "Page token must be a string"}
  end
end

defmodule Gemini.Types.Request.GetModelRequest do
  @moduledoc """
  Request structure for getting a specific model.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:name, String.t(), enforce: true)
  end

  @doc """
  Create a new GetModelRequest with name normalization.

  ## Examples

      iex> GetModelRequest.new("gemini-flash-lite-latest")
      {:ok, %GetModelRequest{name: "models/gemini-flash-lite-latest"}}

      iex> GetModelRequest.new("models/gemini-2.5-pro")
      {:ok, %GetModelRequest{name: "models/gemini-2.5-pro"}}

      iex> GetModelRequest.new("")
      {:error, "Model name cannot be empty"}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(model_name) when is_binary(model_name) and model_name != "" do
    normalized_name = normalize_model_name(model_name)

    case validate_model_name(normalized_name) do
      :ok -> {:ok, %__MODULE__{name: normalized_name}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(""), do: {:error, "Model name cannot be empty"}
  def new(_), do: {:error, "Model name must be a string"}

  # Private helper functions

  defp normalize_model_name(model_name) do
    if String.starts_with?(model_name, "models/") do
      model_name
    else
      "models/#{model_name}"
    end
  end

  defp validate_model_name(model_name) do
    if String.starts_with?(model_name, "models/") and String.length(model_name) > 7 do
      :ok
    else
      {:error, "Invalid model name format: #{model_name}"}
    end
  end
end

defmodule Gemini.Types.Request.GenerateContentRequest do
  @moduledoc """
  Request structure for content generation.

  Supports all generation parameters including safety settings,
  system instructions, tools, and generation configuration.
  """

  use TypedStruct

  alias Gemini.Types.{Content, SafetySetting, GenerationConfig}

  @derive Jason.Encoder
  typedstruct do
    field(:contents, [Content.t()], enforce: true)
    field(:tools, [map()], default: [])
    field(:tool_config, map() | nil, default: nil)
    field(:safety_settings, [SafetySetting.t()], default: [])
    field(:system_instruction, Content.t() | nil, default: nil)
    field(:generation_config, GenerationConfig.t() | nil, default: nil)
  end

  @doc """
  Create a new GenerateContentRequest with validation.

  ## Parameters
  - `contents` - List of Content structs or single string
  - `opts` - Keyword list of options:
    - `:generation_config` - GenerationConfig struct
    - `:safety_settings` - List of SafetySetting structs
    - `:system_instruction` - System instruction as Content or string
    - `:tools` - List of tool definitions
    - `:tool_config` - Tool configuration

  ## Examples

      iex> GenerateContentRequest.new("Hello world")
      {:ok, %GenerateContentRequest{contents: [%Content{...}]}}

      iex> GenerateContentRequest.new([Content.text("Hello")])
      {:ok, %GenerateContentRequest{...}}
  """
  @spec new(String.t() | [Content.t()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(contents, opts \\ []) do
    with {:ok, normalized_contents} <- normalize_contents(contents),
         {:ok, system_instruction} <-
           normalize_system_instruction(Keyword.get(opts, :system_instruction)) do
      request = %__MODULE__{
        contents: normalized_contents,
        generation_config: Keyword.get(opts, :generation_config),
        safety_settings: Keyword.get(opts, :safety_settings, []),
        system_instruction: system_instruction,
        tools: Keyword.get(opts, :tools, []),
        tool_config: Keyword.get(opts, :tool_config)
      }

      {:ok, request}
    end
  end

  @doc """
  Convert request to map suitable for JSON encoding.

  Removes nil fields to create clean JSON payload.
  """
  @spec to_json_map(t()) :: map()
  def to_json_map(%__MODULE__{} = request) do
    request
    |> Map.from_struct()
    |> Enum.filter(fn {_k, v} -> v != nil and v != [] end)
    |> Map.new()
  end

  # Private helper functions

  defp normalize_contents(contents) when is_binary(contents) do
    {:ok, [Content.text(contents)]}
  end

  defp normalize_contents(contents) when is_list(contents) do
    try do
      normalized = Enum.map(contents, &normalize_content/1)
      {:ok, normalized}
    rescue
      error -> {:error, "Invalid contents: #{inspect(error)}"}
    end
  end

  defp normalize_contents(_) do
    {:error, "Contents must be a string or list of Content structs"}
  end

  defp normalize_content(%Content{} = content), do: content
  defp normalize_content(text) when is_binary(text), do: Content.text(text)

  defp normalize_content(invalid) do
    raise ArgumentError, "Invalid content: #{inspect(invalid)}"
  end

  defp normalize_system_instruction(nil), do: {:ok, nil}
  defp normalize_system_instruction(%Content{} = content), do: {:ok, content}

  defp normalize_system_instruction(text) when is_binary(text) do
    {:ok, Content.text(text)}
  end

  defp normalize_system_instruction(_) do
    {:error, "System instruction must be a string or Content struct"}
  end
end

defmodule Gemini.Types.Request.CountTokensRequest do
  @moduledoc """
  Request structure for counting tokens.

  Supports counting tokens for both simple contents and
  full GenerateContentRequest structures.
  """

  use TypedStruct

  alias Gemini.Types.Content
  alias Gemini.Types.Request.GenerateContentRequest

  @derive Jason.Encoder
  typedstruct do
    field(:contents, [Content.t()] | nil, default: nil)
    field(:generate_content_request, GenerateContentRequest.t() | nil, default: nil)
  end

  @doc """
  Create a new CountTokensRequest.

  ## Parameters
  - `input` - Either contents (string/list) or a GenerateContentRequest
  - `opts` - Additional options

  ## Examples

      iex> CountTokensRequest.new("Hello world")
      {:ok, %CountTokensRequest{contents: [%Content{...}]}}

      iex> CountTokensRequest.new(generate_request)
      {:ok, %CountTokensRequest{generate_content_request: generate_request}}
  """
  @spec new(String.t() | [Content.t()] | GenerateContentRequest.t(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def new(input, opts \\ [])

  def new(%GenerateContentRequest{} = request, _opts) do
    {:ok, %__MODULE__{generate_content_request: request}}
  end

  def new(contents, _opts) do
    with {:ok, normalized_contents} <- normalize_contents(contents) do
      {:ok, %__MODULE__{contents: normalized_contents}}
    end
  end

  @doc """
  Convert request to map suitable for JSON encoding.

  Only includes the non-nil field (either contents or generate_content_request).
  """
  @spec to_json_map(t()) :: map()
  def to_json_map(%__MODULE__{generate_content_request: %GenerateContentRequest{} = req}) do
    %{generateContentRequest: GenerateContentRequest.to_json_map(req)}
  end

  def to_json_map(%__MODULE__{contents: contents}) when is_list(contents) do
    %{contents: contents}
  end

  # Private helper functions

  defp normalize_contents(contents) when is_binary(contents) do
    {:ok, [Content.text(contents)]}
  end

  defp normalize_contents(contents) when is_list(contents) do
    try do
      normalized = Enum.map(contents, &normalize_content/1)
      {:ok, normalized}
    rescue
      error -> {:error, "Invalid contents: #{inspect(error)}"}
    end
  end

  defp normalize_contents(_) do
    {:error, "Contents must be a string or list of Content structs"}
  end

  defp normalize_content(%Content{} = content), do: content
  defp normalize_content(text) when is_binary(text), do: Content.text(text)

  defp normalize_content(invalid) do
    raise ArgumentError, "Invalid content: #{inspect(invalid)}"
  end
end
