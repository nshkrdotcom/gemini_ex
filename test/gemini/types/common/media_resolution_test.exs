defmodule Gemini.Types.MediaResolutionTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.MediaResolution

  describe "from_api/1" do
    test "maps API strings to atoms" do
      assert MediaResolution.from_api("MEDIA_RESOLUTION_LOW") == :media_resolution_low
      assert MediaResolution.from_api("MEDIA_RESOLUTION_MEDIUM") == :media_resolution_medium
      assert MediaResolution.from_api("MEDIA_RESOLUTION_HIGH") == :media_resolution_high
    end

    test "returns unspecified for unknown values" do
      assert MediaResolution.from_api("SOMETHING") == :media_resolution_unspecified
      assert MediaResolution.from_api(nil) == nil
    end
  end

  describe "to_api/1" do
    test "maps atoms to API strings" do
      assert MediaResolution.to_api(:media_resolution_low) == "MEDIA_RESOLUTION_LOW"
      assert MediaResolution.to_api(:media_resolution_medium) == "MEDIA_RESOLUTION_MEDIUM"
      assert MediaResolution.to_api(:media_resolution_high) == "MEDIA_RESOLUTION_HIGH"
    end

    test "defaults to unspecified string for unknown atoms" do
      assert MediaResolution.to_api(:other) == "MEDIA_RESOLUTION_UNSPECIFIED"
    end
  end
end
