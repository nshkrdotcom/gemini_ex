# Files API Example
# Run with: mix run examples/15_files_api.exs
#
# Demonstrates:
# - Uploading a file with the Gemini Files API
# - Using the File struct directly in generation
# - Getting metadata and listing files
# - Cleaning up uploaded files

defmodule FilesAPIExample do
  alias Gemini.APIs.Files

  @fixture_path Path.expand("../test/fixtures/test_document.txt", __DIR__)

  def run do
    print_header("FILES API")

    if gemini_api_key_available?() do
      demo_files_api()
      print_footer()
    else
      IO.puts("[SKIP] Files API examples require GEMINI_API_KEY.")
      IO.puts("[SKIP] Vertex AI credentials are not enough for Gemini Files uploads.")
      IO.puts("")
    end
  end

  defp demo_files_api do
    print_section("1. Upload, Generate, Inspect, Delete")

    uploaded_file =
      case Files.upload(@fixture_path, auth: :gemini) do
        {:ok, file} ->
          IO.puts("UPLOADED:")
          IO.puts("  name: #{file.name}")
          IO.puts("  mime_type: #{file.mime_type}")
          IO.puts("")
          file

        {:error, error} ->
          IO.puts("[ERROR] Upload failed: #{inspect(error)}")
          System.halt(1)
      end

    try do
      demo_generate(uploaded_file)
      demo_get(uploaded_file)
      demo_list(uploaded_file)
    after
      case Files.delete(uploaded_file.name, auth: :gemini) do
        :ok ->
          IO.puts("CLEANUP:")
          IO.puts("  deleted #{uploaded_file.name}")
          IO.puts("")

        {:error, error} ->
          IO.puts("[ERROR] Cleanup failed: #{inspect(error)}")
          IO.puts("")
      end
    end
  end

  defp demo_generate(file) do
    IO.puts("GENERATE:")

    case Gemini.generate([file, "\n\n", "Summarize this file in one sentence."]) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("  #{text}")
        IO.puts("")

      {:error, error} ->
        IO.puts("  [ERROR] #{inspect(error)}")
        IO.puts("")
    end
  end

  defp demo_get(file) do
    IO.puts("GET:")

    case Files.get(file.name, auth: :gemini) do
      {:ok, fetched} ->
        IO.puts("  state: #{inspect(fetched.state)}")
        IO.puts("  uri: #{fetched.uri}")
        IO.puts("")

      {:error, error} ->
        IO.puts("  [ERROR] #{inspect(error)}")
        IO.puts("")
    end
  end

  defp demo_list(file) do
    IO.puts("LIST:")

    case Files.list(page_size: 5, auth: :gemini) do
      {:ok, page} ->
        present? = Enum.any?(page.files, &(&1.name == file.name))
        IO.puts("  returned #{length(page.files)} files")
        IO.puts("  uploaded file present?: #{present?}")
        IO.puts("")

      {:error, error} ->
        IO.puts("  [ERROR] #{inspect(error)}")
        IO.puts("")
    end
  end

  defp gemini_api_key_available? do
    case System.get_env("GEMINI_API_KEY") do
      value when is_binary(value) and value != "" -> true
      _ -> false
    end
  end

  defp print_header(title) do
    IO.puts("")
    IO.puts(String.duplicate("=", 70))
    IO.puts("  #{title}")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end

  defp print_section(title) do
    IO.puts(String.duplicate("-", 70))
    IO.puts(title)
    IO.puts(String.duplicate("-", 70))
    IO.puts("")
  end

  defp print_footer do
    IO.puts(String.duplicate("=", 70))
    IO.puts("  EXAMPLE COMPLETE")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end
end

FilesAPIExample.run()
