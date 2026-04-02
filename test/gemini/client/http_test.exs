defmodule Gemini.Client.HTTPTest do
  use ExUnit.Case, async: false

  alias Gemini.Client.HTTP

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

  @app_env_keys [
    {:gemini, :auth},
    {:gemini, :api_key},
    {:gemini_ex, :auth},
    {:gemini_ex, :api_key}
  ]

  setup do
    original_env = Enum.map(@env_vars, fn key -> {key, System.get_env(key)} end)

    original_app_env =
      Enum.map(@app_env_keys, fn {app, key} -> {app, key, Application.get_env(app, key)} end)

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@app_env_keys, fn {app, key} -> Application.delete_env(app, key) end)

    on_exit(fn ->
      Enum.each(original_env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      Enum.each(original_app_env, fn
        {app, key, nil} -> Application.delete_env(app, key)
        {app, key, value} -> Application.put_env(app, key, value)
      end)
    end)

    :ok
  end

  describe "auth_config_for_request/1" do
    test "honors auth: :vertex_ai even when gemini key is present" do
      System.put_env("GEMINI_API_KEY", "gemini-key")
      System.put_env("VERTEX_PROJECT_ID", "vertex-proj")
      System.put_env("VERTEX_LOCATION", "us-central1")
      System.put_env("VERTEX_ACCESS_TOKEN", "vertex-token")

      auth_config = HTTP.auth_config_for_request(auth: :vertex_ai)

      assert auth_config.type == :vertex_ai
      assert auth_config.credentials.project_id == "vertex-proj"
      assert auth_config.credentials.location == "us-central1"
      assert auth_config.credentials.access_token == "vertex-token"
    end

    test "supports auth: :vertex alias" do
      System.put_env("VERTEX_PROJECT_ID", "vertex-proj")
      System.put_env("VERTEX_LOCATION", "us-central1")
      System.put_env("VERTEX_ACCESS_TOKEN", "vertex-token")

      auth_config = HTTP.auth_config_for_request(auth: :vertex)

      assert auth_config.type == :vertex_ai
      assert auth_config.credentials.project_id == "vertex-proj"
    end

    test "applies per-request gemini api_key override" do
      System.put_env("GEMINI_API_KEY", "env-key")

      auth_config = HTTP.auth_config_for_request(auth: :gemini, api_key: "override-key")

      assert auth_config.type == :gemini
      assert auth_config.credentials.api_key == "override-key"
    end

    test "infers gemini auth when only api_key override is provided" do
      System.put_env("VERTEX_PROJECT_ID", "vertex-proj")
      System.put_env("VERTEX_LOCATION", "us-central1")
      System.put_env("VERTEX_ACCESS_TOKEN", "vertex-token")

      auth_config = HTTP.auth_config_for_request(api_key: "override-key")

      assert auth_config.type == :gemini
      assert auth_config.credentials.api_key == "override-key"
    end

    test "applies per-request vertex overrides" do
      System.put_env("VERTEX_PROJECT_ID", "env-proj")
      System.put_env("VERTEX_LOCATION", "us-central1")
      System.put_env("VERTEX_ACCESS_TOKEN", "env-token")

      auth_config =
        HTTP.auth_config_for_request(
          auth: :vertex_ai,
          project_id: "override-proj",
          location: "europe-west4",
          access_token: "override-token",
          quota_project_id: "billing-proj"
        )

      assert auth_config.type == :vertex_ai
      assert auth_config.credentials.project_id == "override-proj"
      assert auth_config.credentials.location == "europe-west4"
      assert auth_config.credentials.access_token == "override-token"
      assert auth_config.credentials.quota_project_id == "billing-proj"
    end

    test "infers vertex auth when only a vertex override is provided" do
      System.put_env("GEMINI_API_KEY", "gemini-key")

      auth_config = HTTP.auth_config_for_request(project_id: "override-proj")

      assert auth_config.type == :vertex_ai
      assert auth_config.credentials.project_id == "override-proj"
    end
  end
end
