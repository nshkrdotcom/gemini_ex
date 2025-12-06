defmodule Gemini.Auth.VertexStrategy do
  @moduledoc """
  Authentication strategy for Google Vertex AI using OAuth2/Service Account.

  This strategy supports multiple authentication methods:
  - Service Account JSON file (via VERTEX_JSON_FILE environment variable)
  - OAuth2 access tokens
  - Application Default Credentials (ADC)

  Based on the Vertex AI documentation, this strategy can generate self-signed JWTs
  for authenticated endpoints and standard Bearer tokens for regular API calls.

  ## ADC Support

  If no explicit credentials are provided, this strategy will automatically
  fall back to Application Default Credentials (ADC), which searches for
  credentials in the following order:

  1. GOOGLE_APPLICATION_CREDENTIALS environment variable
  2. User credentials from gcloud CLI (~/.config/gcloud/application_default_credentials.json)
  3. GCP metadata server (for Cloud Run, GKE, Compute Engine, etc.)
  """

  @behaviour Gemini.Auth.Strategy

  require Logger

  alias Gemini.Auth.{ADC, JWT}

  @vertex_ai_scopes [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  @required_service_account_keys [
    :type,
    :project_id,
    :private_key_id,
    :private_key,
    :client_email,
    :client_id,
    :auth_uri,
    :token_uri,
    :auth_provider_x509_cert_url,
    :client_x509_cert_url
  ]

  @doc """
  Get authentication headers for Vertex AI requests.

  Supports multiple credential types:
  - %{access_token: token} - Direct access token
  - %{service_account_key: path} - Service account JSON file path
  - %{service_account_data: data} - Service account JSON data
  - %{jwt_token: token} - Pre-signed JWT token

  Returns `{:ok, headers}` on success, or `{:error, reason}` if authentication fails.
  """
  @impl true
  def headers(%{access_token: access_token})
      when is_binary(access_token) and access_token != "" do
    {:ok,
     [
       {"Content-Type", "application/json"},
       {"Authorization", "Bearer #{access_token}"}
     ]}
  end

  def headers(%{access_token: nil}) do
    {:error, "Access token is nil"}
  end

  def headers(%{access_token: ""}) do
    {:error, "Access token is empty"}
  end

  def headers(%{jwt_token: jwt_token}) when is_binary(jwt_token) and jwt_token != "" do
    {:ok,
     [
       {"Content-Type", "application/json"},
       {"Authorization", "Bearer #{jwt_token}"}
     ]}
  end

  def headers(%{service_account_key: key_path} = credentials) when is_binary(key_path) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        {:ok,
         [
           {"Content-Type", "application/json"},
           {"Authorization", "Bearer #{access_token}"}
         ]}

      {:error, reason} = error ->
        Logger.error(
          "[VertexStrategy] Failed to generate access token from service account key: #{inspect(reason)}"
        )

        error
    end
  end

  def headers(%{service_account_data: data} = credentials) when is_map(data) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        {:ok,
         [
           {"Content-Type", "application/json"},
           {"Authorization", "Bearer #{access_token}"}
         ]}

      {:error, reason} = error ->
        Logger.error(
          "[VertexStrategy] Failed to generate access token from service account data: #{inspect(reason)}"
        )

        error
    end
  end

  def headers(%{} = credentials) do
    # If no explicit credentials provided, try ADC
    if map_size(credentials) == 0 or
         (Map.has_key?(credentials, :project_id) and Map.has_key?(credentials, :location) and
            map_size(credentials) == 2) do
      Logger.debug("[VertexStrategy] No explicit credentials, attempting ADC")

      case ADC.load_credentials() do
        {:ok, adc_creds} ->
          case ADC.get_access_token(adc_creds) do
            {:ok, access_token} ->
              {:ok,
               [
                 {"Content-Type", "application/json"},
                 {"Authorization", "Bearer #{access_token}"}
               ]}

            {:error, reason} ->
              Logger.error("[VertexStrategy] Failed to get ADC token: #{inspect(reason)}")
              {:error, "Failed to get access token from ADC: #{reason}"}
          end

        {:error, reason} ->
          Logger.error("[VertexStrategy] ADC not available: #{inspect(reason)}")

          {:error,
           "No valid Vertex AI credentials found. Expected :access_token, :jwt_token, :service_account_key, or :service_account_data. ADC also failed: #{reason}"}
      end
    else
      {:error,
       "No valid Vertex AI credentials found. Expected :access_token, :jwt_token, :service_account_key, or :service_account_data. Got: #{inspect(Map.keys(credentials))}"}
    end
  end

  @impl true
  def base_url(%{project_id: _project_id, location: location}) do
    "https://#{location}-aiplatform.googleapis.com/v1"
  end

  def base_url(%{project_id: _project_id}) do
    {:error, "Location is required for Vertex AI base URL"}
  end

  def base_url(%{location: _location}) do
    {:error, "Project ID is required for Vertex AI base URL"}
  end

  def base_url(_config) do
    {:error, "Project ID and Location are required for Vertex AI base URL"}
  end

  @impl true
  def build_path(model, endpoint, %{project_id: project_id, location: location}) do
    # Vertex AI uses a different path structure
    # Format: projects/{project}/locations/{location}/publishers/google/models/{model}:{endpoint}
    normalized_model =
      if String.starts_with?(model, "models/") do
        String.replace_prefix(model, "models/", "")
      else
        model
      end

    "projects/#{project_id}/locations/#{location}/publishers/google/models/#{normalized_model}:#{endpoint}"
  end

  @impl true
  def refresh_credentials(%{refresh_token: refresh_token} = credentials)
      when is_binary(refresh_token) do
    # TODO: Implement OAuth2 token refresh
    # This would typically involve making a request to Google's OAuth2 token endpoint
    # For now, return the existing credentials
    {:ok, credentials}
  end

  def refresh_credentials(%{adc_credentials: adc_creds} = credentials) do
    # Refresh ADC token
    case ADC.refresh_token(adc_creds) do
      {:ok, access_token} ->
        updated_credentials = Map.put(credentials, :access_token, access_token)
        {:ok, updated_credentials}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_credentials(%{service_account_key: _key_path} = credentials) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        updated_credentials = Map.put(credentials, :access_token, access_token)
        {:ok, updated_credentials}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_credentials(%{service_account_data: _data} = credentials) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        updated_credentials = Map.put(credentials, :access_token, access_token)
        {:ok, updated_credentials}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_credentials(credentials) do
    # For other credential types, return as-is
    {:ok, credentials}
  end

  @doc """
  Create a signed JWT for authenticated Vertex AI endpoints.

  This is used for Vector Search endpoints with JWT authentication as described in v1.md.

  ## Parameters
  - `service_account_email`: The service account email (issuer)
  - `audience`: The audience specified during index deployment
  - `credentials`: The credentials map containing authentication info
  - `opts`: Additional options for JWT creation

  ## Examples

      iex> credentials = %{service_account_key: "/path/to/key.json"}
      iex> {:ok, jwt} = Gemini.Auth.VertexStrategy.create_signed_jwt(
      ...>   "my-service@project.iam.gserviceaccount.com",
      ...>   "my-app-audience",
      ...>   credentials
      ...> )
  """
  @spec create_signed_jwt(String.t(), String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def create_signed_jwt(service_account_email, audience, credentials, opts \\ []) do
    cond do
      service_account_key = Map.get(credentials, :service_account_key) ->
        JWT.create_signed_token(
          service_account_email,
          audience,
          Keyword.put(opts, :service_account_key, service_account_key)
        )

      service_account_data = Map.get(credentials, :service_account_data) ->
        JWT.create_signed_token(
          service_account_email,
          audience,
          Keyword.put(opts, :service_account_data, service_account_data)
        )

      access_token = Map.get(credentials, :access_token) ->
        JWT.create_signed_token(
          service_account_email,
          audience,
          Keyword.put(opts, :access_token, access_token)
        )

      true ->
        {:error, "No suitable credentials found for JWT signing"}
    end
  end

  @doc """
  Authenticate with Vertex AI using various methods.

  Supports the following authentication methods:
  - OAuth2 with project_id and location
  - Service Account with key file path
  - Service Account with key data
  - Direct access token
  """
  def authenticate(%{project_id: project_id, location: location, auth_method: :oauth2})
      when is_binary(project_id) and is_binary(location) do
    # For OAuth2, we would typically refresh/validate the access token
    {:ok,
     %{
       project_id: project_id,
       location: location,
       access_token: "oauth2-placeholder-token"
     }}
  end

  def authenticate(%{
        project_id: project_id,
        location: location,
        service_account_key: key_path,
        auth_method: :service_account
      })
      when is_binary(project_id) and is_binary(location) and is_binary(key_path) do
    case generate_access_token(%{service_account_key: key_path}) do
      {:ok, access_token} ->
        {:ok,
         %{
           project_id: project_id,
           location: location,
           access_token: access_token,
           service_account_key: key_path
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def authenticate(%{
        project_id: project_id,
        location: location,
        service_account_data: data,
        auth_method: :service_account
      })
      when is_binary(project_id) and is_binary(location) and is_map(data) do
    case generate_access_token(%{service_account_data: data}) do
      {:ok, access_token} ->
        {:ok,
         %{
           project_id: project_id,
           location: location,
           access_token: access_token,
           service_account_data: data
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def authenticate(%{project_id: project_id, location: location, access_token: access_token})
      when is_binary(project_id) and is_binary(location) and is_binary(access_token) do
    {:ok,
     %{
       project_id: project_id,
       location: location,
       access_token: access_token
     }}
  end

  def authenticate(%{project_id: project_id, location: location})
      when is_binary(project_id) and is_binary(location) do
    # Try ADC if no explicit auth method specified
    Logger.debug("[VertexStrategy] Attempting ADC authentication")

    case ADC.load_credentials() do
      {:ok, adc_creds} ->
        case ADC.get_access_token(adc_creds) do
          {:ok, access_token} ->
            {:ok,
             %{
               project_id: project_id,
               location: location,
               access_token: access_token,
               adc_credentials: adc_creds
             }}

          {:error, reason} ->
            Logger.warning("[VertexStrategy] ADC token failed: #{inspect(reason)}")
            # Fall back to OAuth2
            authenticate(%{project_id: project_id, location: location, auth_method: :oauth2})
        end

      {:error, reason} ->
        Logger.warning("[VertexStrategy] ADC not available: #{inspect(reason)}")
        # Fall back to OAuth2
        authenticate(%{project_id: project_id, location: location, auth_method: :oauth2})
    end
  end

  def authenticate(%{}) do
    {:error, "Missing required fields: project_id and location"}
  end

  def authenticate(_config) do
    {:error, "Invalid configuration for Vertex AI authentication"}
  end

  # Private helper functions

  defp generate_access_token(%{service_account_key: key_path}) do
    with {:ok, key_data} <- JWT.load_service_account_key(key_path) do
      generate_access_token(%{service_account_data: key_data})
    else
      {:error, reason} ->
        {:error, "Failed to load service account key: #{reason}"}
    end
  end

  defp generate_access_token(%{service_account_data: key_data}) do
    with {:ok, normalized_key} <- normalize_service_account_key(key_data) do
      generate_access_token_from_key(normalized_key)
    end
  end

  defp generate_access_token(_credentials) do
    {:error, "No service account credentials available"}
  end

  @spec normalize_service_account_key(map()) ::
          {:ok, JWT.service_account_key()} | {:error, String.t()}
  defp normalize_service_account_key(key_data) when is_map(key_data) do
    normalized_key_data =
      if has_string_service_account_keys?(key_data) do
        for key <- @required_service_account_keys, into: %{} do
          {key, Map.get(key_data, Atom.to_string(key))}
        end
      else
        key_data
      end

    if valid_service_account_key?(normalized_key_data) do
      {:ok, Map.take(normalized_key_data, @required_service_account_keys)}
    else
      {:error, "Invalid service account data: missing required fields"}
    end
  end

  defp normalize_service_account_key(_),
    do: {:error, "Invalid service account data: missing required fields"}

  defp has_string_service_account_keys?(key_data) do
    Enum.any?(@required_service_account_keys, fn key ->
      Map.has_key?(key_data, Atom.to_string(key))
    end)
  end

  defp valid_service_account_key?(key_data) do
    Enum.all?(@required_service_account_keys, fn key ->
      value = Map.get(key_data, key)
      is_binary(value)
    end)
  end

  @spec generate_access_token_from_key(JWT.service_account_key()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp generate_access_token_from_key(
         %{client_email: client_email, token_uri: token_uri} = key_data
       ) do
    # Create OAuth2 JWT for token exchange
    # This follows the OAuth2 service account flow per Google documentation:
    # https://developers.google.com/identity/protocols/oauth2/service-account#httprest
    now = System.system_time(:second)

    # The scope MUST be included in the JWT claims for jwt-bearer grant type
    jwt_payload = %{
      iss: client_email,
      sub: client_email,
      aud: token_uri,
      iat: now,
      exp: now + 3600,
      scope: Enum.join(@vertex_ai_scopes, " ")
    }

    case JWT.sign_with_key(jwt_payload, key_data) do
      {:ok, assertion} ->
        exchange_jwt_for_access_token(assertion, token_uri)

      {:error, reason} ->
        {:error, "Failed to sign OAuth2 JWT: #{inspect(reason)}"}
    end
  end

  @spec exchange_jwt_for_access_token(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp exchange_jwt_for_access_token(assertion, token_uri) do
    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    # Note: scope is NOT included here - it's in the JWT assertion itself
    body =
      URI.encode_query(%{
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => assertion
      })

    case Req.post(token_uri, headers: headers, body: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        case response_body do
          %{"access_token" => access_token} ->
            {:ok, access_token}

          _ ->
            case Jason.decode(response_body) do
              {:ok, %{"access_token" => access_token}} ->
                {:ok, access_token}

              {:ok, response} ->
                {:error, "Unexpected token response: #{inspect(response)}"}

              {:error, reason} ->
                {:error, "Failed to parse token response: #{reason}"}
            end
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        error_body = if is_binary(body), do: body, else: inspect(body)
        {:error, "Token exchange failed with HTTP #{status}: #{error_body}"}

      {:error, reason} ->
        {:error, "Token exchange request failed: #{reason}"}
    end
  end
end
