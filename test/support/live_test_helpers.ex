defmodule Gemini.Test.LiveHelpers do
  @moduledoc """
  Helper functions for Live API integration tests.
  """

  import ExUnit.Assertions

  require Logger

  alias Gemini.Live.Session

  @quota_error_code 1011
  @transient_internal_error "Internal error encountered."

  def connect_or_skip(session) do
    case Session.connect(session) do
      :ok ->
        :ok

      {:error, {:setup_failed, {:closed, @quota_error_code, reason}}} ->
        case classify_1011_reason(reason) do
          :quota_exceeded ->
            Logger.warning("Live API quota exceeded: #{inspect(reason)}")
            :quota_exceeded

          :transient_backend_error ->
            Logger.warning("Live API transient backend error: #{inspect(reason)}")
            :transient_backend_error

          :fatal ->
            flunk(
              "Live API connection failed: {:closed, #{@quota_error_code}, #{inspect(reason)}}"
            )
        end

      {:error, reason} ->
        flunk("Live API connection failed: #{inspect(reason)}")
    end
  end

  @spec skippable_websocket_close?(term()) :: :quota_exceeded | :transient_backend_error | false
  def skippable_websocket_close?({:closed, @quota_error_code, reason}) do
    case classify_1011_reason(reason) do
      :fatal -> false
      other -> other
    end
  end

  def skippable_websocket_close?(_), do: false

  defp classify_1011_reason(reason) when is_binary(reason) do
    normalized = String.downcase(reason)

    cond do
      String.contains?(normalized, "quota") or
          String.contains?(normalized, "resource exhausted") ->
        :quota_exceeded

      normalized == String.downcase(@transient_internal_error) or
          String.contains?(normalized, "internal error") ->
        :transient_backend_error

      true ->
        :fatal
    end
  end

  defp classify_1011_reason(_reason), do: :fatal
end
