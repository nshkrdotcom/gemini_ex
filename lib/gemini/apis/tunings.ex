defmodule Gemini.APIs.Tunings do
  @moduledoc """
  API module for model tuning (fine-tuning) operations.

  The Tunings API allows you to create, manage, and monitor fine-tuning jobs
  for Gemini models. This is a Vertex AI only feature.

  ## Prerequisites

  - Vertex AI authentication configured
  - Project with Vertex AI API enabled
  - Training data in JSONL format uploaded to GCS

  ## Example

      # Create a tuning job
      config = %Gemini.Types.Tuning.CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "my-tuned-model",
        training_dataset_uri: "gs://bucket/training.jsonl"
      }

      {:ok, job} = Gemini.APIs.Tunings.tune(config, auth: :vertex_ai)

      # Wait for completion
      {:ok, completed} = Gemini.APIs.Tunings.wait_for_completion(job.name)

  ## Training Data Format

  Training data should be in JSONL format with the following structure:

      {"contents": [{"role": "user", "parts": [{"text": "..."}]}, {"role": "model", "parts": [{"text": "..."}]}]}

  """

  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Config
  alias Gemini.Types.Tuning
  alias Gemini.Types.Tuning.{CreateTuningJobConfig, ListTuningJobsResponse, TuningJob}

  import Gemini.Utils.PollingHelpers, only: [timed_out?: 2, maybe_add: 3]

  @default_poll_interval 5_000
  @default_timeout 3_600_000

  @doc """
  Creates a new model tuning job.

  ## Parameters

  - `config` - CreateTuningJobConfig struct with tuning configuration
  - `opts` - Keyword list of options:
    - `:auth` - Authentication strategy (`:vertex_ai` required)
    - `:project_id` - GCP project ID (optional, uses config default)
    - `:location` - GCP location (optional, defaults to "us-central1")

  ## Example

      config = %CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "custom-model",
        training_dataset_uri: "gs://bucket/data.jsonl",
        epoch_count: 10
      }

      {:ok, job} = Gemini.APIs.Tunings.tune(config, auth: :vertex_ai)

  """
  @spec tune(CreateTuningJobConfig.t() | map(), keyword()) ::
          {:ok, TuningJob.t()} | {:error, term()}
  def tune(config, opts \\ [])

  def tune(%CreateTuningJobConfig{} = config, opts) do
    with {:ok, {headers, base_url}} <- get_auth(opts),
         {:ok, project_id} <- get_project_id(opts) do
      location = Keyword.get(opts, :location, "us-central1")
      url = "#{base_url}/v1/projects/#{project_id}/locations/#{location}/tuningJobs"
      body = Tuning.to_api_map(config)

      case Req.post(url, json: body, headers: headers, receive_timeout: 30_000) do
        {:ok, %{status: status, body: response_body}} when status in 200..299 ->
          {:ok, Tuning.from_api_response(response_body)}

        {:ok, %{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  def tune(config, opts) when is_map(config) do
    struct_config = struct(CreateTuningJobConfig, config)
    tune(struct_config, opts)
  end

  @doc """
  Gets details of a tuning job.

  ## Parameters

  - `name` - Full resource name of the tuning job
  - `opts` - Keyword list of options:
    - `:auth` - Authentication strategy

  ## Example

      {:ok, job} = Gemini.APIs.Tunings.get(
        "projects/123/locations/us-central1/tuningJobs/456",
        auth: :vertex_ai
      )

  """
  @spec get(String.t(), keyword()) :: {:ok, TuningJob.t()} | {:error, term()}
  def get(name, opts \\ []) do
    with {:ok, {headers, base_url}} <- get_auth(opts) do
      url = "#{base_url}/v1/#{name}"

      case Req.get(url, headers: headers, receive_timeout: 30_000) do
        {:ok, %{status: status, body: response_body}} when status in 200..299 ->
          {:ok, Tuning.from_api_response(response_body)}

        {:ok, %{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  @doc """
  Lists tuning jobs with pagination.

  ## Parameters

  - `opts` - Keyword list of options:
    - `:auth` - Authentication strategy
    - `:project_id` - GCP project ID
    - `:location` - GCP location
    - `:page_size` - Number of results per page
    - `:page_token` - Token for next page
    - `:filter` - Filter expression

  ## Example

      {:ok, response} = Gemini.APIs.Tunings.list(
        auth: :vertex_ai,
        page_size: 10
      )

  """
  @spec list(keyword()) :: {:ok, ListTuningJobsResponse.t()} | {:error, term()}
  def list(opts \\ []) do
    with {:ok, {headers, base_url}} <- get_auth(opts),
         {:ok, project_id} <- get_project_id(opts) do
      location = Keyword.get(opts, :location, "us-central1")
      url = "#{base_url}/v1/projects/#{project_id}/locations/#{location}/tuningJobs"

      params =
        []
        |> maybe_add(:pageSize, opts[:page_size])
        |> maybe_add(:pageToken, opts[:page_token])
        |> maybe_add(:filter, opts[:filter])

      case Req.get(url, headers: headers, params: params, receive_timeout: 30_000) do
        {:ok, %{status: status, body: response_body}} when status in 200..299 ->
          {:ok, ListTuningJobsResponse.from_api_response(response_body)}

        {:ok, %{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  @doc """
  Lists all tuning jobs, automatically handling pagination.

  ## Parameters

  - `opts` - Same as `list/1`

  ## Example

      {:ok, all_jobs} = Gemini.APIs.Tunings.list_all(auth: :vertex_ai)

  """
  @spec list_all(keyword()) :: {:ok, [TuningJob.t()]} | {:error, term()}
  def list_all(opts \\ []) do
    list_all_pages(opts, [])
  end

  defp list_all_pages(opts, acc) do
    case list(opts) do
      {:ok, %ListTuningJobsResponse{tuning_jobs: jobs, next_page_token: nil}} ->
        {:ok, acc ++ jobs}

      {:ok, %ListTuningJobsResponse{tuning_jobs: jobs, next_page_token: ""}} ->
        {:ok, acc ++ jobs}

      {:ok, %ListTuningJobsResponse{tuning_jobs: jobs, next_page_token: token}} ->
        list_all_pages(Keyword.put(opts, :page_token, token), acc ++ jobs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Cancels a running tuning job.

  ## Parameters

  - `name` - Full resource name of the tuning job
  - `opts` - Keyword list of options

  ## Example

      :ok = Gemini.APIs.Tunings.cancel(
        "projects/123/locations/us-central1/tuningJobs/456",
        auth: :vertex_ai
      )

  """
  @spec cancel(String.t(), keyword()) :: {:ok, TuningJob.t()} | {:error, term()}
  def cancel(name, opts \\ []) do
    with {:ok, {headers, base_url}} <- get_auth(opts) do
      url = "#{base_url}/v1/#{name}:cancel"

      case Req.post(url, headers: headers, json: %{}, receive_timeout: 30_000) do
        {:ok, %{status: status, body: response_body}} when status in 200..299 ->
          {:ok, Tuning.from_api_response(response_body)}

        {:ok, %{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  @doc """
  Waits for a tuning job to complete.

  Polls the job status at regular intervals until it reaches a terminal state
  (succeeded, failed, cancelled, or expired).

  ## Parameters

  - `name` - Full resource name of the tuning job
  - `opts` - Keyword list of options:
    - `:poll_interval` - Milliseconds between polls (default: 5000)
    - `:timeout` - Maximum wait time in milliseconds (default: 3600000 = 1 hour)
    - `:on_progress` - Callback function called with job on each poll

  ## Example

      {:ok, completed} = Gemini.APIs.Tunings.wait_for_completion(
        "projects/123/locations/us-central1/tuningJobs/456",
        auth: :vertex_ai,
        poll_interval: 10_000,
        on_progress: fn job -> IO.puts("State: \#{job.state}") end
      )

  """
  @spec wait_for_completion(String.t(), keyword()) :: {:ok, TuningJob.t()} | {:error, term()}
  def wait_for_completion(name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    on_progress = Keyword.get(opts, :on_progress, fn _ -> :ok end)
    start_time = System.monotonic_time(:millisecond)

    do_wait(name, opts, poll_interval, timeout, on_progress, start_time)
  end

  defp do_wait(name, opts, poll_interval, timeout, on_progress, start_time) do
    if timed_out?(start_time, timeout) do
      {:error, :timeout}
    else
      case get(name, opts) do
        {:ok, job} ->
          on_progress.(job)

          handle_job_state(job, name, opts, poll_interval, timeout, on_progress, start_time)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp handle_job_state(job, name, opts, poll_interval, timeout, on_progress, start_time) do
    if Tuning.job_complete?(job) do
      {:ok, job}
    else
      Process.sleep(poll_interval)
      do_wait(name, opts, poll_interval, timeout, on_progress, start_time)
    end
  end

  # Private helpers

  defp get_auth(opts) do
    auth = Keyword.get(opts, :auth, :vertex_ai)

    if auth != :vertex_ai do
      {:error, {:invalid_auth, "Tunings API requires Vertex AI authentication"}}
    else
      location = Keyword.get(opts, :location, "us-central1")

      case MultiAuthCoordinator.coordinate_auth(auth, opts) do
        {:ok, _auth_strategy, headers} ->
          base_url = "https://#{location}-aiplatform.googleapis.com"
          {:ok, {headers, base_url}}

        {:error, reason} ->
          {:error, {:auth_failed, reason}}
      end
    end
  end

  defp get_project_id(opts) do
    project_id =
      Keyword.get(opts, :project_id) ||
        Config.get_auth_config(:vertex_ai)[:project_id] ||
        System.get_env("VERTEX_PROJECT_ID") ||
        System.get_env("GOOGLE_CLOUD_PROJECT")

    case project_id do
      nil -> {:error, :project_id_required}
      id -> {:ok, id}
    end
  end
end
