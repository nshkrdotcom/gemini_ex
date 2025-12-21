defmodule Gemini.APIs.CoordinatorSystemInstructionTest do
  @moduledoc """
  Tests for system instruction support in the Coordinator.

  System instructions allow setting persistent system prompts that
  guide the model's behavior across the conversation.
  """

  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.Content

  describe "system_instruction in request building" do
    test "includes system_instruction as string in request" do
      # Test that system_instruction is properly included when passed as string
      opts = [
        system_instruction: "You are a helpful assistant specialized in Python.",
        model: "gemini-2.5-flash"
      ]

      # We can test the internal build function
      {:ok, request} = Coordinator.__test_build_request__("Hello", opts)

      assert Map.has_key?(request, :systemInstruction)

      assert request.systemInstruction.parts == [
               %{text: "You are a helpful assistant specialized in Python."}
             ]
    end

    test "includes system_instruction as Content struct in request" do
      # Test that system_instruction is properly included when passed as Content struct
      system_content = Content.text("You are a coding expert.", "user")

      opts = [
        system_instruction: system_content,
        model: "gemini-2.5-flash"
      ]

      {:ok, request} = Coordinator.__test_build_request__("Explain recursion", opts)

      assert Map.has_key?(request, :systemInstruction)
      assert request.systemInstruction.role == "user"
      assert length(request.systemInstruction.parts) == 1
    end

    test "includes system_instruction as map with parts in request" do
      # Test that system_instruction is properly included when passed as map
      opts = [
        system_instruction: %{
          parts: [%{text: "You are an expert mathematician."}]
        },
        model: "gemini-2.5-flash"
      ]

      {:ok, request} = Coordinator.__test_build_request__("What is calculus?", opts)

      assert Map.has_key?(request, :systemInstruction)
      assert request.systemInstruction.parts == [%{text: "You are an expert mathematician."}]
    end

    test "omits systemInstruction when not provided" do
      opts = [model: "gemini-2.5-flash"]

      {:ok, request} = Coordinator.__test_build_request__("Hello", opts)

      refute Map.has_key?(request, :systemInstruction)
    end

    test "system_instruction works with generation_config" do
      opts = [
        system_instruction: "Be concise.",
        model: "gemini-2.5-flash",
        temperature: 0.5,
        max_output_tokens: 100
      ]

      {:ok, request} = Coordinator.__test_build_request__("Hello", opts)

      assert Map.has_key?(request, :systemInstruction)
      assert Map.has_key?(request, :generationConfig)
      assert request.generationConfig.temperature == 0.5
      assert request.generationConfig.maxOutputTokens == 100
    end
  end

  describe "format_system_instruction/1" do
    test "formats string to Content-like structure" do
      result = Coordinator.__test_format_system_instruction__("You are helpful.")

      assert result == %{parts: [%{text: "You are helpful."}]}
    end

    test "formats Content struct preserving structure" do
      content = %Content{role: "user", parts: [%Gemini.Types.Part{text: "Be helpful."}]}
      result = Coordinator.__test_format_system_instruction__(content)

      assert result.role == "user"
      assert length(result.parts) == 1
    end

    test "formats map with parts preserving structure" do
      input = %{parts: [%{text: "Custom instruction."}]}
      result = Coordinator.__test_format_system_instruction__(input)

      assert result.parts == [%{text: "Custom instruction."}]
    end

    test "returns nil for nil input" do
      assert Coordinator.__test_format_system_instruction__(nil) == nil
    end
  end
end
