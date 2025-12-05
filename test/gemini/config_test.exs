defmodule Gemini.ConfigTest do
  use ExUnit.Case, async: false

  alias Gemini.Config

  import Gemini.Test.ModelHelpers

  # All environment variables that Config reads from
  @env_vars ~w(
    GEMINI_API_KEY
    GOOGLE_CLOUD_PROJECT
    GOOGLE_CLOUD_LOCATION
    VERTEX_PROJECT_ID
    VERTEX_LOCATION
    VERTEX_ACCESS_TOKEN
    VERTEX_SERVICE_ACCOUNT
    VERTEX_JSON_FILE
  )

  setup do
    # Save all original environment variables
    original_env = Enum.map(@env_vars, fn key -> {key, System.get_env(key)} end)

    on_exit(fn ->
      # Restore all original environment variables
      Enum.each(original_env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    %{original_env: original_env}
  end

  # Helper to clear all config-related env vars for isolated tests
  defp clear_all_auth_env_vars do
    Enum.each(@env_vars, &System.delete_env/1)
  end

  describe "get/0" do
    test "returns default gemini configuration when no environment variables set" do
      clear_all_auth_env_vars()

      config = Config.get()

      assert config.auth_type == :gemini
      assert config.api_key == nil
      assert config.model == default_model()
    end

    test "detects gemini auth type when GEMINI_API_KEY is set" do
      clear_all_auth_env_vars()
      System.put_env("GEMINI_API_KEY", "test-key")

      config = Config.get()

      assert config.auth_type == :gemini
      assert config.api_key == "test-key"
    end

    test "detects vertex auth type when GOOGLE_CLOUD_PROJECT is set" do
      clear_all_auth_env_vars()
      System.put_env("GOOGLE_CLOUD_PROJECT", "test-project")
      System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")

      config = Config.get()

      assert config.auth_type == :vertex
      assert config.project_id == "test-project"
      assert config.location == "us-central1"
    end

    test "gemini takes priority when both auth types are available" do
      clear_all_auth_env_vars()
      System.put_env("GEMINI_API_KEY", "test-key")
      System.put_env("GOOGLE_CLOUD_PROJECT", "test-project")
      System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")

      config = Config.get()

      assert config.auth_type == :gemini
      assert config.api_key == "test-key"
    end
  end

  describe "get/1" do
    test "allows overriding auth_type" do
      clear_all_auth_env_vars()
      System.put_env("GEMINI_API_KEY", "test-key")

      config =
        Config.get(auth_type: :vertex, project_id: "override-project", location: "us-west1")

      assert config.auth_type == :vertex
      assert config.project_id == "override-project"
      assert config.location == "us-west1"
    end

    test "allows overriding specific fields while keeping detection" do
      clear_all_auth_env_vars()
      System.put_env("GEMINI_API_KEY", "test-key")

      config = Config.get(model: default_model())

      assert config.auth_type == :gemini
      assert config.api_key == "test-key"
      assert config.model == default_model()
    end
  end

  describe "default_model/0" do
    test "returns default model" do
      assert Config.default_model() == default_model()
    end
  end

  describe "auth_config/0" do
    test "uses runtime configure env stored under :gemini app" do
      original_env =
        Enum.map(
          ~w(GEMINI_API_KEY GOOGLE_CLOUD_PROJECT GOOGLE_CLOUD_LOCATION VERTEX_SERVICE_ACCOUNT VERTEX_JSON_FILE VERTEX_ACCESS_TOKEN VERTEX_PROJECT_ID VERTEX_LOCATION),
          fn key -> {key, System.get_env(key)} end
        )

      Enum.each(original_env, fn {key, _} -> System.delete_env(key) end)

      Application.put_env(:gemini, :auth, %{type: :gemini, credentials: %{api_key: "runtime-key"}})

      on_exit(fn ->
        Application.delete_env(:gemini, :auth)

        Enum.each(original_env, fn
          {key, nil} -> System.delete_env(key)
          {key, value} -> System.put_env(key, value)
        end)
      end)

      assert %{type: :gemini, credentials: %{api_key: "runtime-key"}} = Config.auth_config()
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
