defmodule Gemini.ConfigTest do
  use ExUnit.Case, async: false

  alias Gemini.Config

  setup do
    # Save original environment variables
    original_gemini_key = System.get_env("GEMINI_API_KEY")
    original_project = System.get_env("GOOGLE_CLOUD_PROJECT")
    original_location = System.get_env("GOOGLE_CLOUD_LOCATION")

    on_exit(fn ->
      # Restore original environment variables
      if original_gemini_key do
        System.put_env("GEMINI_API_KEY", original_gemini_key)
      else
        System.delete_env("GEMINI_API_KEY")
      end

      if original_project do
        System.put_env("GOOGLE_CLOUD_PROJECT", original_project)
      else
        System.delete_env("GOOGLE_CLOUD_PROJECT")
      end

      if original_location do
        System.put_env("GOOGLE_CLOUD_LOCATION", original_location)
      else
        System.delete_env("GOOGLE_CLOUD_LOCATION")
      end
    end)

    %{
      original_gemini_key: original_gemini_key,
      original_project: original_project,
      original_location: original_location
    }
  end

  describe "get/0" do
    test "returns default gemini configuration when no environment variables set" do
      # Clear any existing environment variables for this test
      System.delete_env("GEMINI_API_KEY")
      System.delete_env("GOOGLE_CLOUD_PROJECT")
      System.delete_env("GOOGLE_CLOUD_LOCATION")

      config = Config.get()

      assert config.auth_type == :gemini
      assert config.api_key == nil
      assert config.model == "gemini-flash-lite-latest"
    end

    test "detects gemini auth type when GEMINI_API_KEY is set" do
      System.put_env("GEMINI_API_KEY", "test-key")
      System.delete_env("GOOGLE_CLOUD_PROJECT")

      config = Config.get()

      assert config.auth_type == :gemini
      assert config.api_key == "test-key"

      # Cleanup
      System.delete_env("GEMINI_API_KEY")
    end

    test "detects vertex auth type when GOOGLE_CLOUD_PROJECT is set" do
      System.delete_env("GEMINI_API_KEY")
      System.put_env("GOOGLE_CLOUD_PROJECT", "test-project")
      System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")

      config = Config.get()

      assert config.auth_type == :vertex
      assert config.project_id == "test-project"
      assert config.location == "us-central1"

      # Cleanup
      System.delete_env("GOOGLE_CLOUD_PROJECT")
      System.delete_env("GOOGLE_CLOUD_LOCATION")
    end

    test "gemini takes priority when both auth types are available" do
      System.put_env("GEMINI_API_KEY", "test-key")
      System.put_env("GOOGLE_CLOUD_PROJECT", "test-project")
      System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")

      config = Config.get()

      assert config.auth_type == :gemini
      assert config.api_key == "test-key"

      # Cleanup
      System.delete_env("GEMINI_API_KEY")
      System.delete_env("GOOGLE_CLOUD_PROJECT")
      System.delete_env("GOOGLE_CLOUD_LOCATION")
    end
  end

  describe "get/1" do
    test "allows overriding auth_type" do
      System.put_env("GEMINI_API_KEY", "test-key")

      config =
        Config.get(auth_type: :vertex, project_id: "override-project", location: "us-west1")

      assert config.auth_type == :vertex
      assert config.project_id == "override-project"
      assert config.location == "us-west1"

      # Cleanup
      System.delete_env("GEMINI_API_KEY")
    end

    test "allows overriding specific fields while keeping detection" do
      System.put_env("GEMINI_API_KEY", "test-key")

      config = Config.get(model: "gemini-flash-lite-latest")

      assert config.auth_type == :gemini
      assert config.api_key == "test-key"
      assert config.model == "gemini-flash-lite-latest"

      # Cleanup
      System.delete_env("GEMINI_API_KEY")
    end
  end

  describe "default_model/0" do
    test "returns default model" do
      assert Config.default_model() == "gemini-flash-lite-latest"
    end
  end

  describe "detect_auth_type/1" do
    test "returns :gemini when api_key is present" do
      config = %{api_key: "test-key"}
      assert Config.detect_auth_type(config) == :gemini
    end

    test "returns :vertex when project_id is present" do
      config = %{project_id: "test-project"}
      assert Config.detect_auth_type(config) == :vertex
    end

    test "returns :gemini when both are present (gemini priority)" do
      config = %{api_key: "test-key", project_id: "test-project"}
      assert Config.detect_auth_type(config) == :gemini
    end

    test "returns :gemini as default when neither is present" do
      config = %{}
      assert Config.detect_auth_type(config) == :gemini
    end
  end
end
