defmodule Gemini.Auth.GeminiStrategyTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth.GeminiStrategy

  describe "headers/1" do
    test "returns headers with API key when present" do
      config = %{api_key: "test-api-key-123"}

      assert {:ok, headers} = GeminiStrategy.headers(config)

      assert headers == [
               {"Content-Type", "application/json"},
               {"x-goog-api-key", "test-api-key-123"}
             ]
    end

    test "returns error when API key is missing" do
      config = %{}

      assert {:error, error} = GeminiStrategy.headers(config)
      assert error =~ "API key is missing"
    end

    test "returns error when API key is nil" do
      config = %{api_key: nil}

      assert {:error, error} = GeminiStrategy.headers(config)
      assert error =~ "API key is nil"
    end

    test "returns error when API key is empty string" do
      config = %{api_key: ""}

      assert {:error, error} = GeminiStrategy.headers(config)
      assert error =~ "API key is empty"
    end
  end

  describe "base_url/1" do
    test "returns Gemini API base URL" do
      config = %{}

      assert GeminiStrategy.base_url(config) == "https://generativelanguage.googleapis.com/v1beta"
    end

    test "base URL is consistent regardless of config" do
      config1 = %{api_key: "key1"}
      config2 = %{api_key: "key2", project_id: "project"}

      assert GeminiStrategy.base_url(config1) == GeminiStrategy.base_url(config2)
    end
  end
end
