defmodule Gemini.APIs.TuningsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Tuning.{TuningJob, CreateTuningJobConfig, ListTuningJobsResponse}
  alias Gemini.Types.Tuning

  describe "TuningJob type parsing" do
    test "from_api_response/1 parses all fields correctly" do
      response = %{
        "name" => "projects/123/locations/us-central1/tuningJobs/456",
        "tunedModelDisplayName" => "my-tuned-model",
        "baseModel" => "gemini-2.5-flash-001",
        "state" => "JOB_STATE_RUNNING",
        "createTime" => "2025-12-05T10:00:00Z",
        "updateTime" => "2025-12-05T10:05:00Z",
        "supervisedTuningSpec" => %{
          "trainingDatasetUri" => "gs://bucket/training.jsonl",
          "validationDatasetUri" => "gs://bucket/validation.jsonl",
          "hyperParameters" => %{
            "epochCount" => "10",
            "learningRateMultiplier" => "1.0",
            "adapterSize" => "ADAPTER_SIZE_ONE"
          }
        }
      }

      job = Tuning.from_api_response(response)

      assert job.name == "projects/123/locations/us-central1/tuningJobs/456"
      assert job.tuned_model_display_name == "my-tuned-model"
      assert job.base_model == "gemini-2.5-flash-001"
      assert job.state == :job_state_running
      assert job.create_time == "2025-12-05T10:00:00Z"
      assert job.supervised_tuning_spec.training_dataset_uri == "gs://bucket/training.jsonl"
      assert job.supervised_tuning_spec.validation_dataset_uri == "gs://bucket/validation.jsonl"
      assert job.supervised_tuning_spec.hyper_parameters.epoch_count == 10
      assert job.supervised_tuning_spec.hyper_parameters.learning_rate_multiplier == 1.0
      assert job.supervised_tuning_spec.hyper_parameters.adapter_size == "ADAPTER_SIZE_ONE"
    end

    test "from_api_response/1 handles succeeded state with tuned model" do
      response = %{
        "name" => "projects/123/locations/us-central1/tuningJobs/456",
        "state" => "JOB_STATE_SUCCEEDED",
        "tunedModel" => "projects/123/locations/us-central1/models/tuned-model-123",
        "startTime" => "2025-12-05T10:00:00Z",
        "endTime" => "2025-12-05T12:00:00Z"
      }

      job = Tuning.from_api_response(response)
      assert job.state == :job_state_succeeded
      assert job.tuned_model == "projects/123/locations/us-central1/models/tuned-model-123"
      assert job.start_time == "2025-12-05T10:00:00Z"
      assert job.end_time == "2025-12-05T12:00:00Z"
    end

    test "from_api_response/1 handles failed state with error" do
      response = %{
        "name" => "projects/123/locations/us-central1/tuningJobs/456",
        "state" => "JOB_STATE_FAILED",
        "error" => %{
          "message" => "Invalid training data format",
          "code" => 400,
          "details" => [%{"type" => "InvalidDataFormat"}]
        }
      }

      job = Tuning.from_api_response(response)
      assert job.state == :job_state_failed
      assert job.error.message == "Invalid training data format"
      assert job.error.code == 400
      assert is_list(job.error.details)
    end

    test "from_api_response/1 handles minimal response" do
      response = %{
        "name" => "projects/123/locations/us-central1/tuningJobs/456",
        "state" => "JOB_STATE_QUEUED"
      }

      job = Tuning.from_api_response(response)
      assert job.name == "projects/123/locations/us-central1/tuningJobs/456"
      assert job.state == :job_state_queued
      assert is_nil(job.tuned_model)
      assert is_nil(job.error)
    end
  end

  describe "CreateTuningJobConfig.to_api_map/1" do
    test "converts config with required fields only" do
      config = %CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "my-model",
        training_dataset_uri: "gs://bucket/training.jsonl"
      }

      request = Tuning.to_api_map(config)

      assert request["baseModel"] == "gemini-2.5-flash-001"
      assert request["tunedModelDisplayName"] == "my-model"
      assert request["supervisedTuningSpec"]["trainingDatasetUri"] == "gs://bucket/training.jsonl"
      refute Map.has_key?(request["supervisedTuningSpec"], "validationDatasetUri")
      refute Map.has_key?(request["supervisedTuningSpec"], "hyperParameters")
    end

    test "converts config with all fields" do
      config = %CreateTuningJobConfig{
        base_model: "gemini-2.5-pro-001",
        tuned_model_display_name: "advanced-model",
        training_dataset_uri: "gs://bucket/training.jsonl",
        validation_dataset_uri: "gs://bucket/validation.jsonl",
        epoch_count: 15,
        learning_rate_multiplier: 0.8,
        adapter_size: "ADAPTER_SIZE_FOUR",
        labels: %{"env" => "prod", "team" => "ml"}
      }

      request = Tuning.to_api_map(config)

      assert request["baseModel"] == "gemini-2.5-pro-001"
      assert request["tunedModelDisplayName"] == "advanced-model"

      spec = request["supervisedTuningSpec"]
      assert spec["trainingDatasetUri"] == "gs://bucket/training.jsonl"
      assert spec["validationDatasetUri"] == "gs://bucket/validation.jsonl"

      params = spec["hyperParameters"]
      assert params["epochCount"] == 15
      assert params["learningRateMultiplier"] == 0.8
      assert params["adapterSize"] == "ADAPTER_SIZE_FOUR"

      assert request["labels"] == %{"env" => "prod", "team" => "ml"}
    end

    test "converts config with partial hyperparameters" do
      config = %CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "my-model",
        training_dataset_uri: "gs://bucket/training.jsonl",
        epoch_count: 20
      }

      request = Tuning.to_api_map(config)

      params = request["supervisedTuningSpec"]["hyperParameters"]
      assert params["epochCount"] == 20
      refute Map.has_key?(params, "learningRateMultiplier")
      refute Map.has_key?(params, "adapterSize")
    end
  end

  describe "State conversion" do
    test "parse_state/1 converts API strings to atoms" do
      assert Tuning.parse_state("JOB_STATE_UNSPECIFIED") == :job_state_unspecified
      assert Tuning.parse_state("JOB_STATE_QUEUED") == :job_state_queued
      assert Tuning.parse_state("JOB_STATE_PENDING") == :job_state_pending
      assert Tuning.parse_state("JOB_STATE_RUNNING") == :job_state_running
      assert Tuning.parse_state("JOB_STATE_SUCCEEDED") == :job_state_succeeded
      assert Tuning.parse_state("JOB_STATE_FAILED") == :job_state_failed
      assert Tuning.parse_state("JOB_STATE_CANCELLING") == :job_state_cancelling
      assert Tuning.parse_state("JOB_STATE_CANCELLED") == :job_state_cancelled
      assert Tuning.parse_state("JOB_STATE_PAUSED") == :job_state_paused
      assert Tuning.parse_state("JOB_STATE_EXPIRED") == :job_state_expired
      assert is_nil(Tuning.parse_state(nil))
      assert Tuning.parse_state("UNKNOWN") == :job_state_unspecified
    end

    test "state_to_api/1 converts atoms to API strings" do
      assert Tuning.state_to_api(:job_state_unspecified) == "JOB_STATE_UNSPECIFIED"
      assert Tuning.state_to_api(:job_state_queued) == "JOB_STATE_QUEUED"
      assert Tuning.state_to_api(:job_state_pending) == "JOB_STATE_PENDING"
      assert Tuning.state_to_api(:job_state_running) == "JOB_STATE_RUNNING"
      assert Tuning.state_to_api(:job_state_succeeded) == "JOB_STATE_SUCCEEDED"
      assert Tuning.state_to_api(:job_state_failed) == "JOB_STATE_FAILED"
      assert Tuning.state_to_api(:job_state_cancelling) == "JOB_STATE_CANCELLING"
      assert Tuning.state_to_api(:job_state_cancelled) == "JOB_STATE_CANCELLED"
      assert Tuning.state_to_api(:job_state_paused) == "JOB_STATE_PAUSED"
      assert Tuning.state_to_api(:job_state_expired) == "JOB_STATE_EXPIRED"
    end
  end

  describe "TuningJob helper functions" do
    test "job_complete?/1 identifies terminal states" do
      assert Tuning.job_complete?(%TuningJob{state: :job_state_succeeded})
      assert Tuning.job_complete?(%TuningJob{state: :job_state_failed})
      assert Tuning.job_complete?(%TuningJob{state: :job_state_cancelled})
      assert Tuning.job_complete?(%TuningJob{state: :job_state_expired})
      refute Tuning.job_complete?(%TuningJob{state: :job_state_running})
      refute Tuning.job_complete?(%TuningJob{state: :job_state_queued})
      refute Tuning.job_complete?(%TuningJob{state: :job_state_pending})
    end

    test "job_running?/1 identifies active states" do
      assert Tuning.job_running?(%TuningJob{state: :job_state_queued})
      assert Tuning.job_running?(%TuningJob{state: :job_state_pending})
      assert Tuning.job_running?(%TuningJob{state: :job_state_running})
      refute Tuning.job_running?(%TuningJob{state: :job_state_succeeded})
      refute Tuning.job_running?(%TuningJob{state: :job_state_failed})
    end

    test "job_succeeded?/1 identifies success" do
      assert Tuning.job_succeeded?(%TuningJob{state: :job_state_succeeded})
      refute Tuning.job_succeeded?(%TuningJob{state: :job_state_running})
      refute Tuning.job_succeeded?(%TuningJob{state: :job_state_failed})
    end

    test "job_failed?/1 identifies failure" do
      assert Tuning.job_failed?(%TuningJob{state: :job_state_failed})
      refute Tuning.job_failed?(%TuningJob{state: :job_state_running})
      refute Tuning.job_failed?(%TuningJob{state: :job_state_succeeded})
    end
  end

  describe "ListTuningJobsResponse" do
    test "from_api_response/1 parses job list" do
      response = %{
        "tuningJobs" => [
          %{
            "name" => "projects/123/locations/us-central1/tuningJobs/1",
            "state" => "JOB_STATE_SUCCEEDED"
          },
          %{
            "name" => "projects/123/locations/us-central1/tuningJobs/2",
            "state" => "JOB_STATE_RUNNING"
          }
        ],
        "nextPageToken" => "page2"
      }

      list_response = ListTuningJobsResponse.from_api_response(response)

      assert length(list_response.tuning_jobs) == 2
      assert Enum.at(list_response.tuning_jobs, 0).state == :job_state_succeeded
      assert Enum.at(list_response.tuning_jobs, 1).state == :job_state_running
      assert list_response.next_page_token == "page2"
      assert ListTuningJobsResponse.has_more_pages?(list_response)
    end

    test "from_api_response/1 handles empty list" do
      response = %{"tuningJobs" => []}
      list_response = ListTuningJobsResponse.from_api_response(response)

      assert list_response.tuning_jobs == []
      assert is_nil(list_response.next_page_token)
      refute ListTuningJobsResponse.has_more_pages?(list_response)
    end

    test "has_more_pages?/1 detects pagination" do
      refute ListTuningJobsResponse.has_more_pages?(%ListTuningJobsResponse{
               next_page_token: nil
             })

      refute ListTuningJobsResponse.has_more_pages?(%ListTuningJobsResponse{next_page_token: ""})

      assert ListTuningJobsResponse.has_more_pages?(%ListTuningJobsResponse{
               next_page_token: "abc"
             })
    end
  end

  describe "Error handling" do
    test "CreateTuningJobConfig requires all three required fields" do
      # TypedStruct with enforce: true will raise if any required fields are missing
      # All three fields are required: base_model, tuned_model_display_name, training_dataset_uri
      assert %CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "test",
        training_dataset_uri: "gs://bucket/data.jsonl"
      }
    end

    test "parses error details correctly" do
      response = %{
        "name" => "projects/123/locations/us-central1/tuningJobs/456",
        "state" => "JOB_STATE_FAILED",
        "error" => %{
          "message" => "Training failed",
          "code" => 500
        }
      }

      job = Tuning.from_api_response(response)
      assert job.error.message == "Training failed"
      assert job.error.code == 500
    end
  end
end
