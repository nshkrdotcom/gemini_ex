defmodule Gemini.Types.Response.ModalityTokenCountTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.ModalityTokenCount

  describe "from_api/1" do
    test "parses modality and token_count" do
      payload = %{"modality" => "TEXT", "tokenCount" => 42}

      assert %ModalityTokenCount{modality: :text, token_count: 42} =
               ModalityTokenCount.from_api(payload)
    end

    test "returns nil for nil input" do
      assert ModalityTokenCount.from_api(nil) == nil
    end

    test "falls back to unspecified modality for unknown values" do
      payload = %{"modality" => "UNKNOWN_MODALITY", "tokenCount" => 7}

      assert %ModalityTokenCount{modality: :modality_unspecified, token_count: 7} =
               ModalityTokenCount.from_api(payload)
    end
  end
end
