defmodule Gemini.Types.GenerationConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.GenerationConfig

  describe "property_ordering field" do
    test "accepts list of strings" do
      config = GenerationConfig.new(property_ordering: ["a", "b", "c"])
      assert config.property_ordering == ["a", "b", "c"]
    end

    test "defaults to nil" do
      config = GenerationConfig.new()
      assert config.property_ordering == nil
    end

    test "accepts empty list" do
      config = GenerationConfig.new(property_ordering: [])
      assert config.property_ordering == []
    end
  end
end
