defmodule Gemini.Types.Operation do
  @moduledoc """
  Type definitions for long-running operations.

  Long-running operations are used for tasks that may take significant time to complete,
  such as video generation, file imports, model tuning, and batch processing.

  ## Operation Lifecycle

  1. **Initiated** - Operation is created, `done: false`
  2. **Running** - Operation is processing, `done: false`
  3. **Completed** - Operation finished successfully, `done: true`, `response` populated
  4. **Failed** - Operation failed, `done: true`, `error` populated

  ## Polling Pattern

      {:ok, operation} = some_long_running_call()

      # Poll until complete
      {:ok, completed} = Gemini.APIs.Operations.wait(operation.name,
        poll_interval: 5000,
        timeout: 300_000
      )

      case completed do
        %{done: true, error: nil, response: response} ->
          IO.puts("Success: \#{inspect(response)}")
        %{done: true, error: error} ->
          IO.puts("Failed: \#{error.message}")
      end

  ## Example

      # Video generation returns an operation
      {:ok, op} = Gemini.generate_video("A cat playing piano")

      # Wait for completion
      {:ok, completed} = Gemini.APIs.Operations.wait(op.name)

      # Get the result
      video_uri = completed.response["generatedVideos"]
  """

  use TypedStruct

  @typedoc """
  Operation error details.
  """
  @type operation_error :: %{
          optional(:code) => integer(),
          optional(:message) => String.t(),
          optional(:details) => [map()]
        }

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Represents a long-running operation.

    ## Fields

    - `name` - Server-assigned unique identifier (e.g., "operations/abc123")
    - `metadata` - Service-specific metadata about the operation progress
    - `done` - Whether the operation is complete (true = finished, false = in progress)
    - `error` - Error result if the operation failed (mutually exclusive with response)
    - `response` - Success result if the operation completed (mutually exclusive with error)
    """

    field(:name, String.t())
    field(:metadata, map())
    field(:done, boolean(), default: false)
    field(:error, operation_error())
    field(:response, map())
  end

  @doc """
  Creates an Operation from API response.

  ## Parameters

  - `response` - Map from API response with string keys

  ## Examples

      response = %{
        "name" => "operations/abc123",
        "done" => false,
        "metadata" => %{"@type" => "...", "progress" => 50}
      }
      op = Gemini.Types.Operation.from_api_response(response)
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    %__MODULE__{
      name: response["name"],
      metadata: response["metadata"],
      done: response["done"] || false,
      error: parse_error(response["error"]),
      response: response["response"]
    }
  end

  @doc """
  Checks if the operation is complete (successfully or failed).
  """
  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{done: true}), do: true
  def complete?(_), do: false

  @doc """
  Checks if the operation completed successfully.
  """
  @spec succeeded?(t()) :: boolean()
  def succeeded?(%__MODULE__{done: true, error: nil}), do: true
  def succeeded?(_), do: false

  @doc """
  Checks if the operation failed.
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{done: true, error: error}) when not is_nil(error), do: true
  def failed?(_), do: false

  @doc """
  Checks if the operation is still running.
  """
  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{done: false}), do: true
  def running?(_), do: false

  @doc """
  Gets the progress percentage from metadata, if available.

  Returns nil if progress information is not available in metadata.
  """
  @spec get_progress(t()) :: float() | nil
  def get_progress(%__MODULE__{metadata: nil}), do: nil

  def get_progress(%__MODULE__{metadata: metadata}) when is_map(metadata) do
    # Try common progress field names
    metadata["progress"] ||
      metadata["progressPercent"] ||
      metadata["completionPercentage"]
  end

  @doc """
  Extracts the operation ID from the full name.

  ## Examples

      op = %Operation{name: "operations/abc123"}
      Operation.get_id(op)
      # => "abc123"
  """
  @spec get_id(t()) :: String.t() | nil
  def get_id(%__MODULE__{name: nil}), do: nil

  def get_id(%__MODULE__{name: name}) do
    case String.split(name, "/") do
      ["operations", id] -> id
      _ -> name
    end
  end

  # Private helpers

  defp parse_error(nil), do: nil

  defp parse_error(error) when is_map(error) do
    %{
      code: error["code"],
      message: error["message"],
      details: error["details"]
    }
  end
end

defmodule Gemini.Types.ListOperationsResponse do
  @moduledoc """
  Response type for listing operations.
  """

  use TypedStruct

  alias Gemini.Types.Operation

  @derive Jason.Encoder
  typedstruct do
    @typedoc """
    Response from listing operations.

    - `operations` - List of Operation structs
    - `next_page_token` - Token for fetching next page (nil if no more pages)
    """
    field(:operations, [Operation.t()], default: [])
    field(:next_page_token, String.t())
  end

  @doc """
  Creates a ListOperationsResponse from API response.
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(response) when is_map(response) do
    operations =
      (response["operations"] || [])
      |> Enum.map(&Operation.from_api_response/1)

    %__MODULE__{
      operations: operations,
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
