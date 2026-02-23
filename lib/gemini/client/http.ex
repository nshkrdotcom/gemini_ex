defmodule Gemini.Client.HTTP do
  @moduledoc """
  HTTP client for both Gemini and Vertex AI APIs using Req.

  Supports multiple authentication strategies for regular (non-streaming) HTTP requests.
  For streaming requests, see `Gemini.Client.HTTPStreaming`.

  ## Rate Limiting

  All requests are automatically routed through the rate limiter unless
  `disable_rate_limiter: true` is passed in options. The rate limiter:

  - Enforces concurrency limits per model
  - Honors 429 RetryInfo delays from the API
  - Retries transient failures with backoff
  - Tracks token usage for budget estimation

  See `Gemini.RateLimiter` for configuration options.
  """

  alias Gemini.Auth
  alias Gemini.Config
  alias Gemini.Error
  alias Gemini.RateLimiter
  alias Gemini.Telemetry

  @doc """
  Make a GET request using the configured authentication.
  """
  def get(path, opts \\ []) do
    auth_config = resolve_auth_config(opts)
    request(:get, path, nil, auth_config, opts)
  end

  @doc """
  Make a POST request using the configured authentication.
  """
  def post(path, body, opts \\ []) do
    auth_config = resolve_auth_config(opts)
    request(:post, path, body, auth_config, opts)
  end

  @doc """
  Make a PATCH request using the configured authentication.
  """
  def patch(path, body, opts \\ []) do
    auth_config = resolve_auth_config(opts)
    request(:patch, path, body, auth_config, opts)
  end

  @doc """
  Make a DELETE request using the configured authentication.
  """
  def delete(path, opts \\ []) do
    auth_config = resolve_auth_config(opts)
    request(:delete, path, nil, auth_config, opts)
  end

  @doc false
  @spec auth_config_for_request(keyword()) :: %{type: :gemini | :vertex_ai, credentials: map()}
  def auth_config_for_request(opts \\ []) do
    resolve_auth_config(opts)
  end

  @doc """
  Make an authenticated HTTP request.

  ## Options

  In addition to standard request options, supports rate limiter options:

  - `:disable_rate_limiter` - Bypass rate limiting (default: false)
  - `:non_blocking` - Return immediately if rate limited (default: false)
  - `:max_concurrency_per_model` - Override concurrency limit
  """
  def request(method, path, body, auth_config, opts \\ []) do
    Config.validate!()

    case auth_config do
      nil ->
        {:error, Error.config_error("No authentication configured")}

      %{type: auth_type, credentials: credentials} ->
        execute_authenticated_request(method, path, body, auth_type, credentials, opts)
    end
  end

  # Execute the actual HTTP request with telemetry
  defp execute_request(method, url, headers, body, opts) do
    start_time = System.monotonic_time()
    metadata = Telemetry.build_request_metadata(url, method, opts)
    measurements = %{system_time: System.system_time()}

    Telemetry.execute([:gemini, :request, :start], measurements, metadata)

    timeout = Keyword.get(opts, :timeout, Config.timeout())

    req_opts = [
      method: method,
      url: url,
      headers: headers,
      receive_timeout: timeout,
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

  # Private functions

  @spec resolve_auth_config(keyword()) :: %{type: :gemini | :vertex_ai, credentials: map()}
  defp resolve_auth_config(opts) when is_list(opts) do
    case normalize_auth_strategy(Keyword.get(opts, :auth)) do
      nil ->
        Config.auth_config()

      strategy ->
        credentials =
          Config.get_auth_config(strategy)
          |> apply_auth_overrides(strategy, opts)

        %{type: strategy, credentials: credentials}
    end
  end

  defp normalize_auth_strategy(:vertex), do: :vertex_ai
  defp normalize_auth_strategy(:gemini), do: :gemini
  defp normalize_auth_strategy(:vertex_ai), do: :vertex_ai
  defp normalize_auth_strategy(_), do: nil

  defp apply_auth_overrides(credentials, :gemini, opts) do
    credentials
    |> maybe_put_cred(:api_key, Keyword.get(opts, :api_key))
  end

  defp apply_auth_overrides(credentials, :vertex_ai, opts) do
    credentials
    |> maybe_put_cred(:project_id, Keyword.get(opts, :project_id))
    |> maybe_put_cred(:location, Keyword.get(opts, :location))
    |> maybe_put_cred(:access_token, Keyword.get(opts, :access_token))
    |> maybe_put_cred(:service_account_key, Keyword.get(opts, :service_account_key))
    |> maybe_put_cred(:service_account_key, Keyword.get(opts, :service_account))
    |> maybe_put_cred(:service_account_data, Keyword.get(opts, :service_account_data))
    |> maybe_put_cred(:quota_project_id, Keyword.get(opts, :quota_project_id))
  end

  defp maybe_put_cred(credentials, _key, nil), do: credentials
  defp maybe_put_cred(credentials, _key, ""), do: credentials
  defp maybe_put_cred(credentials, key, value), do: Map.put(credentials, key, value)

  defp execute_authenticated_request(method, path, body, auth_type, credentials, opts) do
    url = build_authenticated_url(auth_type, path, credentials)

    case Auth.build_headers(auth_type, credentials) do
      {:ok, headers} ->
        model = extract_model_from_path(path)

        request_fn = fn ->
          execute_request(method, url, headers, body, opts)
        end

        maybe_rate_limited_request(request_fn, model, opts)

      {:error, reason} ->
        {:error, Error.auth_error(reason)}
    end
  end

  defp maybe_rate_limited_request(request_fn, model, opts) do
    if Keyword.get(opts, :disable_rate_limiter, false) do
      request_fn.()
    else
      RateLimiter.execute_with_usage_tracking(request_fn, model, opts)
    end
  end

  defp build_authenticated_url(auth_type, path, credentials) do
    base_url = Auth.get_base_url(auth_type, credentials)

    cond do
      String.starts_with?(path, "https://") or String.starts_with?(path, "http://") ->
        path

      String.starts_with?(path, "/") ->
        build_absolute_url(base_url, path)

      String.contains?(path, ":") ->
        full_path =
          Auth.build_path(
            auth_type,
            extract_model_from_path(path),
            extract_endpoint_from_path(path),
            credentials
          )

        "#{base_url}/#{full_path}"

      true ->
        "#{base_url}/#{path}"
    end
  end

  defp build_absolute_url(base_url, absolute_path) do
    uri = URI.parse(base_url)

    port_segment =
      cond do
        is_nil(uri.port) -> ""
        uri.scheme == "https" and uri.port == 443 -> ""
        uri.scheme == "http" and uri.port == 80 -> ""
        true -> ":#{uri.port}"
      end

    "#{uri.scheme}://#{uri.host}#{port_segment}#{absolute_path}"
  end

  defp extract_model_from_path(path) do
    # Extract model from paths like "models/gemini-2.0-flash:generateContent"
    [model_path | _rest] = String.split(path, ":")

    model_path
    |> String.replace_prefix("models/", "")
    |> String.trim_leading("/")
  end

  defp extract_endpoint_from_path(path) do
    # Extract endpoint from paths like "models/gemini-2.0-flash:generateContent"
    path
    |> String.split(":")
    |> List.last()
    |> String.split("?")
    |> hd()
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
    {error_info, error_details} = parse_error_body(body, status)

    {:error, Error.api_error(status, error_info, error_details)}
  end

  defp handle_response({:error, reason}) do
    {:error, Error.network_error(reason)}
  end

  defp build_default_error(status) do
    message = %{"message" => "HTTP #{status}"}
    {message, %{"error" => message}}
  end

  defp parse_error_body(%{"error" => error} = decoded, _status), do: {error, decoded}

  defp parse_error_body(body, status) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> parse_error_body(decoded, status)
      _ -> build_default_error(status)
    end
  end

  defp parse_error_body(decoded, _status) when is_map(decoded) do
    {decoded, %{"error" => decoded}}
  end

  defp parse_error_body(_body, status), do: build_default_error(status)
end
