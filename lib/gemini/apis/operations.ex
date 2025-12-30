defmodule Gemini.APIs.Operations do
  @moduledoc """
  Operations API for managing long-running operations.

  Long-running operations are returned by asynchronous API calls that may take
  significant time to complete, such as:

  - Video generation
  - File imports
  - Model tuning
  - Large batch processing

  ## Polling Pattern

  The typical pattern for handling long-running operations:

      # Start a long-running operation
      {:ok, operation} = some_async_api_call()

      # Wait for completion with polling
      {:ok, completed} = Gemini.APIs.Operations.wait(operation.name,
        poll_interval: 5000,      # Check every 5 seconds
        timeout: 600_000,         # Wait up to 10 minutes
        on_progress: fn op ->
          if progress = Gemini.Types.Operation.get_progress(op) do
            IO.puts("Progress: \#{progress}%")
          end
        end
      )

      # Handle result
      if Gemini.Types.Operation.succeeded?(completed) do
        result = completed.response
        # Process successful result
      else
        error = completed.error
        # Handle error
      end

  ## Manual Polling

  For more control, you can poll manually:

      {:ok, op} = Gemini.APIs.Operations.get(operation_name)

      cond do
        Operation.succeeded?(op) -> handle_success(op.response)
        Operation.failed?(op) -> handle_failure(op.error)
        Operation.running?(op) -> poll_again_later()
      end

  ## Cancellation

  Some operations can be cancelled while in progress:

      :ok = Gemini.APIs.Operations.cancel(operation_name)
  """

  alias Gemini.Client.HTTP
  alias Gemini.Types.{ListOperationsResponse, Operation}

  import Gemini.Utils.PollingHelpers, only: [timed_out?: 2]
  import Gemini.Utils.MapHelpers, only: [build_paginated_path: 2]

  @type operation_opts :: [{:auth, :gemini | :vertex_ai}]

  @type wait_opts :: [
          {:poll_interval, pos_integer()}
          | {:timeout, pos_integer()}
          | {:on_progress, (Operation.t() -> any())}
          | {:auth, :gemini | :vertex_ai}
        ]

  @type list_opts :: [
          {:page_size, pos_integer()}
          | {:page_token, String.t()}
          | {:filter, String.t()}
          | {:auth, :gemini | :vertex_ai}
        ]

  @doc """
  Get the current status of an operation.

  ## Parameters

  - `name` - Operation name (e.g., "operations/abc123")
  - `opts` - Options

  ## Examples

      {:ok, op} = Gemini.APIs.Operations.get("operations/abc123")

      if op.done do
        IO.puts("Operation completed")
      else
        IO.puts("Still running...")
      end
  """
  @spec get(String.t(), operation_opts()) :: {:ok, Operation.t()} | {:error, term()}
  def get(name, opts \\ []) do
    path = normalize_operation_path(name)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, Operation.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List operations, optionally filtered.

  ## Parameters

  - `opts` - List options

  ## Options

  - `:page_size` - Number of operations per page (default: 100)
  - `:page_token` - Token from previous response for pagination
  - `:filter` - Filter string (e.g., "done=true")
  - `:auth` - Authentication strategy

  ## Examples

      # List all operations
      {:ok, response} = Gemini.APIs.Operations.list()

      # List only completed operations
      {:ok, response} = Gemini.APIs.Operations.list(filter: "done=true")

      # With pagination
      {:ok, response} = Gemini.APIs.Operations.list(page_size: 10)
  """
  @spec list(list_opts()) :: {:ok, ListOperationsResponse.t()} | {:error, term()}
  def list(opts \\ []) do
    path = build_list_path(opts)

    case HTTP.get(path, opts) do
      {:ok, response} -> {:ok, ListOperationsResponse.from_api_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List all operations across all pages.

  Automatically handles pagination to retrieve all operations.

  ## Parameters

  - `opts` - List options

  ## Examples

      {:ok, all_ops} = Gemini.APIs.Operations.list_all()
      completed = Enum.filter(all_ops, &Operation.complete?/1)
  """
  @spec list_all(list_opts()) :: {:ok, [Operation.t()]} | {:error, term()}
  def list_all(opts \\ []) do
    collect_all_operations(opts, [])
  end

  @doc """
  Cancel a running operation.

  Not all operations support cancellation. If the operation doesn't support
  cancellation or is already complete, this may return an error.

  ## Parameters

  - `name` - Operation name
  - `opts` - Options

  ## Examples

      :ok = Gemini.APIs.Operations.cancel("operations/abc123")
  """
  @spec cancel(String.t(), operation_opts()) :: :ok | {:error, term()}
  def cancel(name, opts \\ []) do
    path = "#{normalize_operation_path(name)}:cancel"

    case HTTP.post(path, %{}, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete an operation.

  Typically used to clean up completed operations.

  ## Parameters

  - `name` - Operation name
  - `opts` - Options

  ## Examples

      :ok = Gemini.APIs.Operations.delete("operations/abc123")
  """
  @spec delete(String.t(), operation_opts()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    path = normalize_operation_path(name)

    case HTTP.delete(path, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Wait for an operation to complete.

  Polls the operation status until it reaches a terminal state (done = true),
  or the timeout is reached.

  ## Parameters

  - `name` - Operation name
  - `opts` - Wait options

  ## Options

  - `:poll_interval` - Milliseconds between status checks (default: 5000)
  - `:timeout` - Maximum wait time in milliseconds (default: 600000 = 10 min)
  - `:on_progress` - Callback for status updates `fn(Operation.t()) -> any()`

  ## Returns

  - `{:ok, Operation.t()}` - Completed operation (check `done`, `error`, `response`)
  - `{:error, :timeout}` - Timed out waiting for completion
  - `{:error, reason}` - Failed to poll status

  ## Examples

      # Simple wait
      {:ok, completed} = Gemini.APIs.Operations.wait("operations/abc123")

      # With progress tracking
      {:ok, completed} = Gemini.APIs.Operations.wait("operations/abc123",
        poll_interval: 2000,
        timeout: 300_000,
        on_progress: fn op ->
          if progress = Operation.get_progress(op) do
            IO.puts("Progress: \#{progress}%")
          end
        end
      )

      # Handle result
      cond do
        Operation.succeeded?(completed) ->
          IO.puts("Success: \#{inspect(completed.response)}")
        Operation.failed?(completed) ->
          IO.puts("Failed: \#{completed.error.message}")
      end
  """
  @spec wait(String.t(), wait_opts()) :: {:ok, Operation.t()} | {:error, term()}
  def wait(name, opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, 5000)
    timeout = Keyword.get(opts, :timeout, 600_000)
    on_progress = Keyword.get(opts, :on_progress)
    get_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)
    do_wait(name, get_opts, poll_interval, timeout, start_time, on_progress)
  end

  @doc """
  Wait for an operation with exponential backoff.

  Similar to `wait/2` but uses exponential backoff for polling intervals,
  which is more efficient for operations that may take a long time.

  ## Parameters

  - `name` - Operation name
  - `opts` - Wait options

  ## Options

  Same as `wait/2` plus:
  - `:initial_delay` - Initial delay in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay in milliseconds (default: 30000)
  - `:multiplier` - Backoff multiplier (default: 2)

  ## Examples

      {:ok, completed} = Gemini.APIs.Operations.wait_with_backoff("operations/abc123",
        initial_delay: 1000,
        max_delay: 30_000,
        timeout: 600_000
      )
  """
  @spec wait_with_backoff(String.t(), keyword()) ::
          {:ok, Operation.t()} | {:error, term()}
  def wait_with_backoff(name, opts \\ []) do
    initial_delay = Keyword.get(opts, :initial_delay, 1000)
    max_delay = Keyword.get(opts, :max_delay, 30_000)
    multiplier = Keyword.get(opts, :multiplier, 2)
    timeout = Keyword.get(opts, :timeout, 600_000)
    on_progress = Keyword.get(opts, :on_progress)
    get_opts = Keyword.take(opts, [:auth])

    start_time = System.monotonic_time(:millisecond)

    do_wait_backoff(
      name,
      get_opts,
      initial_delay,
      max_delay,
      multiplier,
      timeout,
      start_time,
      on_progress
    )
  end

  # Private Functions

  defp normalize_operation_path("operations/" <> _ = name), do: name
  defp normalize_operation_path(name), do: "operations/#{name}"

  defp build_list_path(opts), do: build_paginated_path("operations", opts)

  defp collect_all_operations(opts, acc) do
    case list(opts) do
      {:ok, %{operations: ops, next_page_token: nil}} ->
        {:ok, acc ++ ops}

      {:ok, %{operations: ops, next_page_token: token}} ->
        collect_all_operations(Keyword.put(opts, :page_token, token), acc ++ ops)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_wait(name, opts, poll_interval, timeout, start_time, on_progress) do
    case get(name, opts) do
      {:ok, operation} ->
        maybe_report_progress(on_progress, operation)

        handle_operation_wait(operation, timeout, start_time, fn ->
          Process.sleep(poll_interval)
          do_wait(name, opts, poll_interval, timeout, start_time, on_progress)
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_wait_backoff(
         name,
         opts,
         current_delay,
         max_delay,
         multiplier,
         timeout,
         start_time,
         on_progress
       ) do
    case get(name, opts) do
      {:ok, operation} ->
        maybe_report_progress(on_progress, operation)

        handle_operation_wait(operation, timeout, start_time, fn ->
          Process.sleep(current_delay)
          next_delay = min(current_delay * multiplier, max_delay)

          do_wait_backoff(
            name,
            opts,
            next_delay,
            max_delay,
            multiplier,
            timeout,
            start_time,
            on_progress
          )
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_operation_wait(operation, timeout, start_time, continue_fun) do
    cond do
      Operation.complete?(operation) -> {:ok, operation}
      timed_out?(start_time, timeout) -> {:error, :timeout}
      true -> continue_fun.()
    end
  end

  defp maybe_report_progress(nil, _operation), do: :ok
  defp maybe_report_progress(callback, operation), do: callback.(operation)
end
