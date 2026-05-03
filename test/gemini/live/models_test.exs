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

    test "matches candidate against Vertex full resource names" do
      candidates = ["gemini-live-2.5-flash", "gemini-live-2.5-flash-preview"]

      available = [
        "projects/test-proj/locations/us-central1/publishers/google/models/gemini-live-2.5-flash"
      ]

      assert {:ok, "gemini-live-2.5-flash"} = Models.pick_from_available(candidates, available)
    end

    test "matches candidate when available names include endpoint suffixes" do
      candidates = ["gemini-live-2.5-flash"]

      available = [
        "publishers/google/models/gemini-live-2.5-flash:bidiGenerateContent"
      ]

      assert {:ok, "gemini-live-2.5-flash"} = Models.pick_from_available(candidates, available)
    end
  end

  describe "resolve/2 with available_models option" do
    test "selects candidate when available_models provided" do
      model =
        Models.resolve(:audio,
          candidates: [
            "gemini-3.1-flash-live-preview",
            "gemini-2.5-flash-native-audio-preview-12-2025"
          ],
          available_models: ["models/gemini-2.5-flash-native-audio-preview-12-2025"]
        )

      assert model == "gemini-2.5-flash-native-audio-preview-12-2025"
    end

    test "prefers the latest registry-backed audio live model from availability" do
      model =
        Models.resolve(:audio,
          candidates: ["definitely-not-a-model"],
          available_models: [
            "models/gemini-2.5-flash-native-audio-preview-12-2025",
            "models/gemini-3.1-flash-live-preview"
          ]
        )

      assert model == "gemini-3.1-flash-live-preview"
    end

    test "does not infer audio-first Live models as text session candidates" do
      error =
        assert_raise ArgumentError, fn ->
          Models.resolve(:text,
            candidates: ["definitely-not-a-model"],
            available_models: [
              "models/gemini-2.5-flash-native-audio-preview-12-2025",
              "models/gemini-3.1-flash-live-preview"
            ]
          )
        end

      assert String.contains?(error.message, "No live default model available for modality :text")
    end

    test "raises when no text-session live models are available" do
      error =
        assert_raise ArgumentError, fn ->
          Models.resolve(:text,
            auth: :vertex_ai,
            candidates: ["definitely-not-a-model"],
            available_models: []
          )
        end

      assert String.contains?(error.message, "No live default model available for modality :text")
    end

    test "does not expose legacy text-live aliases as current vertex candidates" do
      candidates = Models.candidates(:text, auth: :vertex_ai)

      refute "gemini-live-2.5-flash" in candidates
      assert candidates == []
    end
  end
end
