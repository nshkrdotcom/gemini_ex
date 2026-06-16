defmodule Gemini.AuthTest do
  use ExUnit.Case, async: true

  alias Gemini.Auth
  alias Gemini.Auth.{GeminiStrategy, VertexStrategy}

  describe "get_strategy/1" do
    test "returns GeminiStrategy for :gemini auth type" do
      assert Auth.get_strategy(:gemini) == GeminiStrategy
    end

    test "returns VertexStrategy for :vertex auth type" do
      assert Auth.get_strategy(:vertex) == VertexStrategy
    end

    test "raises error for unknown auth type" do
      assert_raise ArgumentError, "Unknown authentication type: :invalid", fn ->
        Auth.get_strategy(:invalid)
      end
    end
  end

  describe "build_headers/2" do
    test "delegates to strategy headers/1 for gemini" do
      credentials = %{api_key: "test-key"}

      assert {:ok, headers} = Auth.build_headers(:gemini, credentials)
      assert is_list(headers)
      assert {"x-goog-api-key", "test-key"} in headers
    end

    test "returns error when credentials are invalid" do
      credentials = %{}

      assert {:error, _} = Auth.build_headers(:gemini, credentials)
    end
  end

  describe "get_base_url/2" do
    test "delegates to strategy base_url/1" do
      credentials = %{}

      assert Auth.get_base_url(:gemini, credentials) ==
               "https://generativelanguage.googleapis.com/v1beta"
    end
  end
end
