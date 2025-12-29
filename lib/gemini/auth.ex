defmodule Gemini.Auth do
  @moduledoc """
  Authentication strategy behavior and implementations for Gemini and Vertex AI.

  This module provides a unified interface for different authentication methods:
  - Gemini API: Simple API key authentication
  - Vertex AI: OAuth2/Service Account authentication
  """

  @type auth_type :: :gemini | :vertex_ai
  @type credentials ::
          %{
            api_key: String.t()
          }
          | %{
              access_token: String.t(),
              project_id: String.t(),
              location: String.t()
            }

  defmodule Strategy do
    @moduledoc """
    Behavior for authentication strategies.
    """
    @callback headers(credentials :: map()) ::
                {:ok, [{String.t(), String.t()}]} | {:error, term()}
    @callback base_url(credentials :: map()) :: String.t()
    @callback build_path(model :: String.t(), endpoint :: String.t(), credentials :: map()) ::
                String.t()
    @callback refresh_credentials(credentials :: map()) :: {:ok, map()} | {:error, term()}
  end

  @doc """
  Get the appropriate authentication strategy based on configuration.
  """
  @spec get_strategy(auth_type()) :: module()
  def get_strategy(auth_type) do
    case auth_type do
      :gemini -> Gemini.Auth.GeminiStrategy
      :vertex_ai -> Gemini.Auth.VertexStrategy
      :vertex -> Gemini.Auth.VertexStrategy
      _ -> raise ArgumentError, "Unknown authentication type: #{inspect(auth_type)}"
    end
  end

  @doc """
  Authenticate using the given strategy and configuration.
  """
  @spec authenticate(module(), map()) :: {:ok, map()} | {:error, term()}
  def authenticate(strategy_module, config) do
    strategy_module.authenticate(config)
  end

  @doc """
  Get base URL using the given strategy and configuration.
  """
  @spec base_url(module(), map()) :: String.t() | {:error, term()}
  def base_url(strategy_module, config) do
    strategy_module.base_url(config)
  end

  @doc """
  Build authenticated headers for the given strategy and credentials.

  Returns `{:ok, headers}` on success, or `{:error, reason}` if authentication fails
  (e.g., service account token generation failure).
  """
  @spec build_headers(auth_type(), map()) ::
          {:ok, [{String.t(), String.t()}]} | {:error, term()}
  def build_headers(auth_type, credentials) do
    strategy = get_strategy(auth_type)
    strategy.headers(credentials)
  end

  @doc """
  Get the base URL for the given strategy and credentials.
  """
  @spec get_base_url(auth_type(), map()) :: String.t() | {:error, term()}
  def get_base_url(auth_type, credentials) do
    strategy = get_strategy(auth_type)
    strategy.base_url(credentials)
  end

  @doc """
  Build the full path for an API endpoint.
  """
  @spec build_path(auth_type(), String.t(), String.t(), map()) :: String.t()
  def build_path(auth_type, model, endpoint, credentials) do
    strategy = get_strategy(auth_type)
    strategy.build_path(model, endpoint, credentials)
  end

  @doc """
  Refresh credentials if needed (mainly for Vertex AI OAuth tokens).
  """
  @spec refresh_credentials(auth_type(), map()) :: {:ok, map()} | {:error, term()}
  def refresh_credentials(auth_type, credentials) do
    strategy = get_strategy(auth_type)
    strategy.refresh_credentials(credentials)
  end
end
