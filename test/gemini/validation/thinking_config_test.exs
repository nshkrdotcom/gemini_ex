defmodule Gemini.Validation.ThinkingConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Validation.ThinkingConfig

  describe "validate_budget/2 for Gemini 2.5 Pro" do
    test "rejects budget of 0 (cannot disable thinking)" do
      assert {:error, msg} = ThinkingConfig.validate_budget(0, "gemini-2.5-pro")
      assert msg =~ "cannot disable thinking"
      assert msg =~ "minimum budget: 128"
    end

    test "accepts budget in valid range (128-32768)" do
      assert :ok = ThinkingConfig.validate_budget(128, "gemini-2.5-pro")
      assert :ok = ThinkingConfig.validate_budget(1024, "gemini-2.5-pro")
      assert :ok = ThinkingConfig.validate_budget(16_384, "gemini-2.5-pro")
      assert :ok = ThinkingConfig.validate_budget(32_768, "gemini-2.5-pro")
    end

    test "rejects budget below minimum" do
      assert {:error, msg} = ThinkingConfig.validate_budget(127, "gemini-2.5-pro")
      assert msg =~ "between 128 and 32,768"
    end

    test "rejects budget above maximum" do
      assert {:error, msg} = ThinkingConfig.validate_budget(32_769, "gemini-2.5-pro")
      assert msg =~ "between 128 and 32,768"
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, "gemini-2.5-pro")
    end

    test "handles alternative model name format" do
      assert :ok = ThinkingConfig.validate_budget(1024, "gemini-pro-2.5")
    end
  end

  describe "validate_budget/2 for Gemini 2.5 Flash" do
    test "accepts budget of 0 (can disable)" do
      assert :ok = ThinkingConfig.validate_budget(0, "gemini-2.5-flash")
    end

    test "accepts budget in valid range (0-24576)" do
      assert :ok = ThinkingConfig.validate_budget(0, "gemini-2.5-flash")
      assert :ok = ThinkingConfig.validate_budget(1024, "gemini-2.5-flash")
      assert :ok = ThinkingConfig.validate_budget(8192, "gemini-2.5-flash")
      assert :ok = ThinkingConfig.validate_budget(24_576, "gemini-2.5-flash")
    end

    test "rejects budget above maximum" do
      assert {:error, msg} = ThinkingConfig.validate_budget(24_577, "gemini-2.5-flash")
      assert msg =~ "between 0 and 24,576"
    end

    test "rejects negative budget (except -1)" do
      assert {:error, _msg} = ThinkingConfig.validate_budget(-2, "gemini-2.5-flash")
      assert {:error, _msg} = ThinkingConfig.validate_budget(-100, "gemini-2.5-flash")
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, "gemini-2.5-flash")
    end

    test "handles alternative model name format" do
      assert :ok = ThinkingConfig.validate_budget(512, "gemini-flash-2.5")
    end
  end

  describe "validate_budget/2 for Gemini 2.5 Flash Lite" do
    test "accepts budget of 0 (can disable)" do
      assert :ok = ThinkingConfig.validate_budget(0, "gemini-2.5-flash-lite")
    end

    test "accepts budget in valid range (512-24576)" do
      assert :ok = ThinkingConfig.validate_budget(512, "gemini-2.5-flash-lite")
      assert :ok = ThinkingConfig.validate_budget(1024, "gemini-2.5-flash-lite")
      assert :ok = ThinkingConfig.validate_budget(24_576, "gemini-2.5-flash-lite")
    end

    test "rejects budget between 1-511" do
      assert {:error, msg} = ThinkingConfig.validate_budget(1, "gemini-2.5-flash-lite")
      assert msg =~ "0 or between 512 and 24,576"

      assert {:error, _msg} = ThinkingConfig.validate_budget(511, "gemini-2.5-flash-lite")
    end

    test "rejects budget above maximum" do
      assert {:error, _msg} = ThinkingConfig.validate_budget(24_577, "gemini-2.5-flash-lite")
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, "gemini-2.5-flash-lite")
    end
  end

  describe "validate_budget/2 for unknown models" do
    test "allows any budget for unknown models" do
      # Let API validate for models we don't recognize
      assert :ok = ThinkingConfig.validate_budget(0, "gemini-1.5-pro")
      assert :ok = ThinkingConfig.validate_budget(1000, "some-future-model")
      assert :ok = ThinkingConfig.validate_budget(50_000, "unknown-model")
    end

    test "still allows dynamic thinking" do
      assert :ok = ThinkingConfig.validate_budget(-1, "unknown-model")
    end
  end

  describe "validate/2 with config map" do
    test "validates budget in config map" do
      config = %{thinking_budget: 1024}
      assert :ok = ThinkingConfig.validate(config, "gemini-2.5-flash")
    end

    test "returns error for invalid budget in config map" do
      config = %{thinking_budget: 0}
      assert {:error, _msg} = ThinkingConfig.validate(config, "gemini-2.5-pro")
    end

    test "returns :ok for config without thinking_budget" do
      config = %{some_other_field: "value"}
      assert :ok = ThinkingConfig.validate(config, "gemini-2.5-flash")
    end
  end
end
