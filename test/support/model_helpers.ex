defmodule Gemini.Test.ModelHelpers do
  @moduledoc """
  Centralized model references and auth detection for tests.

  All tests should use these helpers instead of hardcoding model strings
  or duplicating auth detection logic.

  ## Usage

      import Gemini.Test.ModelHelpers

      test "works with any auth" do
        if auth_available?() do
          result = Gemini.generate("Hello", model: default_model())
        end
      end

      test "requires Gemini API only" do
        if gemini_api_available?() do
          # Models API only works with Gemini API
          {:ok, models} = Gemini.list_models()
        end
      end

  ## Auth Detection

  - `auth_available?/0` - True if ANY auth (Gemini or Vertex) is configured
  - `gemini_api_available?/0` - True only if Gemini API key is configured
  - `vertex_api_available?/0` - True only if Vertex AI is configured
  - `current_api/0` - Returns `:gemini` or `:vertex_ai`

  ## Model Selection

  - `default_model/0` - Generation model (auto-detects auth)
  - `embedding_model/0` - Embedding model (auto-detects auth)
  - `default_model_for/1` - Get model for specific API type
  """

  alias Gemini.Config
  alias Gemini.Test.AuthHelpers

  # =============================================================================
  # Auth Detection
  # =============================================================================

  @doc """
  Check if any authentication is available (Gemini API or Vertex AI).

  Use this for tests that work with either auth type.
  """
  @spec auth_available?() :: boolean()
  def auth_available? do
    case AuthHelpers.detect_auth() do
      {:ok, _, _} -> true
      :missing -> false
    end
  end

  @doc """
  Check if Gemini API authentication is available.

  Use this for tests that ONLY work with Gemini API (e.g., list_models, get_model).
  """
  @spec gemini_api_available?() :: boolean()
  def gemini_api_available? do
    case AuthHelpers.detect_auth() do
      {:ok, :gemini, _} -> true
      _ -> false
    end
  end

  @doc """
  Check if Vertex AI authentication is available.

  Use this for tests that ONLY work with Vertex AI.
  """
  @spec vertex_api_available?() :: boolean()
  def vertex_api_available? do
    case AuthHelpers.detect_auth() do
      {:ok, :vertex_ai, _} -> true
      _ -> false
    end
  end

  # =============================================================================
  # API Type Detection
  # =============================================================================

  @doc """
  Returns the current API type based on detected authentication.

  ## Returns
  - `:gemini` - When GEMINI_API_KEY is configured
  - `:vertex_ai` - When Vertex AI credentials are configured

  ## Examples

      case current_api() do
        :gemini -> IO.puts("Using Gemini API")
        :vertex_ai -> IO.puts("Using Vertex AI")
      end
  """
  @spec current_api() :: :gemini | :vertex_ai
  def current_api, do: Config.current_api_type()

  @doc """
  Returns the default generation model for the detected auth type.

  - **Gemini API**: `"gemini-flash-lite-latest"`
  - **Vertex AI**: `"gemini-2.5-flash-lite"`

  Use this for ALL tests unless a specific capability is required.
  """
  @spec default_model() :: String.t()
  def default_model, do: Config.default_model()

  @doc """
  Returns the default model for a specific API type.

  ## Parameters
  - `api_type`: `:gemini` or `:vertex_ai`

  ## Examples

      default_model_for(:gemini)
      #=> "gemini-flash-lite-latest"

      default_model_for(:vertex_ai)
      #=> "gemini-2.5-flash-lite"
  """
  @spec default_model_for(:gemini | :vertex_ai) :: String.t()
  def default_model_for(api_type), do: Config.default_model_for(api_type)

  @doc """
  Returns the embedding model for the detected auth type.

  - **Gemini API**: `"gemini-embedding-001"` (3072 dimensions)
  - **Vertex AI**: `"embeddinggemma"` (768 dimensions)

  Only use for embedding API tests.
  """
  @spec embedding_model() :: String.t()
  def embedding_model, do: Config.default_embedding_model()

  @doc """
  Returns the embedding model for a specific API type.

  ## Parameters
  - `api_type`: `:gemini` or `:vertex_ai`

  ## Examples

      embedding_model_for(:gemini)
      #=> "gemini-embedding-001"

      embedding_model_for(:vertex_ai)
      #=> "embeddinggemma"
  """
  @spec embedding_model_for(:gemini | :vertex_ai) :: String.t()
  def embedding_model_for(api_type), do: Config.default_embedding_model_for(api_type)

  @doc """
  Returns a model with thinking/reasoning capability.

  Only use for tests that specifically require thinking capability.
  Uses flash_2_5 which supports thinking_budget configuration.

  Note: This model works with both Gemini API and Vertex AI.
  """
  @spec thinking_model() :: String.t()
  def thinking_model, do: Config.get_model(:flash_2_5)

  @doc """
  Check if a model key is available for the current auth type.

  ## Examples

      if model_available?(:flash_lite_latest) do
        # Use AI Studio-specific alias
      else
        # Use universal model
      end
  """
  @spec model_available?(atom()) :: boolean()
  def model_available?(model_key), do: Config.model_available?(model_key, current_api())

  @doc """
  Returns a universal model that works with both APIs.

  Use this when you need a model that's guaranteed to work regardless
  of which authentication is configured.
  """
  @spec universal_model() :: String.t()
  def universal_model, do: Config.get_model(:flash_2_5_lite)

  @doc """
  Returns a model that supports structured outputs for both APIs.

  Flash 2.5 supports JSON schema-based structured outputs.
  """
  @spec structured_output_model() :: String.t()
  def structured_output_model, do: Config.get_model(:flash_2_5)

  @doc """
  Returns a model that supports context caching.

  Only specific model versions support explicit caching:
  - gemini-2.5-flash
  - gemini-2.5-flash-lite
  - gemini-2.5-pro
  - gemini-3-pro-preview
  - gemini-3-flash-preview

  Use this for context cache tests.
  """
  @spec caching_model() :: String.t()
  def caching_model, do: Config.get_model(:flash_2_5)

  @doc """
  Get the default embedding dimensions for the current auth type.

  - **Gemini API**: 3072
  - **Vertex AI**: 768
  """
  @spec default_embedding_dimensions() :: pos_integer()
  def default_embedding_dimensions do
    model = embedding_model()
    Config.default_embedding_dimensions(model) || 768
  end

  @doc """
  Check if embeddings from the current auth type need normalization.

  Gemini API embeddings need normalization for dimensions below 3072.
  EmbeddingGemma (Vertex AI) embeddings are always pre-normalized.

  ## Parameters
  - `dimensions`: The output dimensions being used
  """
  @spec needs_embedding_normalization?(pos_integer()) :: boolean()
  def needs_embedding_normalization?(dimensions) do
    Config.needs_normalization?(embedding_model(), dimensions)
  end
end
