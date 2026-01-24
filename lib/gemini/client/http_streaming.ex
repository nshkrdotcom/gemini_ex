defmodule Gemini.Client.HTTPStreaming do
  @moduledoc """
  HTTP client for streaming Server-Sent Events (SSE) from Gemini API.

  Provides proper streaming support with:
  - Incremental SSE parsing
  - Connection management
  - Error handling and retries
  - Backpressure support
  """

  alias Gemini.Config
  alias Gemini.Error
  alias Gemini.SSE.Parser
  alias Gemini.TaskSupervisor
  alias Gemini.Telemetry

  require Logger

  @default_max_backoff_ms 10_000
  @default_connect_timeout_ms 5_000

  @type stream_event :: %{
          type: :data | :error | :complete,
          data: map() | nil,
          error: term() | nil
        }

  @type stream_callback :: (stream_event() -> :ok | :stop)

  @doc """
  Start an SSE stream with a callback function.

  ## Parameters
  - `url` - Full URL for the streaming endpoint
  - `headers` - HTTP headers including authentication
  - `body` - Request body (will be JSON encoded)
  - `callback` - Function called for each event
  - `opts` - Options including timeout, retry settings
    - `:timeout` - Receive timeout per attempt (default: `Gemini.Config.timeout/0`)
    - `:max_retries` - Number of retry attempts (default: 3)
    - `:max_backoff_ms` - Max backoff between retries (default: 10_000)
    - `:connect_timeout` - Finch connect timeout (default: 5_000)

  ## Examples

      callback = fn
        %{type: :data, data: data} ->
          IO.puts("Received data")
          :ok
        %{type: :complete} ->
          IO.puts("Stream complete")
          :ok
        %{type: :error, error: _error} ->
          IO.puts("Stream error")
          :stop
      end

      HTTPStreaming.stream_sse(url, headers, body, callback)
  """
  @spec stream_sse(
          String.t(),
          [{String.t(), String.t()}],
          map() | nil,
          stream_callback(),
          keyword()
        ) ::
          {:ok, :completed} | {:error, term()}
  def stream_sse(url, headers, body, callback, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, Config.timeout())
    max_retries = Keyword.get(opts, :max_retries, 3)
    max_backoff_ms = Keyword.get(opts, :max_backoff_ms, @default_max_backoff_ms)
    connect_timeout = Keyword.get(opts, :connect_timeout, @default_connect_timeout_ms)
    method = Keyword.get(opts, :method, :post)
    add_sse_params? = Keyword.get(opts, :add_sse_params, true)

    stream_id = Telemetry.generate_stream_id()
    metadata = Telemetry.build_stream_metadata(url, method, stream_id, opts)
    measurements = %{system_time: System.system_time()}

    Telemetry.execute([:gemini, :stream, :start], measurements, metadata)

    try do
      # Wrap the callback to emit telemetry for chunks
      telemetry_callback = fn event ->
        case event do
          %{type: :data, data: data} ->
            chunk_measurements = %{
              chunk_size: calculate_chunk_size(data),
              system_time: System.system_time()
            }

            Telemetry.execute([:gemini, :stream, :chunk], chunk_measurements, metadata)

          _ ->
            :ok
        end

        callback.(event)
      end

      stream_config = %{
        timeout: timeout,
        max_retries: max_retries,
        max_backoff_ms: max_backoff_ms,
        connect_timeout: connect_timeout,
        method: method,
        add_sse_params?: add_sse_params?
      }

      result = stream_with_retries(url, headers, body, telemetry_callback, stream_config, 0)

      case result do
        {:ok, :completed} ->
          # Emit stream completion event
          Telemetry.execute([:gemini, :stream, :stop], %{}, metadata)
          result

        {:error, error} ->
          Telemetry.execute(
            [:gemini, :stream, :exception],
            measurements,
            Map.put(metadata, :reason, error)
          )

          result
      end
    rescue
      exception ->
        Telemetry.execute(
          [:gemini, :stream, :exception],
          measurements,
          Map.put(metadata, :reason, exception)
        )

        reraise exception, __STACKTRACE__
    end
  end

  @doc """
  Start an SSE stream that sends events to a GenServer process.

  Events are sent as messages: {:stream_event, stream_id, event}
  """
  @spec stream_to_process(
          String.t(),
          [{String.t(), String.t()}],
          map(),
          String.t(),
          pid(),
          keyword()
        ) ::
          {:ok, pid()} | {:error, term()}
  def stream_to_process(url, headers, body, stream_id, target_pid, opts \\ []) do
    callback = fn event ->
      send(target_pid, {:stream_event, stream_id, event})
      :ok
    end

    # Start streaming in a separate process
    TaskSupervisor.start_child(fn ->
      url
      |> safe_stream_sse(headers, body, callback, opts)
      |> forward_stream_result(target_pid, stream_id)
    end)
  end

  @spec safe_stream_sse(
          String.t(),
          [{String.t(), String.t()}],
          map() | nil,
          stream_callback(),
          keyword()
        ) ::
          {:ok, :completed} | {:error, term()}
  defp safe_stream_sse(url, headers, body, callback, opts) do
    stream_sse(url, headers, body, callback, opts)
  rescue
    exception -> {:error, exception}
  catch
    :exit, reason -> {:error, reason}
  end

  @spec forward_stream_result({:ok, :completed} | {:error, term()}, pid(), String.t()) :: :ok
  defp forward_stream_result(result, target_pid, stream_id) do
    case result do
      {:ok, :completed} ->
        send(target_pid, {:stream_complete, stream_id})

      {:error, error} ->
        send(target_pid, {:stream_error, stream_id, error})
    end

    :ok
  end

  # Private implementation

  @spec stream_with_retries(
          String.t(),
          list(),
          map() | nil,
          stream_callback(),
          map(),
          non_neg_integer()
        ) ::
          {:ok, :completed} | {:error, term()}
  defp stream_with_retries(
         url,
         headers,
         body,
         callback,
         config,
         attempt
       ) do
    case do_stream(url, headers, body, callback, config) do
      {:ok, :completed} ->
        {:ok, :completed}

      {:error, error} when attempt < config.max_retries ->
        Logger.warning("Stream attempt #{attempt + 1} failed: #{inspect(error)}, retrying...")

        # Exponential backoff
        delay = min(1000 * :math.pow(2, attempt), config.max_backoff_ms) |> round()
        Process.sleep(delay)

        stream_with_retries(url, headers, body, callback, config, attempt + 1)

      {:error, error} ->
        Logger.error("Stream failed after #{config.max_retries} retries: #{inspect(error)}")
        {:error, error}
    end
  end

  @spec do_stream(
          String.t(),
          list(),
          map() | nil,
          stream_callback(),
          map()
        ) ::
          {:ok, :completed} | {:error, term()}
  defp do_stream(url, headers, body, callback, config) do
    sse_url = if config.add_sse_params?, do: add_sse_params(url), else: url

    # Use a more direct approach with custom HTTP handling
    case stream_with_finch(sse_url, headers, body, callback, config) do
      {:ok, :completed} ->
        {:ok, :completed}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec stream_with_finch(
          String.t(),
          list(),
          map() | nil,
          stream_callback(),
          map()
        ) ::
          {:ok, :completed} | {:error, term()}
  defp stream_with_finch(url, headers, body, callback, config) do
    Logger.debug("Starting real-time streaming with Req to #{url} (#{config.method})")

    # Use Req's `:self` option for real-time streaming
    req_opts =
      [
        method: config.method,
        url: url,
        headers: add_sse_headers(headers),
        receive_timeout: config.timeout,
        connect_options: [timeout: config.connect_timeout],
        # Use :self to get messages as they arrive
        into: :self
      ]
      |> maybe_put_json(body)

    try do
      Req.request(req_opts)
      |> handle_stream_response(callback, config.timeout)
    catch
      {:stop_stream, :completed} ->
        {:ok, :completed}

      {:stop_stream, :requested} ->
        {:ok, :completed}

      {:stop_stream, error} ->
        {:error, error}
    end
  end

  defp handle_stream_response({:ok, response}, callback, timeout) do
    # Check for HTTP errors before starting to stream
    if response.status >= 400 do
      handle_stream_error_response(response, callback, timeout)
    else
      parser = Parser.new()
      stream_loop(response, parser, callback, timeout)
    end
  end

  defp handle_stream_response({:error, %{reason: reason}}, callback, _timeout) do
    error = Error.network_error("Transport error: #{inspect(reason)}")
    emit_stream_error(callback, error)
    {:error, error}
  end

  defp handle_stream_response({:error, reason}, callback, _timeout) do
    error = Error.network_error("Request failed: #{inspect(reason)}")
    emit_stream_error(callback, error)
    {:error, reason}
  end

  defp handle_stream_error_response(response, callback, timeout) do
    # For error responses, the body may be present in `response.body` or may arrive as
    # streaming messages (Req `into: :self`).
    error_body = get_error_response_body(response, timeout)
    normalized_body = normalize_error_body(error_body)
    error_msg = extract_error_message(normalized_body) || "HTTP #{response.status}"
    error_details = build_error_details(normalized_body)

    error = Error.http_error(response.status, error_msg, error_details)
    emit_stream_error(callback, error)
    {:error, error}
  end

  defp build_error_details(nil), do: %{}
  defp build_error_details(""), do: %{}
  defp build_error_details(body), do: %{"body" => body}

  defp emit_stream_error(callback, error) do
    callback.(%{type: :error, data: nil, error: error})
  end

  # Collect error response body from streaming messages
  defp collect_error_body(response, timeout) do
    collect_error_body(response, timeout, "")
  end

  defp collect_error_body(response, timeout, acc) do
    receive do
      message ->
        case Req.parse_message(response, message) do
          {:ok, [{:data, chunk}]} ->
            collect_error_body(response, timeout, acc <> chunk)

          {:ok, [:done]} ->
            acc

          {:ok, other} ->
            Logger.debug("Received other message during error collection: #{inspect(other)}")
            collect_error_body(response, timeout, acc)

          :unknown ->
            Logger.debug("Received unknown message during error collection: #{inspect(message)}")
            collect_error_body(response, timeout, acc)
        end
    after
      timeout ->
        Logger.warning("Timeout collecting error response body")
        acc
    end
  end

  defp get_error_response_body(%Req.Response{body: body} = response, timeout) do
    cond do
      is_map(body) and not is_struct(body) ->
        body

      is_binary(body) and body != "" ->
        body

      true ->
        collect_error_body(response, timeout)
    end
  end

  defp normalize_error_body(nil), do: nil
  defp normalize_error_body(%{} = body), do: body

  defp normalize_error_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      _ -> body
    end
  end

  defp normalize_error_body(other), do: other

  # Process streaming messages in real-time
  defp stream_loop(response, parser, callback, timeout) do
    receive do
      message ->
        case handle_stream_message(response, parser, callback, message) do
          {:continue, next_parser} ->
            stream_loop(response, next_parser, callback, timeout)

          {:stop, result} ->
            result
        end
    after
      timeout ->
        error = Error.network_error("Stream timeout after #{timeout}ms")
        emit_stream_error(callback, error)
        {:error, :timeout}
    end
  end

  defp handle_stream_message(response, parser, callback, message) do
    case Req.parse_message(response, message) do
      {:ok, [{:data, chunk}]} ->
        handle_stream_chunk(chunk, parser, callback)

      {:ok, [:done]} ->
        {:stop, finalize_stream(parser, callback)}

      {:ok, other} ->
        Logger.debug("Received other message: #{inspect(other)}")
        {:continue, parser}

      :unknown ->
        Logger.debug("Received unknown message: #{inspect(message)}")
        {:continue, parser}
    end
  end

  defp handle_stream_chunk(chunk, parser, callback) do
    Logger.debug("Received streaming chunk of size #{byte_size(chunk)}")

    case Parser.parse_chunk(chunk, parser) do
      {:ok, events, new_parser} ->
        case deliver_events(events, new_parser, callback) do
          {:completed, _next_parser} -> {:stop, {:ok, :completed}}
          {:continue, next_parser} -> {:continue, next_parser}
        end

      {:error, error} ->
        emit_stream_error(callback, error)
        {:continue, parser}
    end
  end

  defp finalize_stream(parser, callback) do
    Logger.debug("Stream completed")

    case Parser.finalize(parser) do
      {:ok, remaining_events} ->
        Enum.each(remaining_events, fn event -> emit_data_event(callback, event) end)
    end

    emit_completion_event(callback)
    {:ok, :completed}
  end

  defp emit_data_event(callback, event) do
    callback.(%{type: :data, data: event.data, error: nil})
  end

  defp emit_completion_event(callback) do
    callback.(%{type: :complete, data: nil, error: nil})
  end

  defp deliver_events(events, parser, callback) do
    Enum.reduce_while(events, {:continue, parser}, fn event, {_status, current_parser} ->
      stream_event = %{type: :data, data: event.data, error: nil}
      callback_result = callback.(stream_event)
      done? = Parser.stream_done?(event)

      if callback_result == :stop or done? do
        maybe_emit_completion_event(callback, done?)
        {:halt, {:completed, current_parser}}
      else
        {:cont, {:continue, current_parser}}
      end
    end)
  end

  defp maybe_emit_completion_event(callback, true), do: emit_completion_event(callback)
  defp maybe_emit_completion_event(_callback, false), do: :ok

  @spec add_sse_params(String.t()) :: String.t()
  defp add_sse_params(url) do
    separator = if String.contains?(url, "?"), do: "&", else: "?"
    url <> separator <> "alt=sse"
  end

  @spec maybe_put_json(keyword(), map() | nil) :: keyword()
  defp maybe_put_json(req_opts, nil), do: req_opts
  defp maybe_put_json(req_opts, body) when is_map(body), do: Keyword.put(req_opts, :json, body)

  @spec add_sse_headers([{String.t(), String.t()}]) :: [{String.t(), String.t()}]
  defp add_sse_headers(headers) do
    sse_headers = [
      {"Accept", "text/event-stream"},
      {"Cache-Control", "no-cache"}
    ]

    # Merge with existing headers, avoiding duplicates
    existing_keys = Enum.map(headers, fn {key, _} -> String.downcase(key) end)

    new_headers =
      sse_headers
      |> Enum.reject(fn {key, _} -> String.downcase(key) in existing_keys end)

    headers ++ new_headers
  end

  @spec extract_error_message(term()) :: String.t() | nil
  defp extract_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> extract_error_message(decoded)
      _ -> nil
    end
  end

  defp extract_error_message(%{"error" => %{"message" => message}})
       when is_binary(message) and message != "" do
    message
  end

  defp extract_error_message(%{"error" => error}) when is_binary(error) and error != "" do
    error
  end

  defp extract_error_message(_), do: nil

  # Helper functions for telemetry

  defp calculate_chunk_size(data) when is_map(data) do
    data
    |> Jason.encode()
    |> case do
      {:ok, json} -> byte_size(json)
      _ -> 0
    end
  end

  defp calculate_chunk_size(data) when is_binary(data), do: byte_size(data)
  defp calculate_chunk_size(_), do: 0
end
