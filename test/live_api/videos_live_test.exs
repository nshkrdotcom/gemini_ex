defmodule Gemini.APIs.VideosLiveTest do
  @moduledoc """
  Live API tests for the Veo video generation API.

  Run with: mix test --include live_api test/live_api/videos_live_test.exs

  Requires either:
  - Gemini API credentials (`GEMINI_API_KEY` or `GOOGLE_API_KEY`)
  - Vertex AI credentials (`VERTEX_PROJECT_ID`, location, and token/ADC)

  **Note:** Video generation is very slow (2-5 minutes) and may incur significant API costs.
  These tests are excluded by default and have extended timeouts.
  """

  use ExUnit.Case, async: false

  alias Gemini.APIs.Videos
  alias Gemini.Error
  alias Gemini.Test.AuthHelpers
  alias Gemini.Types.Generation.Video, as: Video
  alias Gemini.Types.Generation.Video.{GeneratedVideo, VideoGenerationConfig}
  alias Gemini.Types.Operation

  @moduletag :live_api
  @moduletag timeout: 300_000

  setup do
    case AuthHelpers.detect_auth(:gemini) do
      {:ok, :gemini, _} ->
        {:ok, skip: false, request_opts: [auth: :gemini]}

      _ ->
        case AuthHelpers.detect_auth(:vertex_ai) do
          {:ok, :vertex_ai, creds} ->
            {:ok,
             skip: false,
             request_opts: [
               auth: :vertex_ai,
               project_id: Map.get(creds, :project_id),
               location: Map.get(creds, :location)
             ]}

          _ ->
            {:ok, skip: true, request_opts: []}
        end
    end
  end

  describe "generate/3" do
    @tag :live_api
    @tag timeout: 300_000
    test "starts video generation operation", %{skip: skip, request_opts: request_opts} do
      if skip do
        :ok
      else
        config = %VideoGenerationConfig{
          number_of_videos: 1,
          duration_seconds: 4,
          aspect_ratio: "16:9"
        }

        case Videos.generate("A cat playing piano in a cozy living room", config, request_opts) do
          {:ok, operation} ->
            assert %Operation{} = operation
            assert is_binary(operation.name)
            assert String.starts_with?(operation.name, "projects/")

            # Operation should start as not done
            # (or might already be done if API is very fast)
            assert is_boolean(operation.done)

          {:error, reason} ->
            assert_not_schema_error!(reason)
            :ok
        end
      end
    end
  end

  describe "get_operation/2" do
    @tag :live_api
    test "retrieves operation status", %{skip: skip, request_opts: request_opts} do
      if skip do
        :ok
      else
        config = %VideoGenerationConfig{
          number_of_videos: 1,
          duration_seconds: 4
        }

        case Videos.generate("A simple test video", config, request_opts) do
          {:ok, operation} ->
            # Try to get the operation status
            case Videos.get_operation(operation.name, request_opts) do
              {:ok, retrieved_op} ->
                assert %Operation{} = retrieved_op
                assert retrieved_op.name == operation.name

              {:error, reason} ->
                assert_not_schema_error!(reason)
                :ok
            end

          {:error, reason} ->
            assert_not_schema_error!(reason)
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

  defp assert_not_schema_error!(reason) do
    message = error_message(reason)

    if String.contains?(message, "`videoConfig` isn't supported") or
         String.contains?(message, "`safetyFilterLevel` isn't supported") do
      flunk("Video request schema is incompatible with current API: #{message}")
    end
  end

  defp error_message(%Error{} = error) do
    cond do
      is_binary(error.message) and error.message != "" ->
        error.message

      is_map(error.message) and is_binary(error.message["message"]) ->
        error.message["message"]

      is_map(error.details) and is_map(error.details["error"]) and
          is_binary(error.details["error"]["message"]) ->
        error.details["error"]["message"]

      true ->
        inspect(error)
    end
  end

  defp error_message(reason), do: inspect(reason)
end
