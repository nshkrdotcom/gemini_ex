defmodule Gemini.Types.File do
  @moduledoc """
  Type definitions for file management operations.

  The Files API allows uploading, downloading, and managing files that can be
  used with Gemini models for multimodal content generation.

  ## File States

  Files go through several states during processing:

  - `:state_unspecified` - Initial/unknown state
  - `:processing` - File is being processed
  - `:active` - File is ready to use
  - `:failed` - Processing failed

  ## File Sources

  - `:source_unspecified` - Unknown source
  - `:uploaded` - User uploaded the file
  - `:generated` - API generated the file (e.g., from video generation)
  - `:registered` - File registered from GCS via RegisterFiles API

  ## Example

      # Upload a file
      {:ok, file} = Gemini.upload_file("path/to/image.png")

      # Check file state
      case file.state do
        :active -> IO.puts("File is ready: \#{file.uri}")
        :processing -> IO.puts("Still processing...")
        :failed -> IO.puts("Failed: \#{file.error}")
      end

      # Use in content generation
      {:ok, response} = Gemini.generate([
        "What's in this image?",
        %{file_uri: file.uri, mime_type: file.mime_type}
      ])
  """

  use TypedStruct

  @typedoc """
  File state enumeration values.

  - `:state_unspecified` - Initial/unknown state
  - `:processing` - File is being processed by the API
  - `:active` - File is ready to use in requests
  - `:failed` - File processing failed (check error field)
  """
  @type file_state ::
          :state_unspecified
          | :processing
          | :active
          | :failed

  @typedoc """
  File source enumeration values.

  - `:source_unspecified` - Unknown source
  - `:uploaded` - User uploaded the file
  - `:generated` - API generated the file (e.g., video generation)
  - `:registered` - File registered from GCS via RegisterFiles API
  """
  @type file_source ::
          :source_unspecified
          | :uploaded
          | :generated
          | :registered

  @typedoc """
  Video metadata for video files.
  """
  @type video_metadata :: %{
          optional(:video_duration) => String.t(),
          optional(:video_duration_seconds) => integer()
        }

  @typedoc """
  File status/error information.
  """
  @type file_status :: %{
          optional(:message) => String.t(),
          optional(:code) => integer()
        }

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Represents a file in the Gemini API.

    ## Writable Fields (can be set on upload)

    - `name` - Resource name (format: "files/{file_id}")
    - `display_name` - Human-readable display name (max 512 characters)
    - `mime_type` - MIME type (e.g., "image/png", "video/mp4")

    ## Read-Only Fields (output only)

    - `size_bytes` - File size in bytes
    - `create_time` - Creation timestamp (ISO 8601)
    - `expiration_time` - When the file expires (ISO 8601)
    - `update_time` - Last update timestamp (ISO 8601)
    - `sha256_hash` - Base64-encoded SHA256 hash
    - `uri` - URI for using the file in content (e.g., "gs://...")
    - `download_uri` - Download URI (only for generated files)
    - `state` - Current processing state
    - `source` - How the file was created
    - `video_metadata` - Metadata for video files
    - `error` - Error information if state is :failed
    """

    # Writable fields
    field(:name, String.t())
    field(:display_name, String.t())
    field(:mime_type, String.t())

    # Read-only fields (output only)
    field(:size_bytes, integer())
    field(:create_time, String.t())
    field(:expiration_time, String.t())
    field(:update_time, String.t())
    field(:sha256_hash, String.t())
    field(:uri, String.t())
    field(:download_uri, String.t())
    field(:state, file_state())
    field(:source, file_source())
    field(:video_metadata, video_metadata())
    field(:error, file_status())
  end

  @doc """
  Creates a new File struct from API response.

  ## Parameters

  - `response` - Map from API response with string keys

  ## Examples

      response = %{
        "name" => "files/abc123",
        "displayName" => "my-image.png",
        "mimeType" => "image/png",
        "sizeBytes" => "1024",
        "state" => "ACTIVE"
      }
      file = Gemini.Types.File.from_api_response(response)
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    # Handle both nested {"file": {...}} and flat response formats
    file_data = response["file"] || response

    %__MODULE__{
      name: file_data["name"],
      display_name: file_data["displayName"],
      mime_type: file_data["mimeType"],
      size_bytes: parse_size_bytes(file_data["sizeBytes"]),
      create_time: file_data["createTime"],
      expiration_time: file_data["expirationTime"],
      update_time: file_data["updateTime"],
      sha256_hash: file_data["sha256Hash"],
      uri: file_data["uri"],
      download_uri: file_data["downloadUri"],
      state: parse_state(file_data["state"]),
      source: parse_source(file_data["source"]),
      video_metadata: parse_video_metadata(file_data["videoMetadata"]),
      error: parse_error(file_data["error"])
    }
  end

  @doc """
  Converts file state atom to API string format.
  """
  @spec state_to_api(file_state()) :: String.t()
  def state_to_api(:state_unspecified), do: "STATE_UNSPECIFIED"
  def state_to_api(:processing), do: "PROCESSING"
  def state_to_api(:active), do: "ACTIVE"
  def state_to_api(:failed), do: "FAILED"

  @doc """
  Parses API state string to atom.
  """
  @spec parse_state(String.t() | nil) :: file_state() | nil
  def parse_state("STATE_UNSPECIFIED"), do: :state_unspecified
  def parse_state("PROCESSING"), do: :processing
  def parse_state("ACTIVE"), do: :active
  def parse_state("FAILED"), do: :failed
  def parse_state(nil), do: nil
  def parse_state(_), do: :state_unspecified

  @doc """
  Converts file source atom to API string format.
  """
  @spec source_to_api(file_source()) :: String.t()
  def source_to_api(:source_unspecified), do: "SOURCE_UNSPECIFIED"
  def source_to_api(:uploaded), do: "UPLOADED"
  def source_to_api(:generated), do: "GENERATED"
  def source_to_api(:registered), do: "REGISTERED"

  @doc """
  Parses API source string to atom.
  """
  @spec parse_source(String.t() | nil) :: file_source() | nil
  def parse_source("SOURCE_UNSPECIFIED"), do: :source_unspecified
  def parse_source("UPLOADED"), do: :uploaded
  def parse_source("GENERATED"), do: :generated
  def parse_source("REGISTERED"), do: :registered
  def parse_source(nil), do: nil
  def parse_source(_), do: :source_unspecified

  @doc """
  Checks if the file is ready to use.
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{state: :active}), do: true
  def active?(_), do: false

  @doc """
  Checks if the file is still processing.
  """
  @spec processing?(t()) :: boolean()
  def processing?(%__MODULE__{state: :processing}), do: true
  def processing?(_), do: false

  @doc """
  Checks if the file processing failed.
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{state: :failed}), do: true
  def failed?(_), do: false

  @doc """
  Checks if the file can be downloaded (only generated files).
  """
  @spec downloadable?(t()) :: boolean()
  def downloadable?(%__MODULE__{source: :generated, download_uri: uri})
      when is_binary(uri) and uri != "",
      do: true

  def downloadable?(_), do: false

  @doc """
  Extracts the file ID from the file name.

  ## Examples

      file = %Gemini.Types.File{name: "files/abc123"}
      Gemini.Types.File.get_id(file)
      # => "abc123"
  """
  @spec get_id(t()) :: String.t() | nil
  def get_id(%__MODULE__{name: nil}), do: nil

  def get_id(%__MODULE__{name: name}) do
    case String.split(name, "/") do
      ["files", id] -> id
      _ -> name
    end
  end

  # Private helpers

  defp parse_size_bytes(nil), do: nil
  defp parse_size_bytes(size) when is_integer(size), do: size

  defp parse_size_bytes(size) when is_binary(size) do
    case Integer.parse(size) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_video_metadata(nil), do: nil

  defp parse_video_metadata(metadata) when is_map(metadata) do
    %{
      video_duration: metadata["videoDuration"],
      video_duration_seconds:
        metadata["videoDurationSeconds"] &&
          parse_size_bytes(metadata["videoDurationSeconds"])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_error(nil), do: nil

  defp parse_error(error) when is_map(error) do
    %{
      message: error["message"],
      code: error["code"]
    }
  end
end

defmodule Gemini.Types.ListFilesResponse do
  @moduledoc """
  Response type for listing files.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response from listing files.

    - `files` - List of File structs
    - `next_page_token` - Token for fetching next page (nil if no more pages)
    """
    field(:files, [Gemini.Types.File.t()], default: [])
    field(:next_page_token, String.t())
  end

  @doc """
  Creates a ListFilesResponse from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    files =
      (response["files"] || [])
      |> Enum.map(&Gemini.Types.File.from_api_response/1)

    %__MODULE__{
      files: files,
      next_page_token: response["nextPageToken"]
    }
  end

  @doc """
  Checks if there are more pages available.
  """
  @spec has_more_pages?(t()) :: boolean()
  def has_more_pages?(%__MODULE__{next_page_token: nil}), do: false
  def has_more_pages?(%__MODULE__{next_page_token: ""}), do: false
  def has_more_pages?(%__MODULE__{next_page_token: _}), do: true
end

defmodule Gemini.Types.UploadFileConfig do
  @moduledoc """
  Configuration options for file upload.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Upload file configuration.

    - `name` - Custom file name (auto-generated if not provided)
    - `display_name` - Human-readable name (max 512 characters)
    - `mime_type` - MIME type (auto-detected if not provided)
    """
    field(:name, String.t())
    field(:display_name, String.t())
    field(:mime_type, String.t())
  end
end

defmodule Gemini.Types.DeleteFileResponse do
  @moduledoc """
  Response type for file deletion.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response from deleting a file (empty on success).
    """
    field(:success, boolean(), default: true)
  end
end
