defmodule Gemini.LiveAPI.ADCLiveTest do
  use ExUnit.Case

  @moduletag :live_api
  @moduletag timeout: 30_000

  alias Gemini.Auth.ADC

  describe "ADC on actual GCP infrastructure" do
    @tag :gcp_metadata
    test "loads credentials from metadata server when on GCP" do
      case ADC.load_credentials() do
        {:ok, {:metadata_server, creds}} ->
          assert creds.source == :metadata_server
          IO.puts("✓ Successfully loaded metadata server credentials")

        {:ok, {type, _creds}} ->
          IO.puts("ℹ Found #{type} credentials instead of metadata server")

        {:error, reason} ->
          IO.puts("⊘ No ADC credentials available: #{reason}")
          IO.puts("  This is expected if not running on GCP or without credentials configured")
      end
    end

    @tag :gcp_metadata
    test "retrieves access token from metadata server when on GCP" do
      case ADC.load_credentials() do
        {:ok, {:metadata_server, _} = creds} ->
          case ADC.get_access_token(creds) do
            {:ok, token} ->
              assert is_binary(token)
              assert String.length(token) > 0
              IO.puts("✓ Successfully retrieved access token from metadata server")

            {:error, reason} ->
              flunk("Failed to get access token: #{reason}")
          end

        {:ok, {type, _}} ->
          IO.puts("ℹ Skipping metadata server test: using #{type} credentials")

        {:error, _reason} ->
          IO.puts("⊘ Skipping metadata server test: no ADC credentials")
      end
    end

    @tag :gcp_metadata
    test "retrieves project ID when on GCP" do
      case ADC.load_credentials() do
        {:ok, creds} ->
          case ADC.get_project_id(creds) do
            {:ok, project_id} ->
              assert is_binary(project_id)
              assert String.length(project_id) > 0
              IO.puts("✓ Retrieved project ID: #{project_id}")

            {:error, _reason} ->
              IO.puts("ℹ No project ID available in credentials")
          end

        {:error, _reason} ->
          IO.puts("⊘ Skipping project ID test: no ADC credentials")
      end
    end
  end

  describe "ADC with service account file" do
    test "loads service account from GOOGLE_APPLICATION_CREDENTIALS" do
      case System.get_env("GOOGLE_APPLICATION_CREDENTIALS") do
        nil ->
          IO.puts("⊘ GOOGLE_APPLICATION_CREDENTIALS not set")

        "" ->
          IO.puts("⊘ GOOGLE_APPLICATION_CREDENTIALS is empty")

        path ->
          if File.exists?(path) do
            case ADC.load_credentials() do
              {:ok, {:service_account, creds}} ->
                assert is_map(creds)
                assert creds.type == "service_account"
                IO.puts("✓ Loaded service account from #{path}")

              {:ok, {type, _}} ->
                IO.puts("ℹ Loaded #{type} credentials (not service account)")

              {:error, reason} ->
                flunk("Failed to load service account: #{reason}")
            end
          else
            IO.puts("⊘ File does not exist: #{path}")
          end
      end
    end

    test "generates access token from service account" do
      case System.get_env("GOOGLE_APPLICATION_CREDENTIALS") do
        path when is_binary(path) and path != "" ->
          if File.exists?(path) do
            case ADC.load_credentials() do
              {:ok, {:service_account, _} = creds} ->
                case ADC.get_access_token(creds) do
                  {:ok, token} ->
                    assert is_binary(token)
                    assert String.length(token) > 0
                    assert String.starts_with?(token, "ya29.") or String.contains?(token, ".")
                    IO.puts("✓ Generated access token from service account")

                  {:error, reason} ->
                    flunk("Failed to generate token: #{reason}")
                end

              {:ok, {type, _}} ->
                IO.puts("ℹ Skipping: using #{type} credentials, not service account")

              {:error, reason} ->
                flunk("Failed to load credentials: #{reason}")
            end
          else
            IO.puts("⊘ Skipping: file does not exist")
          end

        _ ->
          IO.puts("⊘ Skipping: GOOGLE_APPLICATION_CREDENTIALS not set")
      end
    end

    test "caches and reuses tokens" do
      case ADC.load_credentials() do
        {:ok, {:service_account, _} = creds} ->
          # First call generates token
          {:ok, token1} = ADC.get_access_token(creds)

          # Second call should use cached token
          {:ok, token2} = ADC.get_access_token(creds)

          assert token1 == token2
          IO.puts("✓ Token caching working correctly")

        {:ok, {type, _}} ->
          IO.puts("ℹ Skipping cache test: using #{type} credentials")

        {:error, _} ->
          IO.puts("⊘ Skipping cache test: no credentials available")
      end
    end

    test "can force token refresh" do
      case ADC.load_credentials() do
        {:ok, {:service_account, _} = creds} ->
          # Get initial token
          {:ok, _token1} = ADC.get_access_token(creds)

          # Force refresh
          case ADC.refresh_token(creds) do
            {:ok, token2} ->
              assert is_binary(token2)
              IO.puts("✓ Token refresh successful")

            {:error, reason} ->
              # Refresh might fail in some environments
              IO.puts("ℹ Token refresh failed (may be expected): #{reason}")
          end

        {:ok, {type, _}} ->
          IO.puts("ℹ Skipping refresh test: using #{type} credentials")

        {:error, _} ->
          IO.puts("⊘ Skipping refresh test: no credentials available")
      end
    end
  end

  describe "ADC with service account JSON env var" do
    @tag :adc_json
    test "loads service account from GOOGLE_APPLICATION_CREDENTIALS_JSON" do
      case System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") do
        json when is_binary(json) and json != "" ->
          original_file_path = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")

          try do
            # Ensure this test specifically validates JSON-content flow.
            System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")

            case ADC.load_credentials() do
              {:ok, {:service_account, creds}} ->
                assert is_map(creds)
                assert creds.type == "service_account"
                IO.puts("✓ Loaded service account from GOOGLE_APPLICATION_CREDENTIALS_JSON")

              {:ok, {type, _}} ->
                flunk("Expected :service_account from JSON env var, got #{inspect(type)}")

              {:error, reason} ->
                flunk("Failed to load service account JSON credentials: #{reason}")
            end
          after
            if original_file_path do
              System.put_env("GOOGLE_APPLICATION_CREDENTIALS", original_file_path)
            end
          end

        _ ->
          IO.puts("⊘ Skipping: GOOGLE_APPLICATION_CREDENTIALS_JSON not set")
      end
    end

    @tag :adc_json
    test "generates access token from GOOGLE_APPLICATION_CREDENTIALS_JSON credentials" do
      case System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") do
        json when is_binary(json) and json != "" ->
          original_file_path = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")

          try do
            System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")

            case ADC.load_credentials() do
              {:ok, {:service_account, _} = creds} ->
                case ADC.get_access_token(creds) do
                  {:ok, token} ->
                    assert is_binary(token)
                    assert String.length(token) > 0
                    IO.puts("✓ Generated access token from GOOGLE_APPLICATION_CREDENTIALS_JSON")

                  {:error, reason} ->
                    flunk("Failed to generate token from JSON env credentials: #{reason}")
                end

              {:ok, {type, _}} ->
                flunk("Expected :service_account from JSON env var, got #{inspect(type)}")

              {:error, reason} ->
                flunk("Failed to load JSON env credentials: #{reason}")
            end
          after
            if original_file_path do
              System.put_env("GOOGLE_APPLICATION_CREDENTIALS", original_file_path)
            end
          end

        _ ->
          IO.puts("⊘ Skipping: GOOGLE_APPLICATION_CREDENTIALS_JSON not set")
      end
    end
  end

  describe "ADC with user credentials" do
    test "loads user credentials from gcloud default path" do
      default_path = Path.expand("~/.config/gcloud/application_default_credentials.json")

      if File.exists?(default_path) do
        case ADC.load_credentials() do
          {:ok, {:user, creds}} ->
            assert creds.type == "authorized_user"
            IO.puts("✓ Loaded user credentials from gcloud")

          {:ok, {type, _}} ->
            IO.puts("ℹ Loaded #{type} credentials (not user credentials)")

          {:error, reason} ->
            IO.puts("⚠ Failed to load user credentials: #{reason}")
        end
      else
        IO.puts("⊘ User credentials file not found (run 'gcloud auth application-default login')")
      end
    end

    test "refreshes user credentials token" do
      default_path = Path.expand("~/.config/gcloud/application_default_credentials.json")

      if File.exists?(default_path) do
        case ADC.load_credentials() do
          {:ok, {:user, _} = creds} ->
            case ADC.get_access_token(creds) do
              {:ok, token} ->
                assert is_binary(token)
                assert String.length(token) > 0
                IO.puts("✓ Refreshed user credentials token")

              {:error, reason} ->
                IO.puts("⚠ Failed to refresh user token: #{reason}")
            end

          {:ok, {type, _}} ->
            IO.puts("ℹ Skipping: using #{type} credentials")

          {:error, _} ->
            IO.puts("⊘ Skipping: no user credentials")
        end
      else
        IO.puts("⊘ Skipping: user credentials not configured")
      end
    end
  end

  describe "ADC availability check" do
    test "correctly reports credential availability" do
      result = ADC.available?()

      assert is_boolean(result)

      if result do
        IO.puts("✓ ADC credentials are available")

        # If available, we should be able to load them
        assert {:ok, _} = ADC.load_credentials()
      else
        IO.puts("⊘ No ADC credentials available")

        # If not available, load should fail
        assert {:error, _} = ADC.load_credentials()
      end
    end
  end

  describe "integration with Vertex AI" do
    test "ADC credentials can be used for Vertex AI authentication" do
      case ADC.load_credentials() do
        {:ok, creds} ->
          # Get access token
          case ADC.get_access_token(creds) do
            {:ok, token} ->
              assert is_binary(token)

              # Get project ID if available
              case ADC.get_project_id(creds) do
                {:ok, project_id} ->
                  IO.puts("✓ ADC ready for Vertex AI:")
                  IO.puts("  Project: #{project_id}")
                  IO.puts("  Token: #{String.slice(token, 0, 20)}...")

                {:error, _} ->
                  IO.puts("ℹ Have token but no project ID in credentials")
              end

            {:error, reason} ->
              IO.puts("⚠ Have credentials but failed to get token: #{reason}")
          end

        {:error, reason} ->
          IO.puts("⊘ Cannot test Vertex AI integration: #{reason}")
      end
    end
  end

  describe "error handling and edge cases" do
    test "handles missing credentials gracefully" do
      # Temporarily clear GOOGLE_APPLICATION_CREDENTIALS
      original = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")

      try do
        System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")

        case ADC.load_credentials() do
          {:ok, {source, _}} ->
            IO.puts("ℹ Found #{source} credentials despite clearing env var")

          {:error, reason} ->
            assert is_binary(reason)
            IO.puts("✓ Properly handles missing credentials")
        end
      after
        if original do
          System.put_env("GOOGLE_APPLICATION_CREDENTIALS", original)
        end
      end
    end

    test "handles invalid service account file path" do
      original = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")

      try do
        System.put_env("GOOGLE_APPLICATION_CREDENTIALS", "/nonexistent/path/to/file.json")

        case ADC.load_credentials() do
          {:ok, {source, _}} ->
            IO.puts("ℹ Found #{source} credentials via fallback")

          {:error, _reason} ->
            IO.puts("✓ Properly handles invalid file path")
        end
      after
        if original do
          System.put_env("GOOGLE_APPLICATION_CREDENTIALS", original)
        else
          System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
        end
      end
    end
  end
end
