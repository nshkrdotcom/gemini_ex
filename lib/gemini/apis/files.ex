defmodule Gemini.APIs.Files do
  @moduledoc """
  Files API for uploading, managing, and using files with Gemini models.

  The Files API allows you to upload files (images, videos, audio, documents)
  that can be referenced in content generation requests. This is useful for
  multimodal interactions where you want to include media files.

  ## Important Notes

  - **Gemini API Only**: File operations are only supported with the Gemini Developer API,
    not Vertex AI. Using file operations with Vertex AI will return an error.
  - **File Expiration**: Uploaded files expire after 48 hours
  - **Size Limits**: Maximum file size is 2GB for most file types
  - **Processing Time**: Large files (especially video) may take time to process

  ## Quick Start

      # Upload an image
      {:ok, file} = Gemini.APIs.Files.upload("path/to/image.png")

      # Wait for processing (for video files)
      {:ok, ready_file} = Gemini.APIs.Files.wait_for_processing(file.name)

      # Use in content generation
      {:ok, response} = Gemini.generate([
        "What's in this image?",
        %{file_uri: ready_file.uri, mime_type: ready_file.mime_type}
      ])

      # Clean up when done
      :ok = Gemini.APIs.Files.delete(file.name)

  ## Resumable Uploads

  For large files (>10MB), the API uses resumable uploads automatically:

      # Large file upload with progress tracking
      {:ok, file} = Gemini.APIs.Files.upload("path/to/video.mp4",
        on_progress: fn uploaded, total ->
          percent = Float.round(uploaded / total * 100, 1)
          IO.puts("Uploaded: \#{percent}%")
        end
      )

  ## Supported MIME Types

  - Images: `image/png`, `image/jpeg`, `image/gif`, `image/webp`
  - Videos: `video/mp4`, `video/mpeg`, `video/mov`, `video/avi`, `video/webm`
  - Audio: `audio/wav`, `audio/mp3`, `audio/aiff`, `audio/aac`, `audio/ogg`, `audio/flac`
  - Documents: `application/pdf`, `text/plain`, `text/html`, `text/css`, `text/javascript`
  """

  alias Gemini.Client.HTTP
  alias Gemini.Types.{File, ListFilesResponse}

  # Use Elixir.File for standard library file operations to avoid shadowing
  @elixir_file Elixir.File

  @type upload_opts :: [
          {:name, String.t()}
          | {:display_name, String.t()}
          | {:mime_type, String.t()}
          | {:on_progress, (integer(), integer() -> any())}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type list_opts :: [
          {:page_size, pos_integer()}
          | {:page_token, String.t()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type file_opts :: [{:auth, :gemini | :vertex_ai}]

  # Chunk size for resumable uploads (8MB)
  @chunk_size 8 * 1024 * 1024

  # Maximum retries for upload chunks
  @max_retries 3

  # Initial retry delay in milliseconds
  @initial_retry_delay 1000

  @doc """
  Upload a file to be used with Gemini models.

  ## Parameters

  - `file_path` - Path to the file to upload (string or Path)
  - `opts` - Upload options

  ## Options

  - `:name` - Custom file resource name (auto-generated if not provided)
  - `:display_name` - Human-readable display name (max 512 characters)
  - `:mime_type` - MIME type (auto-detected from extension if not provided)
  - `:on_progress` - Callback function `fn(uploaded_bytes, total_bytes) -> any()` for progress updates
  - `:auth` - Authentication strategy (must be `:gemini`)

  ## Returns

  - `{:ok, File.t()}` - Successfully uploaded file with metadata
  - `{:error, reason}` - Upload failed

  ## Examples

      # Simple upload
      {:ok, file} = Gemini.APIs.Files.upload("path/to/image.png")
      IO.puts("Uploaded: \#{file.uri}")

      # With display name
      {:ok, file} = Gemini.APIs.Files.upload("document.pdf",
        display_name: "Important Document"
      )

      # With progress tracking
      {:ok, file} = Gemini.APIs.Files.upload("large_video.mp4",
        on_progress: fn uploaded, total ->
          IO.puts("Progress: \#{div(uploaded * 100, total)}%")
        end
      )
  """
  @spec upload(Path.t() | String.t(), upload_opts()) ::
          {:ok, File.t()} | {:error, term()}
  def upload(file_path, opts \\ []) do
    file_path = to_string(file_path)

    # Validate file exists
    if @elixir_file.exists?(file_path) do
      # Get file info
      file_size = @elixir_file.stat!(file_path).size
      mime_type = Keyword.get(opts, :mime_type) || detect_mime_type(file_path)
      display_name = Keyword.get(opts, :display_name) || Path.basename(file_path)

      # Prepare file metadata
      file_metadata = %{
        file: %{
          displayName: display_name,
          mimeType: mime_type
        }
      }

      # Add custom name if provided
      file_metadata =
        case Keyword.get(opts, :name) do
          nil -> file_metadata
          name -> put_in(file_metadata, [:file, :name], name)
        end

      # Initiate resumable upload
      with {:ok, upload_url} <-
             initiate_resumable_upload(file_metadata, file_size, mime_type, opts),
           {:ok, response} <- upload_file_data(upload_url, file_path, file_size, opts) do
        {:ok, File.from_api_response(response)}
      end
    else
      {:error, {:file_not_found, file_path}}
    end
  end

  @doc """
  Upload a file from binary data.

  ## Parameters

  - `data` - Binary data to upload
  - `opts` - Upload options (`:mime_type` is required)

  ## Examples

      image_data = File.read!("image.png")
      {:ok, file} = Gemini.APIs.Files.upload_data(image_data,
        mime_type: "image/png",
        display_name: "My Image"
      )
  """
  @spec upload_data(binary(), upload_opts()) :: {:ok, File.t()} | {:error, term()}
  def upload_data(data, opts) when is_binary(data) do
    mime_type = Keyword.get(opts, :mime_type)

    if mime_type do
      file_size = byte_size(data)
      display_name = Keyword.get(opts, :display_name, "uploaded_file")

      file_metadata = %{
        file: %{
          displayName: display_name,
          mimeType: mime_type
        }
      }

      with {:ok, upload_url} <-
             initiate_resumable_upload(file_metadata, file_size, mime_type, opts),
           {:ok, response} <- upload_binary_data(upload_url, data, file_size, opts) do
        {:ok, File.from_api_response(response)}
      end
    else
      {:error, {:missing_required_option, :mime_type}}
    end
  end

  @doc """
  Get file metadata by name.

  ## Parameters

  - `name` - File resource name (e.g., "files/abc123")
  - `opts` - Options

  ## Examples

      {:ok, file} = Gemini.APIs.Files.get("files/abc123")
      IO.puts("State: \#{file.state}")
      IO.puts("MIME type: \#{file.mime_type}")
  """
  @spec get(String.t(), file_opts()) :: {:ok, File.t()} | {:error, term()}
  def get(name, opts \\ []) do
    path = normalize_file_path(name)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, File.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all uploaded files.

  ## Parameters

  - `opts` - List options

  ## Options

  - `:page_size` - Number of files per page (default: 100, max: 1000)
  - `:page_token` - Token from previous response for pagination
  - `:auth` - Authentication strategy

  ## Examples

      # List first page
      {:ok, response} = Gemini.APIs.Files.list()
      Enum.each(response.files, fn file ->
        IO.puts("\#{file.name}: \#{file.mime_type}")
      end)

      # Paginate through all files
      {:ok, all_files} = Gemini.APIs.Files.list_all()
  """
  @spec list(list_opts()) :: {:ok, ListFilesResponse.t()} | {:error, term()}
  def list(opts \\ []) do
    path = build_list_path(opts)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, ListFilesResponse.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all files across all pages.

  Automatically handles pagination to retrieve all files.

  ## Parameters

  - `opts` - List options (`:page_size` can be set, default 100)

  ## Examples

      {:ok, all_files} = Gemini.APIs.Files.list_all()
      IO.puts("Total files: \#{length(all_files)}")
  """
  @spec list_all(list_opts()) :: {:ok, [File.t()]} | {:error, term()}
  def list_all(opts \\ []) do
    collect_all_files(opts, [])
  end

  @doc """
  Delete a file.

  ## Parameters

  - `name` - File resource name (e.g., "files/abc123")
  - `opts` - Options

  ## Examples

      :ok = Gemini.APIs.Files.delete("files/abc123")
  """
  @spec delete(String.t(), file_opts()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    path = normalize_file_path(name)

    case HTTP.delete(path, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Wait for a file to finish processing.

  Polls the file status until it reaches `:active` or `:failed` state.

  ## Parameters

  - `name` - File resource name
  - `opts` - Options

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 2000)
  - `:timeout` - Maximum wait time in milliseconds (default: 300000 = 5 min)
  - `:on_status` - Callback for status updates `fn(File.t()) -> any()`

  ## Examples

      {:ok, file} = Gemini.APIs.Files.upload("video.mp4")

      {:ok, ready_file} = Gemini.APIs.Files.wait_for_processing(file.name,
        poll_interval: 5000,
        on_status: fn f -> IO.puts("Status: \#{f.state}") end
      )
  """
  @spec wait_for_processing(String.t(), keyword()) ::
          {:ok, File.t()} | {:error, term()}
  def wait_for_processing(name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 2000)
    timeout = Keyword.get(opts, :timeout, 300_000)
    on_status = Keyword.get(opts, :on_status)
    file_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)
    do_wait_for_processing(name, file_opts, poll_interval, timeout, start_time, on_status)
  end

  @doc """
  Download a generated file's content.

  Only works for files with `source: :generated` (e.g., from video generation).
  Uploaded files cannot be downloaded - you already have the source.

  ## Parameters

  - `file` - File struct or file name
  - `opts` - Options

  ## Examples

      {:ok, file} = Gemini.APIs.Files.get("files/generated-video-123")
      {:ok, video_data} = Gemini.APIs.Files.download(file)
      File.write!("output.mp4", video_data)
  """
  @spec download(File.t() | String.t(), file_opts()) ::
          {:ok, binary()} | {:error, term()}
  def download(file_or_name, opts \\ [])

  def download(%File{} = file, opts) do
    if File.downloadable?(file) do
      do_download(file.download_uri, opts)
    else
      {:error, :not_downloadable}
    end
  end

  def download(name, opts) when is_binary(name) do
    with {:ok, file} <- get(name, opts) do
      download(file, opts)
    end
  end

  # Private Functions

  defp initiate_resumable_upload(file_metadata, file_size, mime_type, _opts) do
    # The upload endpoint uses a different URL structure:
    # https://generativelanguage.googleapis.com/upload/v1beta/files
    # NOT the standard base_url/path pattern
    api_key = Gemini.Config.api_key()

    url = "https://generativelanguage.googleapis.com/upload/v1beta/files?key=#{api_key}"

    headers = [
      {"Content-Type", "application/json"},
      {"X-Goog-Upload-Protocol", "resumable"},
      {"X-Goog-Upload-Command", "start"},
      {"X-Goog-Upload-Header-Content-Length", to_string(file_size)},
      {"X-Goog-Upload-Header-Content-Type", mime_type}
    ]

    body = Jason.encode!(file_metadata)

    case Req.post(url, body: body, headers: headers) do
      {:ok, %Req.Response{status: 200, headers: resp_headers}} ->
        case get_upload_url_from_headers(resp_headers) do
          nil -> {:error, :missing_upload_url}
          upload_url -> {:ok, upload_url}
        end

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:error, Gemini.Error.http_error(status, resp_body)}

      {:error, reason} ->
        {:error, Gemini.Error.network_error(reason)}
    end
  end

  defp get_upload_url_from_headers(headers) do
    Enum.find_value(headers, fn
      # Req wraps header values in lists
      {"x-goog-upload-url", [url | _]} -> url
      {"x-goog-upload-url", url} when is_binary(url) -> url
      _ -> nil
    end)
  end

  defp upload_file_data(upload_url, file_path, file_size, opts) do
    on_progress = Keyword.get(opts, :on_progress)

    @elixir_file.open!(file_path, [:read, :binary], fn file_handle ->
      upload_chunks(upload_url, file_handle, file_size, 0, on_progress, opts)
    end)
  end

  defp upload_binary_data(upload_url, data, file_size, opts) do
    on_progress = Keyword.get(opts, :on_progress)
    upload_binary_chunks(upload_url, data, file_size, 0, on_progress, opts)
  end

  defp upload_chunks(upload_url, file_handle, total_size, offset, on_progress, opts) do
    chunk = IO.binread(file_handle, @chunk_size)

    case chunk do
      :eof ->
        {:error, :unexpected_eof}

      {:error, reason} ->
        {:error, reason}

      data when is_binary(data) ->
        upload_chunk_data(
          upload_url,
          data,
          file_handle,
          total_size,
          offset,
          on_progress,
          opts
        )
    end
  end

  defp upload_binary_chunks(_upload_url, _data, total_size, offset, _on_progress, _opts)
       when offset >= total_size do
    {:error, :unexpected_end}
  end

  defp upload_binary_chunks(upload_url, data, total_size, offset, on_progress, opts) do
    remaining = byte_size(data) - offset
    chunk_size = min(@chunk_size, remaining)
    chunk = binary_part(data, offset, chunk_size)
    is_final = offset + chunk_size >= total_size
    command = if is_final, do: "upload, finalize", else: "upload"

    headers = [
      {"X-Goog-Upload-Command", command},
      {"X-Goog-Upload-Offset", to_string(offset)},
      {"Content-Length", to_string(chunk_size)}
    ]

    case upload_chunk_with_retry(upload_url, chunk, headers, opts, @max_retries) do
      {:ok, response} ->
        new_offset = offset + chunk_size

        if on_progress, do: on_progress.(new_offset, total_size)

        if is_final do
          {:ok, response}
        else
          upload_binary_chunks(upload_url, data, total_size, new_offset, on_progress, opts)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp upload_chunk_with_retry(_url, _data, _headers, _opts, 0) do
    {:error, :max_retries_exceeded}
  end

  defp upload_chunk_with_retry(url, data, headers, opts, retries_left) do
    case do_upload_chunk(url, data, headers, opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, :retriable} ->
        delay = @initial_retry_delay * round(:math.pow(2, @max_retries - retries_left))
        Process.sleep(delay)
        upload_chunk_with_retry(url, data, headers, opts, retries_left - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_upload_chunk(url, data, headers, _opts) do
    # Use Req directly for the upload URL (it's an absolute URL)
    req = Req.new(url: url, body: data, headers: headers)

    case Req.post(req) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status}} when status in [408, 429, 500, 502, 503, 504] ->
        {:error, :retriable}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_file_path("files/" <> _ = name), do: name
  defp normalize_file_path(name), do: "files/#{name}"

  defp build_list_path(opts) do
    query_params = []

    query_params =
      case Keyword.get(opts, :page_size) do
        nil -> query_params
        size -> [{"pageSize", size} | query_params]
      end

    query_params =
      case Keyword.get(opts, :page_token) do
        nil -> query_params
        token -> [{"pageToken", token} | query_params]
      end

    case query_params do
      [] -> "files"
      params -> "files?" <> URI.encode_query(params)
    end
  end

  defp collect_all_files(opts, acc) do
    case list(opts) do
      {:ok, %{files: files, next_page_token: nil}} ->
        {:ok, acc ++ files}

      {:ok, %{files: files, next_page_token: token}} ->
        collect_all_files(Keyword.put(opts, :page_token, token), acc ++ files)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_wait_for_processing(name, opts, poll_interval, timeout, start_time, on_status) do
    case get(name, opts) do
      {:ok, file} ->
        maybe_report_status(on_status, file)
        handle_file_state(file, name, opts, poll_interval, timeout, start_time, on_status)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_download(download_uri, _opts) do
    req = Req.new(url: download_uri)

    case Req.get(req) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @mime_by_ext %{
    ".aac" => "audio/aac",
    ".aiff" => "audio/aiff",
    ".avi" => "video/x-msvideo",
    ".css" => "text/css",
    ".csv" => "text/csv",
    ".flac" => "audio/flac",
    ".flv" => "video/x-flv",
    ".gif" => "image/gif",
    ".heic" => "image/heic",
    ".heif" => "image/heif",
    ".htm" => "text/html",
    ".html" => "text/html",
    ".jpeg" => "image/jpeg",
    ".jpg" => "image/jpeg",
    ".js" => "text/javascript",
    ".json" => "application/json",
    ".m4a" => "audio/mp4",
    ".mkv" => "video/x-matroska",
    ".md" => "text/markdown",
    ".mov" => "video/quicktime",
    ".mp3" => "audio/mpeg",
    ".mp4" => "video/mp4",
    ".mpeg" => "video/mpeg",
    ".mpg" => "video/mpeg",
    ".ogg" => "audio/ogg",
    ".pdf" => "application/pdf",
    ".png" => "image/png",
    ".txt" => "text/plain",
    ".wav" => "audio/wav",
    ".webm" => "video/webm",
    ".webp" => "image/webp",
    ".wmv" => "video/x-ms-wmv",
    ".xml" => "application/xml"
  }

  defp detect_mime_type(file_path) do
    file_path
    |> Path.extname()
    |> String.downcase()
    |> then(&Map.get(@mime_by_ext, &1, "application/octet-stream"))
  end

  defp upload_chunk_data(
         upload_url,
         data,
         file_handle,
         total_size,
         offset,
         on_progress,
         opts
       ) do
    chunk_size = byte_size(data)
    is_final = offset + chunk_size >= total_size
    command = if is_final, do: "upload, finalize", else: "upload"

    headers = [
      {"X-Goog-Upload-Command", command},
      {"X-Goog-Upload-Offset", to_string(offset)},
      {"Content-Length", to_string(chunk_size)}
    ]

    with {:ok, response} <- upload_chunk_with_retry(upload_url, data, headers, opts, @max_retries) do
      new_offset = offset + chunk_size
      maybe_report_progress(on_progress, new_offset, total_size)

      if is_final do
        {:ok, response}
      else
        upload_chunks(upload_url, file_handle, total_size, new_offset, on_progress, opts)
      end
    end
  end

  defp maybe_report_progress(nil, _offset, _total), do: :ok
  defp maybe_report_progress(on_progress, offset, total), do: on_progress.(offset, total)

  defp handle_file_state(%{state: :active} = file, _name, _opts, _poll, _timeout, _start, _cb),
    do: {:ok, file}

  defp handle_file_state(
         %{state: :failed, error: error},
         _name,
         _opts,
         _poll,
         _timeout,
         _start,
         _cb
       ),
       do: {:error, {:file_processing_failed, error}}

  defp handle_file_state(
         %{state: :processing} = _file,
         name,
         opts,
         poll_interval,
         timeout,
         start_time,
         on_status
       ) do
    if processing_timed_out?(start_time, timeout) do
      {:error, :timeout}
    else
      Process.sleep(poll_interval)

      do_wait_for_processing(
        name,
        opts,
        poll_interval,
        timeout,
        start_time,
        on_status
      )
    end
  end

  defp handle_file_state(%{state: state}, _name, _opts, _poll, _timeout, _start, _cb),
    do: {:error, {:unknown_state, state}}

  defp maybe_report_status(nil, _file), do: :ok
  defp maybe_report_status(callback, file), do: callback.(file)

  defp processing_timed_out?(start_time, timeout) do
    System.monotonic_time(:millisecond) - start_time >= timeout
  end
end
