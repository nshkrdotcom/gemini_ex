defmodule Gemini.Types.ModelArmorConfig do
  @moduledoc """
  Configuration for Model Armor integrations.

  **This feature is only supported in Vertex AI, not the Gemini Developer API.**

  Model Armor allows you to apply content filtering templates managed separately
  from your generation requests. This provides centralized policy management
  for content moderation.

  ## Important

  If `model_armor_config` is provided, `safety_settings` must NOT be provided.
  These two options are mutually exclusive.

  ## Fields

  - `prompt_template_name` - Resource name of the Model Armor template to apply
    to prompt content (optional)
  - `response_template_name` - Resource name of the Model Armor template to apply
    to response content (optional)

  ## Example

      config = %Gemini.Types.ModelArmorConfig{
        prompt_template_name: "projects/my-project/locations/us-central1/templates/prompt-filter",
        response_template_name: "projects/my-project/locations/us-central1/templates/response-filter"
      }

      # Use in generate request (Vertex AI only)
      Gemini.generate("Hello world", model_armor_config: config)
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Model Armor configuration.

    - `prompt_template_name` - Model Armor template for filtering prompt content
    - `response_template_name` - Model Armor template for filtering response content
    """
    field(:prompt_template_name, String.t())
    field(:response_template_name, String.t())
  end

  @doc """
  Creates a new ModelArmorConfig struct.

  ## Parameters

  - `opts` - Keyword list with configuration options:
    - `:prompt_template_name` - Template name for prompt filtering
    - `:response_template_name` - Template name for response filtering

  ## Examples

      config = Gemini.Types.ModelArmorConfig.new(
        prompt_template_name: "projects/my-project/locations/us-central1/templates/t1"
      )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      prompt_template_name: Keyword.get(opts, :prompt_template_name),
      response_template_name: Keyword.get(opts, :response_template_name)
    }
  end

  @doc """
  Creates a ModelArmorConfig from API response.

  ## Parameters

  - `data` - Map from API response with camelCase string keys
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = config), do: config

  def from_api(%{} = data) do
    %__MODULE__{
      prompt_template_name: data["promptTemplateName"],
      response_template_name: data["responseTemplateName"]
    }
  end

  @doc """
  Converts ModelArmorConfig to API format (camelCase keys).

  ## Examples

      config = %ModelArmorConfig{
        prompt_template_name: "t1",
        response_template_name: "t2"
      }

      ModelArmorConfig.to_api(config)
      #=> %{"promptTemplateName" => "t1", "responseTemplateName" => "t2"}
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = config) do
    %{}
    |> maybe_put("promptTemplateName", config.prompt_template_name)
    |> maybe_put("responseTemplateName", config.response_template_name)
  end

  @doc """
  Validates that model_armor_config and safety_settings are not both provided.

  This is a helper for request building - these options are mutually exclusive.

  ## Parameters

  - `model_armor_config` - The model armor config (or nil)
  - `safety_settings` - The safety settings list (or nil/empty)
  - `api_type` - Current API type (`:gemini` or `:vertex_ai`)

  ## Returns

  - `:ok` - Validation passed
  - `{:error, reason}` - Validation failed

  ## Examples

      validate_exclusivity(%ModelArmorConfig{...}, [], :vertex_ai)
      #=> :ok

      validate_exclusivity(%ModelArmorConfig{...}, [%SafetySetting{}], :vertex_ai)
      #=> {:error, "model_armor_config and safety_settings are mutually exclusive"}

      validate_exclusivity(%ModelArmorConfig{...}, nil, :gemini)
      #=> {:error, "model_armor_config is only supported in Vertex AI"}
  """
  @spec validate_exclusivity(t() | nil, list() | nil, :gemini | :vertex_ai) ::
          :ok | {:error, String.t()}
  def validate_exclusivity(nil, _safety_settings, _api_type), do: :ok

  def validate_exclusivity(%__MODULE__{}, _safety_settings, :gemini) do
    {:error, "model_armor_config is only supported in Vertex AI, not the Gemini Developer API"}
  end

  def validate_exclusivity(%__MODULE__{}, safety_settings, :vertex_ai)
      when is_list(safety_settings) and safety_settings != [] do
    {:error, "model_armor_config and safety_settings are mutually exclusive"}
  end

  def validate_exclusivity(%__MODULE__{}, _safety_settings, :vertex_ai), do: :ok
end
