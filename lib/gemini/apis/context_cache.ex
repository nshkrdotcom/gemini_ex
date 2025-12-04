defmodule Gemini.APIs.ContextCache do
  @moduledoc """
  Context caching API for improved performance with long context.

  Context caching allows you to cache large amounts of content (code, documents)
  for reuse across multiple requests, reducing latency and cost.

  ## Usage

      # Create a cached context
      {:ok, cache} = Gemini.APIs.ContextCache.create(
        [%Gemini.Types.Content{role: "user", parts: [%{text: large_content}]}],
        display_name: "My Codebase",
        model: "gemini-2.0-flash"
      )

      # Use cached context in requests
      {:ok, response} = Gemini.generate("Analyze this code",
        cached_content: cache.name
      )

      # Delete when done
      :ok = Gemini.APIs.ContextCache.delete(cache.name)

  ## API Endpoints

  - `POST /cachedContents` - Create cached content
  - `GET /cachedContents` - List cached contents
  - `GET /cachedContents/{name}` - Get specific cache
  - `PATCH /cachedContents/{name}` - Update cache TTL
  - `DELETE /cachedContents/{name}` - Delete cache
  """

  alias Gemini.Client.HTTP
  alias Gemini.Types.Content

  @type cache_opts :: [
          display_name: String.t(),
          model: String.t(),
          ttl: non_neg_integer(),
          expire_time: DateTime.t()
        ]

  @type cached_content :: %{
          name: String.t(),
          display_name: String.t() | nil,
          model: String.t(),
          create_time: String.t() | nil,
          update_time: String.t() | nil,
          expire_time: String.t() | nil,
          usage_metadata: map() | nil
        }

  @doc """
  Create a new cached content.

  ## Parameters

  - `contents`: List of Content structs to cache
  - `opts`: Options including:
    - `:display_name` - Human-readable name (required)
    - `:model` - Model to use (default: default model)
    - `:ttl` - Time to live in seconds (default: 3600)
    - `:expire_time` - Specific expiration DateTime

  ## Returns

  - `{:ok, cached_content}` - Created cache metadata
  - `{:error, reason}` - Failed to create cache

  ## Examples

      {:ok, cache} = ContextCache.create(
        [Content.text("Large document content...")],
        display_name: "My Document",
        model: "gemini-2.0-flash",
        ttl: 7200
      )
  """
  @spec create([Content.t()] | [map()], cache_opts()) ::
          {:ok, cached_content()} | {:error, term()}
  def create(contents, opts \\ []) when is_list(contents) do
    display_name =
      Keyword.get(opts, :display_name) ||
        raise ArgumentError, "display_name is required for cached content"

    model = Keyword.get(opts, :model, Gemini.Config.default_model())
    full_model_name = "models/#{model}"

    # Build TTL specification
    ttl_spec = build_ttl_spec(opts)

    # Format contents for API
    formatted_contents = format_contents(contents)

    request_body =
      %{
        model: full_model_name,
        displayName: display_name,
        contents: formatted_contents
      }
      |> Map.merge(ttl_spec)

    case HTTP.post("cachedContents", request_body, opts) do
      {:ok, response} ->
        {:ok, normalize_cache_response(response)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  List all cached contents.

  ## Parameters

  - `opts`: Options including:
    - `:page_size` - Number of results per page
    - `:page_token` - Pagination token

  ## Returns

  - `{:ok, %{cached_contents: [cached_content()], next_page_token: String.t() | nil}}`
  - `{:error, reason}`
  """
  @spec list(keyword()) :: {:ok, map()} | {:error, term()}
  def list(opts \\ []) do
    query_params = []

    query_params =
      if opts[:page_size], do: [{:pageSize, opts[:page_size]} | query_params], else: query_params

    query_params =
      if opts[:page_token],
        do: [{:pageToken, opts[:page_token]} | query_params],
        else: query_params

    path =
      if query_params == [] do
        "cachedContents"
      else
        query_string = URI.encode_query(query_params)
        "cachedContents?#{query_string}"
      end

    case HTTP.get(path, opts) do
      {:ok, response} ->
        cached_contents =
          response
          |> Map.get("cachedContents", [])
          |> Enum.map(&normalize_cache_response/1)

        result = %{
          cached_contents: cached_contents,
          next_page_token: Map.get(response, "nextPageToken")
        }

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get a specific cached content by name.

  ## Parameters

  - `name`: Cache name (format: "cachedContents/{id}")
  - `opts`: Request options

  ## Returns

  - `{:ok, cached_content}` - Cache metadata
  - `{:error, reason}` - Failed to get cache
  """
  @spec get(String.t(), keyword()) :: {:ok, cached_content()} | {:error, term()}
  def get(name, opts \\ []) when is_binary(name) do
    case HTTP.get(name, opts) do
      {:ok, response} ->
        {:ok, normalize_cache_response(response)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update cache TTL.

  ## Parameters

  - `name`: Cache name
  - `opts`: Options including:
    - `:ttl` - New TTL in seconds
    - `:expire_time` - New expiration DateTime

  ## Returns

  - `{:ok, cached_content}` - Updated cache metadata
  - `{:error, reason}` - Failed to update
  """
  @spec update(String.t(), keyword()) :: {:ok, cached_content()} | {:error, term()}
  def update(name, opts \\ []) when is_binary(name) do
    ttl_spec = build_ttl_spec(opts)

    if map_size(ttl_spec) == 0 do
      {:error, "Must specify either :ttl or :expire_time"}
    else
      # PATCH request
      case HTTP.patch(name, ttl_spec, opts) do
        {:ok, response} ->
          {:ok, normalize_cache_response(response)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Delete a cached content.

  ## Parameters

  - `name`: Cache name to delete
  - `opts`: Request options

  ## Returns

  - `:ok` - Successfully deleted
  - `{:error, reason}` - Failed to delete
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) when is_binary(name) do
    case HTTP.delete(name, opts) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp build_ttl_spec(opts) do
    cond do
      opts[:expire_time] ->
        expire_str = DateTime.to_iso8601(opts[:expire_time])
        %{expireTime: expire_str}

      opts[:ttl] ->
        %{ttl: "#{opts[:ttl]}s"}

      true ->
        # Default 1 hour TTL
        %{ttl: "3600s"}
    end
  end

  defp format_contents(contents) do
    Enum.map(contents, fn
      %Content{role: role, parts: parts} ->
        %{
          role: role,
          parts: format_parts(parts)
        }

      %{role: role, parts: parts} ->
        %{
          role: role,
          parts: format_parts(parts)
        }

      %{text: text} ->
        %{
          role: "user",
          parts: [%{text: text}]
        }

      text when is_binary(text) ->
        %{
          role: "user",
          parts: [%{text: text}]
        }
    end)
  end

  defp format_parts(parts) when is_list(parts) do
    Enum.map(parts, fn
      %Gemini.Types.Part{text: text} when is_binary(text) ->
        %{text: text}

      %{text: text} when is_binary(text) ->
        %{text: text}

      %Gemini.Types.Part{inline_data: %{data: data, mime_type: mime}} ->
        %{inlineData: %{data: data, mimeType: mime}}

      %{inline_data: %{data: data, mime_type: mime}} ->
        %{inlineData: %{data: data, mimeType: mime}}

      other ->
        other
    end)
  end

  defp normalize_cache_response(response) when is_map(response) do
    %{
      name: Map.get(response, "name"),
      display_name: Map.get(response, "displayName"),
      model: Map.get(response, "model"),
      create_time: Map.get(response, "createTime"),
      update_time: Map.get(response, "updateTime"),
      expire_time: Map.get(response, "expireTime"),
      usage_metadata: normalize_usage_metadata(Map.get(response, "usageMetadata"))
    }
  end

  defp normalize_usage_metadata(nil), do: nil

  defp normalize_usage_metadata(metadata) when is_map(metadata) do
    %{
      total_token_count: Map.get(metadata, "totalTokenCount"),
      cached_content_token_count: Map.get(metadata, "cachedContentTokenCount")
    }
  end
end
