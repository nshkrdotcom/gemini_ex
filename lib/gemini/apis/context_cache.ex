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
  alias Gemini.Types.MediaResolution
  alias Gemini.Types.Part
  alias Gemini.Types.ToolSerialization
  alias Gemini.Types.CachedContentUsageMetadata
  alias Gemini.Utils.ResourceNames

  require Logger

  @type cache_opts :: [
          display_name: String.t(),
          model: String.t(),
          ttl: non_neg_integer(),
          expire_time: DateTime.t(),
          system_instruction: String.t() | Content.t(),
          tools: [Altar.ADM.FunctionDeclaration.t()],
          tool_config: Altar.ADM.ToolConfig.t(),
          kms_key_name: String.t(),
          auth: :gemini | :vertex_ai,
          project_id: String.t(),
          location: String.t()
        ]

  @type cached_content :: %{
          name: String.t(),
          display_name: String.t() | nil,
          model: String.t(),
          create_time: String.t() | nil,
          update_time: String.t() | nil,
          expire_time: String.t() | nil,
          usage_metadata: CachedContentUsageMetadata.t() | nil
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
  @spec create([Content.t()] | [map()] | String.t(), cache_opts()) ::
          {:ok, cached_content()} | {:error, term()}
  def create(contents, opts \\ [])

  def create(contents, opts) when is_binary(contents) do
    create([Content.text(contents)], opts)
  end

  def create(contents, opts) when is_list(contents) do
    display_name =
      Keyword.get(opts, :display_name) ||
        raise ArgumentError, "display_name is required for cached content"

    model = Keyword.get(opts, :model, Gemini.Config.default_model())
    full_model_name = ResourceNames.normalize_cache_model_name(model, opts)
    validate_cache_model(full_model_name)

    # Build TTL specification
    ttl_spec = build_ttl_spec(opts)

    # Format contents for API
    formatted_contents = format_contents(contents)

    request_body =
      base_create_body(full_model_name, display_name, formatted_contents, ttl_spec, opts)

    path = ResourceNames.cached_contents_path(opts)

    case HTTP.post(path, request_body, opts) do
      {:ok, response} ->
        {:ok, normalize_cache_response(response)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def __test_build_create_body__(contents, opts) do
    display_name =
      Keyword.get(opts, :display_name) ||
        raise ArgumentError, "display_name is required for cached content"

    model = Keyword.get(opts, :model, Gemini.Config.default_model())
    full_model_name = ResourceNames.normalize_cache_model_name(model, opts)
    ttl_spec = build_ttl_spec(opts)
    formatted_contents = format_contents(contents)

    request_body =
      base_create_body(full_model_name, display_name, formatted_contents, ttl_spec, opts)

    path = ResourceNames.cached_contents_path(opts)

    %{body: request_body, path: path}
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

    base_path = ResourceNames.cached_contents_path(opts)

    path =
      if query_params == [] do
        base_path
      else
        query_string = URI.encode_query(query_params)
        "#{base_path}?#{query_string}"
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
    normalized_name = ResourceNames.normalize_cached_content_name(name, opts)

    case HTTP.get(normalized_name, opts) do
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
    normalized_name = ResourceNames.normalize_cached_content_name(name, opts)

    if map_size(ttl_spec) == 0 do
      {:error, "Must specify either :ttl or :expire_time"}
    else
      # PATCH request
      case HTTP.patch(normalized_name, ttl_spec, opts) do
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
    normalized_name = ResourceNames.normalize_cached_content_name(name, opts)

    case HTTP.delete(normalized_name, opts) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp base_create_body(full_model_name, display_name, formatted_contents, ttl_spec, opts) do
    %{
      model: full_model_name,
      displayName: display_name,
      contents: formatted_contents
    }
    |> Map.merge(ttl_spec)
    |> maybe_add_system_instruction(opts)
    |> maybe_add_tools(opts)
    |> maybe_add_tool_config(opts)
    |> maybe_add_kms_key(opts)
  end

  defp build_ttl_spec(opts) do
    cond do
      opts[:expire_time] ->
        expire_str = DateTime.to_iso8601(opts[:expire_time])
        %{expireTime: expire_str}

      opts[:ttl] ->
        %{ttl: "#{opts[:ttl]}s"}

      true ->
        default_ttl = Keyword.get(opts, :default_ttl_seconds, default_ttl_seconds())
        %{ttl: "#{default_ttl}s"}
    end
  end

  defp maybe_add_system_instruction(map, opts) do
    case Keyword.get(opts, :system_instruction) do
      nil ->
        map

      instruction when is_binary(instruction) ->
        Map.put(map, :systemInstruction, %{role: "user", parts: [%{text: instruction}]})

      %Content{} = content ->
        Map.put(map, :systemInstruction, format_content(content))

      %{} = content ->
        Map.put(map, :systemInstruction, format_content(content))
    end
  end

  defp default_ttl_seconds do
    context_cache_config = Application.get_env(:gemini_ex, :context_cache, [])
    Keyword.get(context_cache_config, :default_ttl_seconds, 3_600)
  end

  defp maybe_add_tools(map, opts) do
    case Keyword.get(opts, :tools) do
      tools when is_list(tools) and length(tools) > 0 ->
        Map.put(map, :tools, ToolSerialization.to_api_tool_list(tools))

      _ ->
        map
    end
  end

  defp maybe_add_tool_config(map, opts) do
    case Keyword.get(opts, :tool_config) do
      %Altar.ADM.ToolConfig{} = tool_config ->
        Map.put(map, :toolConfig, ToolSerialization.to_api_tool_config(tool_config))

      _ ->
        map
    end
  end

  defp maybe_add_kms_key(map, opts) do
    case Keyword.get(opts, :kms_key_name) do
      nil ->
        map

      kms_key ->
        auth_type = Keyword.get(opts, :auth) || auth_type_from_config()

        if auth_type == :vertex_ai do
          Map.put(map, :encryptionSpec, %{kmsKeyName: kms_key})
        else
          raise ArgumentError, "kms_key_name is only supported with Vertex AI authentication"
        end
    end
  end

  defp format_contents(contents) do
    Enum.map(contents, &format_content/1)
  end

  defp format_content(%Content{role: role, parts: parts}) do
    %{role: role, parts: format_parts(parts)}
  end

  defp format_content(%{role: role, parts: parts}) do
    %{role: role, parts: format_parts(parts)}
  end

  defp format_content(%{parts: parts} = map) do
    role =
      Map.get(map, :role) ||
        Map.get(map, "role") ||
        "user"

    %{role: role, parts: format_parts(parts)}
  end

  defp format_content(%{text: text} = map) when is_binary(text) do
    role = Map.get(map, :role, "user")
    parts = Map.get(map, :parts, [%{text: text}])
    %{role: role, parts: format_parts(parts)}
  end

  defp format_content(text) when is_binary(text) do
    %{role: "user", parts: [%{text: text}]}
  end

  defp format_parts(parts) when is_list(parts) do
    Enum.map(parts, &format_part/1)
  end

  defp format_part(%Part{text: text} = part) when is_binary(text) do
    %{text: text}
    |> maybe_put_thought_signature(part)
    |> maybe_put_media_resolution(part)
  end

  defp format_part(%{text: text} = part) when is_binary(text) do
    %{text: text}
    |> maybe_put_thought_signature(part)
  end

  defp format_part(%Part{inline_data: %{data: data, mime_type: mime}} = part) do
    %{inlineData: %{data: data, mimeType: mime}}
    |> maybe_put_media_resolution(part)
  end

  defp format_part(%{inline_data: %{data: data, mime_type: mime}} = part) do
    %{inlineData: %{data: data, mimeType: mime}}
    |> maybe_put_media_resolution(part)
  end

  defp format_part(%Part{function_call: %Altar.ADM.FunctionCall{name: name, args: args}} = part) do
    %{functionCall: %{name: name, args: args || %{}}}
    |> maybe_put_thought_signature(part)
  end

  defp format_part(%{function_call: %{name: name} = call} = part) when is_binary(name) do
    args = Map.get(call, :args, %{}) || %{}

    %{functionCall: %{name: name, args: args}}
    |> maybe_put_thought_signature(part)
  end

  defp format_part(%{function_call: %{"name" => name} = call} = part) when is_binary(name) do
    args = Map.get(call, "args", %{}) || %{}

    %{functionCall: %{name: name, args: args}}
    |> maybe_put_thought_signature(part)
  end

  defp format_part(%{file_data: %{file_uri: uri, mime_type: mime}}) when is_binary(uri) do
    %{fileData: %{fileUri: uri, mimeType: mime}}
  end

  defp format_part(%{file_data: %{file_uri: uri}}) when is_binary(uri) do
    %{fileData: %{fileUri: uri}}
  end

  defp format_part(%{file_uri: uri}) when is_binary(uri) do
    %{fileData: %{fileUri: uri}}
  end

  defp format_part(%{"fileData" => _} = part), do: part
  defp format_part(%{"functionResponse" => _} = part), do: part
  defp format_part(%{"functionCall" => _} = part), do: part

  defp format_part(%{parts: _} = part), do: part
  defp format_part(other), do: other

  defp maybe_put_thought_signature(map, %{thought_signature: sig}) when is_binary(sig) do
    Map.put(map, :thoughtSignature, sig)
  end

  defp maybe_put_thought_signature(map, %{"thoughtSignature" => sig}) when is_binary(sig) do
    Map.put(map, :thoughtSignature, sig)
  end

  defp maybe_put_thought_signature(map, _), do: map

  defp maybe_put_media_resolution(map, %{media_resolution: resolution}) do
    case media_resolution_to_api(resolution) do
      nil -> map
      api_value -> Map.put(map, :mediaResolution, api_value)
    end
  end

  defp maybe_put_media_resolution(map, _), do: map

  defp media_resolution_to_api(%Part.MediaResolution{level: level}),
    do: media_resolution_to_api(level)

  defp media_resolution_to_api(atom) when is_atom(atom), do: MediaResolution.to_api(atom)

  defp media_resolution_to_api(value) when is_binary(value) do
    value
    |> MediaResolution.from_api()
    |> MediaResolution.to_api()
  end

  defp media_resolution_to_api(_), do: nil

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
    %CachedContentUsageMetadata{
      total_token_count: Map.get(metadata, "totalTokenCount"),
      cached_content_token_count: Map.get(metadata, "cachedContentTokenCount"),
      audio_duration_seconds: Map.get(metadata, "audioDurationSeconds"),
      image_count: Map.get(metadata, "imageCount"),
      text_count: Map.get(metadata, "textCount"),
      video_duration_seconds: Map.get(metadata, "videoDurationSeconds")
    }
  end

  @valid_cache_models [
    "gemini-2.0-flash-001",
    "gemini-2.0-flash-lite-001",
    "gemini-2.5-flash",
    "gemini-2.5-pro",
    "gemini-3-pro-preview"
  ]

  defp validate_cache_model(model) do
    base_model =
      model
      |> String.split("/")
      |> List.last()

    unless Enum.any?(@valid_cache_models, &String.starts_with?(base_model, &1)) do
      Logger.warning(
        "Model #{model} may not support explicit caching. " <>
          "Use models with explicit version suffixes like 'gemini-2.5-flash'"
      )
    end

    :ok
  end

  defp auth_type_from_config do
    case Gemini.Config.auth_config() do
      %{type: type} -> type
      _ -> :gemini
    end
  end
end
