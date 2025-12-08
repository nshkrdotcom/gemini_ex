defmodule Gemini.LiveAPI.Gemini3ImagePreviewLiveTest do
  @moduledoc """
  Live smoke test for `gemini-3-pro-image-preview` using the Gemini API key.

  Run with:
    mix test --include live_api test/live_api/gemini3_image_preview_live_test.exs

  Saves the first returned image under the gitignored `generated/` directory.
  """

  use ExUnit.Case, async: false

  alias Gemini.Types.GenerationConfig

  @moduletag :live_api
  @moduletag timeout: 180_000

  setup do
    api_key = System.get_env("GEMINI_API_KEY")

    cond do
      is_nil(api_key) or api_key == "" ->
        {:ok, skip: true}

      true ->
        File.mkdir_p!("generated")
        {:ok, skip: false}
    end
  end

  test "generates an image and writes it to generated/", %{skip: skip?} do
    if skip? do
      IO.puts("\nSkipping live image preview test: GEMINI_API_KEY not set")
      assert true
    else
      config =
        GenerationConfig.new()
        |> GenerationConfig.image_config(
          aspect_ratio: "1:1",
          image_size: "1K"
        )
        |> GenerationConfig.response_modalities([:image])

      case Gemini.generate("Create a clean, minimal banana icon on white",
             model: "gemini-3-pro-image-preview",
             generation_config: config
           ) do
        {:ok, response} ->
          images =
            for %{content: %{parts: parts}} <- response.candidates,
                %{inline_data: %{data: data, mime_type: mime}} <- parts do
              {data, mime}
            end

          assert images != [], "Expected at least one inline image in the response"

          {data, mime} = hd(images)
          assert String.starts_with?(mime, "image/")

          {:ok, bin} = Base.decode64(data)
          output_path = Path.join("generated", "gemini3_image_preview_live.png")
          File.write!(output_path, bin)

          assert File.exists?(output_path)

        {:error, reason} ->
          flunk("Live image preview call failed: #{inspect(reason)}")
      end
    end
  end
end
