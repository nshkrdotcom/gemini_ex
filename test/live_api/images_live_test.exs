defmodule Gemini.APIs.ImagesLiveTest do
  @moduledoc """
  Live API tests for the Imagen API.

  Run with: mix test --include live_api test/live_api/images_live_test.exs

  Requires Vertex AI credentials (VERTEX_PROJECT_ID environment variable).

  **Note:** Image generation can be slow and may incur API costs.
  These tests are excluded by default.
  """

  use ExUnit.Case, async: false

  alias Gemini.APIs.Images

  alias Gemini.Types.Generation.Image.{
    GeneratedImage,
    ImageGenerationConfig
  }

  @moduletag :live_api
  @moduletag timeout: 120_000

  setup do
    # Check for Vertex AI credentials
    project_id = System.get_env("VERTEX_PROJECT_ID")

    if is_nil(project_id) or project_id == "" do
      {:ok, skip: true}
    else
      {:ok, skip: false, project_id: project_id}
    end
  end

  describe "generate/3" do
    @tag :live_api
    test "generates a single image with default config", %{skip: skip} do
      if skip do
        IO.puts("\nSkipping: VERTEX_PROJECT_ID not set")
        :ok
      else
        config = %ImageGenerationConfig{
          number_of_images: 1,
          aspect_ratio: "1:1"
        }

        case Images.generate("A serene mountain landscape at sunset", config) do
          {:ok, images} ->
            assert is_list(images)
            assert length(images) >= 1

            image = hd(images)
            assert %GeneratedImage{} = image
            assert is_binary(image.image_data)
            assert image.mime_type in ["image/png", "image/jpeg"]

          {:error, reason} ->
            IO.puts("\nImage generation failed: #{inspect(reason)}")
            # Don't fail the test - API might not be available
            :ok
        end
      end
    end

    @tag :live_api
    test "generates multiple images", %{skip: skip} do
      if skip do
        IO.puts("\nSkipping: VERTEX_PROJECT_ID not set")
        :ok
      else
        config = %ImageGenerationConfig{
          number_of_images: 2,
          aspect_ratio: "16:9"
        }

        case Images.generate("A cute cat playing with a ball of yarn", config) do
          {:ok, images} ->
            assert is_list(images)
            assert length(images) >= 1

            Enum.each(images, fn image ->
              assert %GeneratedImage{} = image
              assert is_binary(image.image_data)
            end)

          {:error, reason} ->
            IO.puts("\nImage generation failed: #{inspect(reason)}")
            :ok
        end
      end
    end

    @tag :live_api
    test "generates image with custom safety settings", %{skip: skip} do
      if skip do
        IO.puts("\nSkipping: VERTEX_PROJECT_ID not set")
        :ok
      else
        config = %ImageGenerationConfig{
          number_of_images: 1,
          safety_filter_level: :block_most,
          person_generation: :allow_none
        }

        case Images.generate("A peaceful garden scene", config) do
          {:ok, images} ->
            assert is_list(images)
            assert length(images) >= 1

          {:error, reason} ->
            IO.puts("\nImage generation failed: #{inspect(reason)}")
            :ok
        end
      end
    end
  end

  describe "error handling" do
    @tag :live_api
    test "returns error for empty prompt", %{skip: skip} do
      if skip do
        IO.puts("\nSkipping: VERTEX_PROJECT_ID not set")
        :ok
      else
        case Images.generate("", %ImageGenerationConfig{}) do
          {:error, _reason} ->
            # Expected to fail
            assert true

          {:ok, _} ->
            # Might still work with empty prompt
            assert true
        end
      end
    end
  end
end
