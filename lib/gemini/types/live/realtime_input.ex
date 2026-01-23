defmodule Gemini.Types.Live.RealtimeInput do
  @moduledoc """
  Realtime input for Live API sessions.

  User input that is sent in real time. Different from ClientContent in that:
  - Can be sent continuously without interrupting model generation
  - End of turn is derived from user activity (e.g., end of speech)
  - Data is processed incrementally for fast response start
  - Always assumed to be user's input (cannot populate conversation history)

  ## Fields

  - `media_chunks` - Deprecated: Use audio, video, or text instead
  - `audio` - Realtime audio input stream
  - `video` - Realtime video input stream
  - `text` - Realtime text input stream
  - `activity_start` - Marks start of user activity (only with manual detection)
  - `activity_end` - Marks end of user activity (only with manual detection)
  - `audio_stream_end` - Indicates audio stream has ended (e.g., mic off)

  ## Example

      # Audio input
      %RealtimeInput{
        audio: %{mime_type: "audio/pcm", data: base64_audio_data}
      }

      # Text input
      %RealtimeInput{text: "Hello, how are you?"}
  """

  alias Gemini.Types.Blob

  @type t :: %__MODULE__{
          media_chunks: [Blob.t() | map()] | nil,
          audio: Blob.t() | map() | nil,
          video: Blob.t() | map() | nil,
          text: String.t() | nil,
          activity_start: boolean() | nil,
          activity_end: boolean() | nil,
          audio_stream_end: boolean() | nil
        }

  defstruct [
    :media_chunks,
    :audio,
    :video,
    :text,
    :activity_start,
    :activity_end,
    :audio_stream_end
  ]

  @doc """
  Creates a new RealtimeInput.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      media_chunks: Keyword.get(opts, :media_chunks),
      audio: Keyword.get(opts, :audio),
      video: Keyword.get(opts, :video),
      text: Keyword.get(opts, :text),
      activity_start: Keyword.get(opts, :activity_start),
      activity_end: Keyword.get(opts, :activity_end),
      audio_stream_end: Keyword.get(opts, :audio_stream_end)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("mediaChunks", convert_blobs_to_api(value.media_chunks))
    |> maybe_put("audio", convert_blob_to_api(value.audio))
    |> maybe_put("video", convert_blob_to_api(value.video))
    |> maybe_put("text", value.text)
    |> maybe_put("activityStart", if(value.activity_start, do: %{}))
    |> maybe_put("activityEnd", if(value.activity_end, do: %{}))
    |> maybe_put("audioStreamEnd", value.audio_stream_end)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      media_chunks: parse_blobs(data["mediaChunks"] || data["media_chunks"]),
      audio: parse_blob(data["audio"]),
      video: parse_blob(data["video"]),
      text: data["text"],
      activity_start: data["activityStart"] != nil || data["activity_start"] != nil,
      activity_end: data["activityEnd"] != nil || data["activity_end"] != nil,
      audio_stream_end: data["audioStreamEnd"] || data["audio_stream_end"]
    }
  end

  defp convert_blobs_to_api(nil), do: nil

  defp convert_blobs_to_api(blobs) when is_list(blobs) do
    Enum.map(blobs, &convert_blob_to_api/1)
  end

  defp convert_blob_to_api(nil), do: nil

  defp convert_blob_to_api(%Blob{} = blob) do
    %{
      "mimeType" => blob.mime_type,
      "data" => blob.data
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp convert_blob_to_api(%{mime_type: mime_type, data: data}) do
    %{
      "mimeType" => mime_type,
      "data" => data
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp convert_blob_to_api(other), do: other

  defp parse_blobs(nil), do: nil

  defp parse_blobs(blobs) when is_list(blobs) do
    Enum.map(blobs, &parse_blob/1)
  end

  defp parse_blob(nil), do: nil

  defp parse_blob(data) when is_map(data) do
    %{
      mime_type: data["mimeType"] || data["mime_type"],
      data: data["data"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
