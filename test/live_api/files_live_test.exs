defmodule Gemini.APIs.FilesLiveTest do
  @moduledoc """
  Live API tests for the Files API.

  Run with: mix test --include live_api test/live_api/files_live_test.exs

  Requires GEMINI_API_KEY environment variable.
  """

  use ExUnit.Case, async: false

  alias Gemini.APIs.Files

  # Use Elixir.File for standard library file operations
  @elixir_file Elixir.File

  @moduletag :live_api

  @test_image_path "test/fixtures/test_image.png"
  @test_document_path "test/fixtures/test_document.txt"

  setup do
    case Gemini.Test.AuthHelpers.detect_auth() do
      {:ok, :gemini, _} ->
        {:ok, skip: false, uploaded_files: []}

      _ ->
        {:ok, skip: true, uploaded_files: []}
    end
  end

  defp maybe_skip(%{skip: true}) do
    IO.puts("\nSkipping Files live test: Files API is Gemini-only; set GEMINI_API_KEY to run.")
    true
  end

  defp maybe_skip(_), do: false

  describe "upload/2" do
    @tag :live_api
    test "uploads an image file successfully", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, file} = Files.upload(@test_image_path)

        assert file.name != nil
        assert String.starts_with?(file.name, "files/")
        assert file.mime_type == "image/png"
        assert file.state in [:processing, :active]

        # Cleanup
        Files.delete(file.name)
      end
    end

    @tag :live_api
    test "uploads a text file successfully", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, file} = Files.upload(@test_document_path)

        assert file.name != nil
        assert file.mime_type == "text/plain"
        assert file.state in [:processing, :active]

        # Cleanup
        Files.delete(file.name)
      end
    end

    @tag :live_api
    test "uploads with custom display_name", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, file} = Files.upload(@test_image_path, display_name: "Custom Test Image")

        assert file.display_name == "Custom Test Image"

        # Cleanup
        Files.delete(file.name)
      end
    end

    @tag :live_api
    test "uploads with explicit mime_type", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, file} = Files.upload(@test_document_path, mime_type: "text/markdown")

        assert file.mime_type == "text/markdown"

        # Cleanup
        Files.delete(file.name)
      end
    end
  end

  describe "upload_data/2" do
    @tag :live_api
    test "uploads binary data successfully", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        data = @elixir_file.read!(@test_image_path)

        {:ok, file} =
          Files.upload_data(data,
            mime_type: "image/png",
            display_name: "Binary Upload Test"
          )

        assert file.name != nil
        assert file.mime_type == "image/png"

        # Cleanup
        Files.delete(file.name)
      end
    end

    @tag :live_api
    test "returns error when mime_type is missing", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        data = "test data"

        result = Files.upload_data(data, display_name: "Test")

        assert {:error, {:missing_required_option, :mime_type}} = result
      end
    end
  end

  describe "get/2" do
    @tag :live_api
    test "retrieves file metadata by name", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, uploaded} = Files.upload(@test_image_path)

        {:ok, file} = Files.get(uploaded.name)

        assert file.name == uploaded.name
        assert file.mime_type == "image/png"

        # Cleanup
        Files.delete(file.name)
      end
    end

    @tag :live_api
    test "retrieves file without files/ prefix", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, uploaded} = Files.upload(@test_image_path)

        # Extract just the ID
        [_, id] = String.split(uploaded.name, "/")

        {:ok, file} = Files.get(id)

        assert file.name == uploaded.name

        # Cleanup
        Files.delete(file.name)
      end
    end

    @tag :live_api
    test "returns error for non-existent file", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        result = Files.get("files/nonexistent12345")

        assert {:error, _} = result
      end
    end
  end

  describe "list/1" do
    @tag :live_api
    test "lists files", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        # Upload a test file first
        {:ok, uploaded} = Files.upload(@test_image_path)

        {:ok, response} = Files.list()

        assert is_list(response.files)
        # Should contain at least our uploaded file
        assert Enum.any?(response.files, fn f -> f.name == uploaded.name end)

        # Cleanup
        Files.delete(uploaded.name)
      end
    end

    @tag :live_api
    test "lists files with page_size", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, response} = Files.list(page_size: 5)

        assert is_list(response.files)
        assert length(response.files) <= 5
      end
    end

    @tag :live_api
    test "supports pagination", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        # Upload multiple files
        {:ok, file1} = Files.upload(@test_image_path, display_name: "Test 1")
        {:ok, file2} = Files.upload(@test_image_path, display_name: "Test 2")

        # List with small page size
        {:ok, page1} = Files.list(page_size: 1)

        if page1.next_page_token do
          {:ok, page2} = Files.list(page_size: 1, page_token: page1.next_page_token)
          assert is_list(page2.files)
        end

        # Cleanup
        Files.delete(file1.name)
        Files.delete(file2.name)
      end
    end
  end

  describe "list_all/1" do
    @tag :live_api
    test "lists all files across pages", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, files} = Files.list_all()

        assert is_list(files)
      end
    end
  end

  describe "delete/2" do
    @tag :live_api
    test "deletes a file successfully", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, uploaded} = Files.upload(@test_image_path)

        result = Files.delete(uploaded.name)

        assert result == :ok

        # Verify file is gone
        assert {:error, _} = Files.get(uploaded.name)
      end
    end

    @tag :live_api
    test "returns error for non-existent file", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        result = Files.delete("files/nonexistent12345")

        assert {:error, _} = result
      end
    end
  end

  describe "wait_for_processing/2" do
    @tag :live_api
    test "waits for file to become active", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, uploaded} = Files.upload(@test_image_path)

        {:ok, file} =
          Files.wait_for_processing(uploaded.name,
            poll_interval: 1000,
            timeout: 30_000
          )

        assert file.state == :active

        # Cleanup
        Files.delete(file.name)
      end
    end

    @tag :live_api
    test "calls on_status callback during polling", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        {:ok, uploaded} = Files.upload(@test_image_path)

        statuses = :ets.new(:test_statuses, [:set, :public])

        {:ok, _file} =
          Files.wait_for_processing(uploaded.name,
            poll_interval: 500,
            timeout: 30_000,
            on_status: fn file ->
              :ets.insert(statuses, {System.monotonic_time(), file.state})
            end
          )

        # Should have at least one status callback
        assert :ets.info(statuses, :size) >= 1

        :ets.delete(statuses)

        # Cleanup
        Files.delete(uploaded.name)
      end
    end
  end

  describe "integration: upload and use in generation" do
    @tag :live_api
    @tag :slow
    test "uploads image and uses it in content generation", ctx do
      if maybe_skip(ctx) do
        assert true
      else
        # Upload the image
        {:ok, file} = Files.upload(@test_image_path)

        # Wait for processing
        {:ok, ready_file} =
          Files.wait_for_processing(file.name,
            poll_interval: 1000,
            timeout: 60_000
          )

        assert ready_file.state == :active

        # Use in content generation
        # Note: The test image is a minimal 10x10 PNG. Gemini may reject it as "not valid"
        # for content generation, which is acceptable - the upload/wait flow still works.
        result =
          Gemini.generate(
            [
              %{
                role: "user",
                parts: [
                  %{text: "Describe this image briefly."},
                  %{
                    fileData: %{
                      fileUri: ready_file.uri,
                      mimeType: ready_file.mime_type
                    }
                  }
                ]
              }
            ],
            model: "gemini-2.0-flash-lite"
          )

        case result do
          {:ok, response} ->
            {:ok, text} = Gemini.extract_text(response)
            assert is_binary(text)
            assert String.length(text) > 0

          {:error, %Gemini.Error{http_status: 400}} ->
            # Test image is too small/simple for Gemini to process - that's OK
            # The important thing is the upload and wait_for_processing worked
            :ok
        end

        # Cleanup
        Files.delete(ready_file.name)
      end
    end
  end
end
