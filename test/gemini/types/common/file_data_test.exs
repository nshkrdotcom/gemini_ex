defmodule Gemini.Types.FileDataTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.FileData

  describe "from_api/1" do
    test "parses camelCase keys" do
      payload = %{
        "fileUri" => "gs://bucket/file.txt",
        "mimeType" => "text/plain",
        "displayName" => "file.txt"
      }

      file_data = FileData.from_api(payload)

      assert file_data.file_uri == "gs://bucket/file.txt"
      assert file_data.mime_type == "text/plain"
      assert file_data.display_name == "file.txt"
    end

    test "returns nil for nil input" do
      assert FileData.from_api(nil) == nil
    end
  end

  describe "to_api/1" do
    test "converts to camelCase keys" do
      struct = %FileData{
        file_uri: "gs://bucket/asset.mp3",
        mime_type: "audio/mpeg",
        display_name: "asset.mp3"
      }

      assert FileData.to_api(struct) == %{
               "fileUri" => "gs://bucket/asset.mp3",
               "mimeType" => "audio/mpeg",
               "displayName" => "asset.mp3"
             }
    end
  end
end
