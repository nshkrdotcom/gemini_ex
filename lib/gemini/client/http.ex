defmodule Gemini.Client.HTTP do
  @moduledoc """
  Unified HTTP client for both Gemini and Vertex AI APIs using Req.

  Supports multiple authentication strategies and provides both
  regular and streaming request capabilities.
  """

  alias Gemini.Config
  alias Gemini.Auth
  alias Gemini.Error
  alias Gemini.Telemetry

  @doc """
  Make a GET request using the configured authentication.
  """
  def get(path, opts \\ []) do
    auth_config = Config.auth_config()
    request(:get, path, nil, auth_config, opts)
  end

  @doc """
  Make a POST request using the configured authentication.
  """
  def post(path, body, opts \\ []) do
    auth_config = Config.auth_config()
    request(:post, path, body, auth_config, opts)
  end

  @doc """
  Make an authenticated HTTP request.
  """
  def request(method, path, body, auth_config, opts \\ []) do
    Config.validate!()

    start_time = System.monotonic_time()

    case auth_config do
      nil ->
        {:error, Error.config_error("No authentication configured")}

      %{type: auth_type, credentials: credentials} ->
        url = build_authenticated_url(auth_type, path, credentials)
        headers = Auth.build_headers(auth_type, credentials)

        metadata = Telemetry.build_request_metadata(url, method, opts)
        measurements = %{system_time: System.system_time()}

        Telemetry.execute([:gemini, :request, :start], measurements, metadata)

        req_opts = [
          method: method,
          url: url,
          headers: headers,
          receive_timeout: Config.timeout(),
          json: body
        ]

        try do
          result = Req.request(req_opts) |> handle_response()

          case result do
            {:ok, _response} ->
              duration = Telemetry.calculate_duration(start_time)

              stop_measurements = %{
                duration: duration,
                status: 200
              }

              Telemetry.execute([:gemini, :request, :stop], stop_measurements, metadata)

            {:error, error} ->
              Telemetry.execute(
                [:gemini, :request, :exception],
                measurements,
                Map.put(metadata, :reason, error)
              )
          end

          result
        rescue
          exception ->
            Telemetry.execute(
              [:gemini, :request, :exception],
              measurements,
              Map.put(metadata, :reason, exception)
            )

            reraise exception, __STACKTRACE__
        end
    end
  end

  @doc """
  Stream a POST request for Server-Sent Events using configured authentication.
  """
  def stream_post(path, body, opts \\ []) do
    auth_config = Config.auth_config()
    stream_post_with_auth(path, body, auth_config, opts)
  end

  @doc """
  Stream a POST request with specific authentication configuration.
  """
  def stream_post_with_auth(path, body, auth_config, opts \\ []) do
    Config.validate!()

    start_time = System.monotonic_time()

    case auth_config do
      nil ->
        {:error, Error.config_error("No authentication configured")}

      %{type: auth_type, credentials: credentials} ->
        url = build_authenticated_url(auth_type, path, credentials)
        headers = Auth.build_headers(auth_type, credentials)

        # Add SSE parameter to URL
        sse_url = if String.contains?(url, "?"), do: "#{url}&alt=sse", else: "#{url}?alt=sse"

        stream_id = Telemetry.generate_stream_id()
        metadata = Telemetry.build_stream_metadata(sse_url, :post, stream_id, opts)
        measurements = %{system_time: System.system_time()}

        Telemetry.execute([:gemini, :stream, :start], measurements, metadata)

        req_opts = [
          url: sse_url,
          headers: headers,
          receive_timeout: Config.timeout(),
          json: body,
          into: :self
        ]

        try do
          result =
            case Req.post(req_opts) do
              {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
                events = parse_sse_stream(body)

                duration = Telemetry.calculate_duration(start_time)

                stop_measurements = %{
                  total_duration: duration,
                  total_chunks: length(events)
                }

                Telemetry.execute([:gemini, :stream, :stop], stop_measurements, metadata)

                {:ok, events}

              {:ok, %Req.Response{status: status}} ->
                error = {:http_error, status, "Stream request failed"}

                Telemetry.execute(
                  [:gemini, :stream, :exception],
                  measurements,
                  Map.put(metadata, :reason, error)
                )

                {:error, Error.http_error(status, "Stream request failed")}

              {:error, reason} ->
                Telemetry.execute(
                  [:gemini, :stream, :exception],
                  measurements,
                  Map.put(metadata, :reason, reason)
                )

                {:error, Error.network_error(reason)}
            end

          result
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
  end

  @doc """
  Raw streaming POST with full URL (used by streaming manager).
  """
  def stream_post_raw(url, body, headers, _opts \\ []) do
    req_opts = [
      url: url,
      headers: headers,
      receive_timeout: Config.timeout(),
      json: body,
      into: :self
    ]

    case Req.post(req_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        events = parse_sse_stream(body)
        {:ok, events}

      {:ok, %Req.Response{status: status}} ->
        {:error, Error.http_error(status, "Stream request failed")}

      {:error, reason} ->
        {:error, Error.network_error(reason)}
    end
  end

  # Private functions

  defp build_authenticated_url(auth_type, path, credentials) do
    base_url = Auth.get_base_url(auth_type, credentials)

    # Check if this is a model-specific endpoint (contains ":" separator)
    # or a general endpoint like "models" for listing
    if String.contains?(path, ":") do
      # Model-specific endpoint, use the auth strategy to build the path
      full_path =
        Auth.build_path(
          auth_type,
          extract_model_from_path(path),
          extract_endpoint_from_path(path),
          credentials
        )

      "#{base_url}/#{full_path}"
    else
      # General endpoint (like "models"), use path directly
      "#{base_url}/#{path}"
    end
  end

  defp extract_model_from_path(path) do
    # Extract model from paths like "models/gemini-2.0-flash:generateContent"
    case String.split(path, ":") do
      [model_path, _endpoint] ->
        model_path |> String.replace_prefix("models/", "") |> String.trim_leading("/")

      _ ->
        # fallback
        Config.default_model()
    end
  end

  defp extract_endpoint_from_path(path) do
    # Extract endpoint from paths like "models/gemini-2.0-flash:generateContent"
    case String.split(path, ":") do
      [_model, endpoint] -> String.split(endpoint, "?") |> hd()
      # fallback
      _ -> "generateContent"
    end
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    case body do
      decoded when is_map(decoded) ->
        {:ok, decoded}

      json_string when is_binary(json_string) ->
        case Jason.decode(json_string) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, Error.invalid_response("Invalid JSON response")}
        end

      _ ->
        {:error, Error.invalid_response("Invalid response format")}
    end
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    error_info =
      case body do
        %{"error" => error} ->
          error

        json_string when is_binary(json_string) ->
          case Jason.decode(json_string) do
            {:ok, %{"error" => error}} -> error
            _ -> %{"message" => "HTTP #{status}"}
          end

        _ ->
          %{"message" => "HTTP #{status}"}
      end

    {:error, Error.api_error(status, error_info)}
  end

  defp handle_response({:error, reason}) do
    {:error, Error.network_error(reason)}
  end

  # Parse Server-Sent Events format
  defp parse_sse_stream(data) when is_binary(data) do
    data
    |> String.split("\n\n")
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.map(&parse_sse_event/1)
    |> Enum.filter(&(&1 != nil))
  rescue
    _ -> []
  end

  defp parse_sse_stream(_), do: []

  defp parse_sse_event(event_data) do
    lines = String.split(event_data, "\n")

    Enum.reduce(lines, %{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        ["data", json_data] ->
          case Jason.decode(json_data) do
            {:ok, decoded} -> Map.put(acc, :data, decoded)
            _ -> acc
          end

        [field, value] ->
          Map.put(acc, String.to_atom(field), value)

        _ ->
          acc
      end
    end)
    |> case do
      %{data: data} -> data
      _ -> nil
    end
  end
end
