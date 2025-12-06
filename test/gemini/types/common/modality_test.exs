defmodule Gemini.Types.ModalityTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Modality

  describe "from_api/1" do
    test "maps known modalities" do
      assert Modality.from_api("TEXT") == :text
      assert Modality.from_api("IMAGE") == :image
      assert Modality.from_api("AUDIO") == :audio
    end

    test "returns unspecified for unknown or nil" do
      assert Modality.from_api("FOO") == :modality_unspecified
      assert Modality.from_api(nil) == nil
    end
  end

  describe "to_api/1" do
    test "converts atoms to API strings" do
      assert Modality.to_api(:text) == "TEXT"
      assert Modality.to_api(:image) == "IMAGE"
      assert Modality.to_api(:audio) == "AUDIO"
    end

    test "defaults to unspecified string for unknown atoms" do
      assert Modality.to_api(:unknown) == "MODALITY_UNSPECIFIED"
    end
  end
end
