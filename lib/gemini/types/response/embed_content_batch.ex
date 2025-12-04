defmodule Gemini.Types.Response.EmbedContentBatch do
  @moduledoc """
  Complete async batch embedding job status and results.

  Returned by get_batch_status and get_batch_result operations.
  Represents the full state of an async batch embedding job including
  progress, timing, and results.

  ## Fields

  - `model`: Model used for embeddings
  - `name`: Batch identifier (format: "batches/{batchId}")
  - `display_name`: Human-readable batch name
  - `input_config`: Input configuration (file or inline)
  - `output`: Output containing results (when complete)
  - `create_time`: When batch was created
  - `end_time`: When batch completed/failed
  - `update_time`: Last update timestamp
  - `batch_stats`: Progress and completion statistics
  - `state`: Current batch state
  - `priority`: Processing priority

  ## Examples

      %EmbedContentBatch{
        model: "models/gemini-embedding-001",
        name: "batches/abc123def456",
        display_name: "Knowledge Base Embeddings",
        state: :processing,
        batch_stats: %EmbedContentBatchStats{
          request_count: 1000,
          successful_request_count: 750,
          failed_request_count: 50,
          pending_request_count: 200
        },
        create_time: ~U[2025-10-14 17:00:00Z],
        ...
      }
  """

  alias Gemini.Types.Request.InputEmbedContentConfig

  alias Gemini.Types.Response.{
    EmbedContentBatchOutput,
    EmbedContentBatchStats,
    BatchState
  }

  @enforce_keys [:model, :name, :display_name]
  defstruct [
    :model,
    :name,
    :display_name,
    :input_config,
    :output,
    :create_time,
    :end_time,
    :update_time,
    :batch_stats,
    :state,
    :priority
  ]

  @type t :: %__MODULE__{
          model: String.t(),
          name: String.t(),
          display_name: String.t(),
          input_config: InputEmbedContentConfig.t() | nil,
          output: EmbedContentBatchOutput.t() | nil,
          create_time: DateTime.t() | nil,
          end_time: DateTime.t() | nil,
          update_time: DateTime.t() | nil,
          batch_stats: EmbedContentBatchStats.t() | nil,
          state: BatchState.t(),
          priority: integer() | nil
        }

  @doc """
  Creates a batch from API response data.

  ## Parameters

  - `data`: Map containing the API response

  ## Examples

      EmbedContentBatch.from_api_response(%{
        "model" => "models/gemini-embedding-001",
        "name" => "batches/abc123",
        "displayName" => "My Batch",
        "state" => "PROCESSING",
        ...
      })
  """
  @spec from_api_response(map()) :: t()
  def from_api_response(data) when is_map(data) do
    %__MODULE__{
      model: data["model"],
      name: data["name"],
      display_name: data["displayName"],
      input_config: parse_input_config(data["inputConfig"]),
      output: parse_output(data["output"]),
      create_time: parse_timestamp(data["createTime"]),
      end_time: parse_timestamp(data["endTime"]),
      update_time: parse_timestamp(data["updateTime"]),
      batch_stats: parse_stats(data["batchStats"]),
      state: BatchState.from_string(data["state"] || "STATE_UNSPECIFIED"),
      priority: data["priority"]
    }
  end

  @doc """
  Checks if the batch is complete (either succeeded or failed).

  ## Examples

      EmbedContentBatch.is_complete?(batch)
      # => true
  """
  @spec is_complete?(t()) :: boolean()
  def is_complete?(%__MODULE__{state: :completed}), do: true
  def is_complete?(%__MODULE__{state: :failed}), do: true
  def is_complete?(%__MODULE__{state: :cancelled}), do: true
  def is_complete?(_), do: false

  @doc """
  Checks if the batch failed.

  ## Examples

      EmbedContentBatch.is_failed?(batch)
      # => false
  """
  @spec is_failed?(t()) :: boolean()
  def is_failed?(%__MODULE__{state: :failed}), do: true
  def is_failed?(_), do: false

  @doc """
  Checks if the batch is currently processing.

  ## Examples

      EmbedContentBatch.is_processing?(batch)
      # => true
  """
  @spec is_processing?(t()) :: boolean()
  def is_processing?(%__MODULE__{state: :processing}), do: true
  def is_processing?(%__MODULE__{state: :pending}), do: true
  def is_processing?(_), do: false

  @doc """
  Calculates the progress percentage of the batch.

  Returns nil if batch stats are not available.

  ## Examples

      EmbedContentBatch.progress_percentage(batch)
      # => 75.5
  """
  @spec progress_percentage(t()) :: float() | nil
  def progress_percentage(%__MODULE__{batch_stats: nil}), do: nil

  def progress_percentage(%__MODULE__{batch_stats: stats}) do
    EmbedContentBatchStats.progress_percentage(stats)
  end

  # Private helpers

  defp parse_input_config(nil), do: nil

  defp parse_input_config(%{"fileName" => file_name}) do
    InputEmbedContentConfig.new_from_file(file_name)
  end

  defp parse_input_config(%{"requests" => _} = data) do
    # For response parsing, we don't need full reconstruction
    # Just store the raw data
    struct(InputEmbedContentConfig, %{
      file_name: data["fileName"],
      requests: nil
    })
  end

  defp parse_input_config(_), do: nil

  defp parse_output(nil), do: nil

  defp parse_output(output_data) when is_map(output_data) do
    EmbedContentBatchOutput.from_api_response(output_data)
  end

  defp parse_stats(nil), do: nil

  defp parse_stats(stats_data) when is_map(stats_data) do
    EmbedContentBatchStats.from_api_response(stats_data)
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(timestamp_string) when is_binary(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end
end
