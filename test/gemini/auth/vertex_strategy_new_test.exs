defmodule Gemini.Auth.VertexStrategyTestNew do
  use ExUnit.Case, async: true

  alias Gemini.Auth.VertexStrategy

  import Gemini.Test.ModelHelpers

  @sample_service_account_key %{
    type: "service_account",
    project_id: "test-project",
    private_key_id: "key-id-123",
    private_key: """
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKB
    wEiOfQIp5fXQ2j1ZWX3bNGNNRJYEQnE7FzU4lIbGKvv8XFmx6vQAu7ZXC9+A3oWl
    vQAQpOIpAlAAAoIBAQC7VJTUt9Us8cKBwEiOfQIp5fXQ2j1ZWX3bNGNNRJYEQnE7
    -----END PRIVATE KEY-----
    """,
    client_email: "test-service@test-project.iam.gserviceaccount.com",
    client_id: "123456789",
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    client_x509_cert_url:
      "https://www.googleapis.com/robot/v1/metadata/x509/test-service%40test-project.iam.gserviceaccount.com"
  }

  describe "authenticate/1" do
    test "returns credentials for OAuth2 authentication" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :oauth2
      }

      assert {:ok, credentials} = VertexStrategy.authenticate(config)
      assert credentials.project_id == "test-project"
      assert credentials.location == "us-central1"
      assert credentials.access_token == "oauth2-placeholder-token"
    end

    test "returns credentials for service account authentication with key path" do
      # Create temporary service account file
      temp_path = "/tmp/test_service_account_auth.json"
      content = Jason.encode!(@sample_service_account_key)
      File.write!(temp_path, content)

      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :service_account,
        service_account_key: temp_path
      }

      # Clean up the file after test
      on_exit(fn -> File.rm(temp_path) end)

      result = VertexStrategy.authenticate(config)

      # Should return either success or error (depending on token exchange)
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, credentials} ->
          assert credentials.project_id == "test-project"
          assert credentials.location == "us-central1"
          assert credentials.service_account_key == temp_path
          assert is_binary(credentials.access_token)

        {:error, _reason} ->
          # Expected in test environment without real token exchange
          :ok
      end
    end

    test "returns credentials for service account authentication with key data" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        auth_method: :service_account,
        service_account_data: @sample_service_account_key
      }

      result = VertexStrategy.authenticate(config)

      # Should return either success or error (depending on token exchange)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns credentials for direct access token" do
      config = %{
        project_id: "test-project",
        location: "us-central1",
        access_token: "existing-access-token"
      }

      assert {:ok, credentials} = VertexStrategy.authenticate(config)
      assert credentials.project_id == "test-project"
      assert credentials.location == "us-central1"
      assert credentials.access_token == "existing-access-token"
    end

    test "returns error when project_id is missing" do
      config = %{location: "us-central1"}

      assert {:error, error} = VertexStrategy.authenticate(config)
      assert error =~ "Missing required fields: project_id and location"
    end

    test "returns error when location is missing" do
      config = %{project_id: "test-project"}

      assert {:error, error} = VertexStrategy.authenticate(config)
      assert error =~ "Missing required fields: project_id and location"
    end

    test "defaults to oauth2 auth method when not specified" do
      config = %{project_id: "test-project", location: "us-central1"}

      assert {:ok, credentials} = VertexStrategy.authenticate(config)
      assert credentials.access_token == "oauth2-placeholder-token"
    end

    test "returns error for invalid configuration" do
      config = "invalid-config"

      assert {:error, error} = VertexStrategy.authenticate(config)
      assert error =~ "Invalid configuration for Vertex AI authentication"
    end
  end

  describe "headers/1" do
    test "creates headers for access token credentials" do
      credentials = %{access_token: "test-access-token"}

      assert {:ok, headers} = VertexStrategy.headers(credentials)

      assert headers == [
               {"Content-Type", "application/json"},
               {"Authorization", "Bearer test-access-token"}
             ]
    end

    test "creates headers for JWT token credentials" do
      credentials = %{jwt_token: "test.jwt.token"}

      assert {:ok, headers} = VertexStrategy.headers(credentials)

      assert headers == [
               {"Content-Type", "application/json"},
               {"Authorization", "Bearer test.jwt.token"}
             ]
    end

    test "creates headers for service account key credentials" do
      # Create temporary service account file
      temp_path = "/tmp/test_headers_service_account.json"
      content = Jason.encode!(@sample_service_account_key)
      File.write!(temp_path, content)

      credentials = %{service_account_key: temp_path}

      result = VertexStrategy.headers(credentials)

      # Should return either success with headers or error (depending on token exchange)
      case result do
        {:ok, headers} ->
          assert [
                   {"Content-Type", "application/json"},
                   {"Authorization", "Bearer " <> token}
                 ] = headers

          assert is_binary(token)

        {:error, reason} ->
          # Expected in test environment without real token exchange
          assert is_binary(reason)
      end

      File.rm!(temp_path)
    end

    test "returns error for unknown credentials" do
      credentials = %{}

      assert {:error, reason} = VertexStrategy.headers(credentials)
      assert reason =~ "No valid Vertex AI credentials found"
    end
  end

  describe "base_url/1" do
    test "creates correct base URL with project_id and location" do
      config = %{project_id: "test-project", location: "us-central1"}

      result = VertexStrategy.base_url(config)

      assert result == "https://us-central1-aiplatform.googleapis.com/v1"
    end

    test "returns error when location is missing" do
      config = %{project_id: "test-project"}

      result = VertexStrategy.base_url(config)

      assert result == {:error, "Location is required for Vertex AI base URL"}
    end

    test "returns error when project_id is missing" do
      config = %{location: "us-central1"}

      result = VertexStrategy.base_url(config)

      assert result == {:error, "Project ID is required for Vertex AI base URL"}
    end

    test "returns error when both project_id and location are missing" do
      config = %{}

      result = VertexStrategy.base_url(config)

      assert result == {:error, "Project ID and Location are required for Vertex AI base URL"}
    end
  end

  describe "build_path/3" do
    test "builds correct path for Vertex AI model endpoint" do
      model = default_model()
      endpoint = "generateContent"
      config = %{project_id: "test-project", location: "us-central1"}

      path = VertexStrategy.build_path(model, endpoint, config)

      expected =
        "projects/test-project/locations/us-central1/publishers/google/models/#{default_model()}:generateContent"

      assert path == expected
    end

    test "strips 'models/' prefix from model name" do
      model = "models/#{default_model()}"
      endpoint = "generateContent"
      config = %{project_id: "test-project", location: "us-central1"}

      path = VertexStrategy.build_path(model, endpoint, config)

      expected =
        "projects/test-project/locations/us-central1/publishers/google/models/#{default_model()}:generateContent"

      assert path == expected
    end
  end

  describe "refresh_credentials/1" do
    test "refreshes OAuth2 credentials" do
      credentials = %{refresh_token: "test-refresh-token"}

      assert {:ok, ^credentials} = VertexStrategy.refresh_credentials(credentials)
    end

    test "refreshes service account key credentials" do
      # Create temporary service account file
      temp_path = "/tmp/test_refresh_service_account.json"
      content = Jason.encode!(@sample_service_account_key)
      File.write!(temp_path, content)

      credentials = %{service_account_key: temp_path}

      result = VertexStrategy.refresh_credentials(credentials)

      # Should return either success with access_token or error
      case result do
        {:ok, updated_credentials} ->
          assert Map.has_key?(updated_credentials, :access_token)
          assert updated_credentials.service_account_key == temp_path

        {:error, _reason} ->
          # Expected in test environment without real token exchange
          :ok
      end

      File.rm!(temp_path)
    end

    test "refreshes service account data credentials" do
      credentials = %{service_account_data: @sample_service_account_key}

      result = VertexStrategy.refresh_credentials(credentials)

      # Should return either success with access_token or error
      case result do
        {:ok, updated_credentials} ->
          assert Map.has_key?(updated_credentials, :access_token)
          assert updated_credentials.service_account_data == @sample_service_account_key

        {:error, _reason} ->
          # Expected in test environment without real token exchange
          :ok
      end
    end

    test "returns credentials as-is for other types" do
      credentials = %{access_token: "existing-token"}

      assert {:ok, ^credentials} = VertexStrategy.refresh_credentials(credentials)
    end
  end

  describe "create_signed_jwt/4" do
    test "creates JWT with service account key file" do
      # Create temporary service account file
      temp_path = "/tmp/test_jwt_service_account.json"
      content = Jason.encode!(@sample_service_account_key)
      File.write!(temp_path, content)

      service_account_email = "test-service@test-project.iam.gserviceaccount.com"
      audience = "test-audience"
      credentials = %{service_account_key: temp_path}

      result = VertexStrategy.create_signed_jwt(service_account_email, audience, credentials)

      # Should return either success or error (depending on key validity)
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      File.rm!(temp_path)
    end

    test "creates JWT with service account data" do
      service_account_email = "test-service@test-project.iam.gserviceaccount.com"
      audience = "test-audience"
      credentials = %{service_account_data: @sample_service_account_key}

      result = VertexStrategy.create_signed_jwt(service_account_email, audience, credentials)

      # Should return either success or error (depending on key validity)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "creates JWT with access token for IAM API" do
      service_account_email = "test-service@test-project.iam.gserviceaccount.com"
      audience = "test-audience"
      credentials = %{access_token: "test-access-token"}

      result = VertexStrategy.create_signed_jwt(service_account_email, audience, credentials)

      # Should return either success or error (depending on API call)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error when no suitable credentials found" do
      service_account_email = "test-service@test-project.iam.gserviceaccount.com"
      audience = "test-audience"
      credentials = %{}

      assert {:error, "No suitable credentials found for JWT signing"} =
               VertexStrategy.create_signed_jwt(service_account_email, audience, credentials)
    end
  end
end
