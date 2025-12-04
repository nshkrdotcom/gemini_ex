defmodule Gemini.Types.Part do
  @moduledoc """
  Part type for content in Gemini API.

  ## Gemini 3 Features

  ### Media Resolution

  Control token allocation for media processing with `media_resolution`:
  - `:low` - 280 tokens for images, 70 for video
  - `:medium` - 560 tokens for images, 70 for video
  - `:high` - 1120 tokens for images, 280 for video

  ### Thought Signature

  Gemini 3 returns `thought_signature` fields that must be echoed back
  in subsequent turns to maintain reasoning context. The SDK handles
  this automatically in chat sessions.
  """

  use TypedStruct

  defmodule MediaResolution do
    @moduledoc """
    Media resolution settings for Gemini 3 vision processing.
    """

    use TypedStruct

    @type level :: :media_resolution_low | :media_resolution_medium | :media_resolution_high

    @derive Jason.Encoder
    typedstruct do
      field(:level, level() | nil, default: nil)
    end
  end

  @derive Jason.Encoder
  typedstruct do
    field(:text, String.t() | nil, default: nil)
    field(:inline_data, Gemini.Types.Blob.t() | nil, default: nil)
    field(:function_call, Altar.ADM.FunctionCall.t() | nil, default: nil)
    field(:media_resolution, MediaResolution.t() | nil, default: nil)
    field(:thought_signature, String.t() | nil, default: nil)
  end

  @typedoc "Text content."
  @type text_content :: String.t() | nil

  @typedoc "Inline data (base64 encoded)."
  @type inline_data :: Gemini.Types.Blob.t() | nil

  @doc """
  Create a text part.
  """
  @spec text(String.t()) :: t()
  def text(text) when is_binary(text) do
    %__MODULE__{text: text}
  end

  @doc """
  Create an inline data part with base64 encoded data.
  """
  @spec inline_data(String.t(), String.t()) :: t()
  def inline_data(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    blob = Gemini.Types.Blob.new(data, mime_type)
    %__MODULE__{inline_data: blob}
  end

  @doc """
  Create a blob part with raw data and MIME type.
  """
  @spec blob(String.t(), String.t()) :: t()
  def blob(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    blob = Gemini.Types.Blob.new(data, mime_type)
    %__MODULE__{inline_data: blob}
  end

  @doc """
  Create a part from a file path.
  """
  @spec file(String.t()) :: t()
  def file(path) when is_binary(path) do
    case Gemini.Types.Blob.from_file(path) do
      {:ok, blob} -> %__MODULE__{inline_data: blob}
      {:error, _error} -> %__MODULE__{text: "Error loading file: #{path}"}
    end
  end

  @doc """
  Create an inline data part with media resolution for Gemini 3.

  ## Parameters
  - `data`: Base64 encoded data
  - `mime_type`: MIME type of the data
  - `resolution`: Media resolution level (`:low`, `:medium`, or `:high`)

  ## Examples

      # High resolution for detailed image analysis
      Part.inline_data_with_resolution(image_data, "image/jpeg", :high)

      # Low resolution for faster processing
      Part.inline_data_with_resolution(video_frame, "image/png", :low)
  """
  @spec inline_data_with_resolution(String.t(), String.t(), :low | :medium | :high) :: t()
  def inline_data_with_resolution(data, mime_type, resolution)
      when is_binary(data) and is_binary(mime_type) and resolution in [:low, :medium, :high] do
    blob = Gemini.Types.Blob.new(data, mime_type)

    resolution_level =
      case resolution do
        :low -> :media_resolution_low
        :medium -> :media_resolution_medium
        :high -> :media_resolution_high
      end

    %__MODULE__{
      inline_data: blob,
      media_resolution: %MediaResolution{level: resolution_level}
    }
  end

  @doc """
  Set media resolution on an existing part.

  ## Parameters
  - `part`: Existing Part struct
  - `resolution`: Resolution level (`:low`, `:medium`, or `:high`)

  ## Examples

      part = Part.inline_data(image_data, "image/jpeg")
      |> Part.with_resolution(:high)
  """
  @spec with_resolution(t(), :low | :medium | :high) :: t()
  def with_resolution(%__MODULE__{} = part, resolution)
      when resolution in [:low, :medium, :high] do
    resolution_level =
      case resolution do
        :low -> :media_resolution_low
        :medium -> :media_resolution_medium
        :high -> :media_resolution_high
      end

    %{part | media_resolution: %MediaResolution{level: resolution_level}}
  end

  @doc """
  Set thought signature on an existing part.

  Used to maintain reasoning context across API calls in Gemini 3.
  The SDK handles this automatically in most cases.

  ## Parameters
  - `part`: Existing Part struct
  - `signature`: Thought signature string from a previous response
  """
  @spec with_thought_signature(t(), String.t()) :: t()
  def with_thought_signature(%__MODULE__{} = part, signature) when is_binary(signature) do
    %{part | thought_signature: signature}
  end
end
