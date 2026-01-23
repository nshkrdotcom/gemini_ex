defmodule Gemini.Types.RegisterFilesTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.{RegisterFilesConfig, RegisterFilesResponse}

  describe "RegisterFilesConfig" do
    test "creates struct with http_options" do
      config = %RegisterFilesConfig{
        http_options: %{timeout: 60_000}
      }

      assert config.http_options == %{timeout: 60_000}
    end

    test "creates empty struct" do
      config = %RegisterFilesConfig{}
      assert config.http_options == nil
    end
  end

  describe "RegisterFilesResponse.from_api/1" do
    test "parses file list" do
      data = %{
        "files" => [
          %{
            "name" => "files/abc123",
            "uri" => "gs://bucket/file.txt",
            "mimeType" => "text/plain"
          },
          %{
            "name" => "files/def456",
            "uri" => "gs://bucket/image.png",
            "mimeType" => "image/png"
          }
        ]
      }

      response = RegisterFilesResponse.from_api(data)

      assert length(response.files) == 2
      assert Enum.at(response.files, 0).name == "files/abc123"
      assert Enum.at(response.files, 0).uri == "gs://bucket/file.txt"
      assert Enum.at(response.files, 1).name == "files/def456"
    end

    test "handles empty files list" do
      data = %{"files" => []}

      response = RegisterFilesResponse.from_api(data)

      assert response.files == []
    end

    test "handles missing files key" do
      data = %{}

      response = RegisterFilesResponse.from_api(data)

      assert response.files == []
    end

    test "handles nil input" do
      response = RegisterFilesResponse.from_api(nil)

      assert response.files == []
    end
  end
end
