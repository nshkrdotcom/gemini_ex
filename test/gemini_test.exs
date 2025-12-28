defmodule GeminiTest do
  use ExUnit.Case
  doctest Gemini

  alias Gemini.Types.{Blob, Content, GenerationConfig, Part, SafetySetting}

  describe "content creation" do
    test "creates text content" do
      content = Content.text("Hello, world!")

      assert %Content{
               parts: [%Part{text: "Hello, world!"}],
               role: "user"
             } = content
    end

    test "creates multimodal content" do
      # Test with a temporary file
      temp_path = "/tmp/test_image.txt"
      File.write!(temp_path, "fake image data")

      content = Content.image(temp_path)

      assert %Content{
               parts: [%Part{inline_data: %Blob{}}],
               role: "user"
             } = content

      File.rm!(temp_path)
    end
  end

  describe "generation config" do
    test "creates creative config" do
      config = GenerationConfig.creative()

      assert %GenerationConfig{
               temperature: 0.9,
               top_p: 1.0,
               top_k: 40
             } = config
    end

    test "creates deterministic config" do
      config = GenerationConfig.deterministic()

      assert %GenerationConfig{
               temperature: +0.0,
               candidate_count: 1
             } = config
    end
  end

  describe "safety settings" do
    test "creates default safety settings" do
      settings = SafetySetting.defaults()

      assert length(settings) == 4

      assert Enum.all?(settings, fn setting ->
               setting.threshold == :block_medium_and_above
             end)
    end

    test "creates permissive safety settings" do
      settings = SafetySetting.permissive()

      assert length(settings) == 4

      assert Enum.all?(settings, fn setting ->
               setting.threshold == :block_only_high
             end)
    end
  end

  # These tests require an API key and internet connection
  # Uncomment and set GEMINI_API_KEY to run them

  # describe "API integration" do
  #   @tag :integration
  #   test "lists models" do
  #     {:ok, response} = Gemini.list_models()
  #     assert length(response.models) > 0
  #   end

  #   @tag :integration
  #   test "generates text content" do
  #     {:ok, text} = Gemini.text("Say hello")
  #     assert is_binary(text)
  #     assert String.length(text) > 0
  #   end

  #   @tag :integration
  #   test "counts tokens" do
  #     {:ok, response} = Gemini.count_tokens("Hello, world!")
  #     assert response.total_tokens > 0
  #   end
  # end
end
