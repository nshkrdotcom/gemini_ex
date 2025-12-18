defmodule Gemini.Types.Generation.Image do
  @moduledoc """
  Type definitions for image generation using Google's Imagen models.

  Imagen is Google's text-to-image generation model that creates high-quality images
  from text descriptions. These types support image generation, editing, and upscaling
  operations through the Vertex AI API.

  ## Supported Models

  - `imagegeneration@006` - Latest stable Imagen model
  - `imagen-3.0-generate-001` - Imagen 3.0 generation model

  ## Example

      config = %ImageGenerationConfig{
        number_of_images: 4,
        aspect_ratio: "1:1",
        safety_filter_level: :block_some,
        person_generation: :allow_adult
      }

      {:ok, images} = Gemini.APIs.Images.generate(
        "A serene mountain landscape at sunset",
        config
      )

  See `Gemini.APIs.Images` for API functions.
  """

  use TypedStruct

  @typedoc """
  Safety filter levels for generated images.

  - `:block_most` - Strictest filtering, blocks most potentially sensitive content
  - `:block_some` - Moderate filtering (recommended for most use cases)
  - `:block_few` - Permissive filtering, blocks only highly sensitive content
  - `:block_none` - No safety filtering applied
  """
  @type safety_filter_level :: :block_most | :block_some | :block_few | :block_none

  @typedoc """
  Person generation policy.

  - `:allow_adult` - Allow generation of adult humans
  - `:allow_all` - Allow generation of humans of all ages
  - `:allow_none` - Do not generate recognizable people

  Legacy alias: `:dont_allow` (mapped to `:allow_none`)
  """
  @type person_generation :: :allow_adult | :allow_all | :allow_none | :dont_allow

  @typedoc """
  Aspect ratio for generated images.

  Common aspect ratios:
  - `"1:1"` - Square (1024x1024)
  - `"9:16"` - Portrait, mobile (768x1344)
  - `"16:9"` - Landscape, desktop (1344x768)
  - `"4:3"` - Standard portrait (896x1152)
  - `"3:4"` - Standard landscape (1152x896)
  """
  @type aspect_ratio :: String.t()

  @typedoc """
  Upscale factor for image enhancement.

  - `:x2` - 2x upscale (e.g., 1024x1024 -> 2048x2048)
  - `:x4` - 4x upscale (e.g., 1024x1024 -> 4096x4096)
  """
  @type upscale_factor :: :x2 | :x4

  @typedoc """
  Edit mode for image editing operations.

  - `:inpainting` - Edit specific regions (requires mask)
  - `:outpainting` - Extend image beyond original boundaries (requires mask)
  - `:product_image` - Product-focused editing
  """
  @type edit_mode :: :inpainting | :outpainting | :product_image

  typedstruct module: ImageGenerationConfig do
    @derive Jason.Encoder
    @moduledoc """
    Configuration for image generation requests.

    ## Fields

    - `number_of_images` - Number of images to generate (1-8, default: 1)
    - `aspect_ratio` - Image aspect ratio (default: "1:1")
    - `safety_filter_level` - Content safety filtering (default: :block_some)
    - `person_generation` - Person generation policy (default: :allow_none; legacy :dont_allow supported)
    - `output_mime_type` - Output format, "image/png" or "image/jpeg" (default: "image/png")
    - `output_compression_quality` - JPEG quality 0-100 (default: 80, only for JPEG)
    - `negative_prompt` - Text describing what to avoid in the image
    - `seed` - Random seed for reproducibility
    - `guidance_scale` - How closely to follow the prompt (1.0-20.0, default: ~7.0)
    - `language` - Language code for prompt interpretation (e.g., "en", "es")
    - `add_watermark` - Whether to add a watermark (default: true)
    """

    field(:number_of_images, pos_integer(), default: 1)
    field(:aspect_ratio, String.t(), default: "1:1")

    field(:safety_filter_level, Gemini.Types.Generation.Image.safety_filter_level(),
      default: :block_some
    )

    field(:person_generation, Gemini.Types.Generation.Image.person_generation(),
      default: :allow_none
    )

    field(:output_mime_type, String.t(), default: "image/png")
    field(:output_compression_quality, integer())
    field(:negative_prompt, String.t())
    field(:seed, integer())
    field(:guidance_scale, float())
    field(:language, String.t())
    field(:add_watermark, boolean(), default: true)
  end

  @type t :: ImageGenerationConfig.t()

  typedstruct module: EditImageConfig do
    @derive Jason.Encoder
    @moduledoc """
    Configuration for image editing operations.

    ## Fields

    - `prompt` - Text description of desired edits
    - `edit_mode` - Type of editing operation (default: :inpainting)
    - `mask_mode` - How to interpret the mask (default: :foreground)
    - `mask_dilation` - Expand mask by pixels (0-50, default: 0)
    - `guidance_scale` - How closely to follow the prompt (default: ~15.0)
    - `number_of_images` - Number of variations to generate (1-8, default: 1)
    - `safety_filter_level` - Content safety filtering (default: :block_some)
    - `seed` - Random seed for reproducibility
    - `output_mime_type` - Output format (default: "image/png")
    """

    field(:prompt, String.t())
    field(:edit_mode, Gemini.Types.Generation.Image.edit_mode(), default: :inpainting)
    field(:mask_mode, atom(), default: :foreground)
    field(:mask_dilation, integer(), default: 0)
    field(:guidance_scale, float())
    field(:number_of_images, pos_integer(), default: 1)

    field(:safety_filter_level, Gemini.Types.Generation.Image.safety_filter_level(),
      default: :block_some
    )

    field(:seed, integer())
    field(:output_mime_type, String.t(), default: "image/png")
  end

  typedstruct module: UpscaleImageConfig do
    @derive Jason.Encoder
    @moduledoc """
    Configuration for image upscaling operations.

    ## Fields

    - `upscale_factor` - Scale factor for upscaling (default: :x2)
    - `output_mime_type` - Output format (default: "image/png")
    - `output_compression_quality` - JPEG quality 0-100 (only for JPEG)
    """

    field(:upscale_factor, Gemini.Types.Generation.Image.upscale_factor(), default: :x2)
    field(:output_mime_type, String.t(), default: "image/png")
    field(:output_compression_quality, integer())
  end

  typedstruct module: GeneratedImage do
    @derive Jason.Encoder
    @moduledoc """
    Represents a generated image result.

    ## Fields

    - `image_data` - Base64-encoded image data
    - `mime_type` - MIME type of the image
    - `image_size` - Size information (width, height in pixels)
    - `safety_attributes` - Safety classification results
    - `rai_info` - Responsible AI filtering information
    """

    field(:image_data, String.t())
    field(:mime_type, String.t())
    field(:image_size, map())
    field(:safety_attributes, map())
    field(:rai_info, map())
  end

  @doc """
  Converts API-style safety filter level string to atom.

  ## Examples

      iex> parse_safety_filter_level("BLOCK_SOME")
      :block_some

      iex> parse_safety_filter_level(:block_most)
      :block_most
  """
  @spec parse_safety_filter_level(String.t() | atom()) :: safety_filter_level()
  def parse_safety_filter_level(level) when is_atom(level), do: level

  def parse_safety_filter_level("BLOCK_MOST"), do: :block_most
  def parse_safety_filter_level("BLOCK_SOME"), do: :block_some
  def parse_safety_filter_level("BLOCK_FEW"), do: :block_few
  def parse_safety_filter_level("BLOCK_NONE"), do: :block_none
  def parse_safety_filter_level(_), do: :block_some

  @doc """
  Converts safety filter level atom to API format.

  ## Examples

      iex> format_safety_filter_level(:block_some)
      "blockSome"
  """
  @spec format_safety_filter_level(safety_filter_level()) :: String.t()
  def format_safety_filter_level(:block_most), do: "blockMost"
  def format_safety_filter_level(:block_some), do: "blockSome"
  def format_safety_filter_level(:block_few), do: "blockFew"
  def format_safety_filter_level(:block_none), do: "blockNone"

  @doc """
  Converts person generation policy to API format.

  ## Examples

      iex> format_person_generation(:allow_adult)
      "allowAdult"
  """
  @spec format_person_generation(person_generation()) :: String.t()
  def format_person_generation(:allow_adult), do: "allowAdult"
  def format_person_generation(:allow_all), do: "allowAll"
  def format_person_generation(:allow_none), do: "allowNone"
  def format_person_generation(:dont_allow), do: "allowNone"

  @doc """
  Converts edit mode to API format.

  ## Examples

      iex> format_edit_mode(:inpainting)
      "inpainting"
  """
  @spec format_edit_mode(edit_mode()) :: String.t()
  def format_edit_mode(:inpainting), do: "inpainting"
  def format_edit_mode(:outpainting), do: "outpainting"
  def format_edit_mode(:product_image), do: "productImage"

  @doc """
  Converts upscale factor to API format.

  ## Examples

      iex> format_upscale_factor(:x2)
      "x2"
  """
  @spec format_upscale_factor(upscale_factor()) :: String.t()
  def format_upscale_factor(:x2), do: "x2"
  def format_upscale_factor(:x4), do: "x4"

  @doc """
  Builds parameters map for image generation API request.
  """
  @spec build_generation_params(String.t(), ImageGenerationConfig.t()) :: map()
  def build_generation_params(prompt, config) do
    params = %{
      "prompt" => prompt,
      "sampleCount" => config.number_of_images,
      "aspectRatio" => config.aspect_ratio,
      "safetyFilterLevel" => format_safety_filter_level(config.safety_filter_level),
      "personGeneration" => format_person_generation(config.person_generation),
      "addWatermark" => config.add_watermark
    }

    params
    |> add_if_present("negativePrompt", config.negative_prompt)
    |> add_if_present("seed", config.seed)
    |> add_if_present("guidanceScale", config.guidance_scale)
    |> add_if_present("language", config.language)
    |> add_if_present("outputMimeType", config.output_mime_type)
    |> add_if_present("outputCompressionQuality", config.output_compression_quality)
  end

  @doc """
  Builds parameters map for image editing API request.
  """
  @spec build_edit_params(String.t(), String.t(), String.t() | nil, EditImageConfig.t()) ::
          map()
  def build_edit_params(prompt, image_data, mask_data, config) do
    params = %{
      "prompt" => prompt,
      "image" => %{"bytesBase64Encoded" => image_data},
      "editMode" => format_edit_mode(config.edit_mode),
      "sampleCount" => config.number_of_images,
      "safetyFilterLevel" => format_safety_filter_level(config.safety_filter_level)
    }

    params =
      if mask_data do
        Map.put(params, "mask", %{
          "image" => %{"bytesBase64Encoded" => mask_data},
          "mode" => config.mask_mode,
          "dilation" => config.mask_dilation
        })
      else
        params
      end

    params
    |> add_if_present("guidanceScale", config.guidance_scale)
    |> add_if_present("seed", config.seed)
    |> add_if_present("outputMimeType", config.output_mime_type)
  end

  @doc """
  Builds parameters map for image upscaling API request.
  """
  @spec build_upscale_params(String.t(), UpscaleImageConfig.t()) :: map()
  def build_upscale_params(image_data, config) do
    params = %{
      "image" => %{"bytesBase64Encoded" => image_data},
      "upscaleFactor" => format_upscale_factor(config.upscale_factor)
    }

    params
    |> add_if_present("outputMimeType", config.output_mime_type)
    |> add_if_present("outputCompressionQuality", config.output_compression_quality)
  end

  @doc """
  Parses a generated image from API response.
  """
  @spec parse_generated_image(map()) :: GeneratedImage.t()
  def parse_generated_image(data) when is_map(data) do
    %GeneratedImage{
      image_data: data["bytesBase64Encoded"],
      mime_type: data["mimeType"],
      image_size: data["imageSize"],
      safety_attributes: data["safetyAttributes"],
      rai_info: data["raiInfo"]
    }
  end

  # Private helpers

  defp add_if_present(map, _key, nil), do: map
  defp add_if_present(map, key, value), do: Map.put(map, key, value)
end
