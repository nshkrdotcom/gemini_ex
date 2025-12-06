defmodule Gemini.Types.BatchJob do
  @moduledoc """
  Type definitions for batch processing jobs.

  Batch processing allows submitting large numbers of requests at once
  with 50% cost savings compared to interactive API calls.

  ## Batch Job States

  - `:job_state_unspecified` - Initial/unknown state
  - `:queued` - Job is queued for processing
  - `:pending` - Job is preparing to run
  - `:running` - Job is actively processing
  - `:succeeded` - Job completed successfully
  - `:failed` - Job failed
  - `:cancelling` - Job is being cancelled
  - `:cancelled` - Job was cancelled
  - `:paused` - Job is paused (Vertex AI)
  - `:expired` - Job expired
  - `:partially_succeeded` - Some requests succeeded, some failed

  ## Example

      # Create a batch job
      {:ok, batch} = Gemini.APIs.Batches.create(
        "gemini-2.0-flash",
        file_name: "files/input-12345"
      )

      # Poll for completion
      {:ok, completed} = Gemini.APIs.Batches.wait(batch.name)

      # Get results
      if BatchJob.succeeded?(completed) do
        IO.puts("Processed \#{completed.completion_stats.total_count} requests")
      end
  """

  use TypedStruct

  @typedoc """
  Batch job state enumeration.
  """
  @type job_state ::
          :job_state_unspecified
          | :queued
          | :pending
          | :running
          | :succeeded
          | :failed
          | :cancelling
          | :cancelled
          | :paused
          | :expired
          | :partially_succeeded

  @typedoc """
  Batch job source configuration.
  """
  @type batch_source :: %{
          optional(:file_name) => String.t(),
          optional(:gcs_uri) => [String.t()],
          optional(:bigquery_uri) => String.t(),
          optional(:format) => String.t(),
          optional(:inlined_requests) => [map()]
        }

  @typedoc """
  Batch job destination configuration.
  """
  @type batch_destination :: %{
          optional(:file_name) => String.t(),
          optional(:gcs_uri) => String.t(),
          optional(:bigquery_uri) => String.t(),
          optional(:format) => String.t(),
          optional(:inlined_responses) => [map()]
        }

  @typedoc """
  Completion statistics for a batch job.
  """
  @type completion_stats :: %{
          optional(:total_count) => integer(),
          optional(:success_count) => integer(),
          optional(:failure_count) => integer()
        }

  @typedoc """
  Batch job error details.
  """
  @type job_error :: %{
          optional(:code) => integer(),
          optional(:message) => String.t(),
          optional(:details) => [String.t()]
        }

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Represents a batch processing job.

    ## Fields

    - `name` - Resource name (e.g., "batches/abc123" for Gemini, "batchPredictionJobs/123" for Vertex)
    - `display_name` - Human-readable name
    - `state` - Current job state
    - `model` - Model used for processing
    - `src` - Input source configuration
    - `dest` - Output destination configuration
    - `create_time` - When the job was created
    - `start_time` - When the job started running
    - `end_time` - When the job completed
    - `update_time` - Last update timestamp
    - `error` - Error details if failed
    - `completion_stats` - Processing statistics
    """

    field(:name, String.t())
    field(:display_name, String.t())
    field(:state, job_state())
    field(:model, String.t())
    field(:src, batch_source())
    field(:dest, batch_destination())
    field(:create_time, String.t())
    field(:start_time, String.t())
    field(:end_time, String.t())
    field(:update_time, String.t())
    field(:error, job_error())
    field(:completion_stats, completion_stats())
  end

  # Terminal states that indicate the job is done
  @terminal_states ~w(succeeded failed cancelled expired partially_succeeded)a

  @doc """
  Creates a BatchJob from API response.

  Handles both Gemini API and Vertex AI response formats.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    %__MODULE__{
      name: response["name"],
      display_name: response["displayName"],
      state: parse_state(response["state"]),
      model: response["model"],
      src: parse_source(response["src"] || response["inputConfig"]),
      dest: parse_destination(response["dest"] || response["outputConfig"]),
      create_time: response["createTime"],
      start_time: response["startTime"],
      end_time: response["endTime"],
      update_time: response["updateTime"],
      error: parse_error(response["error"]),
      completion_stats: parse_stats(response["completionStats"] || response["completionStatus"])
    }
  end

  @doc """
  Converts job state atom to API string format.
  """
  @spec state_to_api(job_state()) :: String.t()
  def state_to_api(:job_state_unspecified), do: "JOB_STATE_UNSPECIFIED"
  def state_to_api(:queued), do: "JOB_STATE_QUEUED"
  def state_to_api(:pending), do: "JOB_STATE_PENDING"
  def state_to_api(:running), do: "JOB_STATE_RUNNING"
  def state_to_api(:succeeded), do: "JOB_STATE_SUCCEEDED"
  def state_to_api(:failed), do: "JOB_STATE_FAILED"
  def state_to_api(:cancelling), do: "JOB_STATE_CANCELLING"
  def state_to_api(:cancelled), do: "JOB_STATE_CANCELLED"
  def state_to_api(:paused), do: "JOB_STATE_PAUSED"
  def state_to_api(:expired), do: "JOB_STATE_EXPIRED"
  def state_to_api(:partially_succeeded), do: "JOB_STATE_PARTIALLY_SUCCEEDED"

  @doc """
  Parses API state string to atom.
  """
  @spec parse_state(String.t() | nil) :: job_state() | nil
  def parse_state("JOB_STATE_UNSPECIFIED"), do: :job_state_unspecified
  def parse_state("JOB_STATE_QUEUED"), do: :queued
  def parse_state("JOB_STATE_PENDING"), do: :pending
  def parse_state("JOB_STATE_RUNNING"), do: :running
  def parse_state("JOB_STATE_SUCCEEDED"), do: :succeeded
  def parse_state("JOB_STATE_FAILED"), do: :failed
  def parse_state("JOB_STATE_CANCELLING"), do: :cancelling
  def parse_state("JOB_STATE_CANCELLED"), do: :cancelled
  def parse_state("JOB_STATE_PAUSED"), do: :paused
  def parse_state("JOB_STATE_EXPIRED"), do: :expired
  def parse_state("JOB_STATE_PARTIALLY_SUCCEEDED"), do: :partially_succeeded
  # Gemini API uses simpler states
  def parse_state("ACTIVE"), do: :running
  def parse_state("COMPLETED"), do: :succeeded
  def parse_state("FAILED"), do: :failed
  def parse_state(nil), do: nil
  def parse_state(_), do: :job_state_unspecified

  @doc """
  Checks if the batch job is complete (terminal state).
  """
  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{state: state}) when state in @terminal_states, do: true
  def complete?(_), do: false

  @doc """
  Checks if the batch job succeeded.
  """
  @spec succeeded?(t()) :: boolean()
  def succeeded?(%__MODULE__{state: :succeeded}), do: true
  def succeeded?(_), do: false

  @doc """
  Checks if the batch job failed.
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{state: :failed}), do: true
  def failed?(_), do: false

  @doc """
  Checks if the batch job is still running.
  """
  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{state: state}) when state in [:queued, :pending, :running], do: true
  def running?(_), do: false

  @doc """
  Checks if the batch job was cancelled.
  """
  @spec cancelled?(t()) :: boolean()
  def cancelled?(%__MODULE__{state: :cancelled}), do: true
  def cancelled?(_), do: false

  @doc """
  Gets the completion percentage if available.
  """
  @spec get_progress(t()) :: float() | nil
  def get_progress(%__MODULE__{completion_stats: nil}), do: nil

  def get_progress(%__MODULE__{completion_stats: stats}) do
    total = stats[:total_count] || 0
    success = stats[:success_count] || 0
    failure = stats[:failure_count] || 0

    if total > 0 do
      (success + failure) / total * 100
    else
      nil
    end
  end

  @doc """
  Extracts the batch ID from the full name.
  """
  @spec get_id(t()) :: String.t() | nil
  def get_id(%__MODULE__{name: nil}), do: nil

  def get_id(%__MODULE__{name: name}) do
    case String.split(name, "/") do
      ["batches", id] -> id
      ["batchPredictionJobs", id] -> id
      _ -> name
    end
  end

  # Private helpers

  defp parse_source(nil), do: nil

  defp parse_source(source) when is_map(source) do
    %{
      file_name: source["fileName"],
      gcs_uri: source["gcsUri"],
      bigquery_uri: source["bigqueryUri"],
      format: source["format"] || source["instancesFormat"],
      inlined_requests: source["inlinedRequests"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_destination(nil), do: nil

  defp parse_destination(dest) when is_map(dest) do
    %{
      file_name: dest["fileName"],
      gcs_uri: dest["gcsUri"],
      bigquery_uri: dest["bigqueryUri"],
      format: dest["format"] || dest["predictionsFormat"],
      inlined_responses: dest["inlinedResponses"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_error(nil), do: nil

  defp parse_error(error) when is_map(error) do
    %{
      code: error["code"],
      message: error["message"],
      details: error["details"]
    }
  end

  defp parse_stats(nil), do: nil

  defp parse_stats(stats) when is_map(stats) do
    %{
      total_count: stats["totalCount"] || stats["completedCount"],
      success_count: stats["successCount"] || stats["successfulCount"],
      failure_count: stats["failureCount"] || stats["failedCount"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end

defmodule Gemini.Types.ListBatchJobsResponse do
  @moduledoc """
  Response type for listing batch jobs.
  """

  use TypedStruct

  alias Gemini.Types.BatchJob

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response from listing batch jobs.
    """
    field(:batch_jobs, [BatchJob.t()], default: [])
    field(:next_page_token, String.t())
  end

  @doc """
  Creates a ListBatchJobsResponse from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    # Handle both Gemini and Vertex AI response formats
    jobs =
      (response["batchJobs"] || response["batchPredictionJobs"] || response["batches"] || [])
      |> Enum.map(&BatchJob.from_api_response/1)

    %__MODULE__{
      batch_jobs: jobs,
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

defmodule Gemini.Types.CreateBatchJobConfig do
  @moduledoc """
  Configuration for creating a batch job.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Configuration for batch job creation.

    - `display_name` - Human-readable name for the batch
    - `model` - Model to use for processing
    - `generation_config` - Generation configuration for content batches
    - `system_instruction` - System instruction for content batches
    """
    field(:display_name, String.t())
    field(:model, String.t())
    field(:generation_config, map())
    field(:system_instruction, map())
  end
end
