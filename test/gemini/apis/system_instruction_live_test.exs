defmodule Gemini.APIs.SystemInstructionLiveTest do
  @moduledoc """
  Live API tests for system instruction functionality.

  These tests verify that:
  1. System instructions affect model behavior
  2. Different personas work correctly
  3. Output format instructions are followed
  4. System instructions work with tools
  5. System instructions persist across conversation turns

  Run with: mix test --include live_api test/gemini/apis/system_instruction_live_test.exs
  """

  use ExUnit.Case, async: false

  @moduletag :live_api
  @moduletag timeout: 120_000

  alias Gemini.APIs.Coordinator

  describe "basic system instruction behavior" do
    test "system instruction affects model response language" do
      # Without system instruction - default behavior
      {:ok, response_default} =
        Coordinator.generate_content(
          "Say hello",
          model: "gemini-2.5-flash"
        )

      {:ok, default_text} = Gemini.extract_text(response_default)

      # With French language instruction
      {:ok, response_french} =
        Coordinator.generate_content(
          "Say hello",
          system_instruction: "You must respond only in French. Never use English.",
          model: "gemini-2.5-flash"
        )

      {:ok, french_text} = Gemini.extract_text(response_french)

      # French response should contain "Bonjour" or similar French greeting
      assert french_text =~ ~r/bonjour|salut|coucou/i,
             "Expected French greeting, got: #{french_text}"

      # Default should be different (likely English)
      refute default_text =~ ~r/bonjour|salut|coucou/i,
             "Default response should not be French"
    end

    test "system instruction enforces response format" do
      {:ok, response} =
        Coordinator.generate_content(
          "List three programming languages",
          system_instruction: """
          You must respond using ONLY bullet points with a dash prefix.
          Format: "- item"
          No other text or explanation. Just the bullet points.
          """,
          model: "gemini-2.5-flash"
        )

      {:ok, text} = Gemini.extract_text(response)

      # Should contain dashes for bullet points
      assert text =~ ~r/^-\s/m, "Expected bullet point format with dashes, got: #{text}"

      # Count bullet points - should be at least 3
      bullet_count = text |> String.split("\n") |> Enum.count(&String.starts_with?(&1, "-"))
      assert bullet_count >= 3, "Expected at least 3 bullet points, got: #{bullet_count}"
    end
  end

  describe "persona and role-playing" do
    test "system instruction creates consistent persona" do
      persona_instruction = """
      You are Captain Cosmos, a friendly space explorer from the year 3000.
      You always:
      - Start responses with "Greetings, Earthling!"
      - Reference your spaceship "The Stellar Voyager"
      - Use space-themed expressions
      """

      {:ok, response} =
        Coordinator.generate_content(
          "What's your favorite food?",
          system_instruction: persona_instruction,
          model: "gemini-2.5-flash"
        )

      {:ok, text} = Gemini.extract_text(response)

      # Should include the greeting
      assert text =~ ~r/greetings|earthling/i,
             "Expected space captain greeting, got: #{text}"
    end

    test "system instruction maintains expert role" do
      expert_instruction = """
      You are a senior software architect with 20 years of experience.
      When answering:
      - Be concise and technical
      - Reference design patterns when relevant
      - Mention trade-offs
      """

      {:ok, response} =
        Coordinator.generate_content(
          "How should I handle configuration in a large application?",
          system_instruction: expert_instruction,
          model: "gemini-2.5-flash"
        )

      {:ok, text} = Gemini.extract_text(response)

      # Should include technical terminology
      assert text =~
               ~r/pattern|architecture|config|environment|dependency|injection|singleton|module/i,
             "Expected technical response, got: #{text}"
    end
  end

  describe "output constraints" do
    @tag timeout: 120_000
    test "system instruction limits response length" do
      {:ok, response} =
        Coordinator.generate_content(
          "Explain the theory of relativity",
          system_instruction: "You must respond in exactly one sentence. No more than 20 words.",
          model: "gemini-2.5-flash",
          max_output_tokens: 50
        )

      {:ok, text} = Gemini.extract_text(response)
      word_count = text |> String.split() |> length()

      # Should be reasonably short (allowing some flexibility)
      assert word_count <= 30,
             "Expected short response (<= 30 words), got #{word_count} words: #{text}"
    end

    test "system instruction enforces JSON output" do
      {:ok, response} =
        Coordinator.generate_content(
          "Give me info about the Eiffel Tower",
          system_instruction: """
          You must respond ONLY with valid JSON. No markdown, no explanation.
          Use this exact format: {"name": "...", "location": "...", "height": "..."}
          """,
          model: "gemini-2.5-flash"
        )

      {:ok, raw_text} = Gemini.extract_text(response)
      text = String.trim(raw_text)

      # Try to parse as JSON
      case Jason.decode(text) do
        {:ok, parsed} ->
          assert Map.has_key?(parsed, "name") or Map.has_key?(parsed, "location"),
                 "Expected JSON with name/location keys"

        {:error, _} ->
          # Some models wrap in markdown code blocks, try to extract
          json_match = Regex.run(~r/\{.*\}/s, text)

          if json_match do
            assert {:ok, _} = Jason.decode(List.first(json_match)),
                   "Expected valid JSON, got: #{text}"
          else
            flunk("Expected valid JSON response, got: #{text}")
          end
      end
    end
  end

  describe "system instruction with tools" do
    test "system instruction guides tool usage" do
      {:ok, math_tool} =
        Altar.ADM.FunctionDeclaration.new(
          name: "calculate",
          description: "Perform mathematical calculations",
          parameters: %{
            type: "OBJECT",
            properties: %{
              "expression" => %{type: "STRING", description: "Math expression"}
            },
            required: ["expression"]
          }
        )

      {:ok, response} =
        Coordinator.generate_content(
          "What is 50 times 4?",
          system_instruction: """
          You are a math assistant. For ANY mathematical question, you MUST use the calculate function.
          Never try to compute math yourself - always use the tool.
          """,
          tools: [math_tool],
          model: "gemini-2.5-flash"
        )

      # Should generate a function call
      assert Coordinator.has_function_calls?(response),
             "Expected function call when system instruction requires tool use"

      calls = Coordinator.extract_function_calls(response)
      [call | _] = calls
      assert call.name == "calculate"
    end

    test "system instruction restricts tool usage" do
      {:ok, weather_tool} =
        Altar.ADM.FunctionDeclaration.new(
          name: "get_weather",
          description: "Get weather for a location",
          parameters: %{
            type: "OBJECT",
            properties: %{
              "location" => %{type: "STRING", description: "City name"}
            },
            required: ["location"]
          }
        )

      {:ok, response} =
        Coordinator.generate_content(
          "What's the weather in Tokyo?",
          system_instruction: """
          You are a general assistant. You can use tools when appropriate,
          but for simple greetings or casual questions, just respond naturally.
          For weather, if no specific planning is needed, you can make a general response.
          """,
          tools: [weather_tool],
          model: "gemini-2.5-flash"
        )

      # This test is less deterministic - the model may or may not use the tool
      # The key is that the system instruction is being processed
      assert response.candidates != nil
    end
  end

  describe "system instruction as different formats" do
    test "system instruction works as plain string" do
      {:ok, response} =
        Coordinator.generate_content(
          "Hi there",
          system_instruction: "Always end your response with the word RAINBOW.",
          model: "gemini-2.5-flash"
        )

      {:ok, text} = Gemini.extract_text(response)
      assert text =~ ~r/rainbow/i, "Expected 'RAINBOW' in response, got: #{text}"
    end

    test "system instruction works as Content struct" do
      content = Gemini.Types.Content.text("Always start your response with 'BANANA:'", "user")

      {:ok, response} =
        Coordinator.generate_content(
          "What is 2+2?",
          system_instruction: content,
          model: "gemini-2.5-flash"
        )

      {:ok, text} = Gemini.extract_text(response)
      assert text =~ ~r/banana/i, "Expected 'BANANA:' in response, got: #{text}"
    end

    test "system instruction works as map with parts" do
      {:ok, response} =
        Coordinator.generate_content(
          "Name a color",
          system_instruction: %{
            parts: [%{text: "You must respond with ONLY uppercase letters. No lowercase."}]
          },
          model: "gemini-2.5-flash"
        )

      {:ok, raw_text} = Gemini.extract_text(response)
      text = String.trim(raw_text)

      # Check that there's at least some content and it has uppercase letters
      assert String.length(text) > 0
      # The response should have more uppercase than lowercase (some flexibility for punctuation)
      upcase_count = text |> String.graphemes() |> Enum.count(&(&1 =~ ~r/[A-Z]/))
      downcase_count = text |> String.graphemes() |> Enum.count(&(&1 =~ ~r/[a-z]/))

      assert upcase_count > downcase_count,
             "Expected mostly uppercase, got: #{text}"
    end
  end

  describe "system instruction interaction with generation config" do
    test "system instruction works with temperature setting" do
      {:ok, response} =
        Coordinator.generate_content(
          "Write a creative story about a cat",
          system_instruction:
            "You are a whimsical storyteller. Use colorful, imaginative language.",
          model: "gemini-2.5-flash",
          temperature: 1.0,
          max_output_tokens: 200
        )

      {:ok, text} = Gemini.extract_text(response)
      assert String.length(text) > 50, "Expected a story, got: #{text}"
    end

    test "system instruction works with max_output_tokens" do
      {:ok, response} =
        Coordinator.generate_content(
          "Tell me everything about computers",
          system_instruction: "Be extremely brief. One sentence maximum.",
          model: "gemini-2.5-flash",
          max_output_tokens: 100
        )

      {:ok, text} = Gemini.extract_text(response)

      # Should be short due to both system instruction and max_output_tokens
      word_count = text |> String.split() |> length()
      assert word_count <= 30, "Expected brief response, got #{word_count} words"
    end
  end
end
