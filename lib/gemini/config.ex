defmodule Gemini.Config do
  @moduledoc """
  Unified configuration management for both Gemini and Vertex AI authentication.

  Supports multiple authentication strategies:
  - Gemini: API key authentication
  - Vertex AI: OAuth2 or Service Account authentication
  """

  @type auth_config :: %{
          type: :gemini | :vertex_ai,
          credentials: map()
        }

  @default_model "gemini-2.0-flash-lite"

  # Model definitions
  @models %{
    # Gemini 2.5 models
    pro_2_5: "gemini-2.5-pro",
    flash_2_5: "gemini-2.5-flash",
    flash_2_5_lite: "gemini-2.5-flash-lite",
    live_2_5_flash_preview: "gemini-live-2.5-flash-preview",
    flash_2_5_preview_native_audio_dialog: "gemini-2.5-flash-preview-native-audio-dialog",
    flash_2_5_exp_native_audio_thinking_dialog: "gemini-2.5-flash-exp-native-audio-thinking-dialog",
    flash_2_5_preview_tts: "gemini-2.5-flash-preview-tts",
    pro_2_5_preview_tts: "gemini-2.5-pro-preview-tts",

    # Gemini 2.0 models
    flash_2_0: "gemini-2.0-flash",
    flash_2_0_preview_image_generation: "gemini-2.0-flash-preview-image-generation",
    flash_2_0_lite: "gemini-2.0-flash-lite",
    flash_2_0_live_001: "gemini-2.0-flash-live-001",

    # Common aliases
    default: "gemini-2.0-flash-lite",
    latest: "gemini-2.5-pro",
    stable: "gemini-2.5-pro"
  }

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

      vertex_access_token() ->
        %{
          type: :vertex_ai,
          credentials: %{
            access_token: vertex_access_token(),
            project_id: vertex_project_id(),
            location: vertex_location()
          }
        }

      vertex_service_account() ->
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

        %{
          type: :vertex_ai,
          credentials: %{
            service_account_key: service_account_path,
            project_id: project_id,
            location: vertex_location()
          }
        }

      true ->
        # Check application config
        case Application.get_env(:gemini_ex, :auth) do
          nil ->
            # Default to looking for basic API key config
            case Application.get_env(:gemini_ex, :api_key) do
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

  @doc """
  Get the default model to use.
  """
  def default_model do
    Application.get_env(:gemini_ex, :default_model, @default_model)
  end

  @doc """
  Get a model name by its key or return the string if it's already a model name.

  ## Examples

      iex> Gemini.Config.get_model(:flash_2_0)
      "gemini-2.0-flash"

      iex> Gemini.Config.get_model("gemini-1.5-pro")
      "gemini-1.5-pro"

      iex> Gemini.Config.get_model(:default)
      "gemini-2.0-flash"
  """
  @spec get_model(atom() | String.t()) :: String.t()
  def get_model(model_key) when is_atom(model_key) do
    case Map.get(@models, model_key) do
      nil ->
        raise "Unknown model key: #{model_key}. Available keys: #{inspect(Map.keys(@models))}"

      model_name ->
        model_name
    end
  end

  def get_model(model_name) when is_binary(model_name) do
    model_name
  end

  @doc """
  Get all available model definitions.

  ## Returns

  A map of model keys to model names.
  """
  @spec models() :: map()
  def models do
    @models
  end

  @doc """
  Check if a model key exists.

  ## Examples

      iex> Gemini.Config.has_model?(:flash_2_0)
      true

      iex> Gemini.Config.has_model?(:unknown)
      false
  """
  @spec has_model?(atom()) :: boolean()
  def has_model?(model_key) when is_atom(model_key) do
    Map.has_key?(@models, model_key)
  end

  @doc """
  Get HTTP timeout in milliseconds.
  """
  def timeout do
    Application.get_env(:gemini_ex, :timeout, 30_000)
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
    case gemini_api_key() do
      nil ->
        # Check application config
        case Application.get_env(:gemini_ex, :api_key) do
          nil -> %{}
          api_key -> %{api_key: api_key}
        end

      api_key ->
        %{api_key: api_key}
    end
  end

  def get_auth_config(:vertex_ai) do
    config = %{}

    # Add project_id if available
    config =
      case vertex_project_id() do
        nil -> config
        project_id -> Map.put(config, :project_id, project_id)
      end

    # Add location
    config = Map.put(config, :location, vertex_location())

    # Add authentication method
    cond do
      vertex_access_token() ->
        Map.put(config, :access_token, vertex_access_token())

      vertex_service_account() ->
        Map.put(config, :service_account_key, vertex_service_account())

      true ->
        # Check application config
        app_config = Application.get_env(:gemini_ex, :vertex_ai, %{})
        Map.merge(config, app_config)
    end
  end

  def get_auth_config(_strategy) do
    %{}
  end

  # Private functions for environment variable access

  defp gemini_api_key do
    System.get_env("GEMINI_API_KEY")
  end

  defp vertex_access_token do
    System.get_env("VERTEX_ACCESS_TOKEN")
  end

  defp vertex_service_account do
    System.get_env("VERTEX_SERVICE_ACCOUNT") || System.get_env("VERTEX_JSON_FILE")
  end

  defp vertex_project_id do
    System.get_env("VERTEX_PROJECT_ID") || System.get_env("GOOGLE_CLOUD_PROJECT")
  end

  defp vertex_location do
    System.get_env("VERTEX_LOCATION") || System.get_env("GOOGLE_CLOUD_LOCATION") || "us-central1"
  end

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
