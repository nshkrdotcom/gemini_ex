defmodule Gemini.APIs.CoordinatorContentNormalizationTest do
  @moduledoc """
  Tests for content normalization in the Coordinator module.

  These tests cover the full matrix of content input formats that
  `build_generate_request/2` → `normalize_content_list/1` →
  `normalize_single_content/1` and `normalize_part/1` must handle.

  Covers findings from the Files API audit report (2026-01-27):
    - Finding #1 (Critical): %{file_uri:, mime_type:} map as content item (Issue #18)
    - Finding #2 (High): %{file_data: %{file_uri:}} map as content item
    - Finding #3 (High): normalize_part missing file-related clauses
    - Finding #4 (Medium): No Part.file_data/2 convenience constructor
    - Finding #5 (Medium): File struct not accepted as content item
    - Finding #6 (Medium): Doc examples in register_files use broken pattern
    - Finding #7 (Low): Error message doesn't mention file_data format
  """

  # async: false because :meck operates on global module state
  use ExUnit.Case, async: false

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.Content
  alias Gemini.Types.File, as: GeminiFile
  alias Gemini.Types.FileData
  alias Gemini.Types.Part

  # ===========================================================================
  # Helper: exercise the normalization path through the public API
  #
  # generate_content/2 calls build_generate_request which calls
  # normalize_content_list → normalize_single_content → normalize_part.
  # Since those are all private, we exercise them through the public entry
  # point. We use :meck to intercept HTTP.post so no real API call is made,
  # and we capture the request body that was built.
  # ===========================================================================

  setup do
    :meck.new(Gemini.Client.HTTP, [:passthrough])

    on_exit(fn ->
      try do
        :meck.unload(Gemini.Client.HTTP)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  defp capture_request_body(input, opts \\ []) do
    test_pid = self()

    :meck.expect(Gemini.Client.HTTP, :post, fn _path, body, _opts ->
      send(test_pid, {:captured_body, body})

      {:ok,
       %{"candidates" => [%{"content" => %{"parts" => [%{"text" => "ok"}], "role" => "model"}}]}}
    end)

    _result = Coordinator.generate_content(input, opts)

    receive do
      {:captured_body, body} -> body
    after
      1000 -> flunk("Did not receive captured request body")
    end
  end

  # ===========================================================================
  # Finding #1 (Critical / Issue #18):
  # %{file_uri: ..., mime_type: ...} map as a top-level content item
  # ===========================================================================

  describe "Issue #18: %{file_uri:, mime_type:} map as content item" do
    test "accepts file_uri + mime_type map in content list" do
      body =
        capture_request_body([
          "What's in this image?",
          %{
            file_uri: "https://generativelanguage.googleapis.com/v1beta/files/abc123",
            mime_type: "image/png"
          }
        ])

      contents = body.contents || body[:contents]
      assert is_list(contents)
      assert length(contents) == 2

      file_content = Enum.at(contents, 1)
      parts = file_content[:parts] || file_content.parts
      assert length(parts) == 1

      part = hd(parts)
      # The part should contain fileData with fileUri and mimeType
      file_data = part[:fileData] || part["fileData"]
      assert file_data != nil

      assert file_data["fileUri"] ==
               "https://generativelanguage.googleapis.com/v1beta/files/abc123"

      assert file_data["mimeType"] == "image/png"
    end

    test "accepts file_uri map without mime_type (uses fallback)" do
      body =
        capture_request_body([
          "Describe this",
          %{file_uri: "https://generativelanguage.googleapis.com/v1beta/files/xyz789"}
        ])

      contents = body.contents || body[:contents]
      file_content = Enum.at(contents, 1)
      parts = file_content[:parts] || file_content.parts
      part = hd(parts)
      file_data = part[:fileData] || part["fileData"]
      assert file_data != nil

      assert file_data["fileUri"] ==
               "https://generativelanguage.googleapis.com/v1beta/files/xyz789"

      # Should have a fallback mime_type
      assert is_binary(file_data["mimeType"])
    end

    test "reproduces exact Issue #18 scenario from bug report" do
      # Exact code from the issue reporter:
      # Gemini.generate([
      #   "What's in this image?",
      #   %{file_uri: "https://generativelanguage.googleapis.com/v1beta/files/iliojskrfq89"}
      # ])
      body =
        capture_request_body([
          "What's in this image?",
          %{
            file_uri: "https://generativelanguage.googleapis.com/v1beta/files/iliojskrfq89"
          }
        ])

      contents = body.contents || body[:contents]
      assert is_list(contents)
      # Should not raise ArgumentError
    end

    test "reproduces Issue #18 scenario with mime_type included" do
      # The documented quick-start pattern from files.ex:26-29 and guides/files.md:27-29
      body =
        capture_request_body([
          "What's in this image?",
          %{
            file_uri: "https://generativelanguage.googleapis.com/v1beta/files/iliojskrfq89",
            mime_type: "image/png"
          }
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end

    test "file_uri with various MIME types" do
      for mime <- ["image/jpeg", "video/mp4", "audio/mpeg", "application/pdf", "text/plain"] do
        body =
          capture_request_body([
            "Process this file",
            %{
              file_uri: "https://generativelanguage.googleapis.com/v1beta/files/test123",
              mime_type: mime
            }
          ])

        contents = body.contents || body[:contents]
        file_content = Enum.at(contents, 1)
        parts = file_content[:parts] || file_content.parts
        part = hd(parts)
        file_data = part[:fileData] || part["fileData"]
        assert file_data["mimeType"] == mime, "Failed for MIME type: #{mime}"
      end
    end

    test "file_uri with gs:// URI scheme (Vertex AI / GCS)" do
      body =
        capture_request_body([
          "Summarize this",
          %{file_uri: "gs://my-bucket/documents/report.pdf", mime_type: "application/pdf"}
        ])

      contents = body.contents || body[:contents]
      file_content = Enum.at(contents, 1)
      parts = file_content[:parts] || file_content.parts
      part = hd(parts)
      file_data = part[:fileData] || part["fileData"]
      assert file_data["fileUri"] == "gs://my-bucket/documents/report.pdf"
    end
  end

  # ===========================================================================
  # Finding #2 (High):
  # %{file_data: %{file_uri: ...}} wrapped map as content item
  # ===========================================================================

  describe "Finding #2: %{file_data: %{file_uri:}} map as content item" do
    test "accepts file_data wrapper map with file_uri and mime_type" do
      body =
        capture_request_body([
          "Summarize this",
          %{file_data: %{file_uri: "gs://bucket/file.txt", mime_type: "text/plain"}}
        ])

      contents = body.contents || body[:contents]
      file_content = Enum.at(contents, 1)
      parts = file_content[:parts] || file_content.parts
      part = hd(parts)
      file_data = part[:fileData] || part["fileData"]
      assert file_data != nil
      assert file_data["fileUri"] == "gs://bucket/file.txt"
      assert file_data["mimeType"] == "text/plain"
    end

    test "accepts file_data wrapper map without mime_type" do
      body =
        capture_request_body([
          "Read this",
          %{file_data: %{file_uri: "gs://bucket/unknown.bin"}}
        ])

      contents = body.contents || body[:contents]
      file_content = Enum.at(contents, 1)
      parts = file_content[:parts] || file_content.parts
      part = hd(parts)
      file_data = part[:fileData] || part["fileData"]
      assert file_data != nil
      assert file_data["fileUri"] == "gs://bucket/unknown.bin"
    end

    test "register_files doc example pattern works" do
      # From files.ex:739-742
      file_uri = "https://generativelanguage.googleapis.com/v1beta/files/registered123"

      body =
        capture_request_body([
          %{text: "Summarize this document"},
          %{file_data: %{file_uri: file_uri}}
        ])

      contents = body.contents || body[:contents]
      assert is_list(contents)
      assert length(contents) == 2
    end
  end

  # ===========================================================================
  # Finding #2 (supplementary):
  # %{text: "..."} bare text map as content item (no :type wrapper)
  # ===========================================================================

  describe "Finding #2 (supplementary): bare %{text:} map as content item" do
    test "accepts bare text map without type wrapper" do
      body =
        capture_request_body([
          %{text: "Hello world"}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
      content = hd(contents)
      parts = content[:parts] || content.parts
      part = hd(parts)
      assert part[:text] == "Hello world" or part.text == "Hello world"
    end

    test "accepts mixed text map and file_data map" do
      body =
        capture_request_body([
          %{text: "Analyze this"},
          %{file_data: %{file_uri: "gs://b/f.pdf", mime_type: "application/pdf"}}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end
  end

  # ===========================================================================
  # Finding #3 (High):
  # normalize_part missing file-related clauses
  # When content is provided as %{role:, parts: [...]}, parts go through
  # normalize_part/1 which must also handle file maps.
  # ===========================================================================

  describe "Finding #3: file maps inside explicit role/parts structure" do
    test "file_data map inside parts list is normalized" do
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              "Describe this image",
              %{file_data: %{file_uri: "gs://bucket/image.jpg", mime_type: "image/jpeg"}}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert length(parts) == 2

      file_part = Enum.at(parts, 1)
      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data != nil
      assert file_data["fileUri"] == "gs://bucket/image.jpg"
      assert file_data["mimeType"] == "image/jpeg"
    end

    test "file_uri map inside parts list is normalized" do
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              "What is this?",
              %{file_uri: "gs://bucket/doc.pdf", mime_type: "application/pdf"}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert length(parts) == 2

      file_part = Enum.at(parts, 1)
      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data != nil
      assert file_data["fileUri"] == "gs://bucket/doc.pdf"
    end

    test "file_uri map without mime_type inside parts list" do
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              "Analyze",
              %{file_uri: "gs://bucket/file.bin"}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      file_part = Enum.at(parts, 1)
      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data != nil
      assert file_data["fileUri"] == "gs://bucket/file.bin"
      assert is_binary(file_data["mimeType"])
    end

    test "multiple file parts in same content" do
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              "Compare these images",
              %{file_uri: "gs://bucket/img1.png", mime_type: "image/png"},
              %{file_uri: "gs://bucket/img2.png", mime_type: "image/png"}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert length(parts) == 3

      for i <- [1, 2] do
        part = Enum.at(parts, i)
        file_data = part[:fileData] || part["fileData"]
        assert file_data != nil, "Part #{i} should have fileData"
      end
    end

    test "mixed text, inline_data, and file_data parts" do
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              "Compare these",
              %{inline_data: %{data: "base64encodeddata", mime_type: "image/png"}},
              %{file_uri: "gs://bucket/img2.jpg", mime_type: "image/jpeg"}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert length(parts) == 3

      # First part: text
      assert (Enum.at(parts, 0)[:text] || Enum.at(parts, 0).text) == "Compare these"

      # Second part: inline_data
      inline = Enum.at(parts, 1)[:inlineData] || Enum.at(parts, 1)["inlineData"]
      assert inline != nil

      # Third part: file_data
      file_data = Enum.at(parts, 2)[:fileData] || Enum.at(parts, 2)["fileData"]
      assert file_data != nil
    end
  end

  # ===========================================================================
  # Finding #5 (Medium):
  # Gemini.Types.File struct accepted as content item
  # (Python SDK supports passing File objects directly)
  # ===========================================================================

  describe "Finding #5: File struct as content item" do
    test "File struct as top-level content item" do
      file = %GeminiFile{
        name: "files/abc123",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/abc123",
        mime_type: "image/png",
        state: :active
      }

      body =
        capture_request_body([
          "Describe this image",
          file
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 2

      file_content = Enum.at(contents, 1)
      parts = file_content[:parts] || file_content.parts
      part = hd(parts)
      file_data = part[:fileData] || part["fileData"]
      assert file_data != nil

      assert file_data["fileUri"] ==
               "https://generativelanguage.googleapis.com/v1beta/files/abc123"

      assert file_data["mimeType"] == "image/png"
    end

    test "File struct inside parts list" do
      file = %GeminiFile{
        name: "files/video456",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/video456",
        mime_type: "video/mp4",
        state: :active
      }

      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              "Describe this video",
              file
            ]
          }
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert length(parts) == 2

      file_part = Enum.at(parts, 1)
      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data != nil

      assert file_data["fileUri"] ==
               "https://generativelanguage.googleapis.com/v1beta/files/video456"

      assert file_data["mimeType"] == "video/mp4"
    end

    test "multiple File structs in content list" do
      file1 = %GeminiFile{
        name: "files/img1",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/img1",
        mime_type: "image/jpeg",
        state: :active
      }

      file2 = %GeminiFile{
        name: "files/img2",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/img2",
        mime_type: "image/jpeg",
        state: :active
      }

      body =
        capture_request_body([
          "Compare these images",
          file1,
          file2
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 3

      for i <- [1, 2] do
        file_content = Enum.at(contents, i)
        parts = file_content[:parts] || file_content.parts
        part = hd(parts)
        file_data = part[:fileData] || part["fileData"]
        assert file_data != nil, "Content item #{i} should have fileData"
      end
    end
  end

  # ===========================================================================
  # Finding #4 (Medium):
  # Part.file_data/2 convenience constructor
  # ===========================================================================

  describe "Finding #4: Part.file_data/2 convenience constructor" do
    test "Part.file_data/2 creates a Part with FileData" do
      part =
        Part.file_data(
          "https://generativelanguage.googleapis.com/v1beta/files/abc123",
          "image/png"
        )

      assert %Part{} = part
      assert %FileData{} = part.file_data

      assert part.file_data.file_uri ==
               "https://generativelanguage.googleapis.com/v1beta/files/abc123"

      assert part.file_data.mime_type == "image/png"
      assert part.text == nil
      assert part.inline_data == nil
    end

    test "Part.file_data/2 with GCS URI" do
      part = Part.file_data("gs://my-bucket/data/file.pdf", "application/pdf")

      assert part.file_data.file_uri == "gs://my-bucket/data/file.pdf"
      assert part.file_data.mime_type == "application/pdf"
    end

    test "Part.file_data/2 result works in Content struct" do
      content = %Content{
        role: "user",
        parts: [
          Part.text("Describe this"),
          Part.file_data(
            "https://generativelanguage.googleapis.com/v1beta/files/test",
            "image/jpeg"
          )
        ]
      }

      body = capture_request_body([content])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
      content_out = hd(contents)
      parts = content_out[:parts] || content_out.parts
      assert length(parts) == 2

      text_part = Enum.at(parts, 0)
      assert text_part[:text] == "Describe this" or text_part.text == "Describe this"

      file_part = Enum.at(parts, 1)
      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data != nil
      assert file_data["fileUri"] == "https://generativelanguage.googleapis.com/v1beta/files/test"
      assert file_data["mimeType"] == "image/jpeg"
    end
  end

  # ===========================================================================
  # Finding #7 (Low):
  # Error message should list file_data / file_uri formats
  # ===========================================================================

  describe "Finding #7: error message mentions file formats" do
    test "ArgumentError message includes file_uri format hint" do
      # The raise happens before HTTP.post, so no meck expect needed here.
      assert_raise ArgumentError, ~r/file_uri/i, fn ->
        # Pass something that should never be valid: an integer
        Coordinator.generate_content([42], [])
      end
    end
  end

  # ===========================================================================
  # Existing formats still work (regression tests)
  # ===========================================================================

  describe "regression: existing content formats still work" do
    test "plain string input" do
      body = capture_request_body("Hello world")

      contents = body.contents || body[:contents]
      assert length(contents) == 1
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert hd(parts)[:text] == "Hello world" or hd(parts).text == "Hello world"
    end

    test "string in list" do
      body = capture_request_body(["Hello", "World"])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end

    test "Content struct passthrough" do
      content = %Content{
        role: "user",
        parts: [Part.text("Hello")]
      }

      body = capture_request_body([content])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
    end

    test "map with role and parts" do
      body =
        capture_request_body([
          %{role: "user", parts: ["Hello", "World"]}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert length(parts) == 2
    end

    test "Anthropic-style text map" do
      body =
        capture_request_body([
          %{type: "text", text: "Hello"}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
    end

    test "Anthropic-style image map" do
      body =
        capture_request_body([
          %{type: "image", source: %{type: "base64", data: "AAAA", mime_type: "image/png"}}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
      content = hd(contents)
      parts = content[:parts] || content.parts
      part = hd(parts)
      inline = part[:inlineData] || part["inlineData"]
      assert inline != nil
    end

    test "inline_data map in parts list" do
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              %{inline_data: %{data: "base64data", mime_type: "image/jpeg"}}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      part = hd(parts)
      inline = part[:inlineData] || part["inlineData"]
      assert inline != nil
    end
  end

  # ===========================================================================
  # End-to-end: documented quick-start patterns
  # These test the exact code snippets from docs/guides.
  # ===========================================================================

  describe "documented patterns: files.ex moduledoc quick-start" do
    test "files.ex lines 26-29: upload result used in generate" do
      # Simulates: ready_file = %File{uri: "...", mime_type: "image/png"}
      # Gemini.generate(["What's in this image?", %{file_uri: ready_file.uri, mime_type: ready_file.mime_type}])
      ready_file_uri = "https://generativelanguage.googleapis.com/v1beta/files/abc"
      ready_file_mime = "image/png"

      body =
        capture_request_body([
          "What's in this image?",
          %{file_uri: ready_file_uri, mime_type: ready_file_mime}
        ])

      contents = body.contents || body[:contents]
      assert is_list(contents)
      assert length(contents) == 2
    end

    test "guides/files.md lines 162-165: upload then generate" do
      body =
        capture_request_body([
          "Describe this image in detail",
          %{
            file_uri: "https://generativelanguage.googleapis.com/v1beta/files/photo",
            mime_type: "image/jpeg"
          }
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end

    test "files.ex lines 739-742: register_files doc example" do
      file_uri = "https://generativelanguage.googleapis.com/v1beta/files/registered"

      body =
        capture_request_body([
          %{text: "Summarize this document"},
          %{file_data: %{file_uri: file_uri}}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end
  end

  # ===========================================================================
  # Python SDK parity: patterns the Python SDK accepts
  # ===========================================================================

  describe "Python SDK parity" do
    test "File object passed directly in content list (Python: contents=[myfile, text])" do
      myfile = %GeminiFile{
        name: "files/uploaded123",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/uploaded123",
        mime_type: "image/jpeg",
        state: :active
      }

      body =
        capture_request_body([myfile, "Can you tell me about the instruments in this photo?"])

      contents = body.contents || body[:contents]
      assert length(contents) == 2

      # First item should be the file
      file_content = Enum.at(contents, 0)
      parts = file_content[:parts] || file_content.parts
      part = hd(parts)
      file_data = part[:fileData] || part["fileData"]
      assert file_data != nil

      # Second item should be text
      text_content = Enum.at(contents, 1)
      text_parts = text_content[:parts] || text_content.parts
      text_part = hd(text_parts)
      assert (text_part[:text] || text_part.text) =~ "instruments"
    end

    test "multiple content types like Python: contents=[myfile, '\\n\\n', text]" do
      myfile = %GeminiFile{
        name: "files/poem",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/poem",
        mime_type: "text/plain",
        state: :active
      }

      body = capture_request_body([myfile, "\n\n", "Can you add a few more lines to this poem?"])

      contents = body.contents || body[:contents]
      assert length(contents) == 3
    end

    test "audio file pattern from Python SDK docs" do
      myfile = %GeminiFile{
        name: "files/sample_mp3",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/sample_mp3",
        mime_type: "audio/mpeg",
        state: :active
      }

      body = capture_request_body([myfile, "Describe this audio clip"])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end

    test "video file pattern from Python SDK docs" do
      myfile = %GeminiFile{
        name: "files/video_clip",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/video_clip",
        mime_type: "video/mp4",
        state: :active
      }

      body = capture_request_body([myfile, "Describe this video clip"])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end

    test "PDF file pattern from Python SDK docs" do
      sample_pdf = %GeminiFile{
        name: "files/test_pdf",
        uri: "https://generativelanguage.googleapis.com/v1beta/files/test_pdf",
        mime_type: "application/pdf",
        state: :active
      }

      body = capture_request_body(["Give me a summary of this pdf file.", sample_pdf])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end
  end

  # ===========================================================================
  # Wire format: verify the final JSON shape matches what the API expects
  # ===========================================================================

  describe "wire format correctness" do
    test "file_data produces correct camelCase API keys" do
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              Part.text("Look at this"),
              %Part{file_data: %FileData{file_uri: "gs://b/f.jpg", mime_type: "image/jpeg"}}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      file_part = Enum.at(parts, 1)

      # Must use camelCase keys for the API
      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data != nil

      # fileUri not file_uri
      assert Map.has_key?(file_data, "fileUri") or Map.has_key?(file_data, :fileUri),
             "Expected camelCase key fileUri, got: #{inspect(file_data)}"

      # mimeType not mime_type
      assert Map.has_key?(file_data, "mimeType") or Map.has_key?(file_data, :mimeType),
             "Expected camelCase key mimeType, got: #{inspect(file_data)}"
    end

    test "Part struct with file_data serializes through format_part correctly" do
      part = %Part{
        file_data: %FileData{
          file_uri: "gs://bucket/doc.pdf",
          mime_type: "application/pdf",
          display_name: "My Document"
        }
      }

      body =
        capture_request_body([
          %Content{role: "user", parts: [Part.text("Read"), part]}
        ])

      contents = body.contents || body[:contents]
      content = hd(contents)
      parts = content[:parts] || content.parts
      file_part = Enum.at(parts, 1)

      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data["fileUri"] == "gs://bucket/doc.pdf"
      assert file_data["mimeType"] == "application/pdf"
      assert file_data["displayName"] == "My Document"
    end

    test "shell curl example format: parts with text + file_data" do
      # Mirrors the shell/curl JSON from the Google API docs:
      # {"contents": [{"parts":[
      #   {"text": "Can you tell me about the instruments in this photo?"},
      #   {"file_data": {"mime_type": "image/jpeg", "file_uri": "gs://..."}}
      # ]}]}
      body =
        capture_request_body([
          %{
            role: "user",
            parts: [
              "Can you tell me about the instruments in this photo?",
              %{file_data: %{file_uri: "gs://bucket/photo.jpg", mime_type: "image/jpeg"}}
            ]
          }
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
      content = hd(contents)
      parts = content[:parts] || content.parts
      assert length(parts) == 2

      text_part = Enum.at(parts, 0)
      assert (text_part[:text] || text_part.text) =~ "instruments"

      file_part = Enum.at(parts, 1)
      file_data = file_part[:fileData] || file_part["fileData"]
      assert file_data != nil
    end
  end

  # ===========================================================================
  # Edge cases
  # ===========================================================================

  describe "edge cases" do
    test "empty file_uri string raises or is handled gracefully" do
      # An empty URI should not produce a valid request silently.
      # Call generate_content directly -- the raise happens in
      # build_generate_request before HTTP.post is reached.
      assert_raise ArgumentError, fn ->
        Coordinator.generate_content(["test", %{file_uri: "", mime_type: "image/png"}], [])
      end
    end

    test "nil file_uri does not match file_uri clause" do
      # Should fall through to the ArgumentError fallback, not crash on nil.
      assert_raise ArgumentError, fn ->
        Coordinator.generate_content(["test", %{file_uri: nil}], [])
      end
    end

    test "Content struct with file_data Part passes through correctly" do
      # This already works (Part struct + format_part handles file_data)
      # but we verify it as a regression test
      content = %Content{
        role: "user",
        parts: [
          Part.text("Analyze"),
          %Part{file_data: %FileData{file_uri: "gs://b/f.txt", mime_type: "text/plain"}}
        ]
      }

      body = capture_request_body([content])

      contents = body.contents || body[:contents]
      content_out = hd(contents)
      parts = content_out[:parts] || content_out.parts
      assert length(parts) == 2
    end

    test "single file_uri map as sole content item" do
      body =
        capture_request_body([
          %{file_uri: "gs://b/audio.mp3", mime_type: "audio/mpeg"}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 1
    end

    test "file_uri map with extra keys is handled" do
      # Users might pass extra keys like display_name
      body =
        capture_request_body([
          "Describe",
          %{file_uri: "gs://b/f.jpg", mime_type: "image/jpeg", display_name: "photo"}
        ])

      contents = body.contents || body[:contents]
      assert length(contents) == 2
    end
  end
end
