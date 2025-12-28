defmodule Gemini.Types.Response.Model do
  @moduledoc """
  Model information response structure.

  Represents the complete model metadata returned by the Gemini API,
  including capabilities, token limits, and generation parameters.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:base_model_id, String.t(), enforce: true)
    field(:version, String.t(), enforce: true)
    field(:display_name, String.t(), enforce: true)
    field(:description, String.t(), enforce: true)
    field(:input_token_limit, integer(), enforce: true)
    field(:output_token_limit, integer(), enforce: true)
    field(:supported_generation_methods, [String.t()], default: [])
    field(:temperature, float() | nil, default: nil)
    field(:max_temperature, float() | nil, default: nil)
    field(:top_p, float() | nil, default: nil)
    field(:top_k, integer() | nil, default: nil)
  end

  @typedoc "Model capability level based on features and limits"
  @type capability_level :: :basic | :standard | :advanced | :premium

  @typedoc "Token capacity classification"
  @type capacity_tier :: :small | :medium | :large | :very_large

  @doc """
  Check if model supports a specific generation method.

  ## Examples

      iex> Model.supports_method?(model, "generateContent")
      true

      iex> Model.supports_method?(model, "nonexistentMethod")
      false
  """
  @spec supports_method?(t(), String.t()) :: boolean()
  def supports_method?(%__MODULE__{supported_generation_methods: methods}, method) do
    method in methods
  end

  @doc """
  Check if model supports streaming content generation.
  """
  @spec supports_streaming?(t()) :: boolean()
  def supports_streaming?(model) do
    supports_method?(model, "streamGenerateContent")
  end

  @doc """
  Check if model supports token counting.
  """
  @spec supports_token_counting?(t()) :: boolean()
  def supports_token_counting?(model) do
    supports_method?(model, "countTokens")
  end

  @doc """
  Check if model supports embeddings.
  """
  @spec supports_embeddings?(t()) :: boolean()
  def supports_embeddings?(model) do
    supports_method?(model, "embedContent") or
      supports_method?(model, "batchEmbedContents")
  end

  @doc """
  Get the effective base model ID.

  Prefers the base_model_id field, but falls back to extracting
  from the name if base_model_id is nil.

  ## Examples

      iex> Model.effective_base_id(%Model{base_model_id: "gemini-flash-lite-latest"})
      "gemini-flash-lite-latest"

      iex> Model.effective_base_id(%Model{name: "models/gemini-2.5-pro", base_model_id: nil})
      "gemini-2.5-pro"
  """
  @spec effective_base_id(t()) :: String.t()
  def effective_base_id(%__MODULE__{base_model_id: base_id}) when is_binary(base_id) do
    base_id
  end

  def effective_base_id(%__MODULE__{name: "models/" <> base_id}) do
    base_id
  end

  def effective_base_id(%__MODULE__{name: name}) do
    name
  end

  @doc """
  Check if model has advanced generation parameters.

  Returns true if the model supports temperature, top_p, or top_k parameters.
  """
  @spec has_advanced_params?(t()) :: boolean()
  def has_advanced_params?(%__MODULE__{temperature: temp, top_p: top_p, top_k: top_k}) do
    not is_nil(temp) or not is_nil(top_p) or not is_nil(top_k)
  end

  @doc """
  Classify model's input token capacity.

  ## Examples

      iex> Model.input_capacity_tier(%Model{input_token_limit: 2_000_000})
      :very_large

      iex> Model.input_capacity_tier(%Model{input_token_limit: 30_000})
      :medium
  """
  @spec input_capacity_tier(t()) :: capacity_tier()
  def input_capacity_tier(%__MODULE__{input_token_limit: limit}) do
    cond do
      limit >= 1_000_000 -> :very_large
      limit >= 100_000 -> :large
      limit >= 30_000 -> :medium
      true -> :small
    end
  end

  @doc """
  Classify model's output token capacity.
  """
  @spec output_capacity_tier(t()) :: capacity_tier()
  def output_capacity_tier(%__MODULE__{output_token_limit: limit}) do
    cond do
      limit >= 8_000 -> :large
      limit >= 4_000 -> :medium
      limit >= 1_000 -> :small
      true -> :small
    end
  end

  @doc """
  Generate a comprehensive capabilities summary.

  ## Example Response

      %{
        supports_streaming: true,
        supports_token_counting: true,
        supports_embeddings: false,
        has_temperature: true,
        has_top_k: true,
        has_top_p: false,
        method_count: 3,
        input_capacity: :very_large,
        output_capacity: :medium
      }
  """
  @spec capabilities_summary(t()) :: map()
  def capabilities_summary(%__MODULE__{} = model) do
    %{
      supports_streaming: supports_streaming?(model),
      supports_token_counting: supports_token_counting?(model),
      supports_embeddings: supports_embeddings?(model),
      has_temperature: not is_nil(model.temperature),
      has_top_k: not is_nil(model.top_k),
      has_top_p: not is_nil(model.top_p),
      method_count: length(model.supported_generation_methods),
      input_capacity: input_capacity_tier(model),
      output_capacity: output_capacity_tier(model)
    }
  end

  @doc """
  Calculate a capability score for model comparison.

  Higher scores indicate more capable models.
  """
  @spec capability_score(t()) :: integer()
  def capability_score(%__MODULE__{} = model) do
    base_score = length(model.supported_generation_methods) * 10

    capacity_score =
      case input_capacity_tier(model) do
        :very_large -> 50
        :large -> 30
        :medium -> 15
        :small -> 5
      end

    params_score = if has_advanced_params?(model), do: 20, else: 0

    base_score + capacity_score + params_score
  end

  @doc """
  Compare two models by capability.

  Returns :lt, :eq, or :gt based on capability scores.
  """
  @spec compare_capabilities(t(), t()) :: :lt | :eq | :gt
  def compare_capabilities(%__MODULE__{} = model1, %__MODULE__{} = model2) do
    score1 = capability_score(model1)
    score2 = capability_score(model2)

    cond do
      score1 < score2 -> :lt
      score1 > score2 -> :gt
      true -> :eq
    end
  end

  @doc """
  Extract model family from the base model ID.

  ## Examples

      iex> Model.model_family(%Model{base_model_id: "gemini-flash-lite-latest"})
      "gemini"

      iex> Model.model_family(%Model{base_model_id: "gemini-embedding-001"})
      "gemini-embedding"
  """
  @spec model_family(t()) :: String.t()
  def model_family(%__MODULE__{} = model) do
    base_id = effective_base_id(model)

    if String.starts_with?(base_id, "gemini-embedding") do
      "gemini-embedding"
    else
      base_id
      |> String.split("-", parts: 2)
      |> hd()
    end
  end

  @doc """
  Check if this appears to be the latest version of a model.

  Heuristic based on name patterns (no version suffix, "latest" in name).
  """
  @spec latest_version?(t()) :: boolean()
  def latest_version?(%__MODULE__{name: name}) do
    base_name = String.replace_prefix(name, "models/", "")

    # Check for version patterns that suggest it's NOT the latest
    not Regex.match?(~r/-\d{3}$/, base_name) and
      not String.contains?(base_name, "preview") and
      (String.contains?(base_name, "latest") or
         not Regex.match?(~r/-(alpha|beta|rc)\d*$/, base_name))
  end

  @doc """
  Determine if model is suitable for production use.

  Based on capability, capacity, and stability indicators.
  """
  @spec production_ready?(t()) :: boolean()
  def production_ready?(%__MODULE__{} = model) do
    supports_method?(model, "generateContent") and
      model.input_token_limit >= 30_000 and
      model.output_token_limit >= 1_000 and
      not String.contains?(model.name, "experimental") and
      not String.contains?(model.display_name, "Experimental")
  end
end

defmodule Gemini.Types.Response.ListModelsResponse do
  @moduledoc """
  Response structure for listing models.

  Contains the list of models and pagination information.
  """

  use TypedStruct

  alias Gemini.Types.Response.Model

  @derive Jason.Encoder
  typedstruct do
    field(:models, [Model.t()], default: [])
    field(:next_page_token, String.t() | nil, default: nil)
  end

  @doc """
  Check if there are more pages available.
  """
  @spec has_next_page?(t()) :: boolean()
  def has_next_page?(%__MODULE__{next_page_token: token}) do
    is_binary(token) and token != ""
  end

  @doc """
  Get the total number of models in this response.
  """
  @spec model_count(t()) :: non_neg_integer()
  def model_count(%__MODULE__{models: models}) do
    length(models)
  end

  @doc """
  Extract model names from the response.
  """
  @spec model_names(t()) :: [String.t()]
  def model_names(%__MODULE__{models: models}) do
    Enum.map(models, &Model.effective_base_id/1)
  end

  @doc """
  Filter models by a predicate function.
  """
  @spec filter_models(t(), (Model.t() -> boolean())) :: [Model.t()]
  def filter_models(%__MODULE__{models: models}, predicate) do
    Enum.filter(models, predicate)
  end

  @doc """
  Group models by a classification function.
  """
  @spec group_models(t(), (Model.t() -> term())) :: map()
  def group_models(%__MODULE__{models: models}, classifier) do
    Enum.group_by(models, classifier)
  end
end
