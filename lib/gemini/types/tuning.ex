defmodule Gemini.Types.Tuning do
  @moduledoc """
  Types for the Tunings API (fine-tuning/model tuning).

  This module provides structs for tuning job configuration, status,
  and response parsing for Google's model tuning API.
  """

  # Sub-types defined as nested modules for cleaner organization

  defmodule HyperParameters do
    @moduledoc """
    Hyperparameters for supervised tuning.
    """
    use TypedStruct

    typedstruct do
      field(:epoch_count, integer())
      field(:learning_rate_multiplier, float())
      field(:adapter_size, String.t())
    end

    @doc """
    Parses hyperparameters from API response.
    """
    @spec from_api_response(map() | nil) :: t() | nil
    def from_api_response(nil), do: nil

    def from_api_response(params) when is_map(params) do
      %__MODULE__{
        epoch_count: parse_integer(params["epochCount"]),
        learning_rate_multiplier: parse_float(params["learningRateMultiplier"]),
        adapter_size: params["adapterSize"]
      }
    end

    defp parse_integer(nil), do: nil
    defp parse_integer(val) when is_integer(val), do: val
    defp parse_integer(val) when is_binary(val), do: String.to_integer(val)

    defp parse_float(nil), do: nil
    defp parse_float(val) when is_float(val), do: val
    defp parse_float(val) when is_integer(val), do: val / 1
    defp parse_float(val) when is_binary(val), do: String.to_float(val)
  end

  defmodule SupervisedTuningSpec do
    @moduledoc """
    Specification for supervised tuning configuration.
    """
    use TypedStruct

    alias Gemini.Types.Tuning.HyperParameters

    typedstruct do
      field(:training_dataset_uri, String.t())
      field(:validation_dataset_uri, String.t())
      field(:hyper_parameters, HyperParameters.t())
    end

    @doc """
    Parses supervised tuning spec from API response.
    """
    @spec from_api_response(map() | nil) :: t() | nil
    def from_api_response(nil), do: nil

    def from_api_response(spec) when is_map(spec) do
      %__MODULE__{
        training_dataset_uri: spec["trainingDatasetUri"],
        validation_dataset_uri: spec["validationDatasetUri"],
        hyper_parameters: HyperParameters.from_api_response(spec["hyperParameters"])
      }
    end
  end

  defmodule TuningJobError do
    @moduledoc """
    Error information for failed tuning jobs.
    """
    use TypedStruct

    typedstruct do
      field(:message, String.t())
      field(:code, integer())
      field(:details, list())
    end

    @doc """
    Parses error from API response.
    """
    @spec from_api_response(map() | nil) :: t() | nil
    def from_api_response(nil), do: nil

    def from_api_response(error) when is_map(error) do
      %__MODULE__{
        message: error["message"],
        code: error["code"],
        details: error["details"] || []
      }
    end
  end

  defmodule TuningJob do
    @moduledoc """
    Represents a tuning job with full status and configuration.
    """
    use TypedStruct

    alias Gemini.Types.Tuning.{SupervisedTuningSpec, TuningJobError}

    typedstruct do
      field(:name, String.t())
      field(:tuned_model_display_name, String.t())
      field(:base_model, String.t())
      field(:state, atom())
      field(:create_time, String.t())
      field(:update_time, String.t())
      field(:start_time, String.t())
      field(:end_time, String.t())
      field(:tuned_model, String.t())
      field(:supervised_tuning_spec, SupervisedTuningSpec.t())
      field(:error, TuningJobError.t())
    end
  end

  defmodule CreateTuningJobConfig do
    @moduledoc """
    Configuration for creating a new tuning job.
    """
    use TypedStruct

    typedstruct enforce: true do
      field(:base_model, String.t())
      field(:tuned_model_display_name, String.t())
      field(:training_dataset_uri, String.t())
      field(:validation_dataset_uri, String.t(), enforce: false)
      field(:epoch_count, integer(), enforce: false)
      field(:learning_rate_multiplier, float(), enforce: false)
      field(:adapter_size, String.t(), enforce: false)
      field(:labels, map(), enforce: false)
    end
  end

  defmodule ListTuningJobsResponse do
    @moduledoc """
    Response from listing tuning jobs with pagination support.
    """
    use TypedStruct

    alias Gemini.Types.Tuning
    alias Gemini.Types.Tuning.TuningJob

    typedstruct do
      field(:tuning_jobs, list(TuningJob.t()), default: [])
      field(:next_page_token, String.t())
    end

    @doc """
    Parses list response from API.
    """
    @spec from_api_response(map()) :: t()
    def from_api_response(response) when is_map(response) do
      jobs =
        (response["tuningJobs"] || [])
        |> Enum.map(&Tuning.from_api_response/1)

      %__MODULE__{
        tuning_jobs: jobs,
        next_page_token: response["nextPageToken"]
      }
    end

    @doc """
    Checks if there are more pages to fetch.
    """
    @spec has_more_pages?(t()) :: boolean()
    def has_more_pages?(%__MODULE__{next_page_token: nil}), do: false
    def has_more_pages?(%__MODULE__{next_page_token: ""}), do: false
    def has_more_pages?(%__MODULE__{next_page_token: _}), do: true
  end

  # Type aliases for convenience
  @type job_state ::
          :job_state_unspecified
          | :job_state_queued
          | :job_state_pending
          | :job_state_running
          | :job_state_succeeded
          | :job_state_failed
          | :job_state_cancelling
          | :job_state_cancelled
          | :job_state_paused
          | :job_state_expired

  @doc """
  Parses a tuning job from API response.
  """
  @spec from_api_response(map()) :: TuningJob.t()
  def from_api_response(response) when is_map(response) do
    %TuningJob{
      name: response["name"],
      tuned_model_display_name: response["tunedModelDisplayName"],
      base_model: response["baseModel"],
      state: parse_state(response["state"]),
      create_time: response["createTime"],
      update_time: response["updateTime"],
      start_time: response["startTime"],
      end_time: response["endTime"],
      tuned_model: response["tunedModel"],
      supervised_tuning_spec:
        SupervisedTuningSpec.from_api_response(response["supervisedTuningSpec"]),
      error: TuningJobError.from_api_response(response["error"])
    }
  end

  @doc """
  Converts CreateTuningJobConfig to API request map.
  """
  @spec to_api_map(CreateTuningJobConfig.t()) :: map()
  def to_api_map(%CreateTuningJobConfig{} = config) do
    base = %{
      "baseModel" => config.base_model,
      "tunedModelDisplayName" => config.tuned_model_display_name
    }

    base =
      if config.labels do
        Map.put(base, "labels", config.labels)
      else
        base
      end

    spec = %{
      "trainingDatasetUri" => config.training_dataset_uri
    }

    spec =
      if config.validation_dataset_uri do
        Map.put(spec, "validationDatasetUri", config.validation_dataset_uri)
      else
        spec
      end

    # Build hyperparameters only if any are set
    hyper_params =
      %{}
      |> maybe_put("epochCount", config.epoch_count)
      |> maybe_put("learningRateMultiplier", config.learning_rate_multiplier)
      |> maybe_put("adapterSize", config.adapter_size)

    spec =
      if map_size(hyper_params) > 0 do
        Map.put(spec, "hyperParameters", hyper_params)
      else
        spec
      end

    Map.put(base, "supervisedTuningSpec", spec)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @doc """
  Parses job state string to atom.
  """
  @spec parse_state(String.t() | nil) :: job_state() | nil
  def parse_state(nil), do: nil
  def parse_state("JOB_STATE_UNSPECIFIED"), do: :job_state_unspecified
  def parse_state("JOB_STATE_QUEUED"), do: :job_state_queued
  def parse_state("JOB_STATE_PENDING"), do: :job_state_pending
  def parse_state("JOB_STATE_RUNNING"), do: :job_state_running
  def parse_state("JOB_STATE_SUCCEEDED"), do: :job_state_succeeded
  def parse_state("JOB_STATE_FAILED"), do: :job_state_failed
  def parse_state("JOB_STATE_CANCELLING"), do: :job_state_cancelling
  def parse_state("JOB_STATE_CANCELLED"), do: :job_state_cancelled
  def parse_state("JOB_STATE_PAUSED"), do: :job_state_paused
  def parse_state("JOB_STATE_EXPIRED"), do: :job_state_expired
  def parse_state(_), do: :job_state_unspecified

  @doc """
  Converts job state atom to API string.
  """
  @spec state_to_api(job_state()) :: String.t()
  def state_to_api(:job_state_unspecified), do: "JOB_STATE_UNSPECIFIED"
  def state_to_api(:job_state_queued), do: "JOB_STATE_QUEUED"
  def state_to_api(:job_state_pending), do: "JOB_STATE_PENDING"
  def state_to_api(:job_state_running), do: "JOB_STATE_RUNNING"
  def state_to_api(:job_state_succeeded), do: "JOB_STATE_SUCCEEDED"
  def state_to_api(:job_state_failed), do: "JOB_STATE_FAILED"
  def state_to_api(:job_state_cancelling), do: "JOB_STATE_CANCELLING"
  def state_to_api(:job_state_cancelled), do: "JOB_STATE_CANCELLED"
  def state_to_api(:job_state_paused), do: "JOB_STATE_PAUSED"
  def state_to_api(:job_state_expired), do: "JOB_STATE_EXPIRED"

  @doc """
  Checks if a tuning job has completed (terminal state).
  """
  @spec job_complete?(TuningJob.t()) :: boolean()
  def job_complete?(%TuningJob{state: :job_state_succeeded}), do: true
  def job_complete?(%TuningJob{state: :job_state_failed}), do: true
  def job_complete?(%TuningJob{state: :job_state_cancelled}), do: true
  def job_complete?(%TuningJob{state: :job_state_expired}), do: true
  def job_complete?(%TuningJob{}), do: false

  @doc """
  Checks if a tuning job is still running (non-terminal state).
  """
  @spec job_running?(TuningJob.t()) :: boolean()
  def job_running?(%TuningJob{state: :job_state_queued}), do: true
  def job_running?(%TuningJob{state: :job_state_pending}), do: true
  def job_running?(%TuningJob{state: :job_state_running}), do: true
  def job_running?(%TuningJob{}), do: false

  @doc """
  Checks if a tuning job succeeded.
  """
  @spec job_succeeded?(TuningJob.t()) :: boolean()
  def job_succeeded?(%TuningJob{state: :job_state_succeeded}), do: true
  def job_succeeded?(%TuningJob{}), do: false

  @doc """
  Checks if a tuning job failed.
  """
  @spec job_failed?(TuningJob.t()) :: boolean()
  def job_failed?(%TuningJob{state: :job_state_failed}), do: true
  def job_failed?(%TuningJob{}), do: false
end
