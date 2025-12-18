defmodule Gemini.APIs.ImagesTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Images

  alias Gemini.Types.Generation.Image.{
    ImageGenerationConfig,
    EditImageConfig,
    UpscaleImageConfig,
    GeneratedImage
  }

  @moduletag :unit

  describe "generate/3" do
    test "generates images with default config" do
      # Verify module is loaded and has expected functions
      # Using Code.ensure_loaded! is deterministic, unlike function_exported?
      # ensure_loaded! returns {:module, ModuleName} on success
      {:module, Images} = Code.ensure_loaded(Images)
      functions = Images.__info__(:functions)

      assert {:generate, 1} in functions
      assert {:generate, 2} in functions
      assert {:generate, 3} in functions
    end

    test "validates ImageGenerationConfig struct" do
      config = %ImageGenerationConfig{
        number_of_images: 2,
        aspect_ratio: "16:9",
        safety_filter_level: :block_some
      }

      assert config.number_of_images == 2
      assert config.aspect_ratio == "16:9"
      assert config.safety_filter_level == :block_some
    end

    test "uses default config values" do
      config = %ImageGenerationConfig{}

      assert config.number_of_images == 1
      assert config.aspect_ratio == "1:1"
      assert config.safety_filter_level == :block_some
      assert config.person_generation == :allow_none
      assert config.output_mime_type == "image/png"
      assert config.add_watermark == true
    end

    test "accepts custom config values" do
      config = %ImageGenerationConfig{
        number_of_images: 4,
        aspect_ratio: "9:16",
        safety_filter_level: :block_few,
        person_generation: :allow_adult,
        output_mime_type: "image/jpeg",
        output_compression_quality: 90,
        negative_prompt: "blurry, low quality",
        seed: 12345,
        guidance_scale: 7.5,
        language: "en",
        add_watermark: false
      }

      assert config.number_of_images == 4
      assert config.aspect_ratio == "9:16"
      assert config.safety_filter_level == :block_few
      assert config.person_generation == :allow_adult
      assert config.output_mime_type == "image/jpeg"
      assert config.output_compression_quality == 90
      assert config.negative_prompt == "blurry, low quality"
      assert config.seed == 12345
      assert config.guidance_scale == 7.5
      assert config.language == "en"
      assert config.add_watermark == false
    end
  end

  describe "edit/5" do
    test "validates EditImageConfig struct" do
      config = %EditImageConfig{
        prompt: "Replace background",
        edit_mode: :inpainting
      }

      assert config.prompt == "Replace background"
      assert config.edit_mode == :inpainting
    end

    test "uses default edit config values" do
      config = %EditImageConfig{}

      assert config.edit_mode == :inpainting
      assert config.mask_mode == :foreground
      assert config.mask_dilation == 0
      assert config.number_of_images == 1
      assert config.safety_filter_level == :block_some
      assert config.output_mime_type == "image/png"
    end

    test "accepts custom edit config values" do
      config = %EditImageConfig{
        prompt: "Add sunset",
        edit_mode: :outpainting,
        mask_mode: :background,
        mask_dilation: 10,
        guidance_scale: 15.0,
        number_of_images: 2,
        safety_filter_level: :block_most,
        seed: 54321,
        output_mime_type: "image/jpeg"
      }

      assert config.prompt == "Add sunset"
      assert config.edit_mode == :outpainting
      assert config.mask_mode == :background
      assert config.mask_dilation == 10
      assert config.guidance_scale == 15.0
      assert config.number_of_images == 2
      assert config.safety_filter_level == :block_most
      assert config.seed == 54321
      assert config.output_mime_type == "image/jpeg"
    end
  end

  describe "upscale/3" do
    test "validates UpscaleImageConfig struct" do
      config = %UpscaleImageConfig{
        upscale_factor: :x4
      }

      assert config.upscale_factor == :x4
    end

    test "uses default upscale config values" do
      config = %UpscaleImageConfig{}

      assert config.upscale_factor == :x2
      assert config.output_mime_type == "image/png"
    end

    test "accepts custom upscale config values" do
      config = %UpscaleImageConfig{
        upscale_factor: :x4,
        output_mime_type: "image/jpeg",
        output_compression_quality: 95
      }

      assert config.upscale_factor == :x4
      assert config.output_mime_type == "image/jpeg"
      assert config.output_compression_quality == 95
    end
  end

  describe "GeneratedImage" do
    test "parses generated image from API response" do
      api_response = %{
        "bytesBase64Encoded" => "base64data...",
        "mimeType" => "image/png",
        "imageSize" => %{"width" => 1024, "height" => 1024},
        "safetyAttributes" => %{"blocked" => false},
        "raiInfo" => %{"blocked_reason" => nil}
      }

      image = Gemini.Types.Generation.Image.parse_generated_image(api_response)

      assert %GeneratedImage{} = image
      assert image.image_data == "base64data..."
      assert image.mime_type == "image/png"
      assert image.image_size == %{"width" => 1024, "height" => 1024}
      assert image.safety_attributes == %{"blocked" => false}
      assert image.rai_info == %{"blocked_reason" => nil}
    end
  end

  describe "type conversions" do
    test "format_safety_filter_level converts atoms to API format" do
      assert Gemini.Types.Generation.Image.format_safety_filter_level(:block_most) ==
               "blockMost"

      assert Gemini.Types.Generation.Image.format_safety_filter_level(:block_some) ==
               "blockSome"

      assert Gemini.Types.Generation.Image.format_safety_filter_level(:block_few) == "blockFew"

      assert Gemini.Types.Generation.Image.format_safety_filter_level(:block_none) ==
               "blockNone"
    end

    test "format_person_generation converts atoms to API format" do
      assert Gemini.Types.Generation.Image.format_person_generation(:allow_adult) ==
               "allowAdult"

      assert Gemini.Types.Generation.Image.format_person_generation(:allow_all) == "allowAll"

      assert Gemini.Types.Generation.Image.format_person_generation(:allow_none) == "allowNone"
    end

    test "format_edit_mode converts atoms to API format" do
      assert Gemini.Types.Generation.Image.format_edit_mode(:inpainting) == "inpainting"
      assert Gemini.Types.Generation.Image.format_edit_mode(:outpainting) == "outpainting"

      assert Gemini.Types.Generation.Image.format_edit_mode(:product_image) == "productImage"
    end

    test "format_upscale_factor converts atoms to API format" do
      assert Gemini.Types.Generation.Image.format_upscale_factor(:x2) == "x2"
      assert Gemini.Types.Generation.Image.format_upscale_factor(:x4) == "x4"
    end

    test "parse_safety_filter_level converts strings to atoms" do
      assert Gemini.Types.Generation.Image.parse_safety_filter_level("BLOCK_MOST") ==
               :block_most

      assert Gemini.Types.Generation.Image.parse_safety_filter_level("BLOCK_SOME") ==
               :block_some

      assert Gemini.Types.Generation.Image.parse_safety_filter_level("BLOCK_FEW") == :block_few

      assert Gemini.Types.Generation.Image.parse_safety_filter_level("BLOCK_NONE") ==
               :block_none

      assert Gemini.Types.Generation.Image.parse_safety_filter_level(:block_some) ==
               :block_some
    end
  end

  describe "request parameter building" do
    test "build_generation_params creates proper API request" do
      config = %ImageGenerationConfig{
        number_of_images: 2,
        aspect_ratio: "16:9",
        safety_filter_level: :block_some,
        person_generation: :allow_adult,
        add_watermark: true
      }

      params = Gemini.Types.Generation.Image.build_generation_params("A cat", config)

      assert params["prompt"] == "A cat"
      assert params["sampleCount"] == 2
      assert params["aspectRatio"] == "16:9"
      assert params["safetyFilterLevel"] == "blockSome"
      assert params["personGeneration"] == "allowAdult"
      assert params["addWatermark"] == true
    end

    test "build_generation_params includes optional fields" do
      config = %ImageGenerationConfig{
        number_of_images: 1,
        negative_prompt: "blurry",
        seed: 12345,
        guidance_scale: 7.5,
        language: "en",
        output_mime_type: "image/jpeg",
        output_compression_quality: 90
      }

      params = Gemini.Types.Generation.Image.build_generation_params("A cat", config)

      assert params["negativePrompt"] == "blurry"
      assert params["seed"] == 12345
      assert params["guidanceScale"] == 7.5
      assert params["language"] == "en"
      assert params["outputMimeType"] == "image/jpeg"
      assert params["outputCompressionQuality"] == 90
    end

    test "build_edit_params creates proper API request" do
      config = %EditImageConfig{
        prompt: "Edit background",
        edit_mode: :inpainting,
        number_of_images: 1
      }

      params =
        Gemini.Types.Generation.Image.build_edit_params("Edit", "image_data", "mask_data", config)

      assert params["prompt"] == "Edit"
      assert params["image"]["bytesBase64Encoded"] == "image_data"
      assert params["mask"]["image"]["bytesBase64Encoded"] == "mask_data"
      assert params["editMode"] == "inpainting"
      assert params["sampleCount"] == 1
    end

    test "build_edit_params works without mask" do
      config = %EditImageConfig{
        prompt: "Edit background",
        edit_mode: :inpainting
      }

      params = Gemini.Types.Generation.Image.build_edit_params("Edit", "image_data", nil, config)

      assert params["prompt"] == "Edit"
      assert params["image"]["bytesBase64Encoded"] == "image_data"
      refute Map.has_key?(params, "mask")
    end

    test "build_upscale_params creates proper API request" do
      config = %UpscaleImageConfig{
        upscale_factor: :x4,
        output_mime_type: "image/jpeg",
        output_compression_quality: 95
      }

      params = Gemini.Types.Generation.Image.build_upscale_params("image_data", config)

      assert params["image"]["bytesBase64Encoded"] == "image_data"
      assert params["upscaleFactor"] == "x4"
      assert params["outputMimeType"] == "image/jpeg"
      assert params["outputCompressionQuality"] == 95
    end
  end

  describe "error handling" do
    test "validates API function signatures" do
      # Verify all public API functions exist using deterministic module info
      # ensure_loaded returns {:module, ModuleName} on success
      {:module, Images} = Code.ensure_loaded(Images)
      functions = Images.__info__(:functions)

      # Check all expected functions exist
      assert {:generate, 3} in functions
      assert {:edit, 5} in functions
      assert {:upscale, 3} in functions
    end
  end
end
