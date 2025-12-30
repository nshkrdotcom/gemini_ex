defmodule Gemini.Utils.PollingHelpers do
  @moduledoc """
  Shared helper functions for polling operations.

  These helpers are used by API modules that need to poll for
  operation completion (batches, tunings, documents, etc.).
  """

  @doc """
  Check if a polling operation has timed out.

  ## Parameters

  - `start_time` - The start time in monotonic milliseconds (from `System.monotonic_time(:millisecond)`)
  - `timeout` - The timeout duration in milliseconds

  ## Examples

      iex> start = System.monotonic_time(:millisecond)
      iex> PollingHelpers.timed_out?(start, 5000)
      false

      iex> start = System.monotonic_time(:millisecond) - 6000
      iex> PollingHelpers.timed_out?(start, 5000)
      true

  """
  @spec timed_out?(integer(), integer()) :: boolean()
  def timed_out?(start_time, timeout) do
    System.monotonic_time(:millisecond) - start_time >= timeout
  end

  @doc """
  Conditionally adds a key-value pair to a keyword list if value is not nil.

  Used for building optional query parameters.

  ## Examples

      iex> PollingHelpers.maybe_add([], :page_token, "abc123")
      [page_token: "abc123"]

      iex> PollingHelpers.maybe_add([], :page_token, nil)
      []

  """
  @spec maybe_add(keyword(), atom(), any()) :: keyword()
  def maybe_add(params, _key, nil), do: params
  def maybe_add(params, key, value), do: [{key, value} | params]
end
