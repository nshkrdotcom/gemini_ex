defmodule Gemini.APIs.Batches do
  @moduledoc """
  Batches API for batch processing of content generation and embedding requests.

  Batch processing allows you to submit large numbers of requests at once,
  with 50% cost savings compared to interactive API calls.

  ## Use Cases

  - Processing large document collections for embeddings
  - Bulk content generation for content pipelines
  - Overnight processing of accumulated requests
  - Cost optimization for high-volume workloads

  ## Batch Sources

  **Gemini API:**
  - `file_name` - Reference to an uploaded file (JSONL format)
  - `inlined_requests` - Direct inline requests (limited size)

  **Vertex AI:**
  - `gcs_uri` - Google Cloud Storage URIs (JSONL files)
  - `bigquery_uri` - BigQuery table URI

  ## Batch Destinations

  **Gemini API:**
  - Results returned in `inlined_responses`
  - Or written to a file

  **Vertex AI:**
  - `gcs_uri` - GCS output prefix
  - `bigquery_uri` - BigQuery output table

  ## Example Workflow

      # 1. Prepare input file (JSONL format)
      #    Each line: {"contents": [{"parts": [{"text": "..."}]}]}

      # 2. Upload the input file
      {:ok, input_file} = Gemini.APIs.Files.upload("input.jsonl")

      # 3. Create batch job
      {:ok, batch} = Gemini.APIs.Batches.create("gemini-2.5-flash",
        file_name: input_file.name,
        display_name: "My Batch Job"
      )

      # 4. Wait for completion
      {:ok, completed} = Gemini.APIs.Batches.wait(batch.name,
        poll_interval: 30_000,
        timeout: 3_600_000  # 1 hour
      )

      # 5. Process results
      if BatchJob.succeeded?(completed) do
        IO.puts("Completed \#{completed.completion_stats.success_count} requests")
      end
  """

  alias Gemini.Client.HTTP
  alias Gemini.Config
  alias Gemini.Types.{BatchJob, ListBatchJobsResponse}

  @type create_opts :: [
          {:display_name, String.t()}
          | {:file_name, String.t()}
          | {:inlined_requests, [map()]}
          | {:gcs_uri, [String.t()]}
          | {:bigquery_uri, String.t()}
          | {:generation_config, map()}
          | {:system_instruction, map()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type batch_opts :: [{:auth, :gemini | :vertex_ai}]

  @type list_opts :: [
          {:page_size, pos_integer()}
          | {:page_token, String.t()}
          | {:filter, String.t()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type wait_opts :: [
          {:poll_interval, pos_integer()}
          | {:timeout, pos_integer()}
          | {:on_progress, (BatchJob.t() -> any())}
          | {:auth, :gemini | :vertex_ai}
        ]

  @doc """
  Create a new batch generation job.

  ## Parameters

  - `model` - Model to use for generation (e.g., "gemini-2.5-flash")
  - `opts` - Batch creation options

  ## Options

  - `:display_name` - Human-readable name for the batch
  - `:file_name` - Input file name (for Gemini API)
  - `:inlined_requests` - Inline requests (for small batches)
  - `:gcs_uri` - GCS input URIs (for Vertex AI)
  - `:bigquery_uri` - BigQuery input URI (for Vertex AI)
  - `:generation_config` - Generation configuration for all requests
  - `:system_instruction` - System instruction for all requests
  - `:auth` - Authentication strategy

  ## Input File Format (JSONL)

  For file-based input, each line should be a JSON object:

      {"contents": [{"parts": [{"text": "First request"}]}]}
      {"contents": [{"parts": [{"text": "Second request"}]}]}

  ## Examples

      # Using uploaded file
      {:ok, batch} = Gemini.APIs.Batches.create("gemini-2.5-flash",
        file_name: "files/abc123",
        display_name: "My Batch"
      )

      # Using inline requests (small batches only)
      {:ok, batch} = Gemini.APIs.Batches.create("gemini-2.5-flash",
        inlined_requests: [
          %{contents: [%{parts: [%{text: "Request 1"}]}]},
          %{contents: [%{parts: [%{text: "Request 2"}]}]}
        ],
        display_name: "Small Batch"
      )

      # With generation config
      {:ok, batch} = Gemini.APIs.Batches.create("gemini-2.5-flash",
        file_name: "files/abc123",
        generation_config: %{
          temperature: 0.7,
          maxOutputTokens: 1000
        }
      )
  """
  @spec create(String.t(), create_opts()) :: {:ok, BatchJob.t()} | {:error, term()}
  def create(model, opts \\ []) do
    path = "models/#{model}:batchGenerateContent"

    request_body = build_create_request(model, opts)

    case HTTP.post(path, request_body, opts) do
      {:ok, response} -> {:ok, BatchJob.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create a new batch embedding job.

  Similar to `create/2` but for embedding requests.

  ## Parameters

  - `model` - Embedding model to use
  - `opts` - Batch creation options

  ## Input File Format (JSONL)

  For embeddings, each line should contain text to embed:

      {"content": {"parts": [{"text": "Text to embed"}]}}
      {"content": {"parts": [{"text": "Another text"}]}}

  ## Examples

      {:ok, batch} = Gemini.APIs.Batches.create_embeddings("text-embedding-004",
        file_name: "files/embeddings-input",
        display_name: "Embedding Batch"
      )
  """
  @spec create_embeddings(String.t(), create_opts()) :: {:ok, BatchJob.t()} | {:error, term()}
  def create_embeddings(model, opts \\ []) do
    model = model || Config.default_embedding_model()
    path = "models/#{model}:batchEmbedContents"

    request_body = build_create_request(model, opts)

    case HTTP.post(path, request_body, opts) do
      {:ok, response} -> {:ok, BatchJob.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the status of a batch job.

  ## Parameters

  - `name` - Batch job name (e.g., "batches/abc123")
  - `opts` - Options

  ## Examples

      {:ok, batch} = Gemini.APIs.Batches.get("batches/abc123")
      IO.puts("State: \#{batch.state}")

      if batch.completion_stats do
        IO.puts("Progress: \#{batch.completion_stats.success_count}/\#{batch.completion_stats.total_count}")
      end
  """
  @spec get(String.t(), batch_opts()) :: {:ok, BatchJob.t()} | {:error, term()}
  def get(name, opts \\ []) do
    path = normalize_batch_path(name)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, BatchJob.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List batch jobs.

  ## Parameters

  - `opts` - List options

  ## Options

  - `:page_size` - Number of jobs per page (default: 100)
  - `:page_token` - Token from previous response for pagination
  - `:filter` - Filter string
  - `:auth` - Authentication strategy

  ## Examples

      {:ok, response} = Gemini.APIs.Batches.list()

      Enum.each(response.batch_jobs, fn job ->
        IO.puts("\#{job.name}: \#{job.state}")
      end)

      # With pagination
      {:ok, response} = Gemini.APIs.Batches.list(page_size: 10)
      if ListBatchJobsResponse.has_more_pages?(response) do
        {:ok, page2} = Gemini.APIs.Batches.list(page_token: response.next_page_token)
      end
  """
  @spec list(list_opts()) :: {:ok, ListBatchJobsResponse.t()} | {:error, term()}
  def list(opts \\ []) do
    path = build_list_path(opts)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, ListBatchJobsResponse.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all batch jobs across all pages.

  Automatically handles pagination.

  ## Examples

      {:ok, all_jobs} = Gemini.APIs.Batches.list_all()
      running = Enum.filter(all_jobs, &BatchJob.running?/1)
  """
  @spec list_all(list_opts()) :: {:ok, [BatchJob.t()]} | {:error, term()}
  def list_all(opts \\ []) do
    collect_all_batches(opts, [])
  end

  @doc """
  Cancel a running batch job.

  Can only cancel jobs that are in `queued` or `running` state.

  ## Parameters

  - `name` - Batch job name
  - `opts` - Options

  ## Examples

      :ok = Gemini.APIs.Batches.cancel("batches/abc123")
  """
  @spec cancel(String.t(), batch_opts()) :: :ok | {:error, term()}
  def cancel(name, opts \\ []) do
    path = "#{normalize_batch_path(name)}:cancel"

    case HTTP.post(path, %{}, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete a batch job.

  Typically used to clean up completed jobs.

  ## Parameters

  - `name` - Batch job name
  - `opts` - Options

  ## Examples

      :ok = Gemini.APIs.Batches.delete("batches/abc123")
  """
  @spec delete(String.t(), batch_opts()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    path = normalize_batch_path(name)

    case HTTP.delete(path, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Wait for a batch job to complete.

  Polls the batch status until it reaches a terminal state (succeeded, failed, etc.)
  or the timeout is reached.

  ## Parameters

  - `name` - Batch job name
  - `opts` - Wait options

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 30000)
  - `:timeout` - Maximum wait time in milliseconds (default: 3600000 = 1 hour)
  - `:on_progress` - Callback for status updates `fn(BatchJob.t()) -> any()`

  ## Examples

      {:ok, completed} = Gemini.APIs.Batches.wait("batches/abc123",
        poll_interval: 60_000,   # Check every minute
        timeout: 7_200_000,      # Wait up to 2 hours
        on_progress: fn batch ->
          if progress = BatchJob.get_progress(batch) do
            IO.puts("Progress: \#{Float.round(progress, 1)}%")
          end
        end
      )

      cond do
        BatchJob.succeeded?(completed) ->
          IO.puts("Success!")
        BatchJob.failed?(completed) ->
          IO.puts("Failed: \#{completed.error.message}")
      end
  """
  @spec wait(String.t(), wait_opts()) :: {:ok, BatchJob.t()} | {:error, term()}
  def wait(name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 30_000)
    timeout = Keyword.get(opts, :timeout, 3_600_000)
    on_progress = Keyword.get(opts, :on_progress)
    get_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)
    do_wait(name, get_opts, poll_interval, timeout, start_time, on_progress)
  end

  @doc """
  Get inlined responses from a completed batch job.

  Only works for batches with inline response output.

  ## Parameters

  - `batch` - Completed BatchJob with inlined responses
  - `opts` - Options

  ## Examples

      {:ok, batch} = Gemini.APIs.Batches.get("batches/abc123")
      if BatchJob.succeeded?(batch) do
        {:ok, responses} = Gemini.APIs.Batches.get_responses(batch)
        Enum.each(responses, &process_response/1)
      end
  """
  @spec get_responses(BatchJob.t()) :: {:ok, [map()]} | {:error, term()}
  def get_responses(%BatchJob{} = batch) do
    cond do
      not BatchJob.complete?(batch) ->
        {:error, {:not_complete, batch.state}}

      is_nil(batch.dest) ->
        {:error, :no_destination}

      not is_nil(batch.dest[:inlined_responses]) ->
        {:ok, batch.dest.inlined_responses}

      not is_nil(batch.dest[:file_name]) ->
        {:error, {:file_output, batch.dest.file_name}}

      not is_nil(batch.dest[:gcs_uri]) ->
        {:error, {:gcs_output, batch.dest.gcs_uri}}

      true ->
        {:error, :unknown_output_format}
    end
  end

  # Private Functions

  defp build_create_request(model, opts) do
    base = %{model: model}

    # Add display name
    base =
      case Keyword.get(opts, :display_name) do
        nil -> base
        name -> Map.put(base, :displayName, name)
      end

    # Add source
    base = add_source(base, opts)

    # Add generation config
    base =
      case Keyword.get(opts, :generation_config) do
        nil -> base
        config -> Map.put(base, :generationConfig, config)
      end

    # Add system instruction
    base =
      case Keyword.get(opts, :system_instruction) do
        nil -> base
        instruction -> Map.put(base, :systemInstruction, instruction)
      end

    base
  end

  defp add_source(request, opts) do
    cond do
      file_name = Keyword.get(opts, :file_name) ->
        put_in(request, [:src], %{fileName: file_name})

      inlined = Keyword.get(opts, :inlined_requests) ->
        put_in(request, [:src], %{inlinedRequests: inlined})

      gcs_uri = Keyword.get(opts, :gcs_uri) ->
        put_in(request, [:src], %{gcsUri: gcs_uri, format: "jsonl"})

      bigquery_uri = Keyword.get(opts, :bigquery_uri) ->
        put_in(request, [:src], %{bigqueryUri: bigquery_uri, format: "bigquery"})

      true ->
        request
    end
  end

  defp normalize_batch_path("batches/" <> _ = name), do: name
  defp normalize_batch_path("batchPredictionJobs/" <> _ = name), do: name
  defp normalize_batch_path(name), do: "batches/#{name}"

  defp build_list_path(opts) do
    query_params = []

    query_params =
      case Keyword.get(opts, :page_size) do
        nil -> query_params
        size -> [{"pageSize", size} | query_params]
      end

    query_params =
      case Keyword.get(opts, :page_token) do
        nil -> query_params
        token -> [{"pageToken", token} | query_params]
      end

    query_params =
      case Keyword.get(opts, :filter) do
        nil -> query_params
        filter -> [{"filter", filter} | query_params]
      end

    case query_params do
      [] -> "batches"
      params -> "batches?" <> URI.encode_query(params)
    end
  end

  defp collect_all_batches(opts, acc) do
    case list(opts) do
      {:ok, %{batch_jobs: jobs, next_page_token: nil}} ->
        {:ok, acc ++ jobs}

      {:ok, %{batch_jobs: jobs, next_page_token: token}} ->
        collect_all_batches(Keyword.put(opts, :page_token, token), acc ++ jobs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_wait(name, opts, poll_interval, timeout, start_time, on_progress) do
    case get(name, opts) do
      {:ok, batch} ->
        maybe_report_progress(on_progress, batch)
        handle_batch_state(batch, name, opts, poll_interval, timeout, start_time, on_progress)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_batch_state(batch, name, opts, poll_interval, timeout, start_time, on_progress) do
    if BatchJob.complete?(batch) do
      {:ok, batch}
    else
      if timed_out?(start_time, timeout) do
        {:error, :timeout}
      else
        Process.sleep(poll_interval)
        do_wait(name, opts, poll_interval, timeout, start_time, on_progress)
      end
    end
  end

  defp maybe_report_progress(nil, _batch), do: :ok
  defp maybe_report_progress(callback, batch), do: callback.(batch)

  defp timed_out?(start_time, timeout) do
    System.monotonic_time(:millisecond) - start_time >= timeout
  end
end
