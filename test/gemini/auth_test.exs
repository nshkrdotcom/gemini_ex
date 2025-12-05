defmodule Gemini.AuthTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth
  alias Gemini.Auth.{GeminiStrategy, VertexStrategy}

  describe "strategy/1" do
    test "returns GeminiStrategy for :gemini auth type" do
      assert Auth.strategy(:gemini) == GeminiStrategy
    end

    test "returns VertexStrategy for :vertex auth type" do
      assert Auth.strategy(:vertex) == VertexStrategy
    end

    test "raises error for unsupported auth type" do
      assert_raise ArgumentError, "Unsupported auth type: :invalid", fn ->
        Auth.strategy(:invalid)
      end
    end
  end

  describe "authenticate/2" do
    test "delegates to strategy authenticate/1" do
      config = %{auth_type: :gemini, api_key: "test-key"}

      assert {:ok, headers} = Auth.authenticate(GeminiStrategy, config)
      assert is_list(headers)
      assert {"x-goog-api-key", "test-key"} in headers
    end

    test "returns error when strategy authentication fails" do
      # missing api_key
      config = %{auth_type: :gemini}

      assert {:error, _} = Auth.authenticate(GeminiStrategy, config)
    end
  end

  describe "base_url/2" do
    test "delegates to strategy base_url/1" do
      config = %{auth_type: :gemini}

      assert Auth.base_url(GeminiStrategy, config) ==
               "https://generativelanguage.googleapis.com/v1beta"
    end
  end
end
