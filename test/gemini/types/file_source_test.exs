defmodule Gemini.Types.FileSourceTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.File

  describe "file source enum" do
    test "parse_source handles REGISTERED" do
      assert File.parse_source("REGISTERED") == :registered
    end

    test "parse_source handles all valid values" do
      assert File.parse_source("SOURCE_UNSPECIFIED") == :source_unspecified
      assert File.parse_source("UPLOADED") == :uploaded
      assert File.parse_source("GENERATED") == :generated
      assert File.parse_source("REGISTERED") == :registered
    end

    test "parse_source returns source_unspecified for unknown values" do
      assert File.parse_source("UNKNOWN") == :source_unspecified
    end

    test "parse_source handles nil" do
      assert File.parse_source(nil) == nil
    end

    test "source_to_api converts registered" do
      assert File.source_to_api(:registered) == "REGISTERED"
    end

    test "source_to_api converts all values" do
      assert File.source_to_api(:source_unspecified) == "SOURCE_UNSPECIFIED"
      assert File.source_to_api(:uploaded) == "UPLOADED"
      assert File.source_to_api(:generated) == "GENERATED"
      assert File.source_to_api(:registered) == "REGISTERED"
    end
  end

  describe "from_api_response with registered source" do
    test "parses file with REGISTERED source" do
      response = %{
        "name" => "files/gcs-registered-123",
        "uri" => "gs://bucket/file.pdf",
        "mimeType" => "application/pdf",
        "state" => "ACTIVE",
        "source" => "REGISTERED"
      }

      file = File.from_api_response(response)

      assert file.name == "files/gcs-registered-123"
      assert file.uri == "gs://bucket/file.pdf"
      assert file.source == :registered
      assert file.state == :active
    end
  end
end
