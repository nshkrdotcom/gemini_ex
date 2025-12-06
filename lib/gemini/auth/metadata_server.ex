defmodule Gemini.Auth.MetadataServer do
  @moduledoc """
  Authentication via GCP metadata server for workloads running on Google Cloud Platform.

  This module provides authentication for workloads running on:
  - Google Compute Engine
  - Google Kubernetes Engine (GKE)
  - Cloud Run
  - Cloud Functions
  - App Engine

  The metadata server provides automatic authentication without requiring
  explicit credentials files, making it ideal for production deployments
  on GCP infrastructure.

  ## Metadata Server Endpoint

  The metadata server is available at `http://metadata.google.internal/computeMetadata/v1/`
  and requires the `Metadata-Flavor: Google` header on all requests.

  ## Features

  - Automatic token retrieval from GCP metadata server
  - Project ID detection
  - Availability checking (determines if running on GCP)
  - Service account information retrieval

  ## Usage

      # Check if running on GCP
      if MetadataServer.available?() do
        # Get access token
        {:ok, token} = MetadataServer.get_access_token()

        # Get project ID
        {:ok, project_id} = MetadataServer.get_project_id()
      end

  ## Timeout Configuration

  Metadata server checks use a short timeout (1 second) to quickly determine
  if the code is running on GCP. If the metadata server is not available,
  the check will fail fast.
  """

  require Logger

  @metadata_base_url "http://metadata.google.internal/computeMetadata/v1"
  @metadata_headers [{"Metadata-Flavor", "Google"}]
  # Short timeout for availability check
  @availability_timeout 1_000
  # Longer timeout for actual token/data retrieval
  @request_timeout 5_000

  @type error_reason :: String.t()

  @doc """
  Check if the GCP metadata server is available.

  This function performs a quick check to determine if the code is running
  on Google Cloud Platform infrastructure with access to the metadata server.

  Uses a 1-second timeout for fast failure in non-GCP environments.

  ## Returns

  - `true` - Running on GCP with metadata server access
  - `false` - Not running on GCP or metadata server unavailable

  ## Examples

      if MetadataServer.available?() do
        # Running on GCP, can use metadata server
        {:ok, token} = MetadataServer.get_access_token()
      else
        # Not on GCP, use other authentication method
        use_service_account_file()
      end
  """
  @spec available?() :: boolean()
  def available? do
    url = "#{@metadata_base_url}/"

    case Req.get(url, headers: @metadata_headers, receive_timeout: @availability_timeout) do
      {:ok, %Req.Response{status: 200}} ->
        Logger.debug("[MetadataServer] Metadata server is available")
        true

      {:ok, %Req.Response{status: status}} ->
        Logger.debug(
          "[MetadataServer] Metadata server responded with unexpected status: #{status}"
        )

        false

      {:error, %Mint.TransportError{reason: :timeout}} ->
        Logger.debug("[MetadataServer] Metadata server not available (timeout)")
        false

      {:error, %Mint.TransportError{reason: :econnrefused}} ->
        Logger.debug("[MetadataServer] Metadata server not available (connection refused)")
        false

      {:error, reason} ->
        Logger.debug("[MetadataServer] Metadata server check failed: #{inspect(reason)}")
        false
    end
  end

  @doc """
  Get an access token from the GCP metadata server.

  Retrieves a fresh access token for the default service account
  associated with the GCP resource (VM, Cloud Run instance, etc.).

  The token will have the scopes assigned to the service account,
  which typically includes `https://www.googleapis.com/auth/cloud-platform`.

  ## Returns

  - `{:ok, %{token: token, expires_in: seconds}}` - Successfully retrieved token
  - `{:error, reason}` - Failed to retrieve token

  ## Examples

      case MetadataServer.get_access_token() do
        {:ok, %{token: token, expires_in: ttl}} ->
          # Use token for API calls
          # Cache with TTL
          TokenCache.put("metadata_server", token, ttl)

        {:error, reason} ->
          Logger.error("Failed to get token: \#{reason}")
      end
  """
  @spec get_access_token() ::
          {:ok, %{token: String.t(), expires_in: pos_integer()}}
          | {:error, error_reason()}
  def get_access_token do
    url = "#{@metadata_base_url}/instance/service-accounts/default/token"

    case Req.get(url, headers: @metadata_headers, receive_timeout: @request_timeout) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse_token_response(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        error_msg = if is_binary(body), do: body, else: inspect(body)
        {:error, "Metadata server returned HTTP #{status}: #{error_msg}"}

      {:error, reason} ->
        {:error, "Failed to contact metadata server: #{inspect(reason)}"}
    end
  end

  @doc """
  Get the GCP project ID from the metadata server.

  Retrieves the project ID for the GCP project in which the code is running.
  This is useful when you need the project ID for Vertex AI or other
  GCP services but don't want to hardcode it.

  ## Returns

  - `{:ok, project_id}` - Successfully retrieved project ID
  - `{:error, reason}` - Failed to retrieve project ID

  ## Examples

      case MetadataServer.get_project_id() do
        {:ok, project_id} ->
          # Use project_id for Vertex AI configuration
          %{project_id: project_id, location: "us-central1"}

        {:error, reason} ->
          Logger.error("Failed to get project ID: \#{reason}")
      end
  """
  @spec get_project_id() :: {:ok, String.t()} | {:error, error_reason()}
  def get_project_id do
    url = "#{@metadata_base_url}/project/project-id"

    case Req.get(url, headers: @metadata_headers, receive_timeout: @request_timeout) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        project_id = String.trim(body)
        Logger.debug("[MetadataServer] Retrieved project ID: #{project_id}")
        {:ok, project_id}

      {:ok, %Req.Response{status: status, body: body}} ->
        error_msg = if is_binary(body), do: body, else: inspect(body)
        {:error, "Metadata server returned HTTP #{status}: #{error_msg}"}

      {:error, reason} ->
        {:error, "Failed to contact metadata server: #{inspect(reason)}"}
    end
  end

  @doc """
  Get the service account email from the metadata server.

  Retrieves the email address of the default service account
  associated with the GCP resource.

  ## Returns

  - `{:ok, email}` - Successfully retrieved service account email
  - `{:error, reason}` - Failed to retrieve email

  ## Examples

      case MetadataServer.get_service_account_email() do
        {:ok, email} ->
          Logger.info("Running as service account: \#{email}")

        {:error, reason} ->
          Logger.error("Failed to get service account: \#{reason}")
      end
  """
  @spec get_service_account_email() :: {:ok, String.t()} | {:error, error_reason()}
  def get_service_account_email do
    url = "#{@metadata_base_url}/instance/service-accounts/default/email"

    case Req.get(url, headers: @metadata_headers, receive_timeout: @request_timeout) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        email = String.trim(body)
        Logger.debug("[MetadataServer] Retrieved service account email: #{email}")
        {:ok, email}

      {:ok, %Req.Response{status: status, body: body}} ->
        error_msg = if is_binary(body), do: body, else: inspect(body)
        {:error, "Metadata server returned HTTP #{status}: #{error_msg}"}

      {:error, reason} ->
        {:error, "Failed to contact metadata server: #{inspect(reason)}"}
    end
  end

  @doc """
  Get all metadata for the instance.

  Retrieves comprehensive metadata about the GCP instance, including
  service account information, project details, and instance attributes.

  ## Returns

  - `{:ok, metadata}` - Map containing instance metadata
  - `{:error, reason}` - Failed to retrieve metadata

  ## Examples

      case MetadataServer.get_instance_metadata() do
        {:ok, metadata} ->
          IO.inspect(metadata, label: "Instance Metadata")

        {:error, reason} ->
          Logger.error("Failed to get metadata: \#{reason}")
      end
  """
  @spec get_instance_metadata() :: {:ok, map()} | {:error, error_reason()}
  def get_instance_metadata do
    with {:ok, project_id} <- get_project_id(),
         {:ok, service_account} <- get_service_account_email() do
      metadata = %{
        project_id: project_id,
        service_account: service_account
      }

      {:ok, metadata}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp parse_token_response(body) when is_map(body) do
    case body do
      %{"access_token" => token, "expires_in" => expires_in}
      when is_binary(token) and is_integer(expires_in) ->
        Logger.debug("[MetadataServer] Retrieved access token (expires in #{expires_in}s)")
        {:ok, %{token: token, expires_in: expires_in}}

      %{"access_token" => token} when is_binary(token) ->
        # Default to 1 hour if expires_in not provided
        Logger.warning("[MetadataServer] No expires_in in token response, defaulting to 3600s")
        {:ok, %{token: token, expires_in: 3600}}

      _ ->
        {:error, "Invalid token response format: #{inspect(body)}"}
    end
  end

  defp parse_token_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> parse_token_response(parsed)
      {:error, reason} -> {:error, "Failed to parse JSON response: #{inspect(reason)}"}
    end
  end

  defp parse_token_response(body) do
    {:error, "Unexpected response body type: #{inspect(body)}"}
  end
end
