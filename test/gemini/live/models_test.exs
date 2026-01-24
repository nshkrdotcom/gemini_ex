defmodule Gemini.Live.ModelsTest do
  use ExUnit.Case, async: true

  alias Gemini.Live.Models

  describe "pick_from_available/2" do
    test "returns first candidate found in available list" do
      candidates = [
        "gemini-live-2.5-flash-preview",
        "gemini-2.0-flash-exp"
      ]

      available = [
        "models/gemini-2.0-flash-exp",
        "models/gemini-2.0-flash-exp-image-generation"
      ]

      assert {:ok, "gemini-2.0-flash-exp"} = Models.pick_from_available(candidates, available)
    end

    test "returns :none when no candidates match" do
      candidates = ["gemini-live-2.5-flash-preview"]
      available = ["models/gemini-2.0-flash-exp"]

      assert :none = Models.pick_from_available(candidates, available)
    end
  end

  describe "resolve/2 with available_models option" do
    test "selects candidate when available_models provided" do
      model =
        Models.resolve(:text,
          candidates: ["gemini-live-2.5-flash-preview", "gemini-2.0-flash-exp"],
          available_models: ["models/gemini-2.0-flash-exp"]
        )

      assert model == "gemini-2.0-flash-exp"
    end

    test "falls back to default when no available candidates" do
      model =
        Models.resolve(:text,
          candidates: ["gemini-live-2.5-flash-preview"],
          available_models: []
        )

      assert model == Models.default(:text)
    end
  end
end
