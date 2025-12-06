defmodule Gemini.Types.Generation.Video do
  @moduledoc """
  Type definitions for video generation using Google's Veo models.

  Veo is Google's advanced text-to-video generation model that creates high-quality
  videos from text descriptions. Video generation is a long-running operation that
  requires polling to check completion status.

  ## Supported Models

  - `veo-2.0-generate-001` - Veo 2.0 video generation model

  ## Example

      config = %VideoGenerationConfig{
        number_of_videos: 1,
        duration_seconds: 8,
        aspect_ratio: "16:9"
      }

      {:ok, operation} = Gemini.APIs.Videos.generate(
        "A cat playing piano in a cozy living room",
        config
      )

      # Wait for completion
      {:ok, completed} = Gemini.APIs.Operations.wait(operation.name)

      # Get video URLs
      videos = completed.response["generatedVideos"]

  See `Gemini.APIs.Videos` for API functions.
  """

  use TypedStruct

  @typedoc """
  Aspect ratio for generated videos.

  Common aspect ratios:
  - `"9:16"` - Vertical/mobile (e.g., 720x1280)
  - `"16:9"` - Horizontal/desktop (e.g., 1280x720)
  - `"1:1"` - Square (e.g., 1024x1024)
  """
  @type aspect_ratio :: String.t()

  @typedoc """
  Video compression format.

  - `:h264` - H.264/AVC compression (default, widely compatible)
  - `:h265` - H.265/HEVC compression (better quality, smaller size)
  """
  @type compression_format :: :h264 | :h265

  typedstruct module: VideoGenerationConfig do
    @derive Jason.Encoder
    @moduledoc """
    Configuration for video generation requests.

    ## Fields

    - `number_of_videos` - Number of videos to generate (1-4, default: 1)
    - `duration_seconds` - Video duration in seconds (4-8, default: 8)
    - `aspect_ratio` - Video aspect ratio (default: "16:9")
    - `fps` - Frames per second (24, 25, or 30, default: 24)
    - `compression_format` - Video compression format (default: :h264)
    - `safety_filter_level` - Content safety filtering (default: :block_some)
    - `negative_prompt` - Text describing what to avoid in the video
    - `seed` - Random seed for reproducibility
    - `guidance_scale` - How closely to follow the prompt (1.0-20.0)
    - `person_generation` - Person generation policy (default: :dont_allow)
    """

    field(:number_of_videos, pos_integer(), default: 1)
    field(:duration_seconds, pos_integer(), default: 8)
    field(:aspect_ratio, String.t(), default: "16:9")
    field(:fps, pos_integer(), default: 24)
    field(:compression_format, Gemini.Types.Generation.Video.compression_format(), default: :h264)
    field(:safety_filter_level, atom(), default: :block_some)
    field(:negative_prompt, String.t())
    field(:seed, integer())
    field(:guidance_scale, float())
    field(:person_generation, atom(), default: :dont_allow)
  end

  @type t :: VideoGenerationConfig.t()

  typedstruct module: GeneratedVideo do
    @derive Jason.Encoder
    @moduledoc """
    Represents a generated video result.

    ## Fields

    - `video_uri` - GCS URI where the video is stored
    - `video_data` - Base64-encoded video data (if requested inline)
    - `mime_type` - MIME type of the video (e.g., "video/mp4")
    - `duration_seconds` - Actual duration of the video
    - `resolution` - Video resolution (width x height)
    - `safety_attributes` - Safety classification results
    - `rai_info` - Responsible AI filtering information
    """

    field(:video_uri, String.t())
    field(:video_data, String.t())
    field(:mime_type, String.t())
    field(:duration_seconds, float())
    field(:resolution, map())
    field(:safety_attributes, map())
    field(:rai_info, map())
  end

  typedstruct module: VideoOperation do
    @derive Jason.Encoder
    @moduledoc """
    Represents a video generation operation with progress tracking.

    Video generation is a long-running operation that can take several minutes.
    This struct wraps the base Operation type with video-specific helpers.

    ## Fields

    - `operation` - Base Operation struct
    - `progress_percent` - Estimated completion percentage (0-100)
    - `estimated_completion_time` - Estimated time until completion
    """

    field(:operation, Gemini.Types.Operation.t())
    field(:progress_percent, float())
    field(:estimated_completion_time, DateTime.t())
  end

  @doc """
  Converts compression format to API format.

  ## Examples

      iex> format_compression_format(:h264)
      "h264"
  """
  @spec format_compression_format(compression_format()) :: String.t()
  def format_compression_format(:h264), do: "h264"
  def format_compression_format(:h265), do: "h265"

  @doc """
  Converts safety filter level to API format.
  """
  @spec format_safety_filter_level(atom()) :: String.t()
  def format_safety_filter_level(:block_most), do: "blockMost"
  def format_safety_filter_level(:block_some), do: "blockSome"
  def format_safety_filter_level(:block_few), do: "blockFew"
  def format_safety_filter_level(:block_none), do: "blockNone"

  @doc """
  Converts person generation policy to API format.
  """
  @spec format_person_generation(atom()) :: String.t()
  def format_person_generation(:allow_adult), do: "allowAdult"
  def format_person_generation(:allow_all), do: "allowAll"
  def format_person_generation(:dont_allow), do: "dontAllow"

  @doc """
  Builds parameters map for video generation API request.
  """
  @spec build_generation_params(String.t(), VideoGenerationConfig.t()) :: map()
  def build_generation_params(prompt, config) do
    params = %{
      "prompt" => prompt,
      "videoConfig" => %{
        "sampleCount" => config.number_of_videos,
        "durationSeconds" => config.duration_seconds,
        "aspectRatio" => config.aspect_ratio,
        "fps" => config.fps,
        "compressionFormat" => format_compression_format(config.compression_format)
      },
      "safetyFilterLevel" => format_safety_filter_level(config.safety_filter_level),
      "personGeneration" => format_person_generation(config.person_generation)
    }

    params
    |> add_if_present("negativePrompt", config.negative_prompt)
    |> add_if_present("seed", config.seed)
    |> add_if_present("guidanceScale", config.guidance_scale)
  end

  @doc """
  Parses a generated video from API response.
  """
  @spec parse_generated_video(map()) :: GeneratedVideo.t()
  def parse_generated_video(data) when is_map(data) do
    %GeneratedVideo{
      video_uri: data["videoUri"] || data["gcsUri"],
      video_data: data["bytesBase64Encoded"],
      mime_type: data["mimeType"],
      duration_seconds: data["durationSeconds"],
      resolution: data["resolution"],
      safety_attributes: data["safetyAttributes"],
      rai_info: data["raiInfo"]
    }
  end

  @doc """
  Wraps an Operation with video-specific metadata.
  """
  @spec wrap_operation(Gemini.Types.Operation.t()) :: VideoOperation.t()
  def wrap_operation(operation) do
    progress = extract_progress(operation)

    %VideoOperation{
      operation: operation,
      progress_percent: progress,
      estimated_completion_time: estimate_completion_time(operation, progress)
    }
  end

  @doc """
  Checks if a video operation is complete.
  """
  @spec complete?(VideoOperation.t()) :: boolean()
  def complete?(%VideoOperation{operation: operation}) do
    Gemini.Types.Operation.complete?(operation)
  end

  @doc """
  Checks if a video operation succeeded.
  """
  @spec succeeded?(VideoOperation.t()) :: boolean()
  def succeeded?(%VideoOperation{operation: operation}) do
    Gemini.Types.Operation.succeeded?(operation)
  end

  @doc """
  Checks if a video operation failed.
  """
  @spec failed?(VideoOperation.t()) :: boolean()
  def failed?(%VideoOperation{operation: operation}) do
    Gemini.Types.Operation.failed?(operation)
  end

  @doc """
  Extracts generated videos from a completed operation.
  """
  @spec extract_videos(Gemini.Types.Operation.t()) ::
          {:ok, [GeneratedVideo.t()]} | {:error, term()}
  def extract_videos(%Gemini.Types.Operation{done: true, response: response})
      when is_map(response) do
    videos =
      (response["generatedVideos"] || response["predictions"] || [])
      |> Enum.map(&parse_generated_video/1)

    {:ok, videos}
  end

  def extract_videos(%Gemini.Types.Operation{done: true, error: error})
      when not is_nil(error) do
    {:error, error}
  end

  def extract_videos(%Gemini.Types.Operation{done: false}) do
    {:error, "Operation not yet complete"}
  end

  # Private helpers

  defp add_if_present(map, _key, nil), do: map
  defp add_if_present(map, key, value), do: Map.put(map, key, value)

  defp extract_progress(%Gemini.Types.Operation{metadata: metadata}) when is_map(metadata) do
    # Try various progress field names
    metadata["progressPercent"] ||
      metadata["progress"] ||
      metadata["completionPercentage"] ||
      0.0
  end

  defp extract_progress(_), do: 0.0

  defp estimate_completion_time(_operation, progress) do
    # Simple estimation based on typical video generation times
    # Veo typically takes 2-5 minutes per video
    if progress > 0 and progress < 100 do
      remaining_percent = 100 - progress
      # Assume ~3 minutes average total time
      estimated_seconds = remaining_percent / 100 * 180

      DateTime.utc_now()
      |> DateTime.add(trunc(estimated_seconds), :second)
    else
      DateTime.utc_now()
    end
  end
end
