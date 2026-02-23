defmodule Gemini.APIs.VideosTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Videos
  alias Gemini.Types.Blob
  alias Gemini.Types.Generation.Video, as: Video

  alias Gemini.Types.Generation.Video.{
    GeneratedVideo,
    VideoGenerationConfig,
    VideoGenerationReferenceImage,
    VideoOperation
  }

  alias Gemini.Types.Operation

  @moduletag :unit

  describe "generate/3" do
    test "validates VideoGenerationConfig struct" do
      config = %VideoGenerationConfig{
        number_of_videos: 2,
        duration_seconds: 8,
        aspect_ratio: "16:9"
      }

      assert config.number_of_videos == 2
      assert config.duration_seconds == 8
      assert config.aspect_ratio == "16:9"
    end

    test "uses default config values" do
      config = %VideoGenerationConfig{}

      assert config.number_of_videos == 1
      assert config.duration_seconds == 8
      assert config.aspect_ratio == "16:9"
      assert config.fps == 24
      assert config.compression_format == :h264
      assert config.safety_filter_level == :block_some
      assert config.person_generation == :dont_allow
    end

    test "accepts custom config values" do
      config = %VideoGenerationConfig{
        number_of_videos: 2,
        duration_seconds: 4,
        aspect_ratio: "9:16",
        fps: 30,
        compression_format: :h265,
        safety_filter_level: :block_few,
        negative_prompt: "low quality",
        seed: 12_345,
        guidance_scale: 10.0,
        person_generation: :allow_adult
      }

      assert config.number_of_videos == 2
      assert config.duration_seconds == 4
      assert config.aspect_ratio == "9:16"
      assert config.fps == 30
      assert config.compression_format == :h265
      assert config.safety_filter_level == :block_few
      assert config.negative_prompt == "low quality"
      assert config.seed == 12_345
      assert config.guidance_scale == 10.0
      assert config.person_generation == :allow_adult
    end

    test "accepts Veo 3.x fields" do
      image = %Blob{data: "image-data", mime_type: "image/png"}
      last_frame = %Blob{data: "frame-data", mime_type: "image/png"}

      reference = %VideoGenerationReferenceImage{
        image: %Blob{data: "ref-data", mime_type: "image/png"},
        reference_type: "asset"
      }

      config = %VideoGenerationConfig{
        image: image,
        last_frame: last_frame,
        reference_images: [reference],
        video: %{"gcsUri" => "gs://bucket/video.mp4"},
        resolution: "1080p"
      }

      assert config.image == image
      assert config.last_frame == last_frame
      assert config.reference_images == [reference]
      assert config.video == %{"gcsUri" => "gs://bucket/video.mp4"}
      assert config.resolution == "1080p"
    end
  end

  describe "GeneratedVideo" do
    test "parses generated video from API response" do
      api_response = %{
        "videoUri" => "gs://bucket/video.mp4",
        "mimeType" => "video/mp4",
        "durationSeconds" => 8.0,
        "resolution" => %{"width" => 1280, "height" => 720},
        "safetyAttributes" => %{"blocked" => false},
        "raiInfo" => %{"blocked_reason" => nil}
      }

      video = Video.parse_generated_video(api_response)

      assert %GeneratedVideo{} = video
      assert video.video_uri == "gs://bucket/video.mp4"
      assert video.mime_type == "video/mp4"
      assert video.duration_seconds == 8.0
      assert video.resolution == %{"width" => 1280, "height" => 720}
      assert video.safety_attributes == %{"blocked" => false}
      assert video.rai_info == %{"blocked_reason" => nil}
    end

    test "parses video with gcsUri instead of videoUri" do
      api_response = %{
        "gcsUri" => "gs://bucket/video.mp4",
        "mimeType" => "video/mp4"
      }

      video = Video.parse_generated_video(api_response)

      assert video.video_uri == "gs://bucket/video.mp4"
    end

    test "parses video with base64 data" do
      api_response = %{
        "bytesBase64Encoded" => "base64videodata...",
        "mimeType" => "video/mp4"
      }

      video = Video.parse_generated_video(api_response)

      assert video.video_data == "base64videodata..."
    end
  end

  describe "VideoOperation" do
    test "wraps operation with video metadata" do
      operation = %Operation{
        name: "operations/abc123",
        done: false,
        metadata: %{"progressPercent" => 50.0}
      }

      video_op = Video.wrap_operation(operation)

      assert %VideoOperation{} = video_op
      assert video_op.operation == operation
      assert video_op.progress_percent == 50.0
      assert %DateTime{} = video_op.estimated_completion_time
    end

    test "complete? returns true when operation is done" do
      operation = %Operation{name: "ops/123", done: true}
      video_op = Video.wrap_operation(operation)

      assert Video.complete?(video_op)
    end

    test "complete? returns false when operation is not done" do
      operation = %Operation{name: "ops/123", done: false}
      video_op = Video.wrap_operation(operation)

      refute Video.complete?(video_op)
    end

    test "succeeded? returns true when operation succeeded" do
      operation = %Operation{name: "ops/123", done: true, error: nil}
      video_op = Video.wrap_operation(operation)

      assert Video.succeeded?(video_op)
    end

    test "failed? returns true when operation failed" do
      operation = %Operation{
        name: "ops/123",
        done: true,
        error: %{message: "Failed", code: 500}
      }

      video_op = Video.wrap_operation(operation)

      assert Video.failed?(video_op)
    end
  end

  describe "extract_videos/1" do
    test "extracts videos from completed operation" do
      operation = %Operation{
        name: "ops/123",
        done: true,
        response: %{
          "generatedVideos" => [
            %{"videoUri" => "gs://bucket/video1.mp4", "mimeType" => "video/mp4"},
            %{"videoUri" => "gs://bucket/video2.mp4", "mimeType" => "video/mp4"}
          ]
        }
      }

      {:ok, videos} = Video.extract_videos(operation)

      assert length(videos) == 2
      assert Enum.all?(videos, &match?(%GeneratedVideo{}, &1))
      assert hd(videos).video_uri == "gs://bucket/video1.mp4"
    end

    test "extracts videos from predictions field" do
      operation = %Operation{
        name: "ops/123",
        done: true,
        response: %{
          "predictions" => [
            %{"videoUri" => "gs://bucket/video.mp4", "mimeType" => "video/mp4"}
          ]
        }
      }

      {:ok, videos} = Video.extract_videos(operation)

      assert length(videos) == 1
      assert hd(videos).video_uri == "gs://bucket/video.mp4"
    end

    test "returns error when operation failed" do
      operation = %Operation{
        name: "ops/123",
        done: true,
        error: %{message: "Generation failed", code: 500}
      }

      {:error, error} = Video.extract_videos(operation)

      assert error == %{message: "Generation failed", code: 500}
    end

    test "returns error when operation not complete" do
      operation = %Operation{
        name: "ops/123",
        done: false
      }

      {:error, error} = Video.extract_videos(operation)

      assert error == "Operation not yet complete"
    end
  end

  describe "type conversions" do
    test "format_compression_format converts atoms to API format" do
      assert Video.format_compression_format(:h264) == "h264"
      assert Video.format_compression_format(:h265) == "h265"
    end

    test "format_safety_filter_level converts atoms to API format" do
      assert Video.format_safety_filter_level(:block_most) ==
               "blockMost"

      assert Video.format_safety_filter_level(:block_some) ==
               "blockSome"

      assert Video.format_safety_filter_level(:block_few) == "blockFew"

      assert Video.format_safety_filter_level(:block_none) ==
               "blockNone"
    end

    test "format_person_generation converts atoms to API format" do
      assert Video.format_person_generation(:allow_adult) ==
               "allow_adult"

      assert Video.format_person_generation(:allow_all) == "allow_all"

      assert Video.format_person_generation(:allow_none) == "dont_allow"
      assert Video.format_person_generation(:dont_allow) == "dont_allow"
    end
  end

  describe "request parameter building" do
    test "build_generation_params creates proper API request" do
      config = %VideoGenerationConfig{
        number_of_videos: 2,
        duration_seconds: 8,
        aspect_ratio: "16:9",
        fps: 30,
        compression_format: :h265,
        resolution: "1080p"
      }

      params = Video.build_generation_params("A cat", config)

      assert params["prompt"] == "A cat"
      assert params["numberOfVideos"] == 2
      assert params["durationSeconds"] == 8
      assert params["aspectRatio"] == "16:9"
      assert params["resolution"] == "1080p"
      assert params["personGeneration"] == "dont_allow"
    end

    test "build_generation_params includes optional fields" do
      config = %VideoGenerationConfig{
        number_of_videos: 1,
        negative_prompt: "low quality",
        seed: 12_345
      }

      params = Video.build_generation_params("A cat", config)

      assert params["negativePrompt"] == "low quality"
      assert params["seed"] == 12_345
    end

    test "build_generation_params omits nil optional fields" do
      config = %VideoGenerationConfig{
        number_of_videos: 1
      }

      params = Video.build_generation_params("A cat", config)

      refute Map.has_key?(params, "negativePrompt")
      refute Map.has_key?(params, "seed")
      refute Map.has_key?(params, "safetyFilterLevel")
      refute Map.has_key?(params, "videoConfig")
    end
  end

  describe "API functions" do
    test "validates function signatures" do
      # Verify all public API functions exist using deterministic module info
      # ensure_loaded returns {:module, ModuleName} on success
      {:module, Videos} = Code.ensure_loaded(Videos)
      functions = Videos.__info__(:functions)

      assert {:generate, 3} in functions
      assert {:get_operation, 2} in functions
      assert {:wait_for_completion, 2} in functions
      assert {:cancel, 2} in functions
      assert {:list_operations, 1} in functions
      assert {:wrap_operation, 1} in functions
    end
  end
end
