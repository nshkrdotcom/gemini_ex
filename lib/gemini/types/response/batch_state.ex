defmodule Gemini.Types.Response.BatchState do
  @moduledoc """
  Represents the state of an async batch embedding job.

  ## States

  - `:unspecified` - State not specified
  - `:pending` - Job queued, not yet processing
  - `:processing` - Currently being processed
  - `:completed` - Successfully completed
  - `:failed` - Processing failed
  - `:cancelled` - Job was cancelled

  ## Examples

      # Convert from API response
      BatchState.from_string("PROCESSING")
      # => :processing

      # Convert to API format
      BatchState.to_string(:completed)
      # => "COMPLETED"
  """

  @type t :: :unspecified | :pending | :processing | :completed | :failed | :cancelled

  @doc """
  Converts a string state from the API to an atom.

  Handles both uppercase API format (e.g., "PENDING") and lowercase format.
  Unknown states default to `:unspecified`.

  ## Parameters

  - `state_string`: The state string from the API

  ## Returns

  The corresponding atom state

  ## Examples

      BatchState.from_string("PROCESSING")
      # => :processing

      BatchState.from_string("pending")
      # => :pending

      BatchState.from_string("UNKNOWN")
      # => :unspecified
  """
  @spec from_string(String.t()) :: t()
  def from_string(state_string) when is_binary(state_string) do
    case String.upcase(state_string) do
      "STATE_UNSPECIFIED" -> :unspecified
      "PENDING" -> :pending
      "PROCESSING" -> :processing
      "COMPLETED" -> :completed
      "FAILED" -> :failed
      "CANCELLED" -> :cancelled
      _ -> :unspecified
    end
  end

  @doc """
  Converts an atom state to the API string format.

  ## Parameters

  - `state`: The state atom

  ## Returns

  The API string representation

  ## Examples

      BatchState.to_string(:processing)
      # => "PROCESSING"

      BatchState.to_string(:completed)
      # => "COMPLETED"
  """
  @spec to_string(t()) :: String.t()
  def to_string(state) when is_atom(state) do
    case state do
      :unspecified -> "STATE_UNSPECIFIED"
      :pending -> "PENDING"
      :processing -> "PROCESSING"
      :completed -> "COMPLETED"
      :failed -> "FAILED"
      :cancelled -> "CANCELLED"
    end
  end
end
