defmodule Gemini.APIs.TokensEstimationTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Tokens
  alias Gemini.Types.Content

  @moduletag :tokens_estimation

  # ADR-0001: Token estimation tests
  describe "Tokens.estimate/1" do
    test "estimates tokens for simple text" do
      {:ok, estimate} = Tokens.estimate("Hello, world!")
      assert is_integer(estimate)
      assert estimate > 0
    end

    test "estimates tokens for longer text" do
      text = String.duplicate("This is a test sentence. ", 100)
      {:ok, estimate} = Tokens.estimate(text)
      assert estimate > 100
    end

    test "estimates tokens for Content struct list" do
      contents = [
        %Content{
          role: "user",
          parts: [%{text: "Hello, this is a test message"}]
        }
      ]

      {:ok, estimate} = Tokens.estimate(contents)
      assert is_integer(estimate)
      assert estimate > 0
    end

    test "handles empty string" do
      {:ok, estimate} = Tokens.estimate("")
      assert estimate == 0
    end

    # ADR-0001: Safe handling of API maps
    test "handles API map with :contents key" do
      api_map = %{
        contents: [
          %{
            role: "user",
            parts: [%{text: "Hello world"}]
          }
        ]
      }

      {:ok, estimate} = Tokens.estimate(api_map)
      assert is_integer(estimate)
      assert estimate > 0
    end

    test "handles API map with string \"contents\" key" do
      api_map = %{
        "contents" => [
          %{
            "role" => "user",
            "parts" => [%{"text" => "Hello world"}]
          }
        ]
      }

      {:ok, estimate} = Tokens.estimate(api_map)
      assert is_integer(estimate)
      assert estimate > 0
    end

    test "returns 0 for unknown map shape (safe fallback)" do
      unknown_map = %{unknown_key: "value"}
      {:ok, estimate} = Tokens.estimate(unknown_map)
      assert estimate == 0
    end

    test "handles inline_data in API map format" do
      api_map = %{
        contents: [
          %{
            parts: [
              %{text: "What's in this image?"},
              %{inline_data: %{mime_type: "image/jpeg", data: "base64data"}}
            ]
          }
        ]
      }

      {:ok, estimate} = Tokens.estimate(api_map)
      # Should include estimate for both text and image
      assert estimate >= 200
    end

    test "handles inlineData (camelCase) in API map format" do
      api_map = %{
        "contents" => [
          %{
            "parts" => [
              %{"text" => "What's in this image?"},
              %{"inlineData" => %{"mimeType" => "image/jpeg", "data" => "base64data"}}
            ]
          }
        ]
      }

      {:ok, estimate} = Tokens.estimate(api_map)
      # Should include estimate for both text and image
      assert estimate >= 200
    end

    test "does not raise on malformed input" do
      # These should all return {:ok, _} without raising
      assert {:ok, _} = Tokens.estimate(%{})
      assert {:ok, _} = Tokens.estimate(%{contents: nil})
      assert {:ok, _} = Tokens.estimate(%{contents: "not a list"})
    end
  end

  describe "Token estimation accuracy" do
    test "rough estimate for typical prompt sizes" do
      # ~1.3 tokens per word is the heuristic
      short_text = "What is the capital of France?"
      {:ok, short_estimate} = Tokens.estimate(short_text)
      # 6 words * 1.3 ~= 8 tokens
      assert short_estimate >= 6 and short_estimate <= 20

      long_text = String.duplicate("The quick brown fox jumps over the lazy dog. ", 50)
      {:ok, long_estimate} = Tokens.estimate(long_text)
      # 450 words * 1.3 ~= 585 tokens
      assert long_estimate >= 400 and long_estimate <= 800
    end
  end
end
