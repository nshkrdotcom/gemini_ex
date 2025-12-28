defmodule Gemini.Validation.ThinkingConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Config
  alias Gemini.Validation.ThinkingConfig

  # Get canonical model names from Config for primary tests
  @pro_2_5 Config.get_model(:pro_2_5)
  @flash_2_5 Config.get_model(:flash_2_5)
  @flash_2_5_lite Config.get_model(:flash_2_5_lite)
  @pro_3 Config.get_model(:pro_3_preview)
  @flash_3 Config.get_model(:flash_3_preview)

  describe "validate_level/2 for Gemini 3 models" do
    test "accepts low/high for Gemini 3 Pro" do
      assert :ok = ThinkingConfig.validate_level(:low, @pro_3)
      assert :ok = ThinkingConfig.validate_level(:high, @pro_3)
    end

    test "rejects minimal/medium for Gemini 3 Pro" do
      assert {:error, msg} = ThinkingConfig.validate_level(:minimal, @pro_3)
      assert msg =~ "only supported on Gemini 3 Flash"

      assert {:error, msg} = ThinkingConfig.validate_level(:medium, @pro_3)
      assert msg =~ "only supported on Gemini 3 Flash"
    end

    test "accepts minimal/medium/low/high for Gemini 3 Flash" do
      assert :ok = ThinkingConfig.validate_level(:minimal, @flash_3)
      assert :ok = ThinkingConfig.validate_level(:low, @flash_3)
      assert :ok = ThinkingConfig.validate_level(:medium, @flash_3)
      assert :ok = ThinkingConfig.validate_level(:high, @flash_3)
    end

    test "accepts unspecified level" do
      assert :ok = ThinkingConfig.validate_level(:unspecified, @flash_3)
    end
  end

  describe "validate_budget/2 for Gemini 2.5 Pro" do
    test "rejects budget of 0 (cannot disable thinking)" do
      assert {:error, msg} = ThinkingConfig.validate_budget(0, @pro_2_5)
      assert msg =~ "cannot disable thinking"
      assert msg =~ "minimum budget: 128"
    end

    test "accepts budget in valid range (128-32768)" do
      assert :ok = ThinkingConfig.validate_budget(128, @pro_2_5)
      assert :ok = ThinkingConfig.validate_budget(1024, @pro_2_5)
      assert :ok = ThinkingConfig.validate_budget(16_384, @pro_2_5)
      assert :ok = ThinkingConfig.validate_budget(32_768, @pro_2_5)
    end

    test "rejects budget below minimum" do
      assert {:error, msg} = ThinkingConfig.validate_budget(127, @pro_2_5)
      assert msg =~ "between 128 and 32,768"
    end

    test "rejects budget above maximum" do
      assert {:error, msg} = ThinkingConfig.validate_budget(32_769, @pro_2_5)
      assert msg =~ "between 128 and 32,768"
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, @pro_2_5)
    end

    # Keep literal string to test alternative format handling
    test "handles alternative model name format" do
      assert :ok = ThinkingConfig.validate_budget(1024, "gemini-pro-2.5")
    end
  end

  describe "validate_budget/2 for Gemini 2.5 Flash" do
    test "accepts budget of 0 (can disable)" do
      assert :ok = ThinkingConfig.validate_budget(0, @flash_2_5)
    end

    test "accepts budget in valid range (0-24576)" do
      assert :ok = ThinkingConfig.validate_budget(0, @flash_2_5)
      assert :ok = ThinkingConfig.validate_budget(1024, @flash_2_5)
      assert :ok = ThinkingConfig.validate_budget(8192, @flash_2_5)
      assert :ok = ThinkingConfig.validate_budget(24_576, @flash_2_5)
    end

    test "rejects budget above maximum" do
      assert {:error, msg} = ThinkingConfig.validate_budget(24_577, @flash_2_5)
      assert msg =~ "between 0 and 24,576"
    end

    test "rejects negative budget (except -1)" do
      assert {:error, _msg} = ThinkingConfig.validate_budget(-2, @flash_2_5)
      assert {:error, _msg} = ThinkingConfig.validate_budget(-100, @flash_2_5)
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, @flash_2_5)
    end

    # Keep literal string to test alternative format handling
    test "handles alternative model name format" do
      assert :ok = ThinkingConfig.validate_budget(512, "gemini-flash-2.5")
    end
  end

  describe "validate_budget/2 for Gemini 2.5 Flash Lite" do
    test "accepts budget of 0 (can disable)" do
      assert :ok = ThinkingConfig.validate_budget(0, @flash_2_5_lite)
    end

    test "accepts budget in valid range (512-24576)" do
      assert :ok = ThinkingConfig.validate_budget(512, @flash_2_5_lite)
      assert :ok = ThinkingConfig.validate_budget(1024, @flash_2_5_lite)
      assert :ok = ThinkingConfig.validate_budget(24_576, @flash_2_5_lite)
    end

    test "rejects budget between 1-511" do
      assert {:error, msg} = ThinkingConfig.validate_budget(1, @flash_2_5_lite)
      assert msg =~ "0 or between 512 and 24,576"

      assert {:error, _msg} = ThinkingConfig.validate_budget(511, @flash_2_5_lite)
    end

    test "rejects budget above maximum" do
      assert {:error, _msg} = ThinkingConfig.validate_budget(24_577, @flash_2_5_lite)
    end

    test "accepts dynamic thinking (-1)" do
      assert :ok = ThinkingConfig.validate_budget(-1, @flash_2_5_lite)
    end
  end

  describe "validate_budget/2 for unknown models" do
    # Keep literal strings - we're specifically testing behavior with unknown/future models
    test "allows any budget for unknown models" do
      # Let API validate for models we don't recognize
      assert :ok = ThinkingConfig.validate_budget(0, "some-old-model")
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
      assert :ok = ThinkingConfig.validate(config, @flash_2_5)
    end

    test "validates thinking level in config map" do
      config = %{thinking_level: :minimal}
      assert :ok = ThinkingConfig.validate(config, @flash_3)
    end

    test "returns error for invalid budget in config map" do
      config = %{thinking_budget: 0}
      assert {:error, _msg} = ThinkingConfig.validate(config, @pro_2_5)
    end

    test "returns :ok for config without thinking_budget" do
      config = %{some_other_field: "value"}
      assert :ok = ThinkingConfig.validate(config, @flash_2_5)
    end
  end
end
