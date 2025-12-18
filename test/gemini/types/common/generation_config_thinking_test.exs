defmodule Gemini.Types.GenerationConfigThinkingTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.GenerationConfig
  alias Gemini.Types.GenerationConfig.ThinkingConfig

  describe "thinking_level/2" do
    test "creates config with minimal thinking (Gemini 3 Flash)" do
      config = GenerationConfig.thinking_level(:minimal)

      assert config.thinking_config.thinking_level == :minimal
      assert config.thinking_config.thinking_budget == nil
    end

    test "creates config with low thinking" do
      config = GenerationConfig.thinking_level(:low)

      assert config.thinking_config.thinking_level == :low
      assert config.thinking_config.thinking_budget == nil
    end

    test "creates config with medium thinking (Gemini 3 Flash)" do
      config = GenerationConfig.thinking_level(:medium)

      assert config.thinking_config.thinking_level == :medium
      assert config.thinking_config.thinking_budget == nil
    end

    test "creates config with high thinking" do
      config = GenerationConfig.thinking_level(:high)

      assert config.thinking_config.thinking_level == :high
      assert config.thinking_config.thinking_budget == nil
    end
  end

  describe "thinking_budget/2" do
    test "creates config with disabled thinking (budget = 0)" do
      config = GenerationConfig.thinking_budget(0)

      assert %ThinkingConfig{thinking_budget: 0} = config.thinking_config
      assert config.thinking_config.include_thoughts == nil
    end

    test "creates config with limited thinking (positive budget)" do
      config = GenerationConfig.thinking_budget(1024)

      assert config.thinking_config.thinking_budget == 1024
      assert config.thinking_config.include_thoughts == nil
    end

    test "creates config with dynamic thinking (budget = -1)" do
      config = GenerationConfig.thinking_budget(-1)

      assert config.thinking_config.thinking_budget == -1
    end

    test "can chain with other config options" do
      config =
        GenerationConfig.new(temperature: 0.7)
        |> GenerationConfig.thinking_budget(512)
        |> GenerationConfig.max_tokens(1000)

      assert config.temperature == 0.7
      assert config.thinking_config.thinking_budget == 512
      assert config.max_output_tokens == 1000
    end

    test "can update thinking_budget on existing config" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.thinking_budget(1024)
        |> GenerationConfig.thinking_budget(2048)

      # Should replace previous value
      assert config.thinking_config.thinking_budget == 2048
    end
  end

  describe "include_thoughts/2" do
    test "enables thought summaries" do
      config = GenerationConfig.include_thoughts(true)

      assert config.thinking_config.include_thoughts == true
    end

    test "disables thought summaries" do
      config = GenerationConfig.include_thoughts(false)

      assert config.thinking_config.include_thoughts == false
    end

    test "can combine with thinking budget" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.thinking_budget(2048)
        |> GenerationConfig.include_thoughts(true)

      assert config.thinking_config.thinking_budget == 2048
      assert config.thinking_config.include_thoughts == true
    end

    test "preserves thinking_budget when adding include_thoughts" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.thinking_budget(1024)
        |> GenerationConfig.include_thoughts(true)

      assert config.thinking_config.thinking_budget == 1024
      assert config.thinking_config.include_thoughts == true
    end
  end

  describe "thinking_config/3" do
    test "creates complete config in one call" do
      config =
        GenerationConfig.thinking_config(GenerationConfig.new(), 1024, include_thoughts: true)

      assert config.thinking_config.thinking_budget == 1024
      assert config.thinking_config.include_thoughts == true
    end

    test "creates config with just budget (thoughts default false)" do
      config = GenerationConfig.thinking_config(512)

      assert config.thinking_config.thinking_budget == 512
      assert config.thinking_config.include_thoughts == false
    end

    test "can chain with other options" do
      config =
        GenerationConfig.new(temperature: 0.8)
        |> GenerationConfig.thinking_config(2048, include_thoughts: true)
        |> GenerationConfig.max_tokens(4000)

      assert config.temperature == 0.8
      assert config.thinking_config.thinking_budget == 2048
      assert config.thinking_config.include_thoughts == true
      assert config.max_output_tokens == 4000
    end
  end

  describe "ThinkingConfig struct" do
    test "can be created directly" do
      thinking = %ThinkingConfig{
        thinking_budget: 1024,
        include_thoughts: true
      }

      assert thinking.thinking_budget == 1024
      assert thinking.include_thoughts == true
    end

    test "has nil defaults" do
      thinking = %ThinkingConfig{}

      assert thinking.thinking_budget == nil
      assert thinking.include_thoughts == nil
    end
  end
end
