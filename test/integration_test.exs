defmodule Gemini.IntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :live_api
  @moduletag timeout: 120_000

  alias Gemini.Types.Content

  import Gemini.Test.ModelHelpers

  setup_all do
    {:ok, %{has_auth: auth_available?()}}
  end

  describe "Models API" do
    # Note: Models API (list_models, get_model) only works with Gemini API, not Vertex AI
    test "lists available models", %{has_auth: _has_auth} do
      if gemini_api_available?() do
        {:ok, response} = Gemini.list_models()

        assert is_list(response.models)
        assert length(response.models) > 0

        # Check that we have common models
        model_names = Enum.map(response.models, & &1.name)
        assert Enum.any?(model_names, &String.contains?(&1, "gemini"))
      else
        IO.puts("Skipping Models API test - requires GEMINI_API_KEY (not supported on Vertex AI)")
        assert true
      end
    end

    test "gets specific model information", %{has_auth: _has_auth} do
      if gemini_api_available?() do
        {:ok, model} = Gemini.get_model(default_model())

        assert model.name =~ default_model()
        assert is_binary(model.display_name)
        assert is_integer(model.input_token_limit)
        assert model.input_token_limit > 0
      else
        IO.puts("Skipping Models API test - requires GEMINI_API_KEY (not supported on Vertex AI)")
        assert true
      end
    end

    test "checks model existence", %{has_auth: _has_auth} do
      if gemini_api_available?() do
        {:ok, exists} = Gemini.model_exists?(default_model())
        assert exists == true

        {:ok, exists} = Gemini.model_exists?("non-existent-model-12345")
        assert exists == false
      else
        IO.puts("Skipping Models API test - requires GEMINI_API_KEY (not supported on Vertex AI)")
        assert true
      end
    end
  end

  describe "Content Generation" do
    test "generates simple text", %{has_auth: has_auth} do
      if has_auth do
        {:ok, text} = Gemini.text("Say hello")

        assert is_binary(text)
        assert String.length(text) > 0
        assert String.downcase(text) =~ "hello"
      else
        IO.puts("Skipping integration test - no API key configured")
        assert true
      end
    end

    test "generates content with response details", %{has_auth: has_auth} do
      if has_auth do
        {:ok, response} = Gemini.generate("What is 2+2?")

        assert length(response.candidates) > 0

        candidate = List.first(response.candidates)
        assert candidate.content != nil
        assert length(candidate.content.parts) > 0

        {:ok, text} = Gemini.extract_text(response)
        assert text =~ "4"
      else
        IO.puts("Skipping integration test - no API key configured")
        assert true
      end
    end

    test "counts tokens", %{has_auth: has_auth} do
      if has_auth do
        {:ok, count_response} = Gemini.count_tokens("This is a test message for token counting.")

        assert is_integer(count_response.total_tokens)
        assert count_response.total_tokens > 0
      else
        IO.puts("Skipping integration test - no API key configured")
        assert true
      end
    end

    test "generates with configuration", %{has_auth: has_auth} do
      if has_auth do
        alias Gemini.Types.GenerationConfig

        config = GenerationConfig.precise(max_output_tokens: 50)
        {:ok, text} = Gemini.text("Write one sentence about cats", generation_config: config)

        assert is_binary(text)
        assert String.length(text) > 0
      else
        IO.puts("Skipping integration test - no API key configured")
        assert true
      end
    end
  end

  describe "Chat Sessions" do
    test "maintains conversation context", %{has_auth: has_auth} do
      if has_auth do
        {:ok, chat} = Gemini.chat()

        # First message
        {:ok, response1, chat} = Gemini.send_message(chat, "My name is Alice. Remember this.")
        {:ok, text1} = Gemini.extract_text(response1)
        assert is_binary(text1)

        # Second message referencing the first
        {:ok, response2, _chat} = Gemini.send_message(chat, "What is my name?")
        {:ok, text2} = Gemini.extract_text(response2)
        assert String.downcase(text2) =~ "alice"
      else
        IO.puts("Skipping integration test - no API key configured")
        assert true
      end
    end
  end

  describe "Error Handling" do
    test "handles invalid model gracefully", %{has_auth: has_auth} do
      if has_auth do
        {:error, error} = Gemini.text("Hello", model: "invalid-model-name-12345")

        assert %Gemini.Error{} = error
        assert error.type in [:api_error, :http_error]
      else
        IO.puts("Skipping integration test - no API key configured")
        assert true
      end
    end
  end

  # This test requires an actual image file - skip if not available
  describe "Multimodal Content" do
    @tag :skip
    test "processes image content" do
      # Create a small test image file
      image_path = "/tmp/test_image.png"

      # This would require creating an actual image file
      # For now, we'll skip this test
      contents = [
        Content.text("What color is this?"),
        Content.image(image_path)
      ]

      {:ok, response} = Gemini.generate(contents)
      {:ok, text} = Gemini.extract_text(response)

      assert is_binary(text)
    end
  end

  # auth_available?/0 and gemini_api_available?/0 are imported from ModelHelpers
end
