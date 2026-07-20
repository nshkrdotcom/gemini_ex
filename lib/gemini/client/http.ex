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
  alias Gemini.GovernedAuthority
  alias Gemini.RateLimiter
  alias Gemini.Telemetry

  @governed_forbidden_options [
    :auth,
    :api_key,
    :project_id,
    :location,
    :access_token,
    :service_account,
    :service_account_key,
    :service_account_data,
    :quota_project_id,
    :base_url,
    :headers,
    :credential_materialization,
    :credential_headers,
    :credential_query_params,
    :account_namespace,
    :rate_limit_scope,
    :concurrency_key,
    :disable_rate_limiter
  ]

  @credential_query_names ~w(
    key api_key access_token token auth_token authorization client_secret private_key
  )

  @vertex_auth_override_keys [
    :project_id,
    :location,
    :access_token,
    :service_account_key,
    :service_account,
    :service_account_data,
    :quota_project_id
  ]

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
  @spec auth_config_for_request(keyword()) :: Config.auth_config() | nil
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
    case auth_config do
      nil ->
        {:error, Error.config_error("No authentication configured")}

      %{type: :governed_authority, credentials: %GovernedAuthority{} = authority} ->
        validate_governed_request_opts!(opts)
        execute_governed_request(method, path, body, GovernedAuthority.new!(authority), opts)

      %{type: auth_type, credentials: credentials} ->
        execute_authenticated_request(method, path, body, auth_type, credentials, opts)
    end
  end

  # Execute the actual HTTP request with telemetry
  defp execute_request(method, url, headers, body, opts, validate_config? \\ true) do
    if validate_config? do
      Config.validate!()
    end

    start_time = System.monotonic_time()
    redaction_values = Keyword.get(opts, :redaction_values, [])
    metadata = Telemetry.build_request_metadata(url, method, opts)
    measurements = %{system_time: System.system_time()}

    Telemetry.execute([:gemini, :request, :start], measurements, metadata)

    timeout = Keyword.get(opts, :timeout, Config.timeout())

    req_opts = [
      method: method,
      url: url,
      headers: headers,
      receive_timeout: timeout,
      # Gemini.RateLimiter owns all retry/retry-budget state. Req retries would
      # escape that account-scoped admission and duplicate lower effects.
      retry: false,
      json: body
    ]

    try do
      result =
        req_opts
        |> Req.request()
        |> handle_response()
        |> Telemetry.redact(redaction_values)

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
            Map.put(metadata, :reason, Telemetry.redact(error, redaction_values))
          )
      end

      result
    rescue
      exception ->
        Telemetry.execute(
          [:gemini, :request, :exception],
          measurements,
          Map.put(metadata, :reason, Telemetry.redact(exception, redaction_values))
        )

        if redaction_values == [] do
          reraise exception, __STACKTRACE__
        else
          raise RuntimeError,
                "governed request failed: #{inspect(Telemetry.redact(exception, redaction_values))}"
        end
    end
  end

  # Private functions

  @spec resolve_auth_config(keyword()) :: Config.auth_config() | nil
  defp resolve_auth_config(opts) when is_list(opts) do
    case Keyword.get(opts, :governed_authority) do
      nil ->
        case normalize_auth_strategy(Keyword.get(opts, :auth)) || infer_auth_strategy(opts) do
          nil ->
            Config.auth_config()

          strategy ->
            credentials =
              Config.get_auth_config(strategy)
              |> apply_auth_overrides(strategy, opts)

            %{type: strategy, credentials: credentials}
        end

      authority ->
        validate_governed_request_opts!(opts)

        %{
          type: :governed_authority,
          credentials: GovernedAuthority.new!(authority)
        }
    end
  end

  defp normalize_auth_strategy(:vertex), do: :vertex_ai
  defp normalize_auth_strategy(:gemini), do: :gemini
  defp normalize_auth_strategy(:vertex_ai), do: :vertex_ai
  defp normalize_auth_strategy(_), do: nil

  defp infer_auth_strategy(opts) do
    cond do
      Keyword.has_key?(opts, :api_key) -> :gemini
      Enum.any?(@vertex_auth_override_keys, &Keyword.has_key?(opts, &1)) -> :vertex_ai
      true -> nil
    end
  end

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

  defp validate_governed_request_opts!(opts) do
    case Enum.find(@governed_forbidden_options, &Keyword.has_key?(opts, &1)) do
      nil ->
        :ok

      key ->
        raise ArgumentError, "governed authority forbids unmanaged #{key}"
    end
  end

  defp execute_governed_request(method, path, body, authority, opts) do
    GovernedAuthority.validate_request_body!(body)
    url = build_governed_url(path, authority)
    headers = GovernedAuthority.headers(authority)
    model = extract_model_from_path(path)
    validate_explicit_governed_model!(path, model, opts)

    managed_opts =
      opts
      |> Keyword.delete(:governed_authority)
      |> Keyword.put(:model, model)
      |> Keyword.put(:account_namespace, GovernedAuthority.account_namespace(authority))
      |> Keyword.put(:rate_limit_scope, GovernedAuthority.rate_limit_scope(authority))
      |> Keyword.put(:disable_rate_limiter, false)
      |> Keyword.put(:governed_context, GovernedAuthority.refs(authority))
      |> Keyword.put(:credential_query_names, GovernedAuthority.credential_query_names(authority))
      |> Keyword.put(:redaction_values, GovernedAuthority.secret_values(authority))

    request_fn = fn ->
      execute_request(method, url, headers, body, managed_opts, false)
    end

    maybe_rate_limited_request(request_fn, model, managed_opts)
  end

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

  defp build_governed_url(path, %GovernedAuthority{base_url: base_url} = authority) do
    if String.starts_with?(path, "https://") or String.starts_with?(path, "http://") do
      raise ArgumentError, "governed authority forbids unmanaged absolute request URLs"
    end

    validate_governed_path_query!(path)
    normalized_base = String.trim_trailing(base_url, "/")

    url =
      if String.starts_with?(path, "/") do
        normalized_base <> path
      else
        normalized_base <> "/" <> path
      end

    append_query_params(url, GovernedAuthority.query_params(authority))
  end

  defp append_query_params(url, []), do: url

  defp append_query_params(url, params) do
    separator = if String.contains?(url, "?"), do: "&", else: "?"

    encoded =
      Enum.map_join(params, "&", fn {key, value} ->
        URI.encode_www_form(key) <> "=" <> URI.encode_www_form(value)
      end)

    url <> separator <> encoded
  end

  defp validate_governed_path_query!(path) do
    query = URI.parse(path).query

    if is_binary(query) do
      query
      |> URI.query_decoder()
      |> Enum.each(fn {key, _value} ->
        if normalize_query_name(key) in @credential_query_names do
          raise ArgumentError, "governed authority forbids credential query parameter #{key}"
        end
      end)
    end
  end

  defp normalize_query_name(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace("-", "_")
  end

  defp validate_explicit_governed_model!(path, model, opts) do
    if governed_generation_path?(path) do
      case Keyword.fetch(opts, :model) do
        {:ok, configured_model} when is_binary(configured_model) ->
          configured_model = String.replace_prefix(configured_model, "models/", "")

          if configured_model != model do
            raise ArgumentError, "governed authority model does not match request path"
          end

        _missing_or_invalid ->
          raise ArgumentError, "governed authority requires an explicit model"
      end
    end

    :ok
  end

  defp governed_generation_path?(path) do
    endpoint = extract_endpoint_from_path(path)
    endpoint in ["generateContent", "streamGenerateContent"]
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
