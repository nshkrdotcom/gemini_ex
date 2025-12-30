defmodule Gemini.Utils.MapHelpers do
  @moduledoc """
  Shared helper functions for building maps with optional values.

  These helpers are used throughout the codebase to conditionally add
  key-value pairs to maps, skipping nil values.
  """

  @doc """
  Conditionally puts a value into a map if the value is not nil.

  ## Examples

      iex> MapHelpers.maybe_put(%{a: 1}, :b, 2)
      %{a: 1, b: 2}

      iex> MapHelpers.maybe_put(%{a: 1}, :b, nil)
      %{a: 1}

  """
  @spec maybe_put(map(), any(), any()) :: map()
  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  @doc """
  Conditionally puts a value into a map if the value is not nil or empty string.

  Useful when building credential maps where empty strings should be treated as missing.

  ## Examples

      iex> MapHelpers.maybe_put_non_empty(%{a: 1}, :b, "value")
      %{a: 1, b: "value"}

      iex> MapHelpers.maybe_put_non_empty(%{a: 1}, :b, "")
      %{a: 1}

      iex> MapHelpers.maybe_put_non_empty(%{a: 1}, :b, nil)
      %{a: 1}

  """
  @spec maybe_put_non_empty(map(), any(), any()) :: map()
  def maybe_put_non_empty(map, _key, nil), do: map
  def maybe_put_non_empty(map, _key, ""), do: map
  def maybe_put_non_empty(map, key, value), do: Map.put(map, key, value)

  @doc """
  Conditionally puts a value into a map if the value is not nil or zero.

  Useful when building request maps where zero values should be omitted.

  ## Examples

      iex> MapHelpers.maybe_put_non_zero(%{a: 1}, :b, 5)
      %{a: 1, b: 5}

      iex> MapHelpers.maybe_put_non_zero(%{a: 1}, :b, 0)
      %{a: 1}

      iex> MapHelpers.maybe_put_non_zero(%{a: 1}, :b, nil)
      %{a: 1}

  """
  @spec maybe_put_non_zero(map(), any(), any()) :: map()
  def maybe_put_non_zero(map, _key, nil), do: map
  def maybe_put_non_zero(map, _key, 0), do: map
  def maybe_put_non_zero(map, key, value), do: Map.put(map, key, value)

  @doc """
  Builds a path with pagination query parameters.

  Takes a base path and options keyword list, extracting standard pagination
  params (:page_size, :page_token, :filter) and building the full path.

  ## Examples

      iex> MapHelpers.build_paginated_path("batches", [page_size: 10])
      "batches?pageSize=10"

      iex> MapHelpers.build_paginated_path("files", [])
      "files"

      iex> MapHelpers.build_paginated_path("operations", [page_size: 20, page_token: "abc", filter: "state=ACTIVE"])
      "operations?pageSize=20&pageToken=abc&filter=state%3DACTIVE"

  """
  @spec build_paginated_path(String.t(), keyword()) :: String.t()
  def build_paginated_path(base_path, opts) do
    query_params =
      []
      |> add_query_param("pageSize", Keyword.get(opts, :page_size))
      |> add_query_param("pageToken", Keyword.get(opts, :page_token))
      |> add_query_param("filter", Keyword.get(opts, :filter))

    case query_params do
      [] -> base_path
      params -> "#{base_path}?#{URI.encode_query(params)}"
    end
  end

  @doc """
  Adds a query parameter to a list if the value is not nil.

  ## Examples

      iex> MapHelpers.add_query_param([], "pageSize", 10)
      [{"pageSize", 10}]

      iex> MapHelpers.add_query_param([{"a", 1}], "b", nil)
      [{"a", 1}]

  """
  @spec add_query_param(list(), String.t(), any()) :: list()
  def add_query_param(params, _key, nil), do: params
  def add_query_param(params, key, value), do: [{key, value} | params]
end
