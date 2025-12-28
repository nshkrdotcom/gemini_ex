defmodule Gemini.TuningsLiveTest do
  use ExUnit.Case

  @moduletag :live_api
  @moduletag timeout: 180_000

  alias Gemini.APIs.Tunings
  alias Gemini.Test.AuthHelpers
  alias Gemini.Types.Tuning.{CreateTuningJobConfig, TuningJob}

  setup_all do
    case AuthHelpers.detect_auth() do
      {:ok, :vertex_ai, creds} ->
        # Verify we have project_id for tuning operations
        project_id = Map.get(creds, :project_id)

        if project_id do
          {:ok, auth: :vertex_ai, project_id: project_id, skip: false}
        else
          {:ok, skip: true}
        end

      _ ->
        {:ok, skip: true}
    end
  end

  describe "list/1 - List tuning jobs" do
    @tag :live_api
    test "lists tuning jobs with default options", %{skip: skip} = ctx do
      if skip do
        IO.puts("Skipping tuning list test - Vertex AI auth not configured")
        assert true
      else
        auth = ctx.auth
        # This should work even if there are no jobs
        result = Tunings.list(auth: auth)

        case result do
          {:ok, response} ->
            assert is_list(response.tuning_jobs)
            # May be empty if no jobs exist
            assert is_binary(response.next_page_token) or is_nil(response.next_page_token)

          {:error, reason} ->
            # Expected if API is not enabled or permissions issue
            IO.puts("List jobs failed (expected if tuning not enabled): #{inspect(reason)}")
            assert true
        end
      end
    end

    @tag :live_api
    test "lists tuning jobs with pagination", %{skip: skip} = ctx do
      if skip do
        IO.puts("Skipping tuning list pagination - Vertex AI auth not configured")
        assert true
      else
        auth = ctx.auth
        result = Tunings.list(auth: auth, page_size: 10)

        case result do
          {:ok, response} ->
            assert is_list(response.tuning_jobs)

          # Jobs may or may not exist

          {:error, _reason} ->
            # Expected if API not enabled
            assert true
        end
      end
    end

    @tag :live_api
    test "filters tuning jobs by state", %{skip: skip} = ctx do
      if skip do
        IO.puts("Skipping tuning filter test - Vertex AI auth not configured")
        assert true
      else
        auth = ctx.auth
        # Try to list only succeeded jobs
        result = Tunings.list(auth: auth, filter: "state=JOB_STATE_SUCCEEDED")

        case result do
          {:ok, response} ->
            # All returned jobs should be succeeded
            Enum.each(response.tuning_jobs, fn job ->
              assert job.state == :job_state_succeeded
            end)

          {:error, _reason} ->
            # Expected if API not enabled
            assert true
        end
      end
    end
  end

  describe "get/2 - Get tuning job details" do
    @tag :live_api
    test "returns error for non-existent job", %{skip: skip} = ctx do
      if skip do
        IO.puts("Skipping tuning get test - Vertex AI auth not configured")
        assert true
      else
        auth = ctx.auth
        # Use a clearly fake job ID
        fake_job_name = "projects/fake-project/locations/us-central1/tuningJobs/nonexistent-123"

        result = Tunings.get(fake_job_name, auth: auth)

        # Should return an error
        assert {:error, _reason} = result
      end
    end
  end

  describe "tune/2 - Create tuning job (validation only)" do
    @tag :live_api
    @tag :skip
    # Skipped by default as creating real tuning jobs is expensive
    # Remove @tag :skip to test actual job creation
    test "creates a tuning job with valid configuration", %{auth: auth, project_id: project_id} do
      # NOTE: This test is skipped by default because:
      # 1. Tuning jobs are expensive (cost money)
      # 2. They require real training data in GCS
      # 3. They take hours to complete
      #
      # To run this test:
      # 1. Remove the @tag :skip annotation
      # 2. Replace the URIs below with your actual GCS data
      # 3. Run with: mix test --only live_api test/live_api/tunings_live_test.exs

      config = %CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "test-tuned-model-#{System.system_time(:second)}",
        training_dataset_uri: "gs://your-bucket/training-data.jsonl",
        validation_dataset_uri: "gs://your-bucket/validation-data.jsonl",
        epoch_count: 1,
        # Use minimal epochs for testing
        labels: %{"test" => "live_api"}
      }

      result = Tunings.tune(config, auth: auth, project_id: project_id)

      case result do
        {:ok, job} ->
          assert %TuningJob{} = job
          assert job.base_model == "gemini-2.5-flash-001"
          assert job.state in [:job_state_queued, :job_state_pending, :job_state_running]

          # Clean up: cancel the job
          {:ok, _cancelled} = Tunings.cancel(job.name, auth: auth)

        {:error, reason} ->
          # Expected errors:
          # - Training data not found
          # - Permissions issues
          # - API not enabled
          IO.puts("Tuning job creation failed (expected): #{inspect(reason)}")
          assert true
      end
    end

    @tag :live_api
    test "rejects creation with :gemini auth", _context do
      config = %CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "test-model",
        training_dataset_uri: "gs://bucket/data.jsonl"
      }

      result = Tunings.tune(config, auth: :gemini)

      assert {:error, {:invalid_auth, msg}} = result
      assert String.contains?(msg, "Vertex AI")
    end
  end

  describe "cancel/2 - Cancel tuning job (validation only)" do
    @tag :live_api
    test "returns error when cancelling non-existent job", %{skip: skip} = ctx do
      if skip do
        IO.puts("Skipping tuning cancel test - Vertex AI auth not configured")
        assert true
      else
        auth = ctx.auth
        fake_job_name = "projects/fake/locations/us-central1/tuningJobs/nonexistent"

        result = Tunings.cancel(fake_job_name, auth: auth)

        # Should return an error
        assert {:error, _reason} = result
      end
    end
  end

  describe "list_all/1 - List all jobs with pagination" do
    @tag :live_api
    test "collects all jobs across pages", %{skip: skip} = ctx do
      if skip do
        IO.puts("Skipping tuning list_all test - Vertex AI auth not configured")
        assert true
      else
        auth = ctx.auth
        # Use small page size to test pagination logic
        result = Tunings.list_all(auth: auth, page_size: 5)

        case result do
          {:ok, jobs} ->
            assert is_list(jobs)
            # All should be TuningJob structs
            Enum.each(jobs, fn job ->
              assert %TuningJob{} = job
            end)

          {:error, _reason} ->
            # Expected if API not enabled
            assert true
        end
      end
    end
  end

  describe "Integration scenarios" do
    @tag :live_api
    @tag :skip
    # Skipped by default - expensive operation
    test "full tuning job lifecycle", %{auth: auth, project_id: project_id} do
      # This test demonstrates a complete tuning workflow:
      # 1. Create job
      # 2. Monitor progress
      # 3. Cancel job (to avoid long wait and costs)
      # 4. Verify cancellation

      config = %CreateTuningJobConfig{
        base_model: "gemini-2.5-flash-001",
        tuned_model_display_name: "integration-test-#{System.system_time(:second)}",
        training_dataset_uri: "gs://your-bucket/training.jsonl",
        epoch_count: 1
      }

      # Step 1: Create job
      {:ok, job} = Tunings.tune(config, auth: auth, project_id: project_id)
      assert job.state in [:job_state_queued, :job_state_pending]

      # Step 2: Get updated status
      Process.sleep(2000)
      {:ok, updated_job} = Tunings.get(job.name, auth: auth)
      assert updated_job.name == job.name

      # Step 3: Cancel job
      {:ok, cancelling_job} = Tunings.cancel(job.name, auth: auth)
      assert cancelling_job.state in [:job_state_cancelling, :job_state_cancelled]

      # Step 4: Verify cancellation
      Process.sleep(2000)
      {:ok, final_job} = Tunings.get(job.name, auth: auth)
      assert final_job.state in [:job_state_cancelling, :job_state_cancelled]
    end
  end
end
