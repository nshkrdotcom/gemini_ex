defmodule Gemini.APIs.Interactions do
  @moduledoc """
  Interactions API (experimental).

  Interactions are stateful, server-managed conversations that support:
  - CRUD lifecycle (create/get/cancel/delete)
  - background execution (`background: true`)
  - SSE streaming with resumable `event_id` tokens (`last_event_id` on `get`)

  Streaming is enabled via `stream: true` (POST body on create, query param on get) and must
  **not** rely on `?alt=sse`.
  """

  alias Gemini.Auth
  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Client.HTTPStreaming
  alias Gemini.Config
  alias Gemini.Error

  alias Gemini.Types.Interactions.{
    AgentConfig,
    Events,
    GenerationConfig,
    Input,
    Interaction,
    Tool
  }

  @type auth_strategy :: :gemini | :vertex_ai
  @type result(t) :: {:ok, t} | {:error, Error.t() | term()}

  @default_poll_interval_ms 2_000
  @default_wait_timeout_ms 300_000

  @doc """
  Create a new interaction.

  ## Required options

  Provide either:
  - `model: "..."` (model-based), or
  - `agent: "..."` (agent-based)

  ## Streaming

  - `stream: true` returns `{:ok, stream}` where `stream` yields `InteractionSSEEvent` variants.
  - Stream ends when the server sends `[DONE]` (independent of `interaction.complete`).
  """
  @spec create(Input.t(), keyword()) ::
          result(Interaction.t() | Enumerable.t())
  def create(input, opts \\ []) do
    auth = Keyword.get(opts, :auth, Config.current_api_type())
    api_version = Keyword.get(opts, :api_version, default_api_version(auth))
    stream? = Keyword.get(opts, :stream, false)

    with :ok <- validate_create_opts(opts),
         {:ok, headers, credentials} <- auth_headers_and_credentials(auth, opts),
         {:ok, url} <- build_create_url(auth, credentials, api_version),
         {:ok, body} <- build_create_body(input, opts, stream?) do
      if stream? do
        {:ok, stream_request(:post, url, headers, body, opts)}
      else
        request_json(:post, url, headers, body, opts, &Interaction.from_api/1)
      end
    end
  end

  @doc """
  Get an interaction by id.

  If `stream: true`, returns an SSE stream. Resumption uses `last_event_id`.
  """
  @spec get(String.t(), keyword()) ::
          result(Interaction.t() | Enumerable.t())
  def get(id, opts \\ []) when is_binary(id) do
    auth = Keyword.get(opts, :auth, Config.current_api_type())
    api_version = Keyword.get(opts, :api_version, default_api_version(auth))
    stream? = Keyword.get(opts, :stream, false)
    last_event_id = Keyword.get(opts, :last_event_id)

    with :ok <- validate_get_opts(stream?, last_event_id),
         {:ok, headers, credentials} <- auth_headers_and_credentials(auth, opts),
         {:ok, url} <- build_get_url(auth, credentials, api_version, id, stream?, last_event_id) do
      if stream? do
        {:ok, stream_request(:get, url, headers, nil, opts)}
      else
        request_json(:get, url, headers, nil, opts, &Interaction.from_api/1)
      end
    end
  end

  @doc """
  Cancel a background interaction by id.
  """
  @spec cancel(String.t(), keyword()) :: result(Interaction.t())
  def cancel(id, opts \\ []) when is_binary(id) do
    auth = Keyword.get(opts, :auth, Config.current_api_type())
    api_version = Keyword.get(opts, :api_version, default_api_version(auth))

    with {:ok, headers, credentials} <- auth_headers_and_credentials(auth, opts),
         {:ok, url} <- build_cancel_url(auth, credentials, api_version, id) do
      request_json(:post, url, headers, %{}, opts, &Interaction.from_api/1)
    end
  end

  @doc """
  Delete an interaction by id.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t() | term()}
  def delete(id, opts \\ []) when is_binary(id) do
    auth = Keyword.get(opts, :auth, Config.current_api_type())
    api_version = Keyword.get(opts, :api_version, default_api_version(auth))

    with {:ok, headers, credentials} <- auth_headers_and_credentials(auth, opts),
         {:ok, url} <- build_delete_url(auth, credentials, api_version, id),
         {:ok, _} <- request_json(:delete, url, headers, nil, opts, fn _ -> :ok end) do
      :ok
    end
  end

  @doc """
  Poll an interaction until it reaches a terminal state.

  Options:
  - `:poll_interval_ms` (default: #{@default_poll_interval_ms})
  - `:timeout_ms` (default: #{@default_wait_timeout_ms})
  - `:on_status` optional callback `fn(Interaction.t()) -> any()`
  - plus all `get/2` options (auth, api_version, timeout, etc.)
  """
  @spec wait_for_completion(String.t(), keyword()) :: result(Interaction.t())
  def wait_for_completion(id, opts \\ []) when is_binary(id) do
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_wait_timeout_ms)
    on_status = Keyword.get(opts, :on_status)

    start_ms = System.monotonic_time(:millisecond)
    do_wait_for_completion(id, opts, poll_interval_ms, timeout_ms, start_ms, on_status)
  end

  @doc false
  @spec build_create_url(auth_strategy(), map(), String.t()) :: result(String.t())
  def build_create_url(auth, credentials, api_version) when is_binary(api_version) do
    with {:ok, base_url} <- base_url_root(auth, credentials),
         {:ok, path} <- create_path(auth, credentials, api_version) do
      {:ok, base_url <> path}
    end
  end

  @doc false
  @spec build_get_url(auth_strategy(), map(), String.t(), String.t(), boolean(), String.t() | nil) ::
          result(String.t())
  def build_get_url(auth, credentials, api_version, id, stream?, last_event_id)
      when is_binary(api_version) and is_binary(id) do
    with {:ok, base_url} <- base_url_root(auth, credentials),
         {:ok, path} <- get_path(auth, credentials, api_version, id, stream?, last_event_id) do
      {:ok, base_url <> path}
    end
  end

  @doc false
  @spec build_cancel_url(auth_strategy(), map(), String.t(), String.t()) :: result(String.t())
  def build_cancel_url(auth, credentials, api_version, id)
      when is_binary(api_version) and is_binary(id) do
    with {:ok, base_url} <- base_url_root(auth, credentials),
         {:ok, path} <- cancel_path(auth, credentials, api_version, id) do
      {:ok, base_url <> path}
    end
  end

  @doc false
  @spec build_delete_url(auth_strategy(), map(), String.t(), String.t()) :: result(String.t())
  def build_delete_url(auth, credentials, api_version, id)
      when is_binary(api_version) and is_binary(id) do
    with {:ok, base_url} <- base_url_root(auth, credentials),
         {:ok, path} <- delete_path(auth, credentials, api_version, id) do
      {:ok, base_url <> path}
    end
  end

  # Internal helpers

  defp validate_create_opts(opts) do
    model = Keyword.get(opts, :model)
    agent = Keyword.get(opts, :agent)
    generation_config = Keyword.get(opts, :generation_config)
    agent_config = Keyword.get(opts, :agent_config)
    response_format = Keyword.get(opts, :response_format)
    response_mime_type = Keyword.get(opts, :response_mime_type)

    cond do
      is_nil(model) and is_nil(agent) ->
        {:error, Error.validation_error("Interactions.create requires either :model or :agent")}

      not is_nil(model) and not is_nil(agent) ->
        {:error, Error.validation_error("Invalid request: specified both :model and :agent")}

      not is_nil(model) and not is_nil(agent_config) ->
        {:error,
         Error.validation_error(
           "Invalid request: specified :model and :agent_config. If specifying :model, use :generation_config."
         )}

      not is_nil(agent) and not is_nil(generation_config) ->
        {:error,
         Error.validation_error(
           "Invalid request: specified :agent and :generation_config. If specifying :agent, use :agent_config."
         )}

      not is_nil(response_format) and is_nil(response_mime_type) ->
        {:error,
         Error.validation_error(
           "Invalid request: :response_mime_type is required when :response_format is set"
         )}

      true ->
        :ok
    end
  end

  defp validate_get_opts(false, last_event_id) when is_binary(last_event_id) do
    {:error, Error.validation_error(":last_event_id can only be used when :stream is true")}
  end

  defp validate_get_opts(_stream?, _last_event_id), do: :ok

  defp auth_headers_and_credentials(auth, opts) do
    with {:ok, _auth, headers} <- MultiAuthCoordinator.coordinate_auth(auth, opts),
         {:ok, credentials} <- MultiAuthCoordinator.get_credentials(auth, opts) do
      {:ok, headers, credentials}
    else
      {:error, reason} -> {:error, Error.auth_error(to_string(reason))}
    end
  end

  defp default_api_version(:gemini), do: "v1beta"
  defp default_api_version(:vertex_ai), do: "v1beta1"

  defp base_url_root(auth, credentials) do
    case Auth.get_base_url(auth, credentials) do
      base_url when is_binary(base_url) ->
        {:ok, strip_api_version_segment(base_url)}

      {:error, reason} ->
        {:error, Error.config_error("Invalid base URL: #{inspect(reason)}")}
    end
  end

  defp strip_api_version_segment(base_url) do
    base_url
    |> String.trim_trailing("/")
    |> String.replace_suffix("/v1", "")
    |> String.replace_suffix("/v1beta", "")
    |> String.replace_suffix("/v1beta1", "")
  end

  defp create_path(:gemini, _credentials, api_version) do
    {:ok, "/#{api_version}/interactions"}
  end

  defp create_path(:vertex_ai, credentials, api_version) do
    project_id = Map.get(credentials, :project_id)
    location = Map.get(credentials, :location)

    cond do
      not is_binary(project_id) or project_id == "" ->
        {:error, Error.validation_error("Vertex Interactions requires :project_id")}

      not is_binary(location) or location == "" ->
        {:error, Error.validation_error("Vertex Interactions requires :location")}

      true ->
        {:ok, "/#{api_version}/projects/#{project_id}/locations/#{location}/interactions"}
    end
  end

  defp get_path(:vertex_ai, credentials, api_version, id, stream?, last_event_id) do
    params =
      []
      |> maybe_add_query("stream", stream? && "true")
      |> maybe_add_query("last_event_id", stream? && last_event_id)

    with {:ok, path} <- vertex_interaction_path(credentials, api_version, id) do
      case params do
        [] -> {:ok, path}
        _ -> {:ok, path <> "?" <> URI.encode_query(Enum.reverse(params))}
      end
    end
  end

  defp get_path(_auth, _credentials, api_version, id, stream?, last_event_id) do
    params =
      []
      |> maybe_add_query("stream", stream? && "true")
      |> maybe_add_query("last_event_id", stream? && last_event_id)

    path = "/#{api_version}/interactions/#{id}"

    case params do
      [] -> {:ok, path}
      _ -> {:ok, path <> "?" <> URI.encode_query(Enum.reverse(params))}
    end
  end

  defp cancel_path(:vertex_ai, credentials, api_version, id) do
    vertex_interaction_path(credentials, api_version, id, "/cancel")
  end

  defp cancel_path(_auth, _credentials, api_version, id) do
    {:ok, "/#{api_version}/interactions/#{id}/cancel"}
  end

  defp delete_path(:vertex_ai, credentials, api_version, id) do
    vertex_interaction_path(credentials, api_version, id)
  end

  defp delete_path(_auth, _credentials, api_version, id) do
    {:ok, "/#{api_version}/interactions/#{id}"}
  end

  defp vertex_interaction_path(credentials, api_version, id, suffix \\ "") do
    with {:ok, base_path} <- create_path(:vertex_ai, credentials, api_version) do
      {:ok, "#{base_path}/#{id}#{suffix}"}
    end
  end

  defp maybe_add_query(params, _key, false), do: params
  defp maybe_add_query(params, _key, nil), do: params
  defp maybe_add_query(params, key, value), do: [{key, value} | params]

  defp build_create_body(input, opts, stream?) do
    model = Keyword.get(opts, :model)
    agent = Keyword.get(opts, :agent)

    generation_config =
      case Keyword.get(opts, :generation_config) do
        nil -> nil
        %GenerationConfig{} = cfg -> GenerationConfig.to_api(cfg)
        cfg when is_map(cfg) -> cfg
        other -> other
      end

    agent_config =
      case Keyword.get(opts, :agent_config) do
        nil -> nil
        %{} = cfg -> AgentConfig.to_api(cfg)
        other -> other
      end

    tools =
      case Keyword.get(opts, :tools) do
        nil -> nil
        list when is_list(list) -> Enum.map(list, &Tool.to_api/1)
        other -> other
      end

    body =
      %{}
      |> Map.put("input", Input.to_api(input))
      |> maybe_put("model", model)
      |> maybe_put("agent", agent)
      |> maybe_put("background", Keyword.get(opts, :background))
      |> maybe_put("generation_config", generation_config)
      |> maybe_put("agent_config", agent_config)
      |> maybe_put("previous_interaction_id", Keyword.get(opts, :previous_interaction_id))
      |> maybe_put("response_format", Keyword.get(opts, :response_format))
      |> maybe_put("response_mime_type", Keyword.get(opts, :response_mime_type))
      |> maybe_put("response_modalities", Keyword.get(opts, :response_modalities))
      |> maybe_put("store", Keyword.get(opts, :store))
      |> maybe_put("system_instruction", Keyword.get(opts, :system_instruction))
      |> maybe_put("tools", tools)

    body =
      if stream? do
        Map.put(body, "stream", true)
      else
        body
      end

    {:ok, body}
  end

  defp request_json(method, url, headers, body, opts, parse_fun) do
    timeout = Keyword.get(opts, :timeout, Config.timeout())

    req_opts =
      [
        method: method,
        url: url,
        headers: headers,
        receive_timeout: timeout
      ]
      |> maybe_put_json(body)

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, parse_fun.(normalize_json_body(response_body))}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        message = extract_error_message(response_body) || "Request failed"
        {:error, Error.http_error(status, message, %{"body" => response_body})}

      {:error, reason} ->
        {:error, Error.network_error("Request failed", reason)}
    end
  end

  defp normalize_json_body(%{} = body), do: body

  defp normalize_json_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _ -> %{}
    end
  end

  defp normalize_json_body(_), do: %{}

  defp extract_error_message(%{"error" => %{"message" => message}})
       when is_binary(message) and message != "" do
    message
  end

  defp extract_error_message(%{"error" => message}) when is_binary(message) and message != "" do
    message
  end

  defp extract_error_message(body) when is_binary(body) do
    body
    |> normalize_json_body()
    |> extract_error_message()
  end

  defp extract_error_message(_), do: nil

  defp maybe_put_json(req_opts, nil), do: req_opts
  defp maybe_put_json(req_opts, body) when is_map(body), do: Keyword.put(req_opts, :json, body)

  defp stream_request(method, url, headers, body, opts) do
    parent = self()
    ref = make_ref()

    stream_opts =
      opts
      |> Keyword.take([:timeout, :max_retries, :max_backoff_ms, :connect_timeout])
      |> Keyword.put(:method, method)
      |> Keyword.put(:add_sse_params, false)

    stream_pid =
      spawn_link(fn ->
        callback = fn
          %{type: :data, data: %{done: true}} ->
            :ok

          %{type: :data, data: data} ->
            send(parent, {:interactions_stream, ref, :data, data})
            :ok

          %{type: :error, error: error} ->
            send(parent, {:interactions_stream, ref, :error, error})
            :stop

          %{type: :complete} ->
            send(parent, {:interactions_stream, ref, :complete})
            :ok
        end

        try do
          _ = HTTPStreaming.stream_sse(url, headers, body, callback, stream_opts)
        rescue
          exception ->
            send(
              parent,
              {:interactions_stream, ref, :error,
               Error.network_error("Stream crashed", exception)}
            )
        catch
          :exit, reason ->
            send(
              parent,
              {:interactions_stream, ref, :error, Error.network_error("Stream exited", reason)}
            )
        after
          send(parent, {:interactions_stream, ref, :done})
          :ok
        end
      end)

    Stream.resource(
      fn -> %{ref: ref, pid: stream_pid} end,
      fn state ->
        receive do
          {:interactions_stream, ^ref, :data, data} ->
            case Events.from_api(data) do
              nil -> {[], state}
              event -> {[event], state}
            end

          {:interactions_stream, ^ref, :error, error} ->
            {[{:error, error}], state}

          {:interactions_stream, ^ref, :complete} ->
            {:halt, state}

          {:interactions_stream, ^ref, :done} ->
            {:halt, state}
        end
      end,
      fn %{pid: pid} ->
        if is_pid(pid) and Process.alive?(pid) do
          Process.unlink(pid)
          Process.exit(pid, :shutdown)
        end
      end
    )
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp do_wait_for_completion(id, opts, poll_interval_ms, timeout_ms, start_ms, on_status) do
    case get(id, Keyword.put(opts, :stream, false)) do
      {:ok, %Interaction{} = interaction} ->
        if is_function(on_status, 1), do: on_status.(interaction)

        if terminal_status?(interaction.status) do
          {:ok, interaction}
        else
          now_ms = System.monotonic_time(:millisecond)

          if now_ms - start_ms > timeout_ms do
            {:error, Error.network_error("Timed out waiting for interaction completion")}
          else
            if poll_interval_ms > 0, do: Process.sleep(poll_interval_ms)
            do_wait_for_completion(id, opts, poll_interval_ms, timeout_ms, start_ms, on_status)
          end
        end

      {:ok, other} ->
        {:error, Error.invalid_response("Unexpected get/2 response: #{inspect(other)}")}

      {:error, error} ->
        {:error, error}
    end
  end

  defp terminal_status?("completed"), do: true
  defp terminal_status?("failed"), do: true
  defp terminal_status?("cancelled"), do: true
  defp terminal_status?("requires_action"), do: true
  defp terminal_status?(_), do: false
end
