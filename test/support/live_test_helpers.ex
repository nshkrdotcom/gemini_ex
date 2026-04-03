defmodule Gemini.Test.LiveHelpers do
  @moduledoc """
  Helper functions for Live API integration tests.
  """

  import ExUnit.Assertions

  require Logger

  alias Gemini.Live.Session

  @quota_error_code 1011
  @transient_internal_error "Internal error encountered."
  @internal_error_table :gemini_live_internal_errors

  def connect_or_skip(session) do
    case Session.connect(session) do
      :ok ->
        :ok

      {:error, {:setup_failed, {:closed, @quota_error_code, reason}}} ->
        handle_1011_close(session, reason)

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

  defp handle_1011_close(session, reason) do
    case classify_1011_reason(reason) do
      :quota_exceeded ->
        Logger.warning("Live API quota exceeded: #{inspect(reason)}")
        :quota_exceeded

      :transient_backend_error ->
        handle_transient_backend_error(session, reason)

      :fatal ->
        flunk("Live API connection failed: {:closed, #{@quota_error_code}, #{inspect(reason)}}")
    end
  end

  defp handle_transient_backend_error(session, reason) do
    if repeated_transient_backend_error?(session, reason) do
      flunk(
        "Live API connection repeatedly failed with transient-looking 1011 for the same config: #{inspect(reason)}"
      )
    else
      Logger.warning("Live API transient backend error: #{inspect(reason)}")
      :transient_backend_error
    end
  end

  defp repeated_transient_backend_error?(session, reason) do
    table = ensure_internal_error_table()
    key = {session_config_fingerprint(session), String.downcase(reason)}

    :ets.update_counter(table, key, {2, 1}, {key, 0}) >= 2
  end

  defp ensure_internal_error_table do
    case :ets.whereis(@internal_error_table) do
      :undefined ->
        :ets.new(@internal_error_table, [:named_table, :public, :set])

      table ->
        table
    end
  rescue
    ArgumentError ->
      @internal_error_table
  end

  defp session_config_fingerprint(session) do
    state = :sys.get_state(session)
    config = state.config

    response_modalities =
      config.generation_config
      |> extract_response_modalities()

    {config.auth, config.model, response_modalities, config.api_version}
  rescue
    _ -> {:unknown_session, inspect(session)}
  end

  defp extract_response_modalities(nil), do: []

  defp extract_response_modalities(%{response_modalities: modalities}) when is_list(modalities),
    do: modalities

  defp extract_response_modalities(config) when is_map(config) do
    config[:response_modalities] || config["response_modalities"] || config["responseModalities"] ||
      []
  end

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
