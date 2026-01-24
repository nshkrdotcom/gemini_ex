defmodule Gemini.Test.LiveHelpers do
  @moduledoc """
  Helper functions for Live API integration tests.
  """

  import ExUnit.Assertions

  require Logger

  alias Gemini.Live.Session

  @quota_error_code 1011

  def connect_or_skip(session) do
    case Session.connect(session) do
      :ok ->
        :ok

      {:error, {:setup_failed, {:closed, @quota_error_code, reason}}} ->
        Logger.warning("Live API quota exceeded: #{inspect(reason)}")
        :quota_exceeded

      {:error, reason} ->
        flunk("Live API connection failed: #{inspect(reason)}")
    end
  end
end
