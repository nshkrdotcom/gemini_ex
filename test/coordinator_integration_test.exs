defmodule CoordinatorIntegrationTest do
  use ExUnit.Case, async: false

  alias Gemini.APIs.Coordinator

  import Gemini.Test.ModelHelpers

  @moduletag :live_api

  describe "Text generation with real API" do
    test "generate_content works and extract_text succeeds" do
      # Works with either Gemini API or Vertex AI
      if auth_available?() do
        prompt = "Say 'Hello World' exactly"

        # Test the full flow that was previously failing
        case Coordinator.generate_content(prompt) do
          {:ok, response} ->
            IO.puts("✅ generate_content succeeded")
            IO.puts("Response type: #{inspect(response.__struct__)}")

            # This was the failing part - extract_text should now work
            case Coordinator.extract_text(response) do
              {:ok, text} ->
                IO.puts("✅ extract_text succeeded: '#{text}'")
                assert String.contains?(text, "Hello")

              {:error, reason} ->
                flunk("extract_text failed: #{inspect(reason)}")
            end

          {:error, reason} ->
            flunk("generate_content failed: #{inspect(reason)}")
        end
      else
        IO.puts("Skipping live API test - no auth configured")
      end
    end

    test "list_models works and returns models" do
      # list_models only works with Gemini API, not Vertex AI
      if gemini_api_available?() do
        case Coordinator.list_models() do
          {:ok, response} ->
            IO.puts("✅ list_models succeeded")
            IO.puts("Response type: #{inspect(response.__struct__)}")
            assert is_struct(response)

          {:error, reason} ->
            flunk("list_models failed: #{inspect(reason)}")
        end
      else
        IO.puts(
          "Skipping list_models test - requires GEMINI_API_KEY (not supported on Vertex AI)"
        )
      end
    end
  end
end
