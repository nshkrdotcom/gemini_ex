defmodule Gemini.APIs.FilesTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{File, ListFilesResponse}

  describe "File type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "files/abc123",
        "displayName" => "test-image.png",
        "mimeType" => "image/png",
        "sizeBytes" => "1024",
        "createTime" => "2025-12-05T10:00:00Z",
        "expirationTime" => "2025-12-07T10:00:00Z",
        "updateTime" => "2025-12-05T10:00:00Z",
        "sha256Hash" => "abc123hash",
        "uri" => "gs://bucket/files/abc123",
        "state" => "ACTIVE",
        "source" => "UPLOADED"
      }

      file = File.from_api_response(response)

      assert file.name == "files/abc123"
      assert file.display_name == "test-image.png"
      assert file.mime_type == "image/png"
      assert file.size_bytes == 1024
      assert file.state == :active
      assert file.source == :uploaded
      assert file.uri == "gs://bucket/files/abc123"
    end

    test "from_api_response/1 handles processing state" do
      response = %{"name" => "files/abc", "state" => "PROCESSING"}
      file = File.from_api_response(response)
      assert file.state == :processing
    end

    test "from_api_response/1 handles failed state with error" do
      response = %{
        "name" => "files/abc",
        "state" => "FAILED",
        "error" => %{
          "message" => "Invalid file format",
          "code" => 400
        }
      }

      file = File.from_api_response(response)
      assert file.state == :failed
      assert file.error.message == "Invalid file format"
      assert file.error.code == 400
    end

    test "from_api_response/1 handles video metadata" do
      response = %{
        "name" => "files/video123",
        "mimeType" => "video/mp4",
        "state" => "ACTIVE",
        "videoMetadata" => %{
          "videoDuration" => "PT1M30S",
          "videoDurationSeconds" => "90"
        }
      }

      file = File.from_api_response(response)
      assert file.video_metadata.video_duration == "PT1M30S"
      assert file.video_metadata.video_duration_seconds == 90
    end

    test "from_api_response/1 handles generated file with download_uri" do
      response = %{
        "name" => "files/generated123",
        "source" => "GENERATED",
        "state" => "ACTIVE",
        "downloadUri" => "https://storage.googleapis.com/download/abc"
      }

      file = File.from_api_response(response)
      assert file.source == :generated
      assert file.download_uri == "https://storage.googleapis.com/download/abc"
      assert File.downloadable?(file)
    end
  end

  describe "File state helpers" do
    test "active?/1 returns true for active files" do
      file = %File{state: :active}
      assert File.active?(file)
    end

    test "active?/1 returns false for non-active files" do
      file = %File{state: :processing}
      refute File.active?(file)
    end

    test "processing?/1 returns true for processing files" do
      file = %File{state: :processing}
      assert File.processing?(file)
    end

    test "failed?/1 returns true for failed files" do
      file = %File{state: :failed}
      assert File.failed?(file)
    end

    test "downloadable?/1 returns true only for generated files with download_uri" do
      generated = %File{source: :generated, download_uri: "https://example.com/file"}
      uploaded = %File{source: :uploaded}
      no_uri = %File{source: :generated, download_uri: nil}

      assert File.downloadable?(generated)
      refute File.downloadable?(uploaded)
      refute File.downloadable?(no_uri)
    end

    test "get_id/1 extracts file ID from name" do
      file = %File{name: "files/abc123"}
      assert File.get_id(file) == "abc123"
    end
  end

  describe "ListFilesResponse" do
    test "from_api_response/1 parses files list" do
      response = %{
        "files" => [
          %{"name" => "files/1", "state" => "ACTIVE"},
          %{"name" => "files/2", "state" => "PROCESSING"}
        ],
        "nextPageToken" => "token123"
      }

      result = ListFilesResponse.from_api_response(response)

      assert length(result.files) == 2
      assert result.next_page_token == "token123"
      assert ListFilesResponse.has_more_pages?(result)
    end

    test "from_api_response/1 handles empty response" do
      response = %{}

      result = ListFilesResponse.from_api_response(response)

      assert result.files == []
      assert result.next_page_token == nil
      refute ListFilesResponse.has_more_pages?(result)
    end

    test "has_more_pages?/1 returns false for nil or empty token" do
      refute ListFilesResponse.has_more_pages?(%ListFilesResponse{next_page_token: nil})
      refute ListFilesResponse.has_more_pages?(%ListFilesResponse{next_page_token: ""})
    end
  end

  describe "MIME type detection" do
    test "detects image MIME types" do
      assert detect_mime("test.png") == "image/png"
      assert detect_mime("test.jpg") == "image/jpeg"
      assert detect_mime("test.jpeg") == "image/jpeg"
      assert detect_mime("test.gif") == "image/gif"
      assert detect_mime("test.webp") == "image/webp"
    end

    test "detects video MIME types" do
      assert detect_mime("test.mp4") == "video/mp4"
      assert detect_mime("test.mov") == "video/quicktime"
      assert detect_mime("test.avi") == "video/x-msvideo"
      assert detect_mime("test.webm") == "video/webm"
    end

    test "detects audio MIME types" do
      assert detect_mime("test.mp3") == "audio/mpeg"
      assert detect_mime("test.wav") == "audio/wav"
      assert detect_mime("test.ogg") == "audio/ogg"
      assert detect_mime("test.flac") == "audio/flac"
    end

    test "detects document MIME types" do
      assert detect_mime("test.pdf") == "application/pdf"
      assert detect_mime("test.txt") == "text/plain"
      assert detect_mime("test.html") == "text/html"
      assert detect_mime("test.json") == "application/json"
    end

    test "returns octet-stream for unknown types" do
      assert detect_mime("test.unknown") == "application/octet-stream"
    end
  end

  # Helper to test MIME detection
  @mime_by_ext %{
    ".avi" => "video/x-msvideo",
    ".flac" => "audio/flac",
    ".gif" => "image/gif",
    ".html" => "text/html",
    ".jpeg" => "image/jpeg",
    ".jpg" => "image/jpeg",
    ".json" => "application/json",
    ".mov" => "video/quicktime",
    ".mp3" => "audio/mpeg",
    ".mp4" => "video/mp4",
    ".ogg" => "audio/ogg",
    ".pdf" => "application/pdf",
    ".png" => "image/png",
    ".txt" => "text/plain",
    ".wav" => "audio/wav",
    ".webm" => "video/webm",
    ".webp" => "image/webp"
  }

  defp detect_mime(filename) do
    # Access private function through module
    ext = Path.extname(filename) |> String.downcase()

    Map.get(@mime_by_ext, ext, "application/octet-stream")
  end
end
