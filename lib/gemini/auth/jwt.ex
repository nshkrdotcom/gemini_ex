defmodule Gemini.Auth.JWT do
  @moduledoc """
  JWT token generation and management for Google Cloud service accounts.

  This module handles JWT creation and signing for Vertex AI authentication
  based on the documentation in v1.md. It supports both service account key files
  and the Google Cloud IAM signJwt API.
  """

  alias Joken.Signer

  @iam_credentials_url "https://iamcredentials.googleapis.com/v1"
  # 1 hour in seconds
  @default_token_lifetime 3600

  @type service_account_key :: %{
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

  @type jwt_payload :: %{
          required(:iss) => String.t(),
          required(:aud) => String.t(),
          required(:sub) => String.t(),
          required(:iat) => integer(),
          required(:exp) => integer(),
          optional(:scope) => String.t(),
          optional(atom()) => any()
        }

  @doc """
  Create a JWT payload for Vertex AI authentication.

  ## Parameters
  - `service_account_email`: The email of the service account (issuer)
  - `audience`: The audience for the JWT (must match deployment config)
  - `opts`: Optional parameters
    - `:lifetime` - Token lifetime in seconds (default: 3600)
    - `:issued_at` - Custom issued at time (default: current time)

  ## Examples

      iex> payload = Gemini.Auth.JWT.create_payload(
      ...>   "my-service@project.iam.gserviceaccount.com",
      ...>   "my-app-audience"
      ...> )
      iex> payload.iss
      "my-service@project.iam.gserviceaccount.com"
  """
  @spec create_payload(String.t(), String.t(), keyword()) :: jwt_payload()
  def create_payload(service_account_email, audience, opts \\ []) do
    now = Keyword.get(opts, :issued_at, System.system_time(:second))
    lifetime = Keyword.get(opts, :lifetime, @default_token_lifetime)

    %{
      iss: service_account_email,
      aud: audience,
      # Both aud and sub should be the same according to v1.md
      sub: audience,
      iat: now,
      exp: now + lifetime
    }
  end

  @doc """
  Sign a JWT payload using a service account private key.

  This method signs the JWT locally using the private key from the service account JSON file.

  ## Examples

      iex> key = %{private_key: "-----BEGIN PRIVATE KEY-----...", client_email: "..."}
      iex> payload = %{iss: "...", aud: "...", sub: "...", iat: 123, exp: 456}
      iex> {:ok, token} = Gemini.Auth.JWT.sign_with_key(payload, key)
  """
  @spec sign_with_key(jwt_payload(), service_account_key()) ::
          {:ok, String.t()} | {:error, term()}
  def sign_with_key(payload, %{private_key: private_key}) do
    try do
      # Create RS256 signer from the private key
      signer = Signer.create("RS256", %{"pem" => private_key})

      # Generate the token
      case Joken.generate_and_sign(%{}, payload, signer) do
        {:ok, token, _claims} -> {:ok, token}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Sign a JWT payload using Google Cloud IAM signJwt API.

  This method uses the Google Cloud IAM service to sign the JWT, which requires
  the caller to have the `roles/iam.serviceAccountTokenCreator` role.

  ## Parameters
  - `payload`: The JWT payload to sign
  - `service_account_email`: The service account email
  - `access_token`: A valid access token for authentication

  ## Examples

      iex> payload = %{iss: "...", aud: "...", sub: "...", iat: 123, exp: 456}
      iex> {:ok, token} = Gemini.Auth.JWT.sign_with_iam_api(
      ...>   payload,
      ...>   "my-service@project.iam.gserviceaccount.com",
      ...>   "ya29.access-token"
      ...> )
  """
  @spec sign_with_iam_api(jwt_payload(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def sign_with_iam_api(payload, service_account_email, access_token) do
    url = "#{@iam_credentials_url}/projects/-/serviceAccounts/#{service_account_email}:signJwt"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    # Convert payload to JSON string as required by the API
    body =
      Jason.encode!(%{
        "payload" => Jason.encode!(payload)
      })

    case Req.post(url, headers: headers, body: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        case response_body do
          %{"signedJwt" => signed_jwt} ->
            {:ok, signed_jwt}

          _ ->
            case Jason.decode(response_body) do
              {:ok, %{"signedJwt" => signed_jwt}} -> {:ok, signed_jwt}
              {:ok, response} -> {:error, "Unexpected response format: #{inspect(response)}"}
              {:error, reason} -> {:error, "Failed to parse response: #{reason}"}
            end
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        error_body = if is_binary(body), do: body, else: inspect(body)
        {:error, "HTTP #{status}: #{error_body}"}

      {:error, reason} ->
        {:error, "Request failed: #{reason}"}
    end
  end

  @doc """
  Load and parse a service account key file.

  ## Examples

      iex> {:ok, key} = Gemini.Auth.JWT.load_service_account_key("/path/to/key.json")
      iex> key.client_email
      "my-service@project.iam.gserviceaccount.com"
  """
  @spec load_service_account_key(String.t()) :: {:ok, service_account_key()} | {:error, term()}
  def load_service_account_key(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, key_data} ->
            # Convert string keys to atom keys for easier access
            parsed_key =
              for {key, val} <- key_data, into: %{} do
                {String.to_atom(key), val}
              end

            {:ok, parsed_key}

          {:error, %Jason.DecodeError{} = reason} ->
            {:error, "Failed to parse JSON: #{Exception.message(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end

  @doc """
  Validate a JWT payload has all required fields.

  ## Examples

      iex> payload = %{iss: "test", aud: "test", sub: "test", iat: 123, exp: 456}
      iex> Gemini.Auth.JWT.validate_payload(payload)
      :ok
  """
  @spec validate_payload(jwt_payload()) :: :ok | {:error, String.t()}
  def validate_payload(%{iss: iss, aud: aud, sub: sub, iat: iat, exp: exp})
      when is_binary(iss) and is_binary(aud) and is_binary(sub) and
             is_integer(iat) and is_integer(exp) do
    cond do
      aud != sub ->
        {:error, "aud and sub claims must be identical for Vertex AI"}

      exp <= iat ->
        {:error, "exp must be greater than iat"}

      iat > System.system_time(:second) + 60 ->
        {:error, "iat cannot be in the future"}

      exp < System.system_time(:second) ->
        {:error, "Token has expired"}

      true ->
        :ok
    end
  end

  def validate_payload(_payload) do
    {:error, "Missing required JWT claims: iss, aud, sub, iat, exp"}
  end

  @doc """
  Create a signed JWT token using the most appropriate method.

  This function automatically chooses between local signing (if private key is available)
  or IAM API signing (if access token is provided).

  ## Examples

      # Using service account key file
      iex> {:ok, token} = Gemini.Auth.JWT.create_signed_token(
      ...>   "my-service@project.iam.gserviceaccount.com",
      ...>   "my-app-audience",
      ...>   service_account_key: "/path/to/key.json"
      ...> )

      # Using IAM API
      iex> {:ok, token} = Gemini.Auth.JWT.create_signed_token(
      ...>   "my-service@project.iam.gserviceaccount.com",
      ...>   "my-app-audience",
      ...>   access_token: "ya29.access-token"
      ...> )
  """
  @spec create_signed_token(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def create_signed_token(service_account_email, audience, opts \\ []) do
    payload = create_payload(service_account_email, audience, opts)

    with :ok <- validate_payload(payload) do
      cond do
        service_account_key = Keyword.get(opts, :service_account_key) ->
          with {:ok, key} <- load_service_account_key(service_account_key) do
            sign_with_key(payload, key)
          end

        service_account_data = Keyword.get(opts, :service_account_data) ->
          sign_with_key(payload, service_account_data)

        access_token = Keyword.get(opts, :access_token) ->
          sign_with_iam_api(payload, service_account_email, access_token)

        true ->
          {:error,
           "Either service_account_key, service_account_data, or access_token must be provided"}
      end
    end
  end

  @doc """
  Extract service account email from a service account key.

  ## Examples

      iex> key = %{client_email: "my-service@project.iam.gserviceaccount.com"}
      iex> Gemini.Auth.JWT.get_service_account_email(key)
      "my-service@project.iam.gserviceaccount.com"
  """
  @spec get_service_account_email(service_account_key()) :: String.t()
  def get_service_account_email(%{client_email: email}), do: email
end
