defmodule Gemini.Types.Response.EmbedContentBatchStats do
  @moduledoc """
  Statistics about an async embedding batch job.

  Tracks the progress and status of requests within a batch.

  ## Fields

  - `request_count`: Total number of requests in the batch (required)
  - `successful_request_count`: Number of successfully completed requests
  - `failed_request_count`: Number of failed requests
  - `pending_request_count`: Number of requests still pending

  ## Examples

      # From API response
      stats = EmbedContentBatchStats.from_api_response(%{
        "requestCount" => "100",
        "successfulRequestCount" => "75",
        "failedRequestCount" => "5",
        "pendingRequestCount" => "20"
      })

      # Check progress
      EmbedContentBatchStats.progress_percentage(stats)
      # => 80.0

      # Check if complete
      EmbedContentBatchStats.is_complete?(stats)
      # => false
  """

  @enforce_keys [:request_count]
  defstruct [
    :request_count,
    :successful_request_count,
    :failed_request_count,
    :pending_request_count
  ]

  @type t :: %__MODULE__{
          request_count: non_neg_integer(),
          successful_request_count: non_neg_integer() | nil,
          failed_request_count: non_neg_integer() | nil,
          pending_request_count: non_neg_integer() | nil
        }

  @doc """
  Creates stats from an API response map.

  Handles both string and integer values from the API.

  ## Parameters

  - `data`: Map containing batch statistics from the API

  ## Returns

  A new `EmbedContentBatchStats` struct

  ## Examples

      EmbedContentBatchStats.from_api_response(%{
        "requestCount" => "100",
        "successfulRequestCount" => "75"
      })
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(data) when is_map(data) do
    %__MODULE__{
      request_count: parse_count(data["requestCount"]),
      successful_request_count: parse_count(data["successfulRequestCount"]),
      failed_request_count: parse_count(data["failedRequestCount"]),
      pending_request_count: parse_count(data["pendingRequestCount"])
    }
  end

  @doc """
  Calculates the progress percentage of the batch.

  Progress is calculated as: (successful + failed) / total * 100

  ## Parameters

  - `stats`: The batch statistics

  ## Returns

  Progress as a float percentage (0.0 to 100.0)

  ## Examples

      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 75,
        failed_request_count: 5,
        pending_request_count: 20
      }

      EmbedContentBatchStats.progress_percentage(stats)
      # => 80.0
  """
  @spec progress_percentage(t()) :: float()
  def progress_percentage(%__MODULE__{} = stats) do
    successful = stats.successful_request_count || 0
    failed = stats.failed_request_count || 0
    total = stats.request_count

    if total == 0 do
      0.0
    else
      (successful + failed) / total * 100
    end
  end

  @doc """
  Checks if the batch is complete (no pending requests).

  ## Parameters

  - `stats`: The batch statistics

  ## Returns

  `true` if no pending requests remain, `false` otherwise

  ## Examples

      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 100,
        failed_request_count: 0,
        pending_request_count: 0
      }

      EmbedContentBatchStats.is_complete?(stats)
      # => true
  """
  @spec is_complete?(t()) :: boolean()
  def is_complete?(%__MODULE__{pending_request_count: nil}), do: false
  def is_complete?(%__MODULE__{pending_request_count: 0}), do: true
  def is_complete?(%__MODULE__{pending_request_count: _}), do: false

  @doc """
  Calculates the success rate of completed requests.

  ## Parameters

  - `stats`: The batch statistics

  ## Returns

  Success rate as a float percentage (0.0 to 100.0)

  ## Examples

      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 80,
        failed_request_count: 20,
        pending_request_count: 0
      }

      EmbedContentBatchStats.success_rate(stats)
      # => 80.0
  """
  @spec success_rate(t()) :: float()
  def success_rate(%__MODULE__{} = stats) do
    successful = stats.successful_request_count || 0
    total = stats.request_count

    if total == 0 do
      0.0
    else
      successful / total * 100
    end
  end

  @doc """
  Calculates the failure rate of completed requests.

  ## Parameters

  - `stats`: The batch statistics

  ## Returns

  Failure rate as a float percentage (0.0 to 100.0)

  ## Examples

      stats = %EmbedContentBatchStats{
        request_count: 100,
        successful_request_count: 80,
        failed_request_count: 20,
        pending_request_count: 0
      }

      EmbedContentBatchStats.failure_rate(stats)
      # => 20.0
  """
  @spec failure_rate(t()) :: float()
  def failure_rate(%__MODULE__{} = stats) do
    failed = stats.failed_request_count || 0
    total = stats.request_count

    if total == 0 do
      0.0
    else
      failed / total * 100
    end
  end

  # Private helpers

  defp parse_count(nil), do: nil

  defp parse_count(value) when is_integer(value), do: value

  defp parse_count(value) when is_binary(value) do
    String.to_integer(value)
  end
end
