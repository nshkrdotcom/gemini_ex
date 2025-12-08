defmodule Gemini.Types.GenerationConfig do
  @moduledoc """
  Configuration for content generation parameters.
  """

  use TypedStruct
  alias Gemini.Types.{MediaResolution, Modality, SpeechConfig}

  defmodule ThinkingConfig do
    @moduledoc """
    Configuration for thinking/reasoning in Gemini models.

    ## Gemini 3 (Recommended)

    Use `thinking_level` for Gemini 3 models:
    - `:low` - Minimizes latency and cost. Best for simple tasks.
    - `:high` - Maximizes reasoning depth (default for Gemini 3).

    Note: `:medium` is not currently supported.

    ## Gemini 2.5 (Legacy)

    Use `thinking_budget` for Gemini 2.5 models:
    - `0` - Disable thinking (Flash/Lite only)
    - `-1` - Dynamic thinking
    - Positive integer - Fixed token budget

    ## Important

    You cannot use both `thinking_level` and `thinking_budget` in the same request.
    Doing so will return a 400 error from the API.
    """

    use TypedStruct

    @type thinking_level :: :low | :medium | :high

    @derive Jason.Encoder
    typedstruct do
      @typedoc "Thinking configuration for Gemini models"
      field(:thinking_budget, integer() | nil, default: nil)
      field(:thinking_level, thinking_level() | nil, default: nil)
      field(:include_thoughts, boolean() | nil, default: nil)
    end
  end

  defmodule ImageConfig do
    @moduledoc """
    Configuration for image generation in Gemini 3 Pro Image.

    Used with `gemini-3-pro-image-preview` model for generating and editing images.

    ## Fields

    - `aspect_ratio` - Output image aspect ratio (e.g., "16:9", "1:1", "4:3", "3:4", "9:16")
    - `image_size` - Output resolution ("2K" or "4K")
    - `output_mime_type` - MIME type for the generated image (Vertex-only)
    - `output_compression_quality` - JPEG compression quality (Vertex-only)

    ## Example

        image_config = %ImageConfig{
          aspect_ratio: "16:9",
          image_size: "4K"
        }
    """

    use TypedStruct

    @type aspect_ratio :: String.t()
    @type image_size :: String.t()

    @derive Jason.Encoder
    typedstruct do
      @typedoc "Image generation configuration"
      field(:aspect_ratio, aspect_ratio() | nil, default: nil)
      field(:image_size, image_size() | nil, default: nil)
      field(:output_mime_type, String.t() | nil, default: nil)
      field(:output_compression_quality, integer() | nil, default: nil)
    end
  end

  @derive Jason.Encoder
  typedstruct do
    field(:stop_sequences, [String.t()], default: [])
    field(:response_mime_type, String.t() | nil, default: nil)
    field(:response_schema, map() | nil, default: nil)
    field(:candidate_count, integer() | nil, default: nil)
    field(:max_output_tokens, integer() | nil, default: nil)
    field(:temperature, float() | nil, default: nil)
    field(:top_p, float() | nil, default: nil)
    field(:top_k, integer() | nil, default: nil)
    field(:presence_penalty, float() | nil, default: nil)
    field(:frequency_penalty, float() | nil, default: nil)
    field(:response_logprobs, boolean() | nil, default: nil)
    field(:logprobs, integer() | nil, default: nil)
    field(:thinking_config, ThinkingConfig.t() | nil, default: nil)
    field(:property_ordering, [String.t()] | nil, default: nil)
    field(:image_config, ImageConfig.t() | nil, default: nil)
    field(:seed, integer() | nil, default: nil)
    field(:response_modalities, [Modality.t()] | nil, default: nil)
    field(:speech_config, SpeechConfig.t() | nil, default: nil)
    field(:media_resolution, MediaResolution.t() | nil, default: nil)
  end

  @doc """
  Create a new generation config with default values.
  """
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Create a creative generation config (higher temperature).
  """
  def creative(opts \\ []) do
    defaults = [
      temperature: 0.9,
      top_p: 1.0,
      top_k: 40
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Create a balanced generation config.
  """
  def balanced(opts \\ []) do
    defaults = [
      temperature: 0.7,
      top_p: 0.95,
      top_k: 40
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Create a precise generation config (lower temperature).
  """
  def precise(opts \\ []) do
    defaults = [
      temperature: 0.2,
      top_p: 0.8,
      top_k: 10
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Create a deterministic generation config.
  """
  def deterministic(opts \\ []) do
    defaults = [
      temperature: 0.0,
      candidate_count: 1
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Set JSON response format.
  """
  def json_response(config \\ %__MODULE__{}) do
    %{config | response_mime_type: "application/json"}
  end

  @doc """
  Set plain text response format.
  """
  def text_response(config \\ %__MODULE__{}) do
    %{config | response_mime_type: "text/plain"}
  end

  @doc """
  Set deterministic generation seed.
  """
  @spec seed(t(), integer()) :: t()
  def seed(config \\ %__MODULE__{}, value) when is_integer(value) do
    %{config | seed: value}
  end

  @doc """
  Set response modalities for the model output.
  """
  @spec response_modalities(t(), [Modality.t()]) :: t()
  def response_modalities(config \\ %__MODULE__{}, modalities) when is_list(modalities) do
    %{config | response_modalities: modalities}
  end

  @doc """
  Set speech generation configuration.
  """
  @spec speech_config(t(), SpeechConfig.t()) :: t()
  def speech_config(config \\ %__MODULE__{}, %SpeechConfig{} = speech_config) do
    %{config | speech_config: speech_config}
  end

  @doc """
  Set media resolution preference.
  """
  @spec media_resolution(t(), MediaResolution.t()) :: t()
  def media_resolution(config \\ %__MODULE__{}, resolution) do
    %{config | media_resolution: resolution}
  end

  @doc """
  Set maximum output tokens.
  """
  def max_tokens(config \\ %__MODULE__{}, tokens) when is_integer(tokens) and tokens > 0 do
    %{config | max_output_tokens: tokens}
  end

  @doc """
  Add stop sequences.
  """
  def stop_sequences(config \\ %__MODULE__{}, sequences) when is_list(sequences) do
    %{config | stop_sequences: sequences}
  end

  @doc """
  Set thinking level for Gemini 3 models.

  Controls the depth of reasoning before the model responds.

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `level`: Thinking level atom
    - `:low` - Minimizes latency and cost. Best for simple instruction following.
    - `:high` - Maximizes reasoning depth. Model may take longer for first token.

  Note: `:medium` is not currently supported by the API.

  ## Important

  Cannot be used with `thinking_budget` in the same request.

  ## Examples

      # Fast responses for simple tasks
      config = GenerationConfig.thinking_level(:low)

      # Deep reasoning for complex tasks (default)
      config = GenerationConfig.thinking_level(:high)

      # Chain with other options
      config =
        GenerationConfig.new()
        |> GenerationConfig.thinking_level(:low)
        |> GenerationConfig.max_tokens(1000)
  """
  @spec thinking_level(t(), ThinkingConfig.thinking_level()) :: t()
  def thinking_level(config \\ %__MODULE__{}, level) when level in [:low, :medium, :high] do
    thinking_config = %ThinkingConfig{thinking_level: level}
    %{config | thinking_config: thinking_config}
  end

  @doc """
  Set thinking budget for Gemini 2.5 series models (legacy).

  For Gemini 3 models, use `thinking_level/2` instead.

  Controls how many thinking tokens the model can use for internal reasoning.

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `budget`: Integer controlling thinking tokens
    - `0`: Disable thinking (Flash/Lite only, NOT Pro)
    - `-1`: Dynamic thinking (model decides budget)
    - Positive integer: Fixed budget
      - Flash: 0-24,576
      - Pro: 128-32,768
      - Lite: 512-24,576

  ## Important

  Cannot be used with `thinking_level` in the same request.

  ## Examples

      # Disable thinking (save costs)
      config = GenerationConfig.thinking_budget(0)

      # Dynamic thinking (model decides)
      config = GenerationConfig.thinking_budget(-1)

      # Fixed budget (balance cost/quality)
      config = GenerationConfig.thinking_budget(1024)

      # Chain with other options
      config =
        GenerationConfig.new()
        |> GenerationConfig.temperature(0.7)
        |> GenerationConfig.thinking_budget(2048)
  """
  @spec thinking_budget(t(), integer()) :: t()
  def thinking_budget(config \\ %__MODULE__{}, budget) when is_integer(budget) do
    thinking_config = %ThinkingConfig{thinking_budget: budget}
    %{config | thinking_config: thinking_config}
  end

  @doc """
  Enable thought summaries in model response.

  When enabled, the model includes a summary of its reasoning process.

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `include`: Boolean to enable/disable thought summaries

  ## Examples

      # Enable thought summaries
      config = GenerationConfig.include_thoughts(true)

      # Combine with thinking budget
      config =
        GenerationConfig.new()
        |> GenerationConfig.thinking_budget(2048)
        |> GenerationConfig.include_thoughts(true)
  """
  @spec include_thoughts(t(), boolean()) :: t()
  def include_thoughts(config \\ %__MODULE__{}, include) when is_boolean(include) do
    current_thinking = config.thinking_config || %ThinkingConfig{}
    thinking_config = %{current_thinking | include_thoughts: include}
    %{config | thinking_config: thinking_config}
  end

  @doc """
  Set complete thinking configuration (budget + thoughts).

  Convenience function to set both thinking budget and thought inclusion.

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `budget`: Thinking budget integer
  - `opts`: Keyword list with optional `:include_thoughts` boolean

  ## Examples

      # Set budget and enable thoughts
      config = GenerationConfig.thinking_config(1024, include_thoughts: true)

      # Just budget (thoughts disabled)
      config = GenerationConfig.thinking_config(512)
  """
  @spec thinking_config(t(), integer(), keyword()) :: t()
  def thinking_config(config \\ %__MODULE__{}, budget, opts \\ [])
      when is_integer(budget) and is_list(opts) do
    include = Keyword.get(opts, :include_thoughts, false)

    thinking_config = %ThinkingConfig{
      thinking_budget: budget,
      include_thoughts: include
    }

    %{config | thinking_config: thinking_config}
  end

  @doc """
  Set temperature for response generation.

  Controls randomness in the output. Higher values (e.g., 0.9) make output more random,
  while lower values (e.g., 0.1) make it more focused and deterministic.

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `temp`: Temperature value (typically 0.0 to 1.0)

  ## Examples

      # Low temperature for focused output
      config = GenerationConfig.temperature(0.2)

      # High temperature for creative output
      config = GenerationConfig.temperature(0.9)

      # Chain with other options
      config =
        GenerationConfig.new()
        |> GenerationConfig.temperature(0.7)
        |> GenerationConfig.max_tokens(1000)
  """
  @spec temperature(t(), float()) :: t()
  def temperature(config \\ %__MODULE__{}, temp) when is_float(temp) or is_integer(temp) do
    %{config | temperature: temp / 1}
  end

  @doc """
  Set property ordering for Gemini 2.0 models.

  Explicitly defines the order in which properties appear in the generated JSON.
  Required for Gemini 2.0 Flash and Gemini 2.0 Flash-Lite when using structured outputs.
  Not needed for Gemini 2.5+ models (they preserve schema key order automatically).

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `ordering`: List of property names in desired order

  ## Examples

      # For Gemini 2.0 models
      config = GenerationConfig.property_ordering(["name", "age", "email"])

      # Chain with other options
      config =
        GenerationConfig.new()
        |> GenerationConfig.json_response()
        |> GenerationConfig.property_ordering(["firstName", "lastName"])

  ## Model Compatibility

  - **Gemini 2.5+**: Optional (implicit ordering from schema keys)
  - **Gemini 2.0**: Required when using structured outputs

  """
  @spec property_ordering(t(), [String.t()]) :: t()
  def property_ordering(config \\ %__MODULE__{}, ordering) when is_list(ordering) do
    %{config | property_ordering: ordering}
  end

  @doc """
  Configure structured JSON output with schema.

  Convenience helper that sets both response MIME type and schema in one call.
  This is the recommended way to set up structured outputs.

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `schema`: JSON Schema map defining the output structure

  ## Examples

      # Basic structured output
      config = GenerationConfig.structured_json(%{
        "type" => "object",
        "properties" => %{
          "answer" => %{"type" => "string"},
          "confidence" => %{"type" => "number"}
        }
      })

      # With property ordering for Gemini 2.0
      config =
        GenerationConfig.structured_json(%{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "age" => %{"type" => "integer"}
          }
        })
        |> GenerationConfig.property_ordering(["name", "age"])

      # Complex schema with new keywords
      config = GenerationConfig.structured_json(%{
        "type" => "object",
        "properties" => %{
          "score" => %{
            "type" => "number",
            "minimum" => 0,
            "maximum" => 100
          }
        }
      })

  ## Supported JSON Schema Keywords

  - Basic types: string, number, integer, boolean, object, array
  - Object: properties, required, additionalProperties
  - Array: items, prefixItems, minItems, maxItems
  - String: enum, format, pattern
  - Number: minimum, maximum, enum
  - Union types: anyOf
  - References: $ref
  - Nullable: type: ["string", "null"]

  See `docs/guides/structured_outputs.md` for comprehensive examples.

  """
  @spec structured_json(t(), map()) :: t()
  def structured_json(config \\ %__MODULE__{}, schema) when is_map(schema) do
    %{config | response_mime_type: "application/json", response_schema: schema}
  end

  @doc """
  Configure image generation settings for Gemini 3 Pro Image.

  Used with `gemini-3-pro-image-preview` model for generating images.

  ## Parameters
  - `config`: GenerationConfig struct (defaults to new config)
  - `opts`: Keyword list of image options
    - `:aspect_ratio` - Output aspect ratio (e.g., "16:9", "1:1", "4:3", "3:4", "9:16")
    - `:image_size` - Output resolution ("2K" or "4K")

  ## Examples

      # Generate 4K landscape image
      config = GenerationConfig.image_config(aspect_ratio: "16:9", image_size: "4K")

      # Generate square image at 2K
      config = GenerationConfig.image_config(aspect_ratio: "1:1", image_size: "2K")

      # Chain with other options
      config =
        GenerationConfig.new()
        |> GenerationConfig.image_config(aspect_ratio: "16:9", image_size: "4K")
  """
  @spec image_config(t(), keyword()) :: t()
  def image_config(config \\ %__MODULE__{}, opts) when is_list(opts) do
    image_cfg = %ImageConfig{
      aspect_ratio: Keyword.get(opts, :aspect_ratio),
      image_size: Keyword.get(opts, :image_size),
      output_mime_type: Keyword.get(opts, :output_mime_type),
      output_compression_quality: Keyword.get(opts, :output_compression_quality)
    }

    %{config | image_config: image_cfg}
  end
end
