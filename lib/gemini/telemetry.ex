defmodule Gemini.Telemetry do
  @moduledoc """
  Telemetry instrumentation helpers for Gemini library.

  This module provides functions to emit telemetry events for requests, streaming,
  and other operations throughout the library. It supports the standard telemetry
  events defined in the Gemini library specification:

  - `[:gemini, :request, :start]` - HTTP request started
  - `[:gemini, :request, :stop]` - HTTP request completed successfully
  - `[:gemini, :request, :exception]` - HTTP request failed with exception
  - `[:gemini, :stream, :start]` - Streaming request started
  - `[:gemini, :stream, :chunk]` - Streaming chunk received
  - `[:gemini, :stream, :stop]` - Streaming request completed
  - `[:gemini, :stream, :exception]` - Streaming request failed with exception

  All telemetry events respect the global telemetry configuration and can be
  disabled by setting `telemetry_enabled: false` in the application config.

  ## Types

  The module works with several key data types for telemetry metadata and measurements.
  """

  alias Gemini.Config

  @secret_keys ~w(
    api_key access_token auth_token authorization bearer client_secret client_token
    credential credential_headers credential_materialization credential_query_params
    password private_key refresh_token secret service_account token
  )

  @secret_query_names ~w(
    key api_key access_token auth_token authorization client_secret private_key token
  )

  @type content_type :: :text | :multimodal | :unknown
  @type stream_id :: binary()
  @type telemetry_event :: [atom()]
  @type telemetry_measurements :: map()
  @type telemetry_metadata :: map()
  @type http_method :: :get | :post | :put | :delete | :patch | atom()

  @doc """
  Execute a telemetry event if telemetry is enabled.

  This function conditionally emits telemetry events based on the global
  telemetry configuration. If telemetry is disabled, the function returns
  immediately without executing the event.

  ## Parameters

  - `event` - A list of atoms representing the telemetry event name
  - `measurements` - A map of numeric measurements (e.g., duration, size)
  - `metadata` - A map of contextual information about the event

  ## Examples

      iex> Gemini.Telemetry.execute([:gemini, :request, :start], %{}, %{url: "/api"})
      :ok

      iex> # When telemetry is disabled, no event is emitted
      iex> Application.put_env(:gemini, :telemetry_enabled, false)
      iex> Gemini.Telemetry.execute([:gemini, :request, :start], %{}, %{})
      :ok
  """
  @spec execute(telemetry_event(), telemetry_measurements(), telemetry_metadata()) :: :ok
  def execute(event, measurements, metadata) when is_list(event) do
    if Config.telemetry_enabled?() do
      :telemetry.execute(event, redact(measurements), redact(metadata))
    end

    :ok
  end

  @doc """
  Generate unique stream IDs for telemetry tracking.

  Creates a cryptographically secure random identifier for tracking
  streaming operations across multiple telemetry events.

  ## Returns

  A 16-character lowercase hexadecimal string representing a unique stream ID.

  ## Examples

      iex> stream_id = Gemini.Telemetry.generate_stream_id()
      iex> is_binary(stream_id) and byte_size(stream_id) == 16
      true

      iex> # Stream IDs should be unique
      iex> id1 = Gemini.Telemetry.generate_stream_id()
      iex> id2 = Gemini.Telemetry.generate_stream_id()
      iex> id1 != id2
      true
  """
  @spec generate_stream_id() :: stream_id()
  def generate_stream_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  @doc """
  Classify content types for telemetry metadata.

  Analyzes the content structure to determine if it contains only text,
  multimodal data (text + images/other media), or unknown content types.
  This classification helps with telemetry analysis and monitoring.

  ## Parameters

  - `contents` - The content to classify (string, list, or other)

  ## Returns

  - `:text` - For plain text content
  - `:multimodal` - For content containing non-text elements
  - `:unknown` - For unrecognized content types

  ## Examples

      iex> Gemini.Telemetry.classify_contents("Hello world")
      :text

      iex> Gemini.Telemetry.classify_contents([%{parts: [%{text: "Hello"}]}])
      :text

      iex> Gemini.Telemetry.classify_contents([%{parts: [%{text: "Hello"}, %{image: "data"}]}])
      :multimodal

      iex> Gemini.Telemetry.classify_contents(%{unknown: "format"})
      :unknown
  """
  @spec classify_contents(term()) :: content_type()
  def classify_contents(contents) when is_binary(contents), do: :text

  def classify_contents(contents) when is_list(contents) do
    if Enum.any?(contents, &has_non_text_parts?/1) do
      :multimodal
    else
      :text
    end
  end

  def classify_contents(_), do: :unknown

  @doc """
  Check if content has non-text parts (for multimodal classification).

  Examines a content structure to determine if it contains any non-text
  elements such as images, audio, or other media types.

  ## Parameters

  - `content` - A content structure with parts to examine

  ## Returns

  - `true` - If the content contains non-text parts
  - `false` - If the content contains only text or is not recognized

  ## Examples

      iex> Gemini.Telemetry.has_non_text_parts?(%{parts: [%{text: "Hello"}]})
      false

      iex> Gemini.Telemetry.has_non_text_parts?(%{parts: [%{text: "Hello"}, %{image: "data"}]})
      true

      iex> Gemini.Telemetry.has_non_text_parts?("not a content structure")
      false
  """
  @spec has_non_text_parts?(term()) :: boolean()
  def has_non_text_parts?(%{parts: parts}) when is_list(parts) do
    Enum.any?(parts, fn
      %{text: _} -> false
      _ -> true
    end)
  end

  def has_non_text_parts?(_), do: false

  @doc """
  Extract model name from options or use default.

  Retrieves the model name from a keyword list of options, falling back
  to the system default model if not specified.

  ## Parameters

  - `opts` - Keyword list of options that may contain a `:model` key

  ## Returns

  The model name as a string.

  ## Examples

      iex> Gemini.Telemetry.extract_model(model: "gemini-flash-lite-latest")
      "gemini-flash-lite-latest"

      iex> Gemini.Telemetry.extract_model([])
      Gemini.Config.get_model(:default)  # default model

      iex> Gemini.Telemetry.extract_model("not a keyword list")
      Gemini.Config.get_model(:default)  # fallback to default
  """
  @spec extract_model(keyword() | term()) :: binary()
  def extract_model(opts) when is_list(opts) do
    case Keyword.fetch(opts, :model) do
      {:ok, model} -> model
      :error -> Config.default_model()
    end
  end

  def extract_model(_), do: Config.default_model()

  @doc """
  Build base metadata for HTTP requests with additional context.

  Creates a standardized metadata map for telemetry events related to
  HTTP requests, including URL, method, model, and other contextual information.

  ## Parameters

  - `url` - The request URL
  - `method` - The HTTP method (atom)
  - `opts` - Optional keyword list with additional metadata

  ## Returns

  A map containing standardized request metadata.

  ## Examples

      iex> metadata = Gemini.Telemetry.build_request_metadata("/api/generate", :post, model: "gemini-flash-lite-latest")
      iex> metadata.url
      "/api/generate"
      iex> metadata.method
      :post
      iex> metadata.model
      "gemini-flash-lite-latest"
  """
  @spec build_request_metadata(binary(), http_method(), keyword()) :: telemetry_metadata()
  def build_request_metadata(url, method, opts \\ []) do
    metadata = %{
      url: redact_url(url, Keyword.get(opts, :credential_query_names, [])),
      method: method,
      model: extract_model(opts),
      function: Keyword.get(opts, :function, :unknown),
      contents_type: Keyword.get(opts, :contents_type, :unknown),
      system_time: System.system_time()
    }

    maybe_put_governed_context(metadata, opts)
  end

  @doc """
  Build base metadata for streaming requests with additional context.

  Creates a standardized metadata map for telemetry events related to
  streaming requests, including all standard request metadata plus
  stream-specific information like stream ID.

  ## Parameters

  - `url` - The request URL
  - `method` - The HTTP method (atom)
  - `stream_id` - Unique identifier for the stream
  - `opts` - Optional keyword list with additional metadata

  ## Returns

  A map containing standardized streaming metadata.

  ## Examples

      iex> stream_id = "abc123def456"
      iex> metadata = Gemini.Telemetry.build_stream_metadata("/api/stream", :post, stream_id)
      iex> metadata.stream_id
      "abc123def456"
      iex> metadata.url
      "/api/stream"
  """
  @spec build_stream_metadata(binary(), http_method(), stream_id(), keyword()) ::
          telemetry_metadata()
  def build_stream_metadata(url, method, stream_id, opts \\ []) do
    metadata = %{
      url: redact_url(url, Keyword.get(opts, :credential_query_names, [])),
      method: method,
      model: extract_model(opts),
      function: Keyword.get(opts, :function, :unknown),
      contents_type: Keyword.get(opts, :contents_type, :unknown),
      stream_id: stream_id,
      system_time: System.system_time()
    }

    maybe_put_governed_context(metadata, opts)
  end

  @doc """
  Recursively redact secret-bearing keys, credential query values, and exact
  transient secret values from telemetry, errors, and retry surfaces.
  """
  @spec redact(term(), [String.t()]) :: term()
  def redact(term, secret_values \\ [])

  def redact(term, _secret_values)
      when is_nil(term) or is_atom(term) or is_number(term) or is_pid(term) or is_reference(term),
      do: term

  def redact(%DateTime{} = value, _secret_values), do: value
  def redact(%NaiveDateTime{} = value, _secret_values), do: value
  def redact(%Date{} = value, _secret_values), do: value
  def redact(%Time{} = value, _secret_values), do: value

  def redact(%_{} = value, secret_values) do
    redacted_fields =
      value
      |> Map.from_struct()
      |> redact(secret_values)

    try do
      struct(value, redacted_fields)
    rescue
      _error -> redact(inspect(value), secret_values)
    end
  end

  def redact(value, secret_values) when is_map(value) do
    Map.new(value, fn {key, nested} ->
      if secret_key?(key) do
        {key, "[REDACTED]"}
      else
        {key, redact(nested, secret_values)}
      end
    end)
  end

  def redact(value, secret_values) when is_list(value),
    do: Enum.map(value, &redact(&1, secret_values))

  def redact(value, secret_values) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&redact(&1, secret_values))
    |> List.to_tuple()
  end

  def redact(value, secret_values) when is_binary(value) do
    secret_values
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.uniq()
    |> Enum.reduce(redact_url(value), fn secret, redacted ->
      String.replace(redacted, secret, "[REDACTED]")
    end)
  end

  def redact(value, _secret_values), do: value

  @doc "Redact credential-like query parameters from a URL or path."
  @spec redact_url(String.t(), [String.t()]) :: String.t()
  def redact_url(url, additional_names \\ []) when is_binary(url) do
    names = Enum.uniq(@secret_query_names ++ Enum.map(additional_names, &to_string/1))

    Enum.reduce(names, url, fn name, redacted ->
      pattern = Regex.compile!("([?&]#{Regex.escape(name)}=)[^&#\\s]*", "i")
      Regex.replace(pattern, redacted, "\\1[REDACTED]")
    end)
  end

  defp secret_key?(key) do
    key
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> String.replace("-", "_")
    |> then(&(&1 in @secret_keys))
  end

  defp maybe_put_governed_context(metadata, opts) do
    case Keyword.get(opts, :governed_context) do
      context when is_map(context) -> Map.put(metadata, :governed_context, redact(context))
      _other -> metadata
    end
  end

  @doc """
  Calculate duration in milliseconds from start time.

  Computes the elapsed time between a start time (in native units)
  and the current time, returning the duration in milliseconds.

  ## Parameters

  - `start_time` - Start time in native time units (from `System.monotonic_time/0`)

  ## Returns

  Duration in milliseconds as an integer.

  ## Examples

      iex> start_time = System.monotonic_time()
      iex> :timer.sleep(10)  # Sleep for 10ms
      iex> duration = Gemini.Telemetry.calculate_duration(start_time)
      iex> duration >= 10
      true
  """
  @spec calculate_duration(integer()) :: non_neg_integer()
  def calculate_duration(start_time) do
    end_time = System.monotonic_time()
    System.convert_time_unit(end_time - start_time, :native, :millisecond)
  end
end
