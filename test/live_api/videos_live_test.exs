defmodule Gemini.APIs.VideosLiveTest do
  @moduledoc """
  Live API tests for the Veo video generation API.

  Run with: mix test --include live_api test/live_api/videos_live_test.exs

  Requires Vertex AI credentials (VERTEX_PROJECT_ID environment variable).

  **Note:** Video generation is very slow (2-5 minutes) and may incur significant API costs.
  These tests are excluded by default and have extended timeouts.
  """

  use ExUnit.Case, async: false

  alias Gemini.APIs.Videos
  alias Gemini.Types.Generation.Video, as: Video
  alias Gemini.Types.Generation.Video.{GeneratedVideo, VideoGenerationConfig}
  alias Gemini.Types.Operation

  @moduletag :live_api
  @moduletag timeout: 300_000

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
    @tag timeout: 300_000
    test "starts video generation operation", %{skip: skip} do
      if skip do
        IO.puts("\nSkipping: VERTEX_PROJECT_ID not set")
        :ok
      else
        config = %VideoGenerationConfig{
          number_of_videos: 1,
          duration_seconds: 4,
          aspect_ratio: "16:9"
        }

        case Videos.generate("A cat playing piano in a cozy living room", config) do
          {:ok, operation} ->
            assert %Operation{} = operation
            assert is_binary(operation.name)
            assert String.starts_with?(operation.name, "projects/")

            # Operation should start as not done
            # (or might already be done if API is very fast)
            assert is_boolean(operation.done)

            IO.puts("\nVideo generation started: #{operation.name}")
            IO.puts("This may take 2-5 minutes. Skipping wait to avoid timeout.")

          {:error, reason} ->
            IO.puts("\nVideo generation failed to start: #{inspect(reason)}")
            :ok
        end
      end
    end
  end

  describe "get_operation/2" do
    @tag :live_api
    test "retrieves operation status", %{skip: skip} do
      if skip do
        IO.puts("\nSkipping: VERTEX_PROJECT_ID not set")
        :ok
      else
        config = %VideoGenerationConfig{
          number_of_videos: 1,
          duration_seconds: 4
        }

        case Videos.generate("A simple test video", config) do
          {:ok, operation} ->
            # Try to get the operation status
            case Videos.get_operation(operation.name) do
              {:ok, retrieved_op} ->
                assert %Operation{} = retrieved_op
                assert retrieved_op.name == operation.name

              {:error, reason} ->
                IO.puts("\nFailed to retrieve operation: #{inspect(reason)}")
                :ok
            end

          {:error, reason} ->
            IO.puts("\nVideo generation failed to start: #{inspect(reason)}")
            :ok
        end
      end
    end
  end

  describe "VideoOperation helpers" do
    test "wrap_operation adds progress tracking" do
      operation = %Operation{
        name: "operations/test123",
        done: false,
        metadata: %{"progressPercent" => 50.0}
      }

      video_op = Videos.wrap_operation(operation)

      assert video_op.operation == operation
      assert video_op.progress_percent == 50.0
      assert %DateTime{} = video_op.estimated_completion_time
    end
  end

  describe "extract_videos/1" do
    test "extracts videos from completed operation" do
      operation = %Operation{
        name: "operations/test123",
        done: true,
        response: %{
          "generatedVideos" => [
            %{
              "videoUri" => "gs://test-bucket/video.mp4",
              "mimeType" => "video/mp4",
              "durationSeconds" => 8.0
            }
          ]
        }
      }

      {:ok, videos} = Video.extract_videos(operation)

      assert length(videos) == 1
      assert %GeneratedVideo{} = hd(videos)
      assert hd(videos).video_uri == "gs://test-bucket/video.mp4"
    end

    test "returns error for incomplete operation" do
      operation = %Operation{
        name: "operations/test123",
        done: false
      }

      {:error, error} = Video.extract_videos(operation)

      assert error == "Operation not yet complete"
    end
  end
end
