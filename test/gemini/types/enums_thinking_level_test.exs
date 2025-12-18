defmodule Gemini.Types.Enums.ThinkingLevelTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Enums.ThinkingLevel

  describe "to_api/1" do
    test "maps thinking levels to API strings" do
      assert ThinkingLevel.to_api(:unspecified) == "THINKING_LEVEL_UNSPECIFIED"
      assert ThinkingLevel.to_api(:minimal) == "MINIMAL"
      assert ThinkingLevel.to_api(:low) == "LOW"
      assert ThinkingLevel.to_api(:medium) == "MEDIUM"
      assert ThinkingLevel.to_api(:high) == "HIGH"
    end
  end

  describe "from_api/1" do
    test "accepts uppercase and lowercase values" do
      assert ThinkingLevel.from_api("THINKING_LEVEL_UNSPECIFIED") == :unspecified
      assert ThinkingLevel.from_api("MINIMAL") == :minimal
      assert ThinkingLevel.from_api("minimal") == :minimal
      assert ThinkingLevel.from_api("LOW") == :low
      assert ThinkingLevel.from_api("low") == :low
      assert ThinkingLevel.from_api("MEDIUM") == :medium
      assert ThinkingLevel.from_api("medium") == :medium
      assert ThinkingLevel.from_api("HIGH") == :high
      assert ThinkingLevel.from_api("high") == :high
    end

    test "returns nil for nil input" do
      assert ThinkingLevel.from_api(nil) == nil
    end
  end
end
