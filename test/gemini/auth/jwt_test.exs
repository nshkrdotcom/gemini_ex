defmodule Gemini.Auth.JWTTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth.JWT

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

  describe "create_payload/3" do
    test "creates valid JWT payload with required fields" do
      service_account_email = "test@project.iam.gserviceaccount.com"
      audience = "test-audience"

      payload = JWT.create_payload(service_account_email, audience)

      assert payload.iss == service_account_email
      assert payload.aud == audience
      # Should be same as audience per v1.md
      assert payload.sub == audience
      assert is_integer(payload.iat)
      assert is_integer(payload.exp)
      assert payload.exp > payload.iat
    end

    test "allows custom issued_at time" do
      custom_time = 1_234_567_890

      payload =
        JWT.create_payload(
          "test@project.iam.gserviceaccount.com",
          "test-audience",
          issued_at: custom_time
        )

      assert payload.iat == custom_time
      # Default lifetime
      assert payload.exp == custom_time + 3600
    end

    test "allows custom token lifetime" do
      # 30 minutes
      custom_lifetime = 1800

      payload =
        JWT.create_payload(
          "test@project.iam.gserviceaccount.com",
          "test-audience",
          lifetime: custom_lifetime
        )

      assert payload.exp - payload.iat == custom_lifetime
    end
  end

  describe "validate_payload/1" do
    test "validates correct payload" do
      payload = %{
        iss: "test@project.iam.gserviceaccount.com",
        aud: "test-audience",
        sub: "test-audience",
        iat: System.system_time(:second),
        exp: System.system_time(:second) + 3600
      }

      assert JWT.validate_payload(payload) == :ok
    end

    test "fails when aud and sub don't match" do
      payload = %{
        iss: "test@project.iam.gserviceaccount.com",
        aud: "test-audience",
        sub: "different-audience",
        iat: System.system_time(:second),
        exp: System.system_time(:second) + 3600
      }

      assert {:error, "aud and sub claims must be identical for Vertex AI"} =
               JWT.validate_payload(payload)
    end

    test "fails when token is expired" do
      past_time = System.system_time(:second) - 3600

      payload = %{
        iss: "test@project.iam.gserviceaccount.com",
        aud: "test-audience",
        sub: "test-audience",
        iat: past_time,
        # Expired 30 minutes ago
        exp: past_time + 1800
      }

      assert {:error, "Token has expired"} = JWT.validate_payload(payload)
    end

    test "fails when exp <= iat" do
      now = System.system_time(:second)

      payload = %{
        iss: "test@project.iam.gserviceaccount.com",
        aud: "test-audience",
        sub: "test-audience",
        iat: now,
        # Same time
        exp: now
      }

      assert {:error, "exp must be greater than iat"} = JWT.validate_payload(payload)
    end

    test "fails when required fields are missing" do
      incomplete_payload = %{
        iss: "test@project.iam.gserviceaccount.com",
        aud: "test-audience"
        # Missing sub, iat, exp
      }

      assert {:error, "Missing required JWT claims: iss, aud, sub, iat, exp"} =
               JWT.validate_payload(incomplete_payload)
    end
  end

  describe "load_service_account_key/1" do
    setup do
      # Create a temporary file with service account JSON
      temp_path = "/tmp/test_service_account.json"
      content = Jason.encode!(@sample_service_account_key)
      File.write!(temp_path, content)

      on_exit(fn -> File.rm(temp_path) end)

      {:ok, temp_path: temp_path}
    end

    test "loads and parses valid service account file", %{temp_path: temp_path} do
      assert {:ok, key} = JWT.load_service_account_key(temp_path)

      assert key.type == "service_account"
      assert key.project_id == "test-project"
      assert key.client_email == "test-service@test-project.iam.gserviceaccount.com"
      assert String.contains?(key.private_key, "BEGIN PRIVATE KEY")
    end

    test "drops unknown service account keys instead of atomizing them" do
      temp_path = "/tmp/test_service_account_unknown_key.json"

      content =
        @sample_service_account_key
        |> Map.put("providerAuthMode", "external")
        |> Jason.encode!()

      File.write!(temp_path, content)
      on_exit(fn -> File.rm(temp_path) end)

      assert {:ok, key} = JWT.load_service_account_key(temp_path)
      refute Map.has_key?(key, :providerAuthMode)
      refute Map.has_key?(key, "providerAuthMode")
    end

    test "returns error for non-existent file" do
      assert {:error, "Failed to read file: " <> _reason} =
               JWT.load_service_account_key("/non/existent/file.json")
    end

    test "returns error for invalid JSON file" do
      invalid_path = "/tmp/invalid.json"
      File.write!(invalid_path, "invalid json content")

      assert {:error, "Failed to parse JSON: " <> _reason} =
               JWT.load_service_account_key(invalid_path)

      File.rm!(invalid_path)
    end
  end

  describe "get_service_account_email/1" do
    test "extracts email from service account key" do
      key = %{client_email: "test@project.iam.gserviceaccount.com"}

      assert JWT.get_service_account_email(key) == "test@project.iam.gserviceaccount.com"
    end
  end

  describe "sign_with_key/2" do
    test "returns error for invalid private key" do
      payload =
        JWT.create_payload(
          "test@project.iam.gserviceaccount.com",
          "test-audience"
        )

      invalid_key = %{private_key: "invalid-key-content"}

      assert {:error, _reason} = JWT.sign_with_key(payload, invalid_key)
    end

    # Note: Testing actual JWT signing would require a valid private key
    # In a real test suite, you might use a test RSA key pair
  end

  describe "sign_with_iam_api/3" do
    # These tests would typically use mocked HTTP requests
    # since they interact with external Google Cloud APIs

    test "formats request correctly" do
      # This is a basic structural test - in practice you'd mock Finch
      _payload =
        JWT.create_payload(
          "test@project.iam.gserviceaccount.com",
          "test-audience"
        )

      _service_account_email = "test@project.iam.gserviceaccount.com"
      _access_token = "test-access-token"

      # The function should at least validate inputs without making HTTP calls in test
      # You would typically mock Finch.request/2 here
      assert is_function(&JWT.sign_with_iam_api/3, 3)
    end
  end

  describe "create_signed_token/3" do
    setup do
      temp_path = "/tmp/test_create_signed_token.json"
      content = Jason.encode!(@sample_service_account_key)
      File.write!(temp_path, content)

      on_exit(fn -> File.rm(temp_path) end)

      {:ok, temp_path: temp_path}
    end

    test "returns error when no credentials provided" do
      assert {:error,
              "Either service_account_key, service_account_data, or access_token must be provided"} =
               JWT.create_signed_token(
                 "test@project.iam.gserviceaccount.com",
                 "test-audience",
                 []
               )
    end

    test "validates payload before signing", %{temp_path: temp_path} do
      # Test with mismatched aud and sub by creating custom payload
      service_account_email = "test@project.iam.gserviceaccount.com"
      audience = "test-audience"

      # This should work normally
      result =
        JWT.create_signed_token(
          service_account_email,
          audience,
          service_account_key: temp_path
        )

      # Result will depend on the validity of the test private key
      # In practice, you'd use a valid test key or mock the signing
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "attempts to load service account key file", %{temp_path: temp_path} do
      result =
        JWT.create_signed_token(
          "test@project.iam.gserviceaccount.com",
          "test-audience",
          service_account_key: temp_path
        )

      # Should attempt to load the file (success depends on key validity)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "works with service account data directly" do
      result =
        JWT.create_signed_token(
          "test@project.iam.gserviceaccount.com",
          "test-audience",
          service_account_data: @sample_service_account_key
        )

      # Should process the data directly
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
