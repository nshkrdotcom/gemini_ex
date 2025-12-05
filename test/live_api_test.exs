defmodule LiveAPITest do
  use ExUnit.Case

  @moduletag :live_api
  @moduletag timeout: 30_000

  @moduledoc """
  Live API tests for Gemini library with both authentication methods and streaming.
  Run with: mix test test/live_api_test.exs --include live_api
  """

  require Logger

  import Gemini.Test.ModelHelpers

  defp mask_api_key(key) when is_binary(key) and byte_size(key) > 2 do
    first_two = String.slice(key, 0, 2)
    "#{first_two}***"
  end

  defp mask_api_key(_), do: "***"

  setup_all do
    Application.ensure_all_started(:gemini)
    {:ok, %{has_auth: auth_available?()}}
  end

  describe "Configuration Detection" do
    test "detects available authentication", %{has_auth: has_auth} do
      IO.puts("\n📋 Testing Configuration Detection")
      IO.puts("-" |> String.duplicate(40))

      auth_config = Gemini.Config.auth_config()
      auth_type = Gemini.Config.detect_auth_type()
      IO.puts("Detected auth type: #{auth_type}")

      default_model = Gemini.Config.default_model()
      IO.puts("Default model: #{default_model}")

      if has_auth do
        assert auth_config != nil
      else
        IO.puts("❌ No auth configured; skipping config assertion")
        assert true
      end
    end
  end

  describe "Gemini API Authentication" do
    test "gemini api text generation" do
      IO.puts("\n🔑 Testing Gemini API Authentication")
      IO.puts("-" |> String.duplicate(40))

      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        Gemini.configure(:gemini, %{api_key: api_key})
        IO.puts("Configured Gemini API with key: #{mask_api_key(api_key)}")

        IO.puts("\n  📝 Testing simple text generation with Gemini API")

        case Gemini.generate("What is the capital of France? Give a brief answer.") do
          {:ok, response} ->
            case Gemini.extract_text(response) do
              {:ok, text} ->
                IO.puts("  ✅ Success: #{String.slice(text, 0, 100)}...")
                assert String.contains?(String.downcase(text), "paris")

              {:error, error} ->
                IO.puts("  ❌ Text extraction failed: #{error}")
                flunk("Text extraction failed: #{error}")
            end

          {:error, error} ->
            IO.puts("  ❌ Generation failed: #{inspect(error)}")
            flunk("Generation failed: #{inspect(error)}")
        end
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping Gemini auth tests")
      end
    end

    test "gemini api model listing" do
      IO.puts("\n  📝 Testing model listing with Gemini API")
      IO.puts("-" |> String.duplicate(40))

      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        Gemini.configure(:gemini, %{api_key: api_key})

        case Gemini.list_models() do
          {:ok, response} ->
            IO.puts("  ✅ Found #{length(response.models)} models")
            assert length(response.models) > 0

          {:error, error} ->
            IO.puts("  ❌ List models failed: #{inspect(error)}")
            flunk("List models failed: #{inspect(error)}")
        end
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping model listing")
      end
    end
  end
end
