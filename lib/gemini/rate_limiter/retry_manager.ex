defmodule Gemini.RateLimiter.RetryManager do
  @moduledoc """
  Manages retry logic with backoff strategies.

  Handles:
  - 429 rate limit responses with server-provided RetryInfo delay
  - Transient 5xx errors with exponential backoff and jitter
  - Network/transport errors with bounded retries

  Coordinates with the rate limiter state to avoid double retries.
  """

  alias Gemini.RateLimiter.{Config, State}
  alias Gemini.Telemetry
  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @type retry_result ::
          {:ok, term()}
          | {:error, {:rate_limited, DateTime.t(), map()}}
          | {:error, {:transient_failure, pos_integer(), term()}}
          | {:error, term()}

  @type response_status :: :success | :rate_limited | :transient | :permanent

  @doc """
  Execute a request function with retry handling.

  ## Parameters

  - `request_fn` - Zero-arity function that makes the actual request
  - `state_key` - Key for rate limit state tracking
  - `config` - Rate limiter configuration
  - `opts` - Additional options

  ## Options

  - `:attempt` - Current attempt number (internal use)

  ## Returns

  - `{:ok, response}` - Request succeeded
  - `{:error, {:rate_limited, retry_at, details}}` - Rate limited, wait until retry_at
  - `{:error, {:transient_failure, attempts, last_error}}` - Transient failure after max attempts
  - `{:error, reason}` - Permanent failure
  """
  @spec execute_with_retry(
          (-> {:ok, term()} | {:error, term()}),
          State.state_key(),
          Config.t(),
          keyword()
        ) :: retry_result()
  def execute_with_retry(request_fn, state_key, config, opts \\ []) do
    attempt = Keyword.get(opts, :attempt, 1)

    # Check if we're already in a retry window
    case State.get_retry_until(state_key) do
      nil ->
        execute_request(request_fn, state_key, config, attempt, opts)

      retry_until ->
        emit_retry_event(:hit, state_key, retry_until)
        handle_active_retry_window(retry_until, state_key, request_fn, config, attempt, opts)
    end
  end

  @doc """
  Classify a response to determine retry behavior.

  ## Returns

  - `:success` - Request succeeded
  - `:rate_limited` - 429 response, should wait for RetryInfo delay
  - `:transient` - Retryable error (5xx, network)
  - `:permanent` - Non-retryable error (4xx except 429)
  """
  @spec classify_response({:ok, term()} | {:error, term()}) :: response_status()
  def classify_response({:ok, _}), do: :success

  def classify_response({:error, %{http_status: 429}}), do: :rate_limited
  def classify_response({:error, %{http_status: status}}) when status in 500..599, do: :transient
  def classify_response({:error, %{http_status: status}}) when status in 400..499, do: :permanent

  def classify_response({:error, %{type: :network_error}}), do: :transient
  def classify_response({:error, %{type: :timeout}}), do: :transient

  # Handle raw tuples from HTTP responses
  def classify_response({:error, {:http_error, 429, _}}), do: :rate_limited

  def classify_response({:error, {:http_error, status, _}}) when status in 500..599,
    do: :transient

  def classify_response({:error, {:http_error, status, _}}) when status in 400..499,
    do: :permanent

  # Network errors
  def classify_response({:error, :timeout}), do: :transient
  def classify_response({:error, :closed}), do: :transient
  def classify_response({:error, :econnrefused}), do: :transient

  def classify_response({:error, _}), do: :permanent

  @doc """
  Calculate backoff duration for a given attempt.

  Uses exponential backoff with jitter: base * 2^(attempt-1) * (1 ± jitter)
  """
  @spec calculate_backoff(pos_integer(), Config.t()) :: pos_integer()
  def calculate_backoff(attempt, %Config{base_backoff_ms: base, jitter_factor: jitter}) do
    exponential = base * :math.pow(2, attempt - 1)
    jitter_range = exponential * jitter
    jitter_amount = :rand.uniform() * 2 * jitter_range - jitter_range
    round(exponential + jitter_amount)
  end

  @doc """
  Extract retry delay from a 429 error response.
  """
  @spec extract_retry_info({:error, term()}) :: map()
  def extract_retry_info({:error, %{details: details}}) when is_map(details),
    do: extract_retry_info_from_details(details)

  def extract_retry_info({:error, {:http_error, 429, body}}) when is_map(body),
    do: extract_retry_info_from_details(body)

  def extract_retry_info(_), do: %{}

  # Private implementation

  defp execute_request(request_fn, state_key, config, attempt, opts) do
    case request_fn.() do
      {:ok, _response} = success ->
        # Clear any retry state on success
        State.clear_retry_state(state_key)
        success

      {:error, _} = error ->
        handle_error(error, state_key, config, request_fn, attempt, opts)
    end
  end

  defp handle_error(error, state_key, config, request_fn, attempt, opts) do
    case classify_response(error) do
      :success ->
        # Shouldn't happen, but handle gracefully
        error

      :rate_limited ->
        handle_rate_limit(error, state_key, config, request_fn, attempt, opts)

      :transient ->
        handle_transient_error(error, state_key, config, request_fn, attempt, opts)

      :permanent ->
        error
    end
  end

  defp handle_rate_limit(error, state_key, config, request_fn, attempt, opts) do
    retry_info = extract_retry_info(error)

    # Update state with retry info
    State.set_retry_state(state_key, retry_info)
    emit_retry_event(:set, state_key, State.get_retry_until(state_key), retry_info)

    if config.non_blocking do
      # Return immediately with retry info
      retry_until = State.get_retry_until(state_key)

      {:error,
       {:rate_limited, retry_until,
        %{
          quota_metric: Map.get(retry_info, "quotaMetric"),
          quota_id: Map.get(retry_info, "quotaId"),
          attempt: attempt
        }}}
    else
      # Wait and retry
      wait_and_retry(state_key, request_fn, config, attempt, opts)
    end
  end

  defp handle_transient_error(error, state_key, config, request_fn, attempt, opts) do
    if attempt >= config.max_attempts do
      {:error, {:transient_failure, attempt, error}}
    else
      backoff = calculate_backoff(attempt, config)

      unless config.non_blocking do
        Process.sleep(backoff)
      end

      execute_with_retry(request_fn, state_key, config, Keyword.put(opts, :attempt, attempt + 1))
    end
  end

  defp handle_active_retry_window(retry_until, state_key, request_fn, config, attempt, opts) do
    if config.non_blocking do
      retry_state = State.get_retry_state(state_key)

      {:error,
       {:rate_limited, retry_until,
        %{
          quota_metric: retry_state && retry_state.quota_metric,
          quota_id: retry_state && retry_state.quota_id,
          attempt: attempt
        }}}
    else
      # Wait for the retry window to pass
      wait_and_retry(state_key, request_fn, config, attempt, opts)
    end
  end

  defp wait_and_retry(state_key, request_fn, config, attempt, opts) do
    case State.get_retry_until(state_key) do
      nil ->
        # Retry window passed, execute immediately
        execute_with_retry(
          request_fn,
          state_key,
          config,
          Keyword.put(opts, :attempt, attempt + 1)
        )

      retry_until ->
        wait_ms = DateTime.diff(retry_until, DateTime.utc_now(), :millisecond)
        jittered_wait = jitter_wait(wait_ms, config)

        if jittered_wait > 0 do
          Process.sleep(jittered_wait)
        end

        emit_retry_event(:release, state_key, retry_until)

        execute_with_retry(
          request_fn,
          state_key,
          config,
          Keyword.put(opts, :attempt, attempt + 1)
        )
    end
  end

  defp extract_retry_info_from_details(details) do
    # Look for retry info in various locations and enrich with quota metadata
    base =
      cond do
        Map.has_key?(details, "error") ->
          error = details["error"]
          extract_from_error_details(error)

        Map.has_key?(details, "retryDelay") ->
          details

        true ->
          %{}
      end

    quota_info = extract_quota_info(details)
    Map.merge(base, quota_info)
  end

  defp extract_from_error_details(error) when is_map(error) do
    case error do
      %{"details" => [%{"@type" => type} = detail | _]} ->
        if type == "type.googleapis.com/google.rpc.RetryInfo" or type == "google.rpc.RetryInfo" do
          %{"retryDelay" => Map.get(detail, "retryDelay", "60s")}
        else
          %{}
        end

      %{"details" => details} when is_list(details) ->
        Enum.find_value(details, %{}, fn
          %{"retryDelay" => _} = info -> info
          _ -> nil
        end)

      %{"retryDelay" => _} = info ->
        info

      _ ->
        %{}
    end
  end

  defp extract_from_error_details(_), do: %{}

  defp extract_quota_info(term) do
    %{}
    |> maybe_put("quotaMetric", find_quota_field(term, "quotaMetric"))
    |> maybe_put("quotaId", find_quota_field(term, "quotaId"))
    |> maybe_put("quotaDimensions", find_quota_field(term, "quotaDimensions"))
    |> maybe_put("quotaValue", find_quota_field(term, "quotaValue"))
  end

  defp find_quota_field(term, field) when is_map(term) do
    Map.get(term, field) ||
      find_in_error(term, field) ||
      find_in_details(term, field) ||
      find_in_violations(term, field)
  end

  defp find_quota_field(_term, _field), do: nil

  defp find_in_error(term, field) do
    case Map.get(term, "error") do
      nil -> nil
      error when is_map(error) -> find_quota_field(error, field)
      _ -> nil
    end
  end

  defp find_in_details(term, field) do
    case Map.get(term, "details") do
      details when is_list(details) ->
        Enum.find_value(details, fn detail -> find_quota_field(detail, field) end)

      _ ->
        nil
    end
  end

  defp find_in_violations(term, field) do
    case Map.get(term, "violations") do
      violations when is_list(violations) ->
        Enum.find_value(violations, fn violation -> find_quota_field(violation, field) end)

      _ ->
        nil
    end
  end

  defp jitter_wait(wait_ms, %Config{jitter_factor: jitter}) when wait_ms > 0 do
    jitter_span = round(wait_ms * jitter)
    jitter_amount = if jitter_span > 0, do: :rand.uniform(jitter_span + 1) - 1, else: 0
    wait_ms + jitter_amount
  end

  defp jitter_wait(_wait_ms, _config), do: 0

  defp emit_retry_event(:set, state_key, retry_until, retry_info) do
    {model, location, _metric} = state_key

    Telemetry.execute(
      [:gemini, :rate_limit, :retry_window, :set],
      %{},
      %{
        model: model,
        location: location,
        retry_until: retry_until,
        quota_metric: Map.get(retry_info, "quotaMetric"),
        quota_id: Map.get(retry_info, "quotaId")
      }
    )
  end

  defp emit_retry_event(:hit, state_key, retry_until) do
    {model, location, _metric} = state_key

    Telemetry.execute(
      [:gemini, :rate_limit, :retry_window, :hit],
      %{},
      %{model: model, location: location, retry_until: retry_until}
    )
  end

  defp emit_retry_event(:release, state_key, retry_until) do
    {model, location, _metric} = state_key

    Telemetry.execute(
      [:gemini, :rate_limit, :retry_window, :release],
      %{},
      %{model: model, location: location, retry_until: retry_until}
    )
  end
end
