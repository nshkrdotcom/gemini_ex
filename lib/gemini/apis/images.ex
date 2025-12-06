defmodule Gemini.APIs.Images do
  @moduledoc """
  API for image generation using Google's Imagen models.

  Imagen is Google's family of text-to-image models that can generate, edit, and
  upscale high-quality images from text descriptions. This module provides a unified
  interface for all image generation operations.

  **Note:** Image generation is currently only available through Vertex AI, not the
  Gemini API. You must configure Vertex AI credentials to use these functions.

  ## Supported Models

  - `imagegeneration@006` - Latest stable Imagen model (recommended)
  - `imagen-3.0-generate-001` - Imagen 3.0 generation model

  ## Capabilities

  - **Text-to-Image**: Generate images from text descriptions
  - **Image Editing**: Modify existing images with inpainting/outpainting
  - **Image Upscaling**: Enhance image resolution (2x or 4x)

  ## Examples

      # Generate an image
      {:ok, images} = Gemini.APIs.Images.generate(
        "A serene mountain landscape at sunset",
        %ImageGenerationConfig{
          number_of_images: 2,
          aspect_ratio: "16:9"
        }
      )

      # Edit an image
      {:ok, edited} = Gemini.APIs.Images.edit(
        "Replace the sky with a starry night",
        image_base64,
        mask_base64,
        %EditImageConfig{edit_mode: :inpainting}
      )

      # Upscale an image
      {:ok, upscaled} = Gemini.APIs.Images.upscale(
        image_base64,
        %UpscaleImageConfig{upscale_factor: :x2}
      )

  ## Configuration Options

  See `Gemini.Types.Generation.Image` for all available configuration options.

  ## Safety and Responsible AI

  All generated images are subject to Google's safety filters and Responsible AI
  policies. You can configure the safety filter level, but some content will always
  be blocked regardless of settings.
  """

  alias Gemini.Client.HTTP
  alias Gemini.Config
  alias Gemini.Error

  alias Gemini.Types.Generation.Image.{
    ImageGenerationConfig,
    EditImageConfig,
    UpscaleImageConfig,
    GeneratedImage
  }

  @type api_result(t) :: {:ok, t} | {:error, term()}
  @type generation_opts :: [
          model: String.t(),
          project_id: String.t(),
          location: String.t()
        ]

  @default_model "imagegeneration@006"
  @default_location "us-central1"

  # ===========================================================================
  # Image Generation API
  # ===========================================================================

  @doc """
  Generate images from a text prompt.

  ## Parameters

  - `prompt` - Text description of the image to generate
  - `config` - ImageGenerationConfig struct with generation parameters (default: %ImageGenerationConfig{})
  - `opts` - Additional options:
    - `:model` - Model to use (default: "imagegeneration@006")
    - `:project_id` - Vertex AI project ID (default: from config)
    - `:location` - Vertex AI location (default: "us-central1")

  ## Returns

  - `{:ok, [GeneratedImage.t()]}` - List of generated images
  - `{:error, term()}` - Error if generation fails

  ## Examples

      # Simple generation
      {:ok, images} = Gemini.APIs.Images.generate(
        "A cat playing piano"
      )

      # With configuration
      config = %ImageGenerationConfig{
        number_of_images: 4,
        aspect_ratio: "1:1",
        safety_filter_level: :block_some,
        person_generation: :allow_adult
      }
      {:ok, images} = Gemini.APIs.Images.generate(
        "Professional headshot photo",
        config
      )

      # Custom model and location
      {:ok, images} = Gemini.APIs.Images.generate(
        "Futuristic cityscape",
        config,
        model: "imagen-3.0-generate-001",
        location: "europe-west4"
      )
  """
  @spec generate(String.t(), ImageGenerationConfig.t(), generation_opts()) ::
          api_result([GeneratedImage.t()])
  def generate(prompt, config \\ %ImageGenerationConfig{}, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    location = Keyword.get(opts, :location, @default_location)

    project_id = get_project_id(opts)

    with :ok <- validate_vertex_ai_config(),
         {:ok, path} <- build_predict_path(project_id, location, model),
         {:ok, request_body} <- build_generation_request(prompt, config) do
      case HTTP.post(path, request_body, opts) do
        {:ok, response} -> parse_generation_response(response)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Edit an existing image using text prompts.

  Supports inpainting (editing specific regions) and outpainting (extending the image).

  ## Parameters

  - `prompt` - Text description of the desired edits
  - `image_data` - Base64-encoded source image
  - `mask_data` - Base64-encoded mask image (nil for auto-masking)
  - `config` - EditImageConfig struct (default: %EditImageConfig{})
  - `opts` - Additional options (same as `generate/3`)

  ## Returns

  - `{:ok, [GeneratedImage.t()]}` - List of edited images
  - `{:error, term()}` - Error if editing fails

  ## Examples

      # Inpainting - edit specific region
      {:ok, edited} = Gemini.APIs.Images.edit(
        "Replace the background with a beach scene",
        image_base64,
        mask_base64,
        %EditImageConfig{edit_mode: :inpainting}
      )

      # Outpainting - extend image
      {:ok, extended} = Gemini.APIs.Images.edit(
        "Continue the landscape to the right",
        image_base64,
        mask_base64,
        %EditImageConfig{edit_mode: :outpainting}
      )
  """
  @spec edit(String.t(), String.t(), String.t() | nil, EditImageConfig.t(), generation_opts()) ::
          api_result([GeneratedImage.t()])
  def edit(prompt, image_data, mask_data \\ nil, config \\ %EditImageConfig{}, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    location = Keyword.get(opts, :location, @default_location)
    project_id = get_project_id(opts)

    with :ok <- validate_vertex_ai_config(),
         {:ok, path} <- build_predict_path(project_id, location, model),
         {:ok, request_body} <- build_edit_request(prompt, image_data, mask_data, config) do
      case HTTP.post(path, request_body, opts) do
        {:ok, response} -> parse_generation_response(response)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Upscale an image to higher resolution.

  ## Parameters

  - `image_data` - Base64-encoded source image
  - `config` - UpscaleImageConfig struct (default: %UpscaleImageConfig{})
  - `opts` - Additional options (same as `generate/3`)

  ## Returns

  - `{:ok, [GeneratedImage.t()]}` - List containing upscaled image
  - `{:error, term()}` - Error if upscaling fails

  ## Examples

      # 2x upscale
      {:ok, [upscaled]} = Gemini.APIs.Images.upscale(
        image_base64,
        %UpscaleImageConfig{upscale_factor: :x2}
      )

      # 4x upscale with JPEG output
      {:ok, [upscaled]} = Gemini.APIs.Images.upscale(
        image_base64,
        %UpscaleImageConfig{
          upscale_factor: :x4,
          output_mime_type: "image/jpeg",
          output_compression_quality: 90
        }
      )
  """
  @spec upscale(String.t(), UpscaleImageConfig.t(), generation_opts()) ::
          api_result([GeneratedImage.t()])
  def upscale(image_data, config \\ %UpscaleImageConfig{}, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    location = Keyword.get(opts, :location, @default_location)
    project_id = get_project_id(opts)

    with :ok <- validate_vertex_ai_config(),
         {:ok, path} <- build_predict_path(project_id, location, model),
         {:ok, request_body} <- build_upscale_request(image_data, config) do
      case HTTP.post(path, request_body, opts) do
        {:ok, response} -> parse_generation_response(response)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # ===========================================================================
  # Request Building
  # ===========================================================================

  @spec build_predict_path(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  defp build_predict_path(project_id, location, model) do
    path =
      "projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:predict"

    {:ok, path}
  end

  @spec build_generation_request(String.t(), ImageGenerationConfig.t()) ::
          {:ok, map()} | {:error, term()}
  defp build_generation_request(prompt, config) do
    params = Gemini.Types.Generation.Image.build_generation_params(prompt, config)

    request = %{
      "instances" => [%{"prompt" => prompt}],
      "parameters" => params
    }

    {:ok, request}
  end

  @spec build_edit_request(String.t(), String.t(), String.t() | nil, EditImageConfig.t()) ::
          {:ok, map()} | {:error, term()}
  defp build_edit_request(prompt, image_data, mask_data, config) do
    params =
      Gemini.Types.Generation.Image.build_edit_params(prompt, image_data, mask_data, config)

    request = %{
      "instances" => [params],
      "parameters" => %{}
    }

    {:ok, request}
  end

  @spec build_upscale_request(String.t(), UpscaleImageConfig.t()) ::
          {:ok, map()} | {:error, term()}
  defp build_upscale_request(image_data, config) do
    params = Gemini.Types.Generation.Image.build_upscale_params(image_data, config)

    request = %{
      "instances" => [params],
      "parameters" => %{}
    }

    {:ok, request}
  end

  # ===========================================================================
  # Response Parsing
  # ===========================================================================

  @spec parse_generation_response(map()) :: {:ok, [GeneratedImage.t()]} | {:error, term()}
  defp parse_generation_response(%{"predictions" => predictions}) when is_list(predictions) do
    images =
      predictions
      |> Enum.flat_map(fn prediction ->
        # Handle both single image and multiple images in response
        cond do
          is_map(prediction) and Map.has_key?(prediction, "bytesBase64Encoded") ->
            [Gemini.Types.Generation.Image.parse_generated_image(prediction)]

          is_map(prediction) and Map.has_key?(prediction, "generatedImages") ->
            Enum.map(
              prediction["generatedImages"],
              &Gemini.Types.Generation.Image.parse_generated_image/1
            )

          true ->
            []
        end
      end)

    {:ok, images}
  end

  defp parse_generation_response(%{"error" => error}) do
    {:error, Error.api_error(:api_error, error["message"] || "Image generation failed")}
  end

  defp parse_generation_response(response) do
    {:error, Error.api_error(:api_error, "Unexpected response format: #{inspect(response)}")}
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  @spec validate_vertex_ai_config() :: :ok | {:error, term()}
  defp validate_vertex_ai_config do
    case Config.auth_config() do
      %{type: :vertex_ai} ->
        :ok

      %{type: :gemini} ->
        {:error,
         Error.config_error(
           "Image generation requires Vertex AI authentication. " <>
             "Please configure VERTEX_PROJECT_ID and either VERTEX_LOCATION or service account credentials."
         )}

      nil ->
        {:error,
         Error.config_error(
           "No authentication configured. Image generation requires Vertex AI credentials."
         )}
    end
  end

  @spec get_project_id(keyword()) :: String.t()
  defp get_project_id(opts) do
    case Keyword.get(opts, :project_id) do
      nil ->
        case Config.auth_config() do
          %{credentials: %{project_id: project_id}} -> project_id
          _ -> nil
        end

      project_id ->
        project_id
    end
  end
end
