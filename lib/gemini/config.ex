defmodule Gemini.Config do
  @moduledoc """
  Unified configuration management for both Gemini and Vertex AI authentication.

  Supports multiple authentication strategies:
  - Gemini API (AI Studio): API key authentication
  - Vertex AI: OAuth2 or Service Account authentication

  ## Model Registry

  Models are organized by API compatibility:
  - **Universal models**: Work identically in both Gemini API and Vertex AI
  - **Gemini API models**: Only available in AI Studio (convenience aliases like `-latest`)
  - **Vertex AI models**: Only available in Vertex AI (e.g., EmbeddingGemma)

  Use `models_for/1` to discover available models for your auth type.

  ## Auth-Aware Defaults

  Default models are automatically selected based on detected authentication:
  - Gemini API: `gemini-flash-lite-latest` (convenience alias)
  - Vertex AI: `gemini-2.0-flash-lite` (universal name)

  For embeddings:
  - Gemini API: `gemini-embedding-001` (3072 dimensions)
  - Vertex AI: `embeddinggemma` (768 dimensions)

  ## Examples

      # Auto-detects auth and uses appropriate default
      Gemini.generate("Hello")

      # Get models available for specific API
      Config.models_for(:vertex_ai)

      # Check if a model works with an API
      Config.model_available?(:flash_lite_latest, :vertex_ai)
      #=> false

      # Get auth-aware embedding model
      Config.default_embedding_model()
  """

  require Logger

  @type auth_config :: %{
          type: :gemini | :vertex_ai,
          credentials: map()
        }

  @type api_type :: :gemini | :vertex_ai | :both
  @type model_category :: :generation | :embedding | :thinking | :image | :live | :tts

  # ===========================================================================
  # Model Registry - Organized by API Compatibility
  # ===========================================================================

  # Universal models - work identically in both Gemini API and Vertex AI
  @universal_models %{
    # Gemini 3 models (preview)
    pro_3_preview: "gemini-3-pro-preview",
    pro_3_image_preview: "gemini-3-pro-image-preview",

    # Gemini 2.5 models (GA)
    pro_2_5: "gemini-2.5-pro",
    flash_2_5: "gemini-2.5-flash",
    flash_2_5_lite: "gemini-2.5-flash-lite",

    # Gemini 2.5 preview/specialized
    live_2_5_flash_preview: "gemini-live-2.5-flash-preview",
    flash_2_5_preview_native_audio_dialog: "gemini-2.5-flash-preview-native-audio-dialog",
    flash_2_5_exp_native_audio_thinking_dialog:
      "gemini-2.5-flash-exp-native-audio-thinking-dialog",
    flash_2_5_preview_tts: "gemini-2.5-flash-preview-tts",
    pro_2_5_preview_tts: "gemini-2.5-pro-preview-tts",

    # Gemini 2.0 models
    flash_2_0: "gemini-2.0-flash",
    flash_2_0_preview_image_generation: "gemini-2.0-flash-preview-image-generation",
    flash_2_0_lite: "gemini-2.0-flash-lite",
    flash_2_0_live_001: "gemini-2.0-flash-live-001",

    # Universal aliases (use these for cross-platform compatibility)
    default_universal: "gemini-2.0-flash-lite",
    latest: "gemini-3-pro-preview",
    stable: "gemini-2.5-pro"
  }

  # Gemini API (AI Studio) only models - convenience aliases that don't work on Vertex AI
  @gemini_api_models %{
    # Convenience aliases (AI Studio only - Vertex AI doesn't support -latest suffix)
    flash_lite_latest: "gemini-flash-lite-latest",
    flash_latest: "gemini-flash-latest",
    pro_latest: "gemini-pro-latest",

    # Embedding model for AI Studio
    embedding: "gemini-embedding-001",
    embedding_exp: "gemini-embedding-exp-03-07",

    # Legacy default alias (AI Studio only)
    default: "gemini-flash-lite-latest"
  }

  # Vertex AI only models - not available in Gemini API (AI Studio)
  @vertex_ai_models %{
    # EmbeddingGemma - Vertex AI's embedding model
    # 300M parameters, 768 dimensions (supports MRL: 128, 256, 512, 768)
    embedding_gemma: "embeddinggemma",
    embedding_gemma_300m: "embeddinggemma-300m",

    # Vertex AI default alias
    default: "gemini-2.0-flash-lite"
  }

  # Default models per API type
  @default_generation_models %{
    gemini: "gemini-flash-lite-latest",
    vertex_ai: "gemini-2.0-flash-lite"
  }

  @default_embedding_models %{
    gemini: "gemini-embedding-001",
    vertex_ai: "embeddinggemma"
  }

  # Embedding configuration per model
  @embedding_config %{
    "gemini-embedding-001" => %{
      default_dimensions: 3072,
      supported_dimensions: [128, 256, 512, 768, 1536, 3072],
      recommended_dimensions: [768, 1536, 3072],
      uses_task_type_param: true,
      requires_normalization_below: 3072
    },
    "gemini-embedding-exp-03-07" => %{
      default_dimensions: 3072,
      supported_dimensions: [128, 256, 512, 768, 1536, 3072],
      recommended_dimensions: [768, 1536, 3072],
      uses_task_type_param: true,
      requires_normalization_below: 3072
    },
    "embeddinggemma" => %{
      default_dimensions: 768,
      supported_dimensions: [128, 256, 512, 768],
      recommended_dimensions: [768],
      uses_task_type_param: false,
      uses_prompt_prefix: true,
      # All dimensions are normalized
      requires_normalization_below: nil
    },
    "embeddinggemma-300m" => %{
      default_dimensions: 768,
      supported_dimensions: [128, 256, 512, 768],
      recommended_dimensions: [768],
      uses_task_type_param: false,
      uses_prompt_prefix: true,
      requires_normalization_below: nil
    }
  }

  # EmbeddingGemma task type to prompt prefix mapping
  @embedding_gemma_prompts %{
    retrieval_query: "task: search result | query: ",
    retrieval_document: "title: {title} | text: ",
    question_answering: "task: question answering | query: ",
    fact_verification: "task: fact checking | query: ",
    classification: "task: classification | query: ",
    clustering: "task: clustering | query: ",
    semantic_similarity: "task: sentence similarity | query: ",
    code_retrieval_query: "task: code retrieval | query: "
  }

  # Combined models map for backward compatibility (prioritizes universal)
  @models Map.merge(@universal_models, @gemini_api_models)

  @doc """
  Get configuration based on environment variables and application config.
  Returns a structured configuration map.
  """
  def get do
    auth_type = detect_auth_type()

    case auth_type do
      :gemini ->
        %{
          auth_type: :gemini,
          api_key: gemini_api_key() || Application.get_env(:gemini_ex, :api_key),
          model: default_model()
        }

      :vertex ->
        %{
          auth_type: :vertex,
          project_id: vertex_project_id(),
          location: vertex_location(),
          model: default_model()
        }
    end
  end

  @doc """
  Get configuration with overrides.
  """
  def get(overrides) when is_list(overrides) do
    base_config = get()
    override_map = Enum.into(overrides, %{})

    Map.merge(base_config, override_map)
  end

  @doc """
  Detect authentication type based on environment variables.
  """
  def detect_auth_type do
    cond do
      gemini_api_key() -> :gemini
      vertex_project_id() && vertex_project_id() != "" -> :vertex
      # default
      true -> :gemini
    end
  end

  @doc """
  Detect authentication type based on configuration map.
  """
  def detect_auth_type(%{api_key: api_key, project_id: _project_id}) when not is_nil(api_key) do
    # gemini takes priority
    :gemini
  end

  def detect_auth_type(%{project_id: project_id}) when not is_nil(project_id) do
    :vertex
  end

  def detect_auth_type(%{api_key: api_key}) when not is_nil(api_key) do
    :gemini
  end

  def detect_auth_type(%{}) do
    # default
    :gemini
  end

  @doc """
  Get the authentication configuration.

  Returns a map with the authentication type and credentials.
  Priority order:
  1. Environment variables
  2. Application configuration
  3. Default to Gemini with API key
  """
  def auth_config do
    cond do
      gemini_api_key() ->
        %{
          type: :gemini,
          credentials: %{api_key: gemini_api_key()}
        }

      vertex_access_token() && vertex_project_id() ->
        %{
          type: :vertex_ai,
          credentials: %{
            access_token: vertex_access_token(),
            project_id: vertex_project_id(),
            location: vertex_location()
          }
        }

      vertex_service_account() &&
          (vertex_project_id() ||
             load_project_from_service_account(vertex_service_account()) |> elem_or_nil()) ->
        service_account_path = vertex_service_account()

        # Load and parse the service account file to get project_id if not provided
        project_id =
          case vertex_project_id() do
            nil ->
              case load_project_from_service_account(service_account_path) do
                {:ok, project} -> project
                _ -> nil
              end

            project ->
              project
          end

        if project_id do
          %{
            type: :vertex_ai,
            credentials: %{
              service_account_key: service_account_path,
              project_id: project_id,
              location: vertex_location()
            }
          }
        else
          nil
        end

      true ->
        # Check application config
        app_auth = Application.get_env(:gemini, :auth) || Application.get_env(:gemini_ex, :auth)

        case app_auth do
          nil ->
            # Default to looking for basic API key config
            case Application.get_env(:gemini_ex, :api_key) ||
                   Application.get_env(:gemini, :api_key) do
              nil -> nil
              api_key -> %{type: :gemini, credentials: %{api_key: api_key}}
            end

          config ->
            config
        end
    end
  end

  @doc """
  Get the API key from environment or application config.
  (Legacy function for backward compatibility)
  """
  def api_key do
    gemini_api_key() || Application.get_env(:gemini_ex, :api_key)
  end

  # ===========================================================================
  # Auth-Aware Default Model Functions
  # ===========================================================================

  @doc """
  Get the default generation model for the current authentication type.

  Returns different defaults based on detected auth:
  - Gemini API (AI Studio): `"gemini-flash-lite-latest"` (convenience alias)
  - Vertex AI: `"gemini-2.0-flash-lite"` (universal name)

  Can be overridden via application config:

      config :gemini_ex, :default_model, "your-model"

  ## Examples

      # With GEMINI_API_KEY set
      Config.default_model()
      #=> "gemini-flash-lite-latest"

      # With VERTEX_PROJECT_ID set
      Config.default_model()
      #=> "gemini-2.0-flash-lite"
  """
  @spec default_model() :: String.t()
  def default_model do
    case Application.get_env(:gemini_ex, :default_model) do
      nil -> default_model_for_auth()
      model -> model
    end
  end

  @doc """
  Get the default model for a specific API type.

  ## Parameters
  - `api_type`: `:gemini` or `:vertex_ai`

  ## Examples

      Config.default_model_for(:gemini)
      #=> "gemini-flash-lite-latest"

      Config.default_model_for(:vertex_ai)
      #=> "gemini-2.0-flash-lite"
  """
  @spec default_model_for(api_type()) :: String.t()
  def default_model_for(:gemini), do: @default_generation_models[:gemini]
  def default_model_for(:vertex_ai), do: @default_generation_models[:vertex_ai]
  def default_model_for(:both), do: @default_generation_models[:vertex_ai]

  @doc """
  Get the default embedding model for the current authentication type.

  Returns different defaults based on detected auth:
  - Gemini API (AI Studio): `"gemini-embedding-001"` (3072 dimensions)
  - Vertex AI: `"embeddinggemma"` (768 dimensions)

  Can be overridden via application config:

      config :gemini_ex, :default_embedding_model, "your-model"

  ## Examples

      # With GEMINI_API_KEY set
      Config.default_embedding_model()
      #=> "gemini-embedding-001"

      # With VERTEX_PROJECT_ID set
      Config.default_embedding_model()
      #=> "embeddinggemma"
  """
  @spec default_embedding_model() :: String.t()
  def default_embedding_model do
    case Application.get_env(:gemini_ex, :default_embedding_model) do
      nil -> default_embedding_model_for_auth()
      model -> model
    end
  end

  @doc """
  Get the default embedding model for a specific API type.

  ## Parameters
  - `api_type`: `:gemini` or `:vertex_ai`

  ## Examples

      Config.default_embedding_model_for(:gemini)
      #=> "gemini-embedding-001"

      Config.default_embedding_model_for(:vertex_ai)
      #=> "embeddinggemma"
  """
  @spec default_embedding_model_for(api_type()) :: String.t()
  def default_embedding_model_for(:gemini), do: @default_embedding_models[:gemini]
  def default_embedding_model_for(:vertex_ai), do: @default_embedding_models[:vertex_ai]
  def default_embedding_model_for(:both), do: @default_embedding_models[:gemini]

  # Private helpers for auth-aware defaults
  defp default_model_for_auth do
    case current_api_type() do
      :vertex_ai -> @default_generation_models[:vertex_ai]
      :gemini -> @default_generation_models[:gemini]
    end
  end

  defp default_embedding_model_for_auth do
    case current_api_type() do
      :vertex_ai -> @default_embedding_models[:vertex_ai]
      :gemini -> @default_embedding_models[:gemini]
    end
  end

  @doc """
  Get the current API type based on detected authentication.

  Returns `:gemini` or `:vertex_ai` based on which credentials are configured.
  """
  @spec current_api_type() :: :gemini | :vertex_ai
  def current_api_type do
    case detect_auth_type() do
      :vertex -> :vertex_ai
      :gemini -> :gemini
    end
  end

  # ===========================================================================
  # Model Lookup and Validation
  # ===========================================================================

  @doc """
  Get a model name by its key or return the string if it's already a model name.

  Optionally validates that the model is available for a specific API.

  ## Parameters
  - `model_key`: Atom key or string model name
  - `opts`: Optional keyword list
    - `:api` - Validate model works with `:gemini` or `:vertex_ai`
    - `:strict` - If true, raise on incompatible model (default: false, warns)

  ## Examples

      iex> Gemini.Config.get_model(:flash_2_0)
      "gemini-2.0-flash"

      iex> Gemini.Config.get_model("gemini-1.5-pro")
      "gemini-1.5-pro"

      iex> Gemini.Config.get_model(:flash_lite_latest, api: :vertex_ai)
      # Logs warning: Model flash_lite_latest (gemini-flash-lite-latest) may not be available on vertex_ai
      "gemini-flash-lite-latest"

      iex> Gemini.Config.get_model(:flash_lite_latest, api: :vertex_ai, strict: true)
      # ** (ArgumentError) Model :flash_lite_latest not available on vertex_ai
  """
  @spec get_model(atom() | String.t(), keyword()) :: String.t()
  def get_model(model_key, opts \\ [])

  def get_model(model_name, _opts) when is_binary(model_name), do: model_name

  def get_model(model_key, opts) when is_atom(model_key) do
    case lookup_model(model_key) do
      {model_name, api_compat} ->
        if api = Keyword.get(opts, :api) do
          validate_model_compat(model_key, model_name, api_compat, api, opts)
        end

        model_name

      :not_found ->
        all_keys =
          Map.keys(@universal_models) ++
            Map.keys(@gemini_api_models) ++ Map.keys(@vertex_ai_models)

        raise ArgumentError,
              "Unknown model key: #{model_key}. Available keys: #{inspect(Enum.uniq(all_keys))}"
    end
  end

  @doc """
  List all models available for a specific API type.

  ## Parameters
  - `api_type`: `:gemini`, `:vertex_ai`, or `:both` (universal only)

  ## Examples

      Config.models_for(:gemini)
      #=> %{flash_lite_latest: "gemini-flash-lite-latest", flash_2_0: "gemini-2.0-flash", ...}

      Config.models_for(:vertex_ai)
      #=> %{embedding_gemma: "embeddinggemma", flash_2_0: "gemini-2.0-flash", ...}

      Config.models_for(:both)
      #=> %{flash_2_0: "gemini-2.0-flash", ...}  # Only universal models
  """
  @spec models_for(api_type()) :: map()
  def models_for(:gemini), do: Map.merge(@universal_models, @gemini_api_models)
  def models_for(:vertex_ai), do: Map.merge(@universal_models, @vertex_ai_models)
  def models_for(:both), do: @universal_models

  @doc """
  Check if a model key is available for a specific API type.

  ## Parameters
  - `model_key`: Atom model key to check
  - `api_type`: `:gemini` or `:vertex_ai`

  ## Examples

      Config.model_available?(:flash_2_0, :vertex_ai)
      #=> true

      Config.model_available?(:flash_lite_latest, :vertex_ai)
      #=> false

      Config.model_available?(:embedding_gemma, :gemini)
      #=> false
  """
  @spec model_available?(atom(), api_type()) :: boolean()
  def model_available?(model_key, api_type) when is_atom(model_key) do
    models_for(api_type) |> Map.has_key?(model_key)
  end

  @doc """
  Get all available model definitions (combined for backward compatibility).

  For API-specific models, use `models_for/1` instead.

  ## Returns

  A map of model keys to model names (universal + Gemini API models).
  """
  @spec models() :: map()
  def models do
    @models
  end

  @doc """
  Check if a model key exists in the combined model registry.

  ## Examples

      iex> Gemini.Config.has_model?(:flash_2_0)
      true

      iex> Gemini.Config.has_model?(:unknown)
      false
  """
  @spec has_model?(atom()) :: boolean()
  def has_model?(model_key) when is_atom(model_key) do
    Map.has_key?(@universal_models, model_key) or
      Map.has_key?(@gemini_api_models, model_key) or
      Map.has_key?(@vertex_ai_models, model_key)
  end

  @doc """
  Get the API compatibility of a model key.

  ## Returns
  - `:both` - Model works in both Gemini API and Vertex AI
  - `:gemini` - Model only works in Gemini API (AI Studio)
  - `:vertex_ai` - Model only works in Vertex AI

  ## Examples

      Config.model_api(:flash_2_0)
      #=> :both

      Config.model_api(:flash_lite_latest)
      #=> :gemini

      Config.model_api(:embedding_gemma)
      #=> :vertex_ai
  """
  @spec model_api(atom()) :: api_type() | nil
  def model_api(model_key) when is_atom(model_key) do
    cond do
      Map.has_key?(@universal_models, model_key) -> :both
      Map.has_key?(@gemini_api_models, model_key) -> :gemini
      Map.has_key?(@vertex_ai_models, model_key) -> :vertex_ai
      true -> nil
    end
  end

  # ===========================================================================
  # Embedding Configuration
  # ===========================================================================

  @doc """
  Get embedding configuration for a specific model.

  Returns configuration including supported dimensions, task type handling, etc.

  ## Parameters
  - `model`: Model name string

  ## Returns
  Map with embedding configuration or nil if not an embedding model.

  ## Examples

      Config.embedding_config("gemini-embedding-001")
      #=> %{
      #=>   default_dimensions: 3072,
      #=>   supported_dimensions: [128, 256, 512, 768, 1536, 3072],
      #=>   recommended_dimensions: [768, 1536, 3072],
      #=>   uses_task_type_param: true,
      #=>   requires_normalization_below: 3072
      #=> }

      Config.embedding_config("embeddinggemma")
      #=> %{
      #=>   default_dimensions: 768,
      #=>   supported_dimensions: [128, 256, 512, 768],
      #=>   uses_task_type_param: false,
      #=>   uses_prompt_prefix: true,
      #=>   ...
      #=> }
  """
  @spec embedding_config(String.t()) :: map() | nil
  def embedding_config(model) when is_binary(model) do
    Map.get(@embedding_config, model)
  end

  @doc """
  Check if an embedding model uses prompt prefixes for task types.

  EmbeddingGemma uses prompt prefixes like "task: search result | query: "
  while Gemini embedding models use a taskType parameter.

  ## Examples

      Config.uses_prompt_prefix?("embeddinggemma")
      #=> true

      Config.uses_prompt_prefix?("gemini-embedding-001")
      #=> false
  """
  @spec uses_prompt_prefix?(String.t()) :: boolean()
  def uses_prompt_prefix?(model) when is_binary(model) do
    case embedding_config(model) do
      %{uses_prompt_prefix: true} -> true
      _ -> false
    end
  end

  @doc """
  Get the prompt prefix for an EmbeddingGemma task type.

  ## Parameters
  - `task_type`: Task type atom (e.g., `:retrieval_query`, `:semantic_similarity`)
  - `opts`: Optional keyword list
    - `:title` - Document title for `:retrieval_document` task type

  ## Examples

      Config.embedding_prompt_prefix(:retrieval_query)
      #=> "task: search result | query: "

      Config.embedding_prompt_prefix(:retrieval_document, title: "My Document")
      #=> "title: My Document | text: "

      Config.embedding_prompt_prefix(:retrieval_document)
      #=> "title: none | text: "
  """
  @spec embedding_prompt_prefix(atom(), keyword()) :: String.t()
  def embedding_prompt_prefix(task_type, opts \\ []) do
    case Map.get(@embedding_gemma_prompts, task_type) do
      nil ->
        # Default to retrieval query if unknown task type
        "task: search result | query: "

      prefix when task_type == :retrieval_document ->
        title = Keyword.get(opts, :title, "none")
        String.replace(prefix, "{title}", title)

      prefix ->
        prefix
    end
  end

  @doc """
  Get the default output dimensionality for an embedding model.

  ## Examples

      Config.default_embedding_dimensions("gemini-embedding-001")
      #=> 3072

      Config.default_embedding_dimensions("embeddinggemma")
      #=> 768
  """
  @spec default_embedding_dimensions(String.t()) :: pos_integer() | nil
  def default_embedding_dimensions(model) when is_binary(model) do
    case embedding_config(model) do
      %{default_dimensions: dims} -> dims
      _ -> nil
    end
  end

  @doc """
  Check if an embedding needs normalization for a given dimensionality.

  Gemini embedding models only return normalized embeddings at full dimensionality.
  Lower dimensions need manual normalization. EmbeddingGemma is always normalized.

  ## Examples

      Config.needs_normalization?("gemini-embedding-001", 768)
      #=> true

      Config.needs_normalization?("gemini-embedding-001", 3072)
      #=> false

      Config.needs_normalization?("embeddinggemma", 256)
      #=> false  # EmbeddingGemma is always normalized
  """
  @spec needs_normalization?(String.t(), pos_integer()) :: boolean()
  def needs_normalization?(model, dimensions) when is_binary(model) and is_integer(dimensions) do
    case embedding_config(model) do
      %{requires_normalization_below: nil} -> false
      %{requires_normalization_below: threshold} -> dimensions < threshold
      _ -> false
    end
  end

  # Private helper to look up model with its API compatibility
  defp lookup_model(key) do
    cond do
      model = Map.get(@universal_models, key) -> {model, :both}
      model = Map.get(@gemini_api_models, key) -> {model, :gemini}
      model = Map.get(@vertex_ai_models, key) -> {model, :vertex_ai}
      true -> :not_found
    end
  end

  defp validate_model_compat(key, name, model_api, requested_api, opts) do
    compatible? = model_api == :both or model_api == requested_api

    unless compatible? do
      msg = "Model #{key} (#{name}) may not be available on #{requested_api}"

      if Keyword.get(opts, :strict, false) do
        suggestion = suggest_alternative(key, requested_api)

        raise ArgumentError,
              msg <>
                ". Use a universal model or one specific to #{requested_api}." <>
                if(suggestion, do: " Suggested alternative: #{suggestion}", else: "")
      else
        Logger.warning("[Gemini.Config] #{msg}")
      end
    end
  end

  # Suggest alternative models when using incompatible model
  defp suggest_alternative(:flash_lite_latest, :vertex_ai), do: ":flash_2_0_lite"
  defp suggest_alternative(:flash_latest, :vertex_ai), do: ":flash_2_0"
  defp suggest_alternative(:embedding, :vertex_ai), do: ":embedding_gemma"
  defp suggest_alternative(:embedding_gemma, :gemini), do: ":embedding"
  defp suggest_alternative(_, _), do: nil

  @doc """
  Get HTTP timeout in milliseconds.
  """
  def timeout do
    Application.get_env(:gemini_ex, :timeout, 120_000)
  end

  @doc """
  Get the base URL for the current authentication type.
  (Legacy function - now determined by auth strategy)
  """
  def base_url do
    case auth_config() do
      %{type: :gemini, credentials: credentials} ->
        Gemini.Auth.get_base_url(:gemini, credentials)

      %{type: :vertex_ai, credentials: credentials} ->
        Gemini.Auth.get_base_url(:vertex_ai, credentials)

      _ ->
        Application.get_env(
          :gemini,
          :base_url,
          "https://generativelanguage.googleapis.com/v1beta"
        )
    end
  end

  @doc """
  Validate that required configuration is present.
  """
  def validate! do
    case auth_config() do
      nil ->
        raise """
        No authentication configured. Please set one of:

        For Gemini API:
        - Environment variable: GEMINI_API_KEY
        - Application config: config :gemini, api_key: "your_api_key"

        For Vertex AI:
        - Environment variables: VERTEX_ACCESS_TOKEN, VERTEX_PROJECT_ID, VERTEX_LOCATION
        - Environment variables: VERTEX_SERVICE_ACCOUNT, VERTEX_PROJECT_ID, VERTEX_LOCATION
        - Application config: config :gemini, auth: %{type: :vertex_ai, credentials: %{...}}
        """

      %{type: :gemini, credentials: %{api_key: nil}} ->
        raise "Gemini API key is nil"

      %{type: :vertex_ai, credentials: credentials} ->
        validate_vertex_config!(credentials)

      %{type: :gemini} ->
        :ok

      _ ->
        raise "Invalid authentication configuration"
    end
  end

  @doc """
  Check if telemetry is enabled.

  Determines whether telemetry events should be emitted based on the
  application configuration. Telemetry is enabled by default unless
  explicitly disabled.

  ## Configuration

  Set `:telemetry_enabled` to `false` in your application config to disable:

      config :gemini, telemetry_enabled: false

  ## Returns

  - `true` - Telemetry is enabled (default)
  - `false` - Telemetry is explicitly disabled

  ## Examples

      iex> # Default behavior (telemetry enabled)
      iex> Gemini.Config.telemetry_enabled?()
      true

      iex> # Explicitly disabled
      iex> Application.put_env(:gemini, :telemetry_enabled, false)
      iex> Gemini.Config.telemetry_enabled?()
      false

      iex> # Any other value defaults to enabled
      iex> Application.put_env(:gemini, :telemetry_enabled, :maybe)
      iex> Gemini.Config.telemetry_enabled?()
      true
  """
  @spec telemetry_enabled? :: boolean()
  def telemetry_enabled? do
    case Application.get_env(:gemini_ex, :telemetry_enabled) do
      false -> false
      _ -> true
    end
  end

  @doc """
  Get authentication configuration for a specific strategy.

  ## Parameters
  - `strategy`: The authentication strategy (`:gemini` or `:vertex_ai`)

  ## Returns
  - A map containing configuration for the specified strategy
  - Returns empty map if no configuration found

  ## Examples

      iex> Gemini.Config.get_auth_config(:gemini)
      %{api_key: "your_api_key"}

      iex> Gemini.Config.get_auth_config(:vertex_ai)
      %{project_id: "your-project", location: "us-central1"}
  """
  @spec get_auth_config(:gemini | :vertex_ai) :: map()
  def get_auth_config(:gemini) do
    cond do
      # App env via configure/2
      match?(%{type: :gemini, credentials: %{api_key: _}}, Application.get_env(:gemini, :auth)) ->
        %{credentials: %{api_key: api_key}} = Application.get_env(:gemini, :auth)
        %{api_key: api_key}

      # Legacy app env
      is_binary(Application.get_env(:gemini_ex, :api_key)) ->
        %{api_key: Application.get_env(:gemini_ex, :api_key)}

      # Direct env var
      is_binary(gemini_api_key()) ->
        %{api_key: gemini_api_key()}

      true ->
        %{}
    end
  end

  def get_auth_config(:vertex_ai) do
    base =
      %{}
      |> maybe_put(:project_id, vertex_project_id())
      |> Map.put(:location, vertex_location())

    app_auth = Application.get_env(:gemini, :auth)
    legacy_app_auth = Application.get_env(:gemini_ex, :auth)
    legacy_vertex = Application.get_env(:gemini_ex, :vertex_ai, %{})

    creds_from_app =
      cond do
        match?(%{type: :vertex_ai, credentials: %{}}, app_auth) ->
          app_auth.credentials

        match?(%{type: :vertex_ai, credentials: %{}}, legacy_app_auth) ->
          legacy_app_auth.credentials

        true ->
          legacy_vertex
      end

    config =
      base
      |> Map.merge(creds_from_app || %{})
      |> maybe_put(:project_id, vertex_project_id())
      |> maybe_put(:location, vertex_location())
      |> maybe_put(:access_token, vertex_access_token())
      |> maybe_put(:service_account_key, vertex_service_account())

    config
  end

  def get_auth_config(_strategy) do
    %{}
  end

  # Private functions for environment variable access

  defp gemini_api_key do
    get_env_non_empty("GEMINI_API_KEY")
  end

  defp vertex_access_token do
    get_env_non_empty("VERTEX_ACCESS_TOKEN")
  end

  defp vertex_service_account do
    get_env_non_empty("VERTEX_SERVICE_ACCOUNT") || get_env_non_empty("VERTEX_JSON_FILE")
  end

  defp vertex_project_id do
    get_env_non_empty("VERTEX_PROJECT_ID") || get_env_non_empty("GOOGLE_CLOUD_PROJECT")
  end

  defp vertex_location do
    get_env_non_empty("VERTEX_LOCATION") || get_env_non_empty("GOOGLE_CLOUD_LOCATION") ||
      "us-central1"
  end

  # Returns nil for empty strings, so "" is treated as "not set"
  defp get_env_non_empty(var) do
    case System.get_env(var) do
      nil -> nil
      "" -> nil
      value -> value
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp elem_or_nil({:ok, value}), do: value
  defp elem_or_nil(_), do: nil

  defp validate_vertex_config!(%{access_token: token, project_id: project, location: location})
       when is_binary(token) and is_binary(project) and is_binary(location) do
    :ok
  end

  defp validate_vertex_config!(%{
         service_account_key: key,
         project_id: project,
         location: location
       })
       when is_binary(key) and is_binary(project) and is_binary(location) do
    :ok
  end

  defp validate_vertex_config!(credentials) do
    raise "Invalid Vertex AI configuration: #{inspect(credentials)}"
  end

  defp load_project_from_service_account(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"project_id" => project_id}} -> {:ok, project_id}
          {:ok, _} -> {:error, "No project_id found in service account file"}
          {:error, reason} -> {:error, "Failed to parse JSON: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end
end
