defmodule Gemini.Test.AuthHelpers do
  @moduledoc """
  Shared auth detection for tests to avoid duplicated environment checks.
  """

  alias Gemini.Config

  @type auth_state :: {:ok, :gemini | :vertex_ai, map()} | :missing

  @doc """
  Detect configured auth using Config.auth_config/0.

  Returns:
    - {:ok, :gemini, %{api_key: key}} when a Gemini API key is configured
    - {:ok, :vertex_ai, creds} when Vertex credentials include project_id and location plus token/key
    - :missing otherwise
  """
  @spec detect_auth() :: auth_state()
  def detect_auth do
    case Config.auth_config() do
      %{type: :gemini, credentials: %{api_key: key}} when is_binary(key) and key != "" ->
        {:ok, :gemini, %{api_key: key}}

      %{type: :vertex_ai, credentials: creds} ->
        vertex_auth_state(creds)

      _ ->
        :missing
    end
  end

  @doc """
  Detect configured auth for a specific strategy, independent of default priority.

  Useful in live tests when both Gemini and Vertex credentials are present and
  tests need to validate each strategy explicitly.
  """
  @spec detect_auth(:gemini | :vertex_ai) :: auth_state()
  def detect_auth(:gemini) do
    case Config.get_auth_config(:gemini) do
      %{api_key: key} when is_binary(key) and key != "" ->
        {:ok, :gemini, %{api_key: key}}

      _ ->
        :missing
    end
  end

  def detect_auth(:vertex_ai) do
    Config.get_auth_config(:vertex_ai)
    |> vertex_auth_state()
  end

  defp vertex_auth_state(creds) do
    if valid_vertex_creds?(creds) do
      {:ok, :vertex_ai, creds}
    else
      :missing
    end
  end

  defp valid_vertex_creds?(creds) do
    project = Map.get(creds, :project_id)
    location = Map.get(creds, :location)

    token =
      Map.get(creds, :access_token) ||
        Map.get(creds, :service_account_key) ||
        Map.get(creds, :service_account_data)

    project && location && token
  end
end
