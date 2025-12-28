defmodule Gemini.Auth.MultiAuthCoordinator do
  @moduledoc """
  Coordinates multiple authentication strategies for concurrent usage.

  Enables per-request auth strategy selection while maintaining
  independent credential management and request routing.

  This module serves as the central coordination point for the Gemini Unified
  Implementation's multi-auth capability, allowing applications to use both
  Gemini API and Vertex AI authentication strategies simultaneously.
  """

  alias Gemini.Auth
  alias Gemini.Config

  @type auth_strategy :: :gemini | :vertex_ai
  @type credentials :: map()
  @type auth_result :: {:ok, auth_strategy(), headers :: list()} | {:error, term()}
  @type request_opts :: keyword()

  @enforce_keys []
  defstruct []

  @type t :: %__MODULE__{}

  @doc """
  Coordinates authentication for the specified strategy.

  This is the main entry point for multi-auth coordination. It routes
  authentication requests to the appropriate strategy while maintaining
  independent credential management.

  ## Parameters
  - `strategy`: The authentication strategy (`:gemini` or `:vertex_ai`)
  - `opts`: Request options (may include configuration overrides)

  ## Returns
  - `{:ok, strategy, headers}` on successful authentication
  - `{:error, reason}` on authentication failure

  ## Examples

      # Coordinate Gemini API authentication
      {:ok, :gemini, headers} = MultiAuthCoordinator.coordinate_auth(:gemini, [])
      
      # Coordinate Vertex AI authentication
      {:ok, :vertex_ai, headers} = MultiAuthCoordinator.coordinate_auth(:vertex_ai, [])
      
      # With configuration overrides
      {:ok, :gemini, headers} = MultiAuthCoordinator.coordinate_auth(:gemini, [api_key: "override"])
  """
  @spec coordinate_auth(auth_strategy(), request_opts()) :: auth_result()
  def coordinate_auth(strategy, opts \\ [])

  def coordinate_auth(:gemini, opts) do
    with {:ok, credentials} <- get_credentials(:gemini, opts),
         {:ok, headers} <- Auth.build_headers(:gemini, credentials) do
      {:ok, :gemini, headers}
    else
      {:error, reason} ->
        {:error, "Gemini auth failed: #{inspect(reason)}"}
    end
  end

  def coordinate_auth(:vertex_ai, opts) do
    with {:ok, credentials} <- get_credentials(:vertex_ai, opts),
         {:ok, headers} <- Auth.build_headers(:vertex_ai, credentials) do
      {:ok, :vertex_ai, headers}
    else
      {:error, reason} ->
        {:error, "Vertex AI auth failed: #{inspect(reason)}"}
    end
  end

  def coordinate_auth(strategy, _opts) do
    {:error, "Unknown authentication strategy: #{inspect(strategy)}"}
  end

  @doc """
  Retrieves credentials for the specified authentication strategy.

  Loads credentials from configuration, with optional overrides from request options.

  ## Parameters
  - `strategy`: The authentication strategy
  - `opts`: Optional configuration overrides

  ## Returns
  - `{:ok, credentials}` on success
  - `{:error, reason}` on failure
  """
  @spec get_credentials(auth_strategy(), request_opts()) ::
          {:ok, credentials()} | {:error, term()}
  def get_credentials(strategy, opts \\ [])

  def get_credentials(:gemini, opts) do
    base_config = Config.get_auth_config(:gemini)

    # Allow api_key override from opts
    api_key = Keyword.get(opts, :api_key, base_config[:api_key])

    case api_key do
      key when is_binary(key) and key != "" ->
        {:ok, %{api_key: key}}

      _ ->
        {:error, "Missing or invalid Gemini API key"}
    end
  end

  def get_credentials(:vertex_ai, opts) do
    base_config = Config.get_auth_config(:vertex_ai)
    credentials = build_vertex_credentials(base_config, opts)

    case add_vertex_auth_method(credentials, base_config, opts) do
      {:ok, _} = ok -> ok
      :no_auth -> validate_vertex_base_credentials(credentials)
    end
  end

  def get_credentials(strategy, _opts) do
    {:error, "Unknown authentication strategy: #{inspect(strategy)}"}
  end

  @doc """
  Validates configuration for the specified authentication strategy.

  Checks that all required configuration is present and valid for the
  given strategy.

  ## Parameters
  - `strategy`: The authentication strategy to validate

  ## Returns
  - `:ok` if configuration is valid
  - `{:error, reason}` if configuration is invalid or missing
  """
  @spec validate_auth_config(auth_strategy()) :: :ok | {:error, term()}
  def validate_auth_config(:gemini) do
    case get_credentials(:gemini) do
      {:ok, %{api_key: key}} when is_binary(key) and key != "" ->
        :ok

      {:ok, _} ->
        {:error, "Invalid Gemini API key"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_auth_config(:vertex_ai) do
    case get_credentials(:vertex_ai) do
      {:ok, %{project_id: project_id, location: location}}
      when is_binary(project_id) and is_binary(location) ->
        :ok

      {:ok, credentials} ->
        missing_fields = []

        missing_fields =
          if Map.has_key?(credentials, :project_id),
            do: missing_fields,
            else: [:project_id | missing_fields]

        missing_fields =
          if Map.has_key?(credentials, :location),
            do: missing_fields,
            else: [:location | missing_fields]

        case missing_fields do
          [] -> :ok
          fields -> {:error, "Missing Vertex AI fields: #{inspect(fields)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_auth_config(strategy) do
    {:error, "Unknown authentication strategy: #{inspect(strategy)}"}
  end

  @doc """
  Refreshes credentials for the specified authentication strategy.

  For strategies that support credential refresh (like Vertex AI OAuth tokens),
  this function will generate fresh credentials. For strategies that don't
  need refresh (like Gemini API keys), it returns the existing credentials.

  ## Parameters
  - `strategy`: The authentication strategy

  ## Returns
  - `{:ok, refreshed_credentials}` on success
  - `{:error, reason}` on failure
  """
  @spec refresh_credentials(auth_strategy()) :: {:ok, credentials()} | {:error, term()}
  def refresh_credentials(:gemini) do
    # Gemini API keys don't need refreshing
    get_credentials(:gemini)
  end

  def refresh_credentials(:vertex_ai) do
    with {:ok, credentials} <- get_credentials(:vertex_ai) do
      # Use the strategy's refresh mechanism
      Auth.refresh_credentials(:vertex_ai, credentials)
    end
  end

  def refresh_credentials(strategy) do
    {:error, "Unknown authentication strategy: #{inspect(strategy)}"}
  end

  # Private helper functions
  defp build_vertex_credentials(base_config, opts) do
    credentials = %{}

    project_id = Keyword.get(opts, :project_id, base_config[:project_id])
    credentials = maybe_put(credentials, :project_id, project_id)

    location = Keyword.get(opts, :location, base_config[:location] || "us-central1")
    credentials = Map.put(credentials, :location, location)

    quota_project_id = Keyword.get(opts, :quota_project_id, base_config[:quota_project_id])
    maybe_put(credentials, :quota_project_id, quota_project_id)
  end

  defp maybe_put(credentials, _key, nil), do: credentials
  defp maybe_put(credentials, _key, ""), do: credentials
  defp maybe_put(credentials, key, value), do: Map.put(credentials, key, value)

  defp add_vertex_auth_method(credentials, base_config, opts) do
    cond do
      access_token = Keyword.get(opts, :access_token) ->
        {:ok, Map.put(credentials, :access_token, access_token)}

      service_account_key =
          Keyword.get(opts, :service_account_key, base_config[:service_account_key]) ->
        {:ok, Map.put(credentials, :service_account_key, service_account_key)}

      service_account_data =
          Keyword.get(opts, :service_account_data, base_config[:service_account_data]) ->
        {:ok, Map.put(credentials, :service_account_data, service_account_data)}

      base_config[:access_token] ->
        {:ok, Map.put(credentials, :access_token, base_config[:access_token])}

      true ->
        :no_auth
    end
  end

  defp validate_vertex_base_credentials(credentials) do
    case {credentials[:project_id], credentials[:location]} do
      {nil, _} -> {:error, "Missing Vertex AI project_id"}
      {_, nil} -> {:error, "Missing Vertex AI location"}
      _ -> {:ok, credentials}
    end
  end
end
