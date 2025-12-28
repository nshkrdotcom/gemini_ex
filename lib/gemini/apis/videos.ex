defmodule Gemini.APIs.Videos do
  @moduledoc """
  API for video generation using Google's Veo models.

  Veo is Google's advanced text-to-video generation model that creates high-quality
  videos from text descriptions. Video generation is a long-running operation that
  can take several minutes to complete.

  Video generation is available through both Vertex AI and the Gemini API
  (for supported Veo models).

  ## Supported Models

  - `veo-2.0-generate-001` - Veo 2.0 video generation model (recommended)
  - `veo-3.1-generate-preview` - Veo 3.1 preview
  - `veo-3.1-fast-generate-preview` - Veo 3.1 Fast preview
  - `veo-3.0-generate-001` - Veo 3.0 stable
  - `veo-3.0-fast-generate-001` - Veo 3.0 Fast stable

  ## Video Generation Workflow

  Video generation is asynchronous and follows a long-running operation pattern:

  1. **Initiate**: Start video generation with `generate/3`
  2. **Poll**: Check operation status with `get_operation/2`
  3. **Wait**: Use `wait_for_completion/2` for automatic polling
  4. **Download**: Retrieve generated videos from GCS URIs

  ## Examples

      # Start video generation
      {:ok, operation} = Gemini.APIs.Videos.generate(
        "A cat playing piano in a cozy living room",
        %VideoGenerationConfig{
          duration_seconds: 8,
          aspect_ratio: "16:9"
        }
      )

      # Wait for completion (automatic polling)
      {:ok, completed_op} = Gemini.APIs.Videos.wait_for_completion(
        operation.name,
        poll_interval: 10_000,  # Check every 10 seconds
        timeout: 300_000        # Wait up to 5 minutes
      )

      # Extract video URIs
      {:ok, videos} = Gemini.Types.Generation.Video.extract_videos(completed_op)
      video_uri = hd(videos).video_uri

      # Manual polling
      {:ok, op} = Gemini.APIs.Videos.get_operation(operation.name)
      if op.done do
        {:ok, videos} = Gemini.Types.Generation.Video.extract_videos(op)
      end

  ## Performance Considerations

  - Video generation typically takes 2-5 minutes per video
  - Longer videos (8s) take more time than shorter videos (4s)
  - Higher resolution/FPS increases generation time
  - Use webhook callbacks for production systems instead of polling

  ## Configuration Options

  See `Gemini.Types.Generation.Video` for all available configuration options.
  """

  alias Gemini.APIs.Operations
  alias Gemini.Client.HTTP
  alias Gemini.Config
  alias Gemini.Error
  alias Gemini.Types.Generation.Video, as: Video
  alias Gemini.Types.Generation.Video.{VideoGenerationConfig, VideoOperation}
  alias Gemini.Types.Operation

  @type api_result(t) :: {:ok, t} | {:error, term()}
  @type generation_opts :: [
          model: String.t(),
          project_id: String.t(),
          location: String.t()
        ]

  @type wait_opts :: [
          poll_interval: pos_integer(),
          timeout: pos_integer(),
          on_progress: (Operation.t() -> any())
        ]

  @default_model "veo-2.0-generate-001"
  @default_location "us-central1"
  @default_poll_interval 10_000
  @default_timeout 300_000

  # ===========================================================================
  # Video Generation API
  # ===========================================================================

  @doc """
  Generate a video from a text prompt.

  This starts a long-running operation. Use `get_operation/2` or `wait_for_completion/2`
  to check the status and retrieve the generated video.

  ## Parameters

  - `prompt` - Text description of the video to generate
  - `config` - VideoGenerationConfig struct (default: %VideoGenerationConfig{})
  - `opts` - Additional options:
    - `:model` - Model to use (default: "veo-2.0-generate-001")
    - `:project_id` - Vertex AI project ID (default: from config)
    - `:location` - Vertex AI location (default: "us-central1")

  ## Returns

  - `{:ok, Operation.t()}` - Long-running operation
  - `{:error, term()}` - Error if generation fails to start

  ## Examples

      # Simple generation
      {:ok, operation} = Gemini.APIs.Videos.generate(
        "A cat playing piano"
      )

      # With configuration
      config = %VideoGenerationConfig{
        number_of_videos: 2,
        duration_seconds: 8,
        aspect_ratio: "16:9",
        fps: 30
      }
      {:ok, operation} = Gemini.APIs.Videos.generate(
        "Cinematic shot of a futuristic city",
        config
      )

      # Custom location
      {:ok, operation} = Gemini.APIs.Videos.generate(
        "Aerial view of mountains",
        config,
        location: "europe-west4"
      )
  """
  @spec generate(String.t(), VideoGenerationConfig.t(), generation_opts()) ::
          api_result(Operation.t())
  def generate(prompt, config \\ %VideoGenerationConfig{}, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    auth_config = Config.auth_config()
    auth_type = auth_type_from_config(auth_config)
    project_id = get_project_id(opts, auth_config)
    location = get_location(opts, auth_config)

    with :ok <- validate_video_auth(auth_type, project_id, location),
         {:ok, path} <- build_predict_path(auth_type, project_id, location, model),
         {:ok, request_body} <- build_generation_request(prompt, config) do
      case HTTP.post(path, request_body, opts) do
        {:ok, response} -> parse_operation_response(response)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Get the current status of a video generation operation.

  ## Parameters

  - `operation_name` - Operation name from `generate/3` response
  - `opts` - Additional options

  ## Returns

  - `{:ok, Operation.t()}` - Current operation status
  - `{:error, term()}` - Error if operation cannot be retrieved

  ## Examples

      {:ok, operation} = Gemini.APIs.Videos.generate("A cat playing piano")

      # Later, check status
      {:ok, current_op} = Gemini.APIs.Videos.get_operation(operation.name)

      cond do
        current_op.done and is_nil(current_op.error) ->
          {:ok, videos} = Video.extract_videos(current_op)
          IO.puts("Video ready: \#{hd(videos).video_uri}")

        current_op.done ->
          IO.puts("Failed: \#{current_op.error.message}")

        true ->
          IO.puts("Still generating...")
      end
  """
  @spec get_operation(String.t(), keyword()) :: api_result(Operation.t())
  def get_operation(operation_name, opts \\ []) do
    Operations.get(operation_name, opts)
  end

  @doc """
  Wait for a video generation operation to complete with automatic polling.

  This function polls the operation status at regular intervals until it completes
  or times out. Useful for synchronous workflows.

  ## Parameters

  - `operation_name` - Operation name from `generate/3` response
  - `opts` - Wait options:
    - `:poll_interval` - Milliseconds between polls (default: 10,000)
    - `:timeout` - Maximum time to wait in milliseconds (default: 300,000)
    - `:on_progress` - Callback function called on each poll with Operation.t()

  ## Returns

  - `{:ok, Operation.t()}` - Completed operation
  - `{:error, :timeout}` - Operation did not complete within timeout
  - `{:error, term()}` - Other errors

  ## Examples

      {:ok, operation} = Gemini.APIs.Videos.generate("A cat playing piano")

      # Wait with defaults (5 minutes)
      {:ok, completed} = Gemini.APIs.Videos.wait_for_completion(operation.name)

      # Custom polling and timeout
      {:ok, completed} = Gemini.APIs.Videos.wait_for_completion(
        operation.name,
        poll_interval: 5_000,   # Poll every 5 seconds
        timeout: 600_000,       # Wait up to 10 minutes
        on_progress: fn op ->
          if progress = Gemini.Types.Operation.get_progress(op) do
            IO.puts("Progress: \#{progress}%")
          end
        end
      )

      # Extract videos
      {:ok, videos} = Video.extract_videos(completed)
  """
  @spec wait_for_completion(String.t(), wait_opts()) :: api_result(Operation.t())
  def wait_for_completion(operation_name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    on_progress = Keyword.get(opts, :on_progress)

    Operations.wait(operation_name,
      poll_interval: poll_interval,
      timeout: timeout,
      on_progress: on_progress
    )
  end

  @doc """
  Cancel a running video generation operation.

  ## Parameters

  - `operation_name` - Operation name to cancel
  - `opts` - Additional options

  ## Returns

  - `:ok` - Operation cancelled successfully
  - `{:error, term()}` - Error if cancellation fails

  ## Examples

      {:ok, operation} = Gemini.APIs.Videos.generate("A cat playing piano")

      # Cancel if taking too long
      :ok = Gemini.APIs.Videos.cancel(operation.name)
  """
  @spec cancel(String.t(), keyword()) :: :ok | {:error, term()}
  def cancel(operation_name, opts \\ []) do
    Operations.cancel(operation_name, opts)
  end

  @doc """
  List video generation operations.

  ## Parameters

  - `opts` - List options:
    - `:page_size` - Number of operations per page
    - `:page_token` - Token for pagination
    - `:filter` - Filter string (e.g., "done=true")

  ## Returns

  - `{:ok, ListOperationsResponse.t()}` - List of operations
  - `{:error, term()}` - Error if listing fails

  ## Examples

      # List all video operations
      {:ok, response} = Gemini.APIs.Videos.list_operations()

      # List only completed operations
      {:ok, response} = Gemini.APIs.Videos.list_operations(filter: "done=true")
  """
  @spec list_operations(keyword()) :: api_result(Gemini.Types.ListOperationsResponse.t())
  def list_operations(opts \\ []) do
    Operations.list(opts)
  end

  @doc """
  Wrap an operation with video-specific metadata.

  Adds video generation progress tracking and estimation.

  ## Examples

      {:ok, op} = Gemini.APIs.Videos.get_operation(operation_name)
      video_op = Gemini.APIs.Videos.wrap_operation(op)

      IO.puts("Progress: \#{video_op.progress_percent}%")
      IO.puts("ETA: \#{video_op.estimated_completion_time}")
  """
  @spec wrap_operation(Operation.t()) :: VideoOperation.t()
  def wrap_operation(operation) do
    Video.wrap_operation(operation)
  end

  # ===========================================================================
  # Request Building
  # ===========================================================================

  @spec build_predict_path(:gemini | :vertex_ai, String.t() | nil, String.t() | nil, String.t()) ::
          {:ok, String.t()} | {:error, term()}
  defp build_predict_path(:vertex_ai, project_id, location, model)
       when is_binary(project_id) and is_binary(location) do
    # Video generation uses the predict endpoint which returns an operation
    path =
      "projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:predict"

    {:ok, path}
  end

  defp build_predict_path(:gemini, _project_id, _location, model) when is_binary(model) do
    {:ok, "models/#{model}:predictLongRunning"}
  end

  defp build_predict_path(_auth, _project_id, _location, _model) do
    {:error, Error.validation_error("Invalid video generation path parameters")}
  end

  @spec build_generation_request(String.t(), VideoGenerationConfig.t()) ::
          {:ok, map()} | {:error, term()}
  defp build_generation_request(prompt, config) do
    params = Video.build_generation_params(prompt, config)

    instance =
      %{"prompt" => prompt}
      |> maybe_put("image", Video.image_to_api(config.image))
      |> maybe_put("video", Video.video_to_api(config.video))
      |> maybe_put("lastFrame", Video.image_to_api(config.last_frame))
      |> maybe_put_list(
        "referenceImages",
        config.reference_images,
        &Video.reference_image_to_api/1
      )

    request = %{
      "instances" => [instance],
      "parameters" => params
    }

    {:ok, request}
  end

  # ===========================================================================
  # Response Parsing
  # ===========================================================================

  @spec parse_operation_response(map()) :: {:ok, Operation.t()} | {:error, term()}
  defp parse_operation_response(%{"name" => _name} = response) do
    # Response is an operation
    {:ok, Operation.from_api_response(response)}
  end

  defp parse_operation_response(%{"error" => error}) do
    {:error, Error.api_error(:api_error, error["message"] || "Video generation failed")}
  end

  defp parse_operation_response(response) do
    # Some predict endpoints may return the operation wrapped differently
    case response do
      %{"metadata" => %{"@type" => type}} when is_binary(type) ->
        {:ok, Operation.from_api_response(response)}

      _ ->
        {:error, Error.api_error(:api_error, "Unexpected response format: #{inspect(response)}")}
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  @spec validate_video_auth(:gemini | :vertex_ai | nil, String.t() | nil, String.t() | nil) ::
          :ok | {:error, term()}
  defp validate_video_auth(:gemini, _project_id, _location), do: :ok

  defp validate_video_auth(:vertex_ai, project_id, location) do
    cond do
      not is_binary(project_id) or project_id == "" ->
        {:error,
         Error.config_error(
           "Video generation requires Vertex AI project_id. " <>
             "Please configure VERTEX_PROJECT_ID."
         )}

      not is_binary(location) or location == "" ->
        {:error,
         Error.config_error(
           "Video generation requires Vertex AI location. " <>
             "Please configure VERTEX_LOCATION."
         )}

      true ->
        :ok
    end
  end

  defp validate_video_auth(nil, _project_id, _location) do
    {:error, Error.config_error("No authentication configured for video generation.")}
  end

  defp validate_video_auth(_other, _project_id, _location) do
    {:error, Error.config_error("Unsupported authentication for video generation.")}
  end

  @spec get_project_id(keyword(), map() | nil) :: String.t() | nil
  defp get_project_id(opts, auth_config) do
    case Keyword.get(opts, :project_id) do
      nil ->
        case auth_config do
          %{credentials: %{project_id: project_id}} -> project_id
          _ -> nil
        end

      project_id ->
        project_id
    end
  end

  @spec get_location(keyword(), map() | nil) :: String.t() | nil
  defp get_location(opts, auth_config) do
    case Keyword.get(opts, :location) do
      nil ->
        case auth_config do
          %{credentials: %{location: location}} when is_binary(location) -> location
          _ -> @default_location
        end

      location ->
        location
    end
  end

  defp auth_type_from_config(%{type: type}), do: type
  defp auth_type_from_config(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_list(map, _key, nil, _fun), do: map
  defp maybe_put_list(map, _key, [], _fun), do: map

  defp maybe_put_list(map, key, list, fun) when is_list(list) do
    Map.put(map, key, Enum.map(list, fun))
  end

  @doc false
  def __test_build_generation_request__(prompt, config),
    do: build_generation_request(prompt, config)

  @doc false
  def __test_build_predict_path__(auth_type, credentials, model)
      when is_map(credentials) and is_binary(model) do
    build_predict_path(
      auth_type,
      Map.get(credentials, :project_id),
      Map.get(credentials, :location),
      model
    )
  end
end
