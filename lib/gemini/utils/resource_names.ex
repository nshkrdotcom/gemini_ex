defmodule Gemini.Utils.ResourceNames do
  @moduledoc """
  Utilities for normalizing Google Cloud resource names for Gemini/Vertex AI.
  """

  alias Gemini.Config

  @doc """
  Normalize cached content names for the active auth strategy.

  - Gemini: ensures `cachedContents/` prefix.
  - Vertex: expands short names to `projects/{project}/locations/{location}/cachedContents/{id}`.
  """
  @spec normalize_cached_content_name(String.t(), keyword()) :: String.t()
  def normalize_cached_content_name(name, opts \\ []) do
    {auth_type, project_id, location} = resolve_auth(opts)

    cond do
      String.starts_with?(name, "projects/") ->
        name

      auth_type == :vertex_ai and String.starts_with?(name, "cachedContents/") ->
        "projects/#{project_id}/locations/#{location}/#{name}"

      auth_type == :vertex_ai and not String.contains?(name, "/") ->
        "projects/#{project_id}/locations/#{location}/cachedContents/#{name}"

      not String.starts_with?(name, "cachedContents/") ->
        "cachedContents/#{name}"

      true ->
        name
    end
  end

  @doc """
  Normalize a cache model name for the active auth strategy.

  - Gemini: ensures `models/` prefix.
  - Vertex: expands to `projects/{project}/locations/{location}/publishers/google/models/{model}`.
  """
  @spec normalize_cache_model_name(String.t(), keyword()) :: String.t()
  def normalize_cache_model_name(model, opts \\ []) do
    {auth_type, project_id, location} = resolve_auth(opts)

    cond do
      String.starts_with?(model, "projects/") ->
        model

      auth_type == :vertex_ai and String.starts_with?(model, "publishers/") ->
        "projects/#{project_id}/locations/#{location}/#{model}"

      auth_type == :vertex_ai and String.starts_with?(model, "models/") ->
        trimmed = String.replace_prefix(model, "models/", "")
        "projects/#{project_id}/locations/#{location}/publishers/google/models/#{trimmed}"

      auth_type == :vertex_ai ->
        "projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}"

      String.starts_with?(model, "models/") ->
        model

      true ->
        "models/#{model}"
    end
  end

  @doc """
  Build the base cachedContents collection path for the active auth strategy.
  """
  @spec cached_contents_path(keyword()) :: String.t()
  def cached_contents_path(opts \\ []) do
    {auth_type, project_id, location} = resolve_auth(opts)

    case auth_type do
      :vertex_ai -> "projects/#{project_id}/locations/#{location}/cachedContents"
      _ -> "cachedContents"
    end
  end

  defp resolve_auth(opts) do
    auth_type = Keyword.get(opts, :auth) || auth_from_config()
    project_id = Keyword.get(opts, :project_id) || credential(:project_id)
    location = Keyword.get(opts, :location) || credential(:location)

    if auth_type == :vertex_ai and (is_nil(project_id) or is_nil(location)) do
      raise ArgumentError,
            "project_id and location are required for Vertex AI cached content operations"
    end

    {auth_type, project_id, location}
  end

  defp auth_from_config do
    case Config.auth_config() do
      %{type: type} -> type
      _ -> :gemini
    end
  end

  defp credential(key) do
    case Config.auth_config() do
      %{credentials: creds} when is_map(creds) -> Map.get(creds, key)
      _ -> nil
    end
  end
end
