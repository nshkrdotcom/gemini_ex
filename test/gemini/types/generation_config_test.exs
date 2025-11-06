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

  describe "property_ordering/2 helper" do
    test "sets property_ordering" do
      config = GenerationConfig.property_ordering(["x", "y", "z"])
      assert config.property_ordering == ["x", "y", "z"]
    end

    test "works with existing config" do
      config =
        GenerationConfig.new(temperature: 0.5)
        |> GenerationConfig.property_ordering(["a", "b"])

      assert config.temperature == 0.5
      assert config.property_ordering == ["a", "b"]
    end

    test "chains with other helpers" do
      config =
        GenerationConfig.new()
        |> GenerationConfig.json_response()
        |> GenerationConfig.property_ordering(["name", "age"])
        |> GenerationConfig.temperature(0.7)

      assert config.response_mime_type == "application/json"
      assert config.property_ordering == ["name", "age"]
      assert config.temperature == 0.7
    end
  end
end
