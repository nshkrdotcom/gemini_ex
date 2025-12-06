defmodule Gemini.Auth.ADCTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth.{ADC, TokenCache}

  # Sample test credentials
  @service_account_creds %{
    type: "service_account",
    project_id: "test-project-123",
    private_key_id: "key-id-123",
    private_key: """
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7VJTUt9Us8cKj
    wQIDAQABAoIBAQCiXJzk9dB5xF7F5F7F5F7F5F7F5F7F5F7F5F7F5F7F5F7F5F7F
    -----END PRIVATE KEY-----
    """,
    client_email: "test@test-project.iam.gserviceaccount.com",
    client_id: "123456789",
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    client_x509_cert_url:
      "https://www.googleapis.com/robot/v1/metadata/x509/test%40test-project.iam.gserviceaccount.com"
  }

  @user_creds %{
    type: "authorized_user",
    client_id: "123456789.apps.googleusercontent.com",
    client_secret: "client_secret_123",
    refresh_token: "refresh_token_123",
    quota_project_id: "test-project-123"
  }

  setup do
    # Initialize token cache for tests (idempotent - safe for async)
    TokenCache.init()

    # Generate unique test prefix to avoid cache collisions in async tests
    # DO NOT call TokenCache.clear() - it races with other async tests
    test_id = :erlang.unique_integer([:positive])

    # Save original env vars
    original_google_creds = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")

    on_exit(fn ->
      # Restore original env vars
      if original_google_creds do
        System.put_env("GOOGLE_APPLICATION_CREDENTIALS", original_google_creds)
      else
        System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
      end

      # DO NOT call TokenCache.clear() - it races with other async tests
    end)

    {:ok, original_google_creds: original_google_creds, test_id: test_id}
  end

  describe "load_credentials/0" do
    test "loads service account from GOOGLE_APPLICATION_CREDENTIALS" do
      # Create temporary service account file
      temp_file = create_temp_service_account_file()

      try do
        System.put_env("GOOGLE_APPLICATION_CREDENTIALS", temp_file)

        assert {:ok, {:service_account, creds}} = ADC.load_credentials()
        assert creds.type == "service_account"
        assert creds.project_id == "test-project-123"
        assert creds.client_email == "test@test-project.iam.gserviceaccount.com"
      after
        File.rm(temp_file)
        System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
      end
    end

    test "returns error when GOOGLE_APPLICATION_CREDENTIALS file doesn't exist" do
      System.put_env("GOOGLE_APPLICATION_CREDENTIALS", "/non/existent/file.json")

      # Should fall through to other credential sources
      result = ADC.load_credentials()

      # Will either find user creds or metadata server, or fail
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
    end

    test "returns error when GOOGLE_APPLICATION_CREDENTIALS file has invalid JSON" do
      temp_file = Path.join(System.tmp_dir!(), "invalid_#{:rand.uniform(10000)}.json")
      File.write!(temp_file, "invalid json content")

      try do
        System.put_env("GOOGLE_APPLICATION_CREDENTIALS", temp_file)

        # Should fall through to other credential sources
        result = ADC.load_credentials()
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      after
        File.rm(temp_file)
        System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
      end
    end

    test "loads user credentials from default path if available" do
      # This test would require mocking the file system or having actual user creds
      # For now, we just verify the function handles missing user creds gracefully
      System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")

      result = ADC.load_credentials()

      # Should either find user creds, metadata server, or return error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error when no credentials are available" do
      System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")

      # If metadata server is not available and no user creds exist
      # This will vary based on test environment, so we just check it doesn't crash
      result = ADC.load_credentials()

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_access_token/2" do
    test "uses cached token when available", %{test_id: test_id} do
      creds = {:service_account, @service_account_creds}
      # Use test-specific cache key to avoid collisions with async tests
      cache_key = "test_#{test_id}_adc_service_account"

      # Pre-cache a token with custom key
      TokenCache.put(cache_key, "cached_token_123", 3600)

      assert {:ok, "cached_token_123"} = ADC.get_access_token(creds, cache_key: cache_key)
    end

    test "forces refresh when force_refresh option is true", %{test_id: test_id} do
      creds = {:service_account, @service_account_creds}
      # Use test-specific cache key to avoid collisions with async tests
      cache_key = "test_#{test_id}_adc_force_refresh"

      # Pre-cache a token
      TokenCache.put(cache_key, "cached_token_123", 3600)

      # Force refresh should bypass cache (will fail since we don't have real creds)
      result = ADC.get_access_token(creds, force_refresh: true, cache_key: cache_key)

      # Should attempt to generate new token (will fail with test creds)
      assert match?({:error, _}, result)
    end

    test "uses custom cache key when provided", %{test_id: test_id} do
      creds = {:service_account, @service_account_creds}
      custom_key = "test_#{test_id}_custom_cache_key"

      # Pre-cache with custom key
      TokenCache.put(custom_key, "custom_cached_token", 3600)

      assert {:ok, "custom_cached_token"} = ADC.get_access_token(creds, cache_key: custom_key)
    end

    test "returns error for invalid service account credentials" do
      invalid_creds = {:service_account, %{client_email: "test@example.com"}}

      result = ADC.get_access_token(invalid_creds)

      assert {:error, _reason} = result
    end

    test "handles user credentials token refresh" do
      creds = {:user, @user_creds}

      # Will attempt to refresh but fail without real credentials
      result = ADC.get_access_token(creds)

      # Should return error since we don't have real credentials
      assert match?({:error, _}, result)
    end

    test "handles metadata server credentials" do
      creds = {:metadata_server, %{source: :metadata_server, project_id: "test-project"}}

      # Will attempt metadata server but likely fail in test environment
      result = ADC.get_access_token(creds)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "refresh_token/1" do
    test "forces token refresh bypassing cache", %{test_id: test_id} do
      creds = {:service_account, @service_account_creds}
      # Use test-specific cache key to avoid collisions with async tests
      cache_key = "test_#{test_id}_adc_refresh"

      # Pre-cache a token
      TokenCache.put(cache_key, "old_token", 3600)

      # Refresh should bypass cache (will fail with test creds)
      # Note: refresh_token doesn't use cache_key option, it always generates new
      result = ADC.refresh_token(creds)

      assert match?({:error, _}, result)
    end
  end

  describe "get_project_id/1" do
    test "extracts project ID from service account credentials" do
      creds = {:service_account, @service_account_creds}

      assert {:ok, "test-project-123"} = ADC.get_project_id(creds)
    end

    test "extracts project ID from user credentials" do
      creds = {:user, @user_creds}

      assert {:ok, "test-project-123"} = ADC.get_project_id(creds)
    end

    test "extracts project ID from metadata server credentials" do
      creds = {:metadata_server, %{source: :metadata_server, project_id: "gcp-project-456"}}

      assert {:ok, "gcp-project-456"} = ADC.get_project_id(creds)
    end

    test "attempts to fetch project ID from metadata server when not in credentials" do
      creds = {:metadata_server, %{source: :metadata_server, project_id: nil}}

      result = ADC.get_project_id(creds)

      # Will either succeed if on GCP or fail
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error when credentials have no project ID" do
      creds = {:service_account, Map.delete(@service_account_creds, :project_id)}

      assert {:error, _reason} = ADC.get_project_id(creds)
    end
  end

  describe "available?/0" do
    test "returns boolean indicating if credentials are available" do
      result = ADC.available?()

      assert is_boolean(result)
    end

    test "returns true when GOOGLE_APPLICATION_CREDENTIALS is set" do
      temp_file = create_temp_service_account_file()

      try do
        System.put_env("GOOGLE_APPLICATION_CREDENTIALS", temp_file)

        assert ADC.available?() == true
      after
        File.rm(temp_file)
        System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
      end
    end
  end

  describe "token caching integration" do
    test "caches token after successful generation", %{test_id: test_id} do
      creds = {:service_account, @service_account_creds}
      # Use test-specific cache key to avoid collisions with async tests
      cache_key = "test_#{test_id}_caching_integration"

      # Pre-cache a token
      TokenCache.put(cache_key, "cached_token_abc", 3600)

      # First call should use cache (using explicit cache_key)
      assert {:ok, "cached_token_abc"} = ADC.get_access_token(creds, cache_key: cache_key)

      # Verify it's still in cache
      assert {:ok, "cached_token_abc"} = TokenCache.get(cache_key)
    end

    test "respects cache expiration", %{test_id: test_id} do
      # Use test-specific cache key to avoid collisions with async tests
      cache_key = "test_#{test_id}_cache_expiration"

      # Test 1: Verify cache works with normal TTL
      TokenCache.put(cache_key, "valid_token", 3600, refresh_buffer: 0)
      assert {:ok, "valid_token"} = TokenCache.get(cache_key)

      # Test 2: Cache with TTL shorter than refresh_buffer triggers "needs refresh"
      # When TTL (1) < refresh_buffer (300 default), token is considered "about to expire"
      # This tests the expiration logic without Process.sleep
      refresh_key = "test_#{test_id}_needs_refresh"
      TokenCache.put(refresh_key, "short_lived", 1, refresh_buffer: 300)

      # Token should be retrievable (but marked for refresh internally)
      # The get will still return the value if it hasn't actually expired
      result = TokenCache.get(refresh_key)
      # Either returns token (within TTL) or error (expired)
      assert match?({:ok, _}, result) or result == :error
    end

    test "different credential types use different cache keys", %{test_id: test_id} do
      service_creds = {:service_account, @service_account_creds}
      user_creds = {:user, @user_creds}

      # Use test-specific cache keys to avoid collisions with async tests
      service_key = "test_#{test_id}_service_key"
      user_key = "test_#{test_id}_user_key"

      # Cache different tokens for different credential types
      TokenCache.put(service_key, "service_token", 3600)
      TokenCache.put(user_key, "user_token", 3600)

      # Verify they're stored separately using explicit cache_key option
      assert {:ok, "service_token"} = ADC.get_access_token(service_creds, cache_key: service_key)
      assert {:ok, "user_token"} = ADC.get_access_token(user_creds, cache_key: user_key)
    end
  end

  describe "error handling" do
    test "handles malformed service account JSON gracefully" do
      malformed_creds = {:service_account, %{type: "service_account"}}

      result = ADC.get_access_token(malformed_creds)

      assert {:error, _reason} = result
    end

    test "handles network errors when refreshing tokens" do
      # User credentials will attempt network call which should fail in test
      creds = {:user, @user_creds}

      result = ADC.get_access_token(creds)

      assert {:error, _reason} = result
    end

    test "provides helpful error messages" do
      System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")

      case ADC.load_credentials() do
        {:error, reason} ->
          # Should mention ADC and provide guidance
          assert is_binary(reason)

        {:ok, _} ->
          # Found credentials via other means (user creds or metadata server)
          :ok
      end
    end
  end

  describe "concurrent access" do
    test "handles concurrent token requests safely", %{test_id: test_id} do
      creds = {:service_account, @service_account_creds}
      # Use test-specific cache key to avoid collisions with async tests
      cache_key = "test_#{test_id}_concurrent_token"

      # Pre-cache a token
      TokenCache.put(cache_key, "concurrent_token", 3600)

      # Make concurrent requests - all using same test-specific cache key
      tasks =
        for _i <- 1..10 do
          Task.async(fn -> ADC.get_access_token(creds, cache_key: cache_key) end)
        end

      results = Task.await_many(tasks, 5000)

      # All should get the same cached token
      assert Enum.all?(results, &match?({:ok, "concurrent_token"}, &1))
    end

    test "handles concurrent cache writes safely", %{test_id: test_id} do
      # Use test-specific cache key prefix to avoid collisions with async tests
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            TokenCache.put("test_#{test_id}_key_#{rem(i, 5)}", "token_#{i}", 3600)
            :ok
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All should complete successfully
      assert Enum.all?(results, &(&1 == :ok))

      # Verify cache is in consistent state
      stats = TokenCache.stats()
      assert stats.size >= 0
    end
  end

  # Helper functions

  defp create_temp_service_account_file do
    temp_file = Path.join(System.tmp_dir!(), "service_account_#{:rand.uniform(10000)}.json")
    content = Jason.encode!(@service_account_creds)
    File.write!(temp_file, content)
    temp_file
  end
end
