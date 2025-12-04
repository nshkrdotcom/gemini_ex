defmodule Gemini.IntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :live_api

  describe "Models API" do
    test "lists available models" do
      {:ok, response} = Gemini.list_models()

      assert is_list(response.models)
      assert length(response.models) > 0

      # Check that we have common models
      model_names = Enum.map(response.models, & &1.name)
      assert Enum.any?(model_names, &String.contains?(&1, "gemini"))
    end

    test "gets specific model information" do
      {:ok, model} = Gemini.get_model("gemini-flash-lite-latest")

      assert model.name =~ "gemini-flash-lite-latest"
      assert is_binary(model.display_name)
      assert is_integer(model.input_token_limit)
      assert model.input_token_limit > 0
    end

    test "checks model existence" do
      {:ok, exists} = Gemini.model_exists?("gemini-flash-lite-latest")
      assert exists == true

      {:ok, exists} = Gemini.model_exists?("non-existent-model-12345")
      assert exists == false
    end
  end

  describe "Content Generation" do
    test "generates simple text" do
      {:ok, text} = Gemini.text("Say hello")

      assert is_binary(text)
      assert String.length(text) > 0
      assert String.downcase(text) =~ "hello"
    end

    test "generates content with response details" do
      {:ok, response} = Gemini.generate("What is 2+2?")

      assert length(response.candidates) > 0

      candidate = List.first(response.candidates)
      assert candidate.content != nil
      assert length(candidate.content.parts) > 0

      {:ok, text} = Gemini.extract_text(response)
      assert text =~ "4"
    end

    test "counts tokens" do
      {:ok, count_response} = Gemini.count_tokens("This is a test message for token counting.")

      assert is_integer(count_response.total_tokens)
      assert count_response.total_tokens > 0
    end

    test "generates with configuration" do
      alias Gemini.Types.GenerationConfig

      config = GenerationConfig.precise(max_output_tokens: 50)
      {:ok, text} = Gemini.text("Write one sentence about cats", generation_config: config)

      assert is_binary(text)
      assert String.length(text) > 0
    end
  end

  describe "Chat Sessions" do
    test "maintains conversation context" do
      {:ok, chat} = Gemini.chat()

      # First message
      {:ok, response1, chat} = Gemini.send_message(chat, "My name is Alice. Remember this.")
      {:ok, text1} = Gemini.extract_text(response1)
      assert is_binary(text1)

      # Second message referencing the first
      {:ok, response2, _chat} = Gemini.send_message(chat, "What is my name?")
      {:ok, text2} = Gemini.extract_text(response2)
      assert String.downcase(text2) =~ "alice"
    end
  end

  describe "Error Handling" do
    test "handles invalid model gracefully" do
      {:error, error} = Gemini.text("Hello", model: "invalid-model-name-12345")

      assert %Gemini.Error{} = error
      assert error.type in [:api_error, :http_error]
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
        Gemini.Types.Content.text("What color is this?"),
        Gemini.Types.Content.image(image_path)
      ]

      {:ok, response} = Gemini.generate(contents)
      {:ok, text} = Gemini.extract_text(response)

      assert is_binary(text)
    end
  end
end
