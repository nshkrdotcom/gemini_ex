defmodule Gemini.Types.Interactions.ImageConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Interactions.ImageConfig

  describe "new/1" do
    test "creates config with valid aspect ratio" do
      config = ImageConfig.new(aspect_ratio: "16:9")
      assert config.aspect_ratio == "16:9"
    end

    test "creates config with valid image size" do
      config = ImageConfig.new(image_size: "2K")
      assert config.image_size == "2K"
    end

    test "creates config with both fields" do
      config = ImageConfig.new(aspect_ratio: "4:3", image_size: "4K")

      assert config.aspect_ratio == "4:3"
      assert config.image_size == "4K"
    end

    test "creates empty config" do
      config = ImageConfig.new()

      assert config.aspect_ratio == nil
      assert config.image_size == nil
    end

    test "accepts new 4:5 aspect ratio" do
      config = ImageConfig.new(aspect_ratio: "4:5")
      assert config.aspect_ratio == "4:5"
    end

    test "accepts new 5:4 aspect ratio" do
      config = ImageConfig.new(aspect_ratio: "5:4")
      assert config.aspect_ratio == "5:4"
    end

    test "accepts 21:9 ultrawide aspect ratio" do
      config = ImageConfig.new(aspect_ratio: "21:9")
      assert config.aspect_ratio == "21:9"
    end

    test "rejects invalid aspect ratio" do
      assert_raise ArgumentError, ~r/Invalid aspect_ratio/, fn ->
        ImageConfig.new(aspect_ratio: "invalid")
      end

      assert_raise ArgumentError, ~r/Invalid aspect_ratio/, fn ->
        ImageConfig.new(aspect_ratio: "7:5")
      end
    end

    test "rejects invalid image size" do
      assert_raise ArgumentError, ~r/Invalid image_size/, fn ->
        ImageConfig.new(image_size: "8K")
      end

      assert_raise ArgumentError, ~r/Invalid image_size/, fn ->
        ImageConfig.new(image_size: "HD")
      end
    end
  end

  describe "valid_aspect_ratios/0" do
    test "returns all valid aspect ratios" do
      ratios = ImageConfig.valid_aspect_ratios()

      assert "1:1" in ratios
      assert "2:3" in ratios
      assert "3:2" in ratios
      assert "3:4" in ratios
      assert "4:3" in ratios
      assert "4:5" in ratios
      assert "5:4" in ratios
      assert "9:16" in ratios
      assert "16:9" in ratios
      assert "21:9" in ratios

      assert length(ratios) == 10
    end
  end

  describe "valid_image_sizes/0" do
    test "returns all valid image sizes" do
      sizes = ImageConfig.valid_image_sizes()

      assert "1K" in sizes
      assert "2K" in sizes
      assert "4K" in sizes

      assert length(sizes) == 3
    end
  end

  describe "valid_aspect_ratio?/1" do
    test "returns true for valid ratios" do
      assert ImageConfig.valid_aspect_ratio?("16:9")
      assert ImageConfig.valid_aspect_ratio?("4:5")
      assert ImageConfig.valid_aspect_ratio?("5:4")
    end

    test "returns false for invalid ratios" do
      refute ImageConfig.valid_aspect_ratio?("invalid")
      refute ImageConfig.valid_aspect_ratio?("7:5")
      refute ImageConfig.valid_aspect_ratio?(nil)
    end
  end

  describe "valid_image_size?/1" do
    test "returns true for valid sizes" do
      assert ImageConfig.valid_image_size?("1K")
      assert ImageConfig.valid_image_size?("2K")
      assert ImageConfig.valid_image_size?("4K")
    end

    test "returns false for invalid sizes" do
      refute ImageConfig.valid_image_size?("8K")
      refute ImageConfig.valid_image_size?("HD")
      refute ImageConfig.valid_image_size?(nil)
    end
  end

  describe "to_api/1" do
    test "converts to snake_case keys" do
      config = %ImageConfig{
        aspect_ratio: "16:9",
        image_size: "2K"
      }

      api = ImageConfig.to_api(config)

      assert api["aspect_ratio"] == "16:9"
      assert api["image_size"] == "2K"
    end

    test "excludes nil values" do
      config = %ImageConfig{aspect_ratio: "16:9"}

      api = ImageConfig.to_api(config)

      assert Map.has_key?(api, "aspect_ratio")
      refute Map.has_key?(api, "image_size")
    end

    test "returns nil for nil input" do
      assert ImageConfig.to_api(nil) == nil
    end
  end

  describe "from_api/1" do
    test "parses snake_case keys" do
      data = %{
        "aspect_ratio" => "4:3",
        "image_size" => "4K"
      }

      config = ImageConfig.from_api(data)

      assert config.aspect_ratio == "4:3"
      assert config.image_size == "4K"
    end

    test "parses camelCase keys" do
      data = %{
        "aspectRatio" => "4:3",
        "imageSize" => "4K"
      }

      config = ImageConfig.from_api(data)

      assert config.aspect_ratio == "4:3"
      assert config.image_size == "4K"
    end

    test "returns nil for nil input" do
      assert ImageConfig.from_api(nil) == nil
    end

    test "passes through existing struct" do
      original = %ImageConfig{aspect_ratio: "16:9"}
      result = ImageConfig.from_api(original)

      assert result == original
    end
  end
end
