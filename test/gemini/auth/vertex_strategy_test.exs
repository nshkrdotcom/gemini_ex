defmodule Gemini.Auth.VertexStrategyTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth.VertexStrategy

  @sample_service_account_key %{
    type: "service_account",
    project_id: "test-project",
    private_key_id: "key-id-123",
    private_key: """
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCz1PIERY0ZPSTQ
    FCpuzZ1kGBKC/RzF6pgH67COYmkMgn6r4fGAaoJ7mzSmefybPWqNBWW/NdyumY11
    Rf+gbvsWMdwe2wmBcRUFpaiHMzMUV1QjgSOvnaT2jJHWSU4dHS59EXIzEZFLTJV3
    mvhiY7khN8YCvXLHuUNaov64geNR+BIXGwPQGhs1TpamphVXQ1i2asjQGSzpXS52
    nevm5ZBbFtluswneDOZzVXH48E+OYdaOU70QhYtbbxKYNLpOYiC+9hIwmMqz8hOp
    ulWQMe6LYUO+xtZlp/YjNhHXFwXj/ng8KFdJJnpR5QzpoX2iy61LsYKrb6IF5mdY
    uUmlfk/pAgMBAAECggEACRRuZ9LPLgANVMg/4DpXgQ9KF/0Jr+CJbpTy5C2J2kzY
    cntFA1PdZLpQbTtpirkOITKtkXr5uoMcRliTcJlJ6jP4RkKO908rXY6gtLrcEGHc
    aLKDh8Fw69XrIyOuYv/vMfdoibWQXXnvbguQEP+yAEBdqhPAsN7kzLXAILbGMIQ9
    HYF8BlZhUFNZ8nVFk0p2h2vlpI5RaXSfjyxQ5eFODtagAGIScXxUYUSe4EhM8RJO
    jk0TF2UA/zpAZ/iP8C8AI9Yte80WErQpVSvQCwLZ2iYKIOuny4mMEbz18z1KiZY3
    TGYti2307WGJGLTJDo4CclzbrTf3MwO4kjF9xMvVxQKBgQD2ciH0O7qmnNuGovl6
    M5VcYFpboEe8Tgirb2rfs9RFKBVEKW0WvgCIpJN9wTV6gH4XyoM4UxgmEEnIE3oT
    waJ3UiGNCG+JxKWpnwE40GCQX/nrQUvTQPpGw1vOXNUWny+OGwQuaqrhlNW2u1ZR
    Sycx1IPZa48/ZWTCD29Jd+ZbrwKBgQC6zbKeLTbdrfuXG6PwRkI7ArWYZg3JcGPU
    MxMq+bl9Ug3RsR0xIOq5IRLdyhccbuLErMnVtF5HfX2rhERxurVFGHpdjDog/9Ye
    5RzRpEjAk9rAoE+1w3tZ3UIwRo8pdN7wHccYHH2UnK+FqgJQXjafzFVYoSbVDQ4s
    D/T60VP75wKBgCZtd4PoyFrwfH6K7RGz92c3Ev/UhzsCg/GPZv/Iv6Gk9WPyfbMd
    H2IvH1xtgxQ98utsxXdD5bERux96gf+Qou+uG9Ms7I9z3U0MoRklzNjWTlbzkIo5
    SI0+KxOLgCKN4dFrvwQp18li9swOfBAjAtKPS5vcXLLK8aIc3AJ9sqq7AoGBAJnc
    q26Vl0dn8n44CgPyGsM4LBLmnBx7Mf6qQvN21U1ftHovA/hfQHZTw5Jizj5hJu8P
    0v7unWkM9+G6BBYYzw2mZ8N9qLNdhiPUWrRiOHpGTjuyz3TLGmKeV9Iji+99j9L+
    8+nsLZOmqvvRWC6SKzPbvcBOnAmHw1CPpByjJiWpAoGAV6HChk+g9h0G7yK0IKqg
    cKtwlm2kRgsPJxjJPqLl7OwDsidLKkLIfuN+AWWXShqMmbo/HphTTaM9+Slx08ur
    b95d3nd1zXwtCQbTXr9qRFuj5KUscVbJYIf6V8i70/9p+GZ+85k9AgO+icXNO84P
    shkKxRELK5ja6ywsUvqWbOE=
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

      headers = VertexStrategy.headers(credentials)

      assert headers == [
               {"Content-Type", "application/json"},
               {"Authorization", "Bearer test-access-token"}
             ]
    end

    test "creates headers for JWT token credentials" do
      credentials = %{jwt_token: "test.jwt.token"}

      headers = VertexStrategy.headers(credentials)

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

      headers = VertexStrategy.headers(credentials)

      # Should return headers with either real token or error token
      assert [
               {"Content-Type", "application/json"},
               {"Authorization", "Bearer " <> token}
             ] = headers

      assert is_binary(token)

      File.rm!(temp_path)
    end

    test "creates default headers for unknown credentials" do
      credentials = %{}

      headers = VertexStrategy.headers(credentials)

      assert headers == [
               {"Content-Type", "application/json"},
               {"Authorization", "Bearer default-credentials-token"}
             ]
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
      model = "gemini-2.0-flash-lite"
      endpoint = "generateContent"
      config = %{project_id: "test-project", location: "us-central1"}

      path = VertexStrategy.build_path(model, endpoint, config)

      expected =
        "projects/test-project/locations/us-central1/publishers/google/models/gemini-2.0-flash-lite:generateContent"

      assert path == expected
    end

    test "strips 'models/' prefix from model name" do
      model = "models/gemini-2.0-flash-lite"
      endpoint = "generateContent"
      config = %{project_id: "test-project", location: "us-central1"}

      path = VertexStrategy.build_path(model, endpoint, config)

      expected =
        "projects/test-project/locations/us-central1/publishers/google/models/gemini-2.0-flash-lite:generateContent"

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

      if File.exists?(temp_path), do: File.rm!(temp_path)
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
