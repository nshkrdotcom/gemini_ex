defmodule Gemini.Types.Interactions.ImageConfig do
  @moduledoc """
  Configuration for image generation in Interactions.

  This type controls image generation parameters when using the Interactions API
  with image generation capabilities.

  ## Aspect Ratios

  The following aspect ratios are supported:

  | Ratio | Description |
  |-------|-------------|
  | `"1:1"` | Square format |
  | `"2:3"` | Portrait (vertical) |
  | `"3:2"` | Landscape (horizontal) |
  | `"3:4"` | Portrait (vertical) |
  | `"4:3"` | Landscape (horizontal), standard photo |
  | `"4:5"` | Portrait (vertical), Instagram-style |
  | `"5:4"` | Landscape (horizontal) |
  | `"9:16"` | Portrait (vertical), phone screen/stories |
  | `"16:9"` | Landscape (horizontal), widescreen |
  | `"21:9"` | Ultrawide panoramic |

  ## Image Sizes

  The following image sizes are supported:

  | Size | Description |
  |------|-------------|
  | `"1K"` | ~1024 pixels on the longest edge |
  | `"2K"` | ~2048 pixels on the longest edge |
  | `"4K"` | ~4096 pixels on the longest edge |

  ## Example

      config = %Gemini.Types.Interactions.ImageConfig{
        aspect_ratio: "16:9",
        image_size: "2K"
      }

      # Use in Interactions generation config
      Gemini.APIs.Interactions.create(
        session_id: session_id,
        input: "Generate an image of a sunset",
        config: %{
          generation_config: %{
            image_config: config
          }
        }
      )
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @valid_aspect_ratios ~w(1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9 21:9)
  @valid_image_sizes ~w(1K 2K 4K)

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Image generation configuration.

    - `aspect_ratio` - The aspect ratio for generated images
    - `image_size` - The size/resolution for generated images
    """
    field(:aspect_ratio, String.t())
    field(:image_size, String.t())
  end

  @doc """
  Creates a new ImageConfig with validation.

  Raises `ArgumentError` if invalid values are provided.

  ## Parameters

  - `opts` - Keyword list with configuration:
    - `:aspect_ratio` - One of #{inspect(@valid_aspect_ratios)}
    - `:image_size` - One of #{inspect(@valid_image_sizes)}

  ## Examples

      ImageConfig.new(aspect_ratio: "16:9", image_size: "2K")
      #=> %ImageConfig{aspect_ratio: "16:9", image_size: "2K"}

      ImageConfig.new(aspect_ratio: "4:5")
      #=> %ImageConfig{aspect_ratio: "4:5", image_size: nil}

      ImageConfig.new(aspect_ratio: "invalid")
      #=> ** (ArgumentError) Invalid aspect_ratio: invalid
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    aspect_ratio = Keyword.get(opts, :aspect_ratio)
    image_size = Keyword.get(opts, :image_size)

    validate_aspect_ratio!(aspect_ratio)
    validate_image_size!(image_size)

    %__MODULE__{
      aspect_ratio: aspect_ratio,
      image_size: image_size
    }
  end

  @doc """
  Creates an ImageConfig from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = config), do: config

  def from_api(%{} = data) do
    %__MODULE__{
      aspect_ratio: data["aspect_ratio"] || data["aspectRatio"],
      image_size: data["image_size"] || data["imageSize"]
    }
  end

  @doc """
  Converts ImageConfig to API format with snake_case keys.
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = config) do
    %{}
    |> maybe_put("aspect_ratio", config.aspect_ratio)
    |> maybe_put("image_size", config.image_size)
  end

  @doc """
  Returns the list of valid aspect ratios.
  """
  @spec valid_aspect_ratios() :: [String.t()]
  def valid_aspect_ratios, do: @valid_aspect_ratios

  @doc """
  Returns the list of valid image sizes.
  """
  @spec valid_image_sizes() :: [String.t()]
  def valid_image_sizes, do: @valid_image_sizes

  @doc """
  Checks if an aspect ratio is valid.
  """
  @spec valid_aspect_ratio?(String.t()) :: boolean()
  def valid_aspect_ratio?(ratio) when is_binary(ratio), do: ratio in @valid_aspect_ratios
  def valid_aspect_ratio?(_), do: false

  @doc """
  Checks if an image size is valid.
  """
  @spec valid_image_size?(String.t()) :: boolean()
  def valid_image_size?(size) when is_binary(size), do: size in @valid_image_sizes
  def valid_image_size?(_), do: false

  # Private validation helpers

  defp validate_aspect_ratio!(nil), do: :ok

  defp validate_aspect_ratio!(ratio) when is_binary(ratio) do
    if ratio in @valid_aspect_ratios do
      :ok
    else
      raise ArgumentError, """
      Invalid aspect_ratio: #{inspect(ratio)}

      Valid aspect ratios: #{inspect(@valid_aspect_ratios)}
      """
    end
  end

  defp validate_image_size!(nil), do: :ok

  defp validate_image_size!(size) when is_binary(size) do
    if size in @valid_image_sizes do
      :ok
    else
      raise ArgumentError, """
      Invalid image_size: #{inspect(size)}

      Valid image sizes: #{inspect(@valid_image_sizes)}
      """
    end
  end
end
