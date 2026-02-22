defmodule Gemini.Auth.ADC do
  @moduledoc """
  Application Default Credentials (ADC) for Google Cloud authentication.

  This module implements Google's Application Default Credentials (ADC) strategy,
  which provides a standardized way to obtain credentials for Google Cloud APIs
  without hardcoding authentication details in your application.

  ## ADC Credential Search Order

  gemini_ex searches for credentials in the following order:

  1. **Environment Variable (JSON, gemini_ex extension)**:
     `GOOGLE_APPLICATION_CREDENTIALS_JSON` containing the service account JSON
     content directly (useful for containerized environments)
  2. **Environment Variable (Path, standard ADC)**: `GOOGLE_APPLICATION_CREDENTIALS` pointing to a
     service account JSON file
  3. **User Credentials (standard ADC)**: `~/.config/gcloud/application_default_credentials.json`
     (created via `gcloud auth application-default login`)
  4. **GCP Metadata Server (standard ADC)**: Automatic credentials for code running on GCP
     infrastructure (Compute Engine, GKE, Cloud Run, Cloud Functions, App Engine)

  ## Features

  - Automatic credential discovery following ADC conventions
  - Token caching with automatic refresh
  - Support for service account and user credentials
  - Metadata server authentication for GCP workloads
  - Thread-safe token management

  ## Usage

      # Load credentials using ADC
      case ADC.load_credentials() do
        {:ok, credentials} ->
          # Get an access token
          case ADC.get_access_token(credentials) do
            {:ok, token} ->
              # Use token for API calls
              make_api_call(token)

            {:error, reason} ->
              Logger.error("Failed to get token: \#{reason}")
          end

        {:error, reason} ->
          Logger.error("No credentials found: \#{reason}")
      end

  ## Setting Up ADC

  ### Option 1: Service Account JSON Content (Containerized Environments)

      export GOOGLE_APPLICATION_CREDENTIALS_JSON='{"type":"service_account",...}'

  ### Option 2: Service Account Key File (Development)

      export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

  ### Option 3: User Credentials (Development)

      gcloud auth application-default login

  ### Option 4: Metadata Server (Production on GCP)

      # No setup required - automatically works on GCP infrastructure

  ## Token Caching

  Access tokens are automatically cached with a 5-minute refresh buffer.
  This means a token with a 1-hour TTL will be refreshed after 55 minutes,
  ensuring your application never uses an expired token.
  """

  require Logger

  alias Gemini.Auth.{JWT, MetadataServer, TokenCache}

  @default_user_credentials_path Path.expand(
                                   "~/.config/gcloud/application_default_credentials.json"
                                 )
  @oauth2_token_uri "https://oauth2.googleapis.com/token"
  @vertex_ai_scopes ["https://www.googleapis.com/auth/cloud-platform"]
  @service_account_json_key_map %{
    "type" => :type,
    "project_id" => :project_id,
    "private_key_id" => :private_key_id,
    "private_key" => :private_key,
    "client_email" => :client_email,
    "client_id" => :client_id,
    "auth_uri" => :auth_uri,
    "token_uri" => :token_uri,
    "auth_provider_x509_cert_url" => :auth_provider_x509_cert_url,
    "client_x509_cert_url" => :client_x509_cert_url
  }

  @type credentials ::
          {:service_account, service_account_credentials()}
          | {:user, user_credentials()}
          | {:metadata_server, metadata_server_credentials()}

  @type service_account_credentials :: %{
          type: String.t(),
          project_id: String.t(),
          private_key_id: String.t(),
          private_key: String.t(),
          client_email: String.t(),
          client_id: String.t(),
          auth_uri: String.t(),
          token_uri: String.t(),
          auth_provider_x509_cert_url: String.t(),
          client_x509_cert_url: String.t()
        }

  @type user_credentials :: %{
          type: String.t(),
          client_id: String.t(),
          client_secret: String.t(),
          refresh_token: String.t(),
          quota_project_id: String.t() | nil
        }

  @type metadata_server_credentials :: %{
          source: :metadata_server,
          project_id: String.t() | nil
        }

  @type access_token :: String.t()
  @type error_reason :: String.t()

  @doc """
  Load credentials following the ADC chain.

  Searches for credentials in this order:
  1. GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable (JSON content, gemini_ex extension)
  2. GOOGLE_APPLICATION_CREDENTIALS environment variable (file path, standard ADC)
  3. User credentials file (~/.config/gcloud/application_default_credentials.json, standard ADC)
  4. GCP metadata server (standard ADC)

  ## Returns

  - `{:ok, credentials}` - Credentials found and loaded
  - `{:error, reason}` - No credentials found or loading failed

  ## Examples

      case ADC.load_credentials() do
        {:ok, {:service_account, creds}} ->
          Logger.info("Using service account: \#{creds.client_email}")

        {:ok, {:user, creds}} ->
          Logger.info("Using user credentials")

        {:ok, {:metadata_server, creds}} ->
          Logger.info("Using metadata server")

        {:error, reason} ->
          Logger.error("No credentials found: \#{reason}")
      end
  """
  @spec load_credentials() :: {:ok, credentials()} | {:error, error_reason()}
  def load_credentials do
    Logger.debug("[ADC] Starting credential discovery")

    # 1. Check GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable (JSON content)
    case System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") do
      nil ->
        Logger.debug("[ADC] GOOGLE_APPLICATION_CREDENTIALS_JSON not set")
        load_credentials_from_file_or_fallback()

      "" ->
        Logger.debug("[ADC] GOOGLE_APPLICATION_CREDENTIALS_JSON is empty")
        load_credentials_from_file_or_fallback()

      json_content ->
        Logger.debug("[ADC] Found GOOGLE_APPLICATION_CREDENTIALS_JSON")
        parse_service_account_json(json_content)
    end
  end

  defp load_credentials_from_file_or_fallback do
    # 2. Check GOOGLE_APPLICATION_CREDENTIALS environment variable (file path)
    case System.get_env("GOOGLE_APPLICATION_CREDENTIALS") do
      nil ->
        Logger.debug("[ADC] GOOGLE_APPLICATION_CREDENTIALS not set")
        load_user_credentials_or_metadata()

      "" ->
        Logger.debug("[ADC] GOOGLE_APPLICATION_CREDENTIALS is empty")
        load_user_credentials_or_metadata()

      path ->
        Logger.debug("[ADC] Found GOOGLE_APPLICATION_CREDENTIALS: #{path}")
        load_service_account_file(path)
    end
  end

  @doc """
  Get an access token from loaded credentials.

  Attempts to retrieve a cached token first. If no cached token exists
  or the cached token is expired, generates a new token and caches it.

  ## Parameters

  - `credentials`: Credentials tuple from `load_credentials/0`
  - `opts`: Optional keyword list
    - `:force_refresh` - Skip cache and force token refresh (default: false)
    - `:cache_key` - Custom cache key (default: auto-generated)

  ## Returns

  - `{:ok, access_token}` - Access token retrieved successfully
  - `{:error, reason}` - Failed to get access token

  ## Examples

      {:ok, creds} = ADC.load_credentials()

      # Get token (uses cache if available)
      {:ok, token} = ADC.get_access_token(creds)

      # Force refresh
      {:ok, fresh_token} = ADC.get_access_token(creds, force_refresh: true)
  """
  @spec get_access_token(credentials(), keyword()) ::
          {:ok, access_token()} | {:error, error_reason()}
  def get_access_token(credentials, opts \\ [])

  def get_access_token({:service_account, creds}, opts) do
    cache_key = Keyword.get(opts, :cache_key, cache_key_for_service_account(creds))
    force_refresh = Keyword.get(opts, :force_refresh, false)

    if force_refresh do
      generate_service_account_token(creds, cache_key)
    else
      case TokenCache.get(cache_key) do
        {:ok, token} ->
          {:ok, token}

        :error ->
          generate_service_account_token(creds, cache_key)
      end
    end
  end

  def get_access_token({:user, creds}, opts) do
    cache_key = Keyword.get(opts, :cache_key, cache_key_for_user(creds))
    force_refresh = Keyword.get(opts, :force_refresh, false)

    if force_refresh do
      refresh_user_token(creds, cache_key)
    else
      case TokenCache.get(cache_key) do
        {:ok, token} ->
          {:ok, token}

        :error ->
          refresh_user_token(creds, cache_key)
      end
    end
  end

  def get_access_token({:metadata_server, _creds}, opts) do
    cache_key = Keyword.get(opts, :cache_key, :metadata_server_token)
    force_refresh = Keyword.get(opts, :force_refresh, false)

    if force_refresh do
      fetch_metadata_server_token(cache_key)
    else
      case TokenCache.get(cache_key) do
        {:ok, token} ->
          {:ok, token}

        :error ->
          fetch_metadata_server_token(cache_key)
      end
    end
  end

  @doc """
  Refresh an access token.

  Forces a token refresh regardless of whether a cached token exists.
  This is equivalent to calling `get_access_token/2` with `force_refresh: true`.

  ## Parameters

  - `credentials`: Credentials tuple from `load_credentials/0`

  ## Returns

  - `{:ok, access_token}` - New access token generated successfully
  - `{:error, reason}` - Failed to refresh token

  ## Examples

      {:ok, creds} = ADC.load_credentials()
      {:ok, fresh_token} = ADC.refresh_token(creds)
  """
  @spec refresh_token(credentials()) :: {:ok, access_token()} | {:error, error_reason()}
  def refresh_token(credentials) do
    get_access_token(credentials, force_refresh: true)
  end

  @doc """
  Get project ID from credentials if available.

  Extracts the project ID from the loaded credentials. Useful for
  configuring Vertex AI which requires a project ID.

  ## Parameters

  - `credentials`: Credentials tuple from `load_credentials/0`

  ## Returns

  - `{:ok, project_id}` - Project ID extracted successfully
  - `{:error, reason}` - No project ID available in credentials

  ## Examples

      {:ok, creds} = ADC.load_credentials()

      case ADC.get_project_id(creds) do
        {:ok, project_id} ->
          # Use for Vertex AI
          %{project_id: project_id, location: "us-central1"}

        {:error, _} ->
          # Prompt user or use environment variable
          System.get_env("VERTEX_PROJECT_ID")
      end
  """
  @spec get_project_id(credentials()) :: {:ok, String.t()} | {:error, error_reason()}
  def get_project_id({:service_account, %{project_id: project_id}}) when is_binary(project_id) do
    {:ok, project_id}
  end

  def get_project_id({:user, %{quota_project_id: project_id}}) when is_binary(project_id) do
    {:ok, project_id}
  end

  def get_project_id({:metadata_server, %{project_id: project_id}})
      when is_binary(project_id) do
    {:ok, project_id}
  end

  def get_project_id({:metadata_server, _creds}) do
    # Try to fetch from metadata server
    MetadataServer.get_project_id()
  end

  def get_project_id(_credentials) do
    {:error, "No project ID available in credentials"}
  end

  @doc """
  Check if ADC credentials are available.

  Performs a quick check to see if any credentials can be found via ADC,
  without actually loading them.

  ## Returns

  - `true` - Credentials are available
  - `false` - No credentials found

  ## Examples

      if ADC.available?() do
        Logger.info("ADC credentials available")
      else
        Logger.warning("No ADC credentials found")
      end
  """
  @spec available?() :: boolean()
  def available? do
    case load_credentials() do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # Private helper functions

  defp load_user_credentials_or_metadata do
    # 2. Check user credentials file
    if File.exists?(@default_user_credentials_path) do
      Logger.debug("[ADC] Found user credentials file: #{@default_user_credentials_path}")
      load_user_credentials_file(@default_user_credentials_path)
    else
      Logger.debug("[ADC] User credentials file not found")
      # 3. Try metadata server
      load_metadata_server_credentials()
    end
  end

  defp parse_service_account_json(json_content) do
    case Jason.decode(json_content) do
      {:ok, %{"type" => "service_account"} = data} ->
        creds = service_account_creds_from_json(data)

        Logger.info(
          "[ADC] Loaded service account credentials from GOOGLE_APPLICATION_CREDENTIALS_JSON"
        )

        {:ok, {:service_account, creds}}

      {:ok, %{"type" => type}} ->
        {:error, "Unsupported credential type: #{type}"}

      {:ok, _} ->
        {:error, "Invalid service account JSON format"}

      {:error, reason} ->
        {:error, "Failed to parse GOOGLE_APPLICATION_CREDENTIALS_JSON: #{inspect(reason)}"}
    end
  end

  defp load_service_account_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"type" => "service_account"} = data} ->
            creds = service_account_creds_from_json(data)

            Logger.info("[ADC] Loaded service account credentials from #{path}")
            {:ok, {:service_account, creds}}

          {:ok, %{"type" => type}} ->
            {:error, "Unsupported credential type: #{type}"}

          {:ok, _} ->
            {:error, "Invalid service account file format"}

          {:error, reason} ->
            {:error, "Failed to parse JSON: #{inspect(reason)}"}
        end

      {:error, reason} ->
        error_msg = "Failed to read service account file: #{inspect(reason)}"
        Logger.warning("[ADC] #{error_msg}")
        # Continue to next credential source
        load_user_credentials_or_metadata()
    end
  end

  defp load_user_credentials_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"type" => "authorized_user"} = data} ->
            creds = %{
              type: data["type"],
              client_id: data["client_id"],
              client_secret: data["client_secret"],
              refresh_token: data["refresh_token"],
              quota_project_id: data["quota_project_id"]
            }

            Logger.info("[ADC] Loaded user credentials from #{path}")
            {:ok, {:user, creds}}

          {:ok, %{"type" => type}} ->
            {:error, "Unsupported credential type: #{type}"}

          {:ok, _} ->
            {:error, "Invalid user credentials file format"}

          {:error, reason} ->
            {:error, "Failed to parse JSON: #{inspect(reason)}"}
        end

      {:error, reason} ->
        error_msg = "Failed to read user credentials file: #{inspect(reason)}"
        Logger.warning("[ADC] #{error_msg}")
        # Continue to metadata server
        load_metadata_server_credentials()
    end
  end

  defp load_metadata_server_credentials do
    if MetadataServer.available?() do
      Logger.info("[ADC] Using GCP metadata server credentials")

      # Try to get project ID, but don't fail if unavailable
      project_id =
        case MetadataServer.get_project_id() do
          {:ok, id} -> id
          {:error, _} -> nil
        end

      {:ok, {:metadata_server, %{source: :metadata_server, project_id: project_id}}}
    else
      Logger.warning("[ADC] Metadata server not available")

      {:error,
       "No credentials found via ADC. Please set GOOGLE_APPLICATION_CREDENTIALS_JSON or GOOGLE_APPLICATION_CREDENTIALS, or run 'gcloud auth application-default login'"}
    end
  end

  defp service_account_creds_from_json(data) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      case Map.get(@service_account_json_key_map, key) do
        nil -> acc
        mapped_key -> Map.put(acc, mapped_key, value)
      end
    end)
  end

  defp generate_service_account_token(creds, cache_key) do
    Logger.debug("[ADC] Generating service account access token")

    try do
      # Create JWT for token exchange
      now = System.system_time(:second)

      jwt_payload = %{
        iss: creds.client_email,
        sub: creds.client_email,
        aud: creds.token_uri,
        iat: now,
        exp: now + 3600,
        scope: Enum.join(@vertex_ai_scopes, " ")
      }

      case JWT.sign_with_key(jwt_payload, creds) do
        {:ok, assertion} ->
          exchange_jwt_for_token(assertion, creds.token_uri, cache_key)

        {:error, reason} ->
          {:error, "Failed to sign JWT: #{inspect(reason)}"}
      end
    rescue
      error in KeyError ->
        {:error, "Invalid service account credentials: missing #{error.key}"}

      error ->
        {:error, "Failed to generate service account token: #{inspect(error)}"}
    end
  end

  defp exchange_jwt_for_token(assertion, token_uri, cache_key) do
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    body =
      URI.encode_query(%{
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => assertion
      })

    case Req.post(token_uri, headers: headers, body: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        parse_and_cache_token(response_body, cache_key)

      {:ok, %Req.Response{status: status, body: body}} ->
        error_body = if is_binary(body), do: body, else: inspect(body)
        {:error, "Token exchange failed with HTTP #{status}: #{error_body}"}

      {:error, reason} ->
        {:error, "Token exchange request failed: #{inspect(reason)}"}
    end
  end

  defp refresh_user_token(creds, cache_key) do
    Logger.debug("[ADC] Refreshing user access token")

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    body =
      URI.encode_query(%{
        "client_id" => creds.client_id,
        "client_secret" => creds.client_secret,
        "refresh_token" => creds.refresh_token,
        "grant_type" => "refresh_token"
      })

    case Req.post(@oauth2_token_uri, headers: headers, body: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        parse_and_cache_token(response_body, cache_key)

      {:ok, %Req.Response{status: status, body: body}} ->
        error_body = if is_binary(body), do: body, else: inspect(body)
        {:error, "Token refresh failed with HTTP #{status}: #{error_body}"}

      {:error, reason} ->
        {:error, "Token refresh request failed: #{inspect(reason)}"}
    end
  end

  defp fetch_metadata_server_token(cache_key) do
    Logger.debug("[ADC] Fetching token from metadata server")

    case MetadataServer.get_access_token() do
      {:ok, %{token: token, expires_in: ttl}} ->
        TokenCache.put(cache_key, token, ttl)
        {:ok, token}

      {:error, reason} ->
        {:error, "Failed to get token from metadata server: #{reason}"}
    end
  end

  defp parse_and_cache_token(response_body, cache_key) do
    case response_body do
      %{"access_token" => access_token, "expires_in" => expires_in}
      when is_binary(access_token) and is_integer(expires_in) ->
        TokenCache.put(cache_key, access_token, expires_in)
        Logger.debug("[ADC] Cached access token (TTL: #{expires_in}s)")
        {:ok, access_token}

      %{"access_token" => access_token} when is_binary(access_token) ->
        # Default to 1 hour if no expires_in
        TokenCache.put(cache_key, access_token, 3600)
        Logger.debug("[ADC] Cached access token (default TTL: 3600s)")
        {:ok, access_token}

      _ ->
        case Jason.decode(response_body) do
          {:ok, decoded} ->
            parse_and_cache_token(decoded, cache_key)

          {:error, reason} ->
            {:error, "Failed to parse token response: #{inspect(reason)}"}
        end
    end
  end

  defp cache_key_for_service_account(creds) do
    email = Map.get(creds, :client_email, "unknown")
    "adc_service_account_#{:erlang.phash2(email)}"
  end

  defp cache_key_for_user(creds) do
    client_id = Map.get(creds, :client_id, "unknown")
    "adc_user_#{:erlang.phash2(client_id)}"
  end
end
