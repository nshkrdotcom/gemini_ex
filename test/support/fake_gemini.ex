defmodule Gemini.Test.FakeGemini do
  @moduledoc """
  Fake Gemini endpoint for testing rate limiting behavior.

  Uses Bypass to create a local HTTP server that can simulate various
  Gemini API responses including 200 success, 429 rate limits, and 5xx errors.

  ## Usage

      setup do
        bypass = Bypass.open()
        {:ok, bypass: bypass}
      end

      test "handles 429 with RetryInfo", %{bypass: bypass} do
        FakeGemini.setup_429_response(bypass, retry_delay: "60s")

        # Make request and assert rate limiting behavior
      end
  """

  @default_model_response %{
    "candidates" => [
      %{
        "content" => %{
          "parts" => [%{"text" => "Hello from fake Gemini!"}],
          "role" => "model"
        },
        "finishReason" => "STOP"
      }
    ],
    "usageMetadata" => %{
      "promptTokenCount" => 10,
      "candidatesTokenCount" => 20,
      "totalTokenCount" => 30
    }
  }

  @doc """
  Setup a successful 200 response.

  ## Options

  - `:response` - Custom response body (default: standard model response)
  - `:delay_ms` - Delay before responding (default: 0)
  - `:times` - Number of times to respond this way (default: unlimited)
  """
  def setup_success(bypass, opts \\ []) do
    response = Keyword.get(opts, :response, @default_model_response)
    delay_ms = Keyword.get(opts, :delay_ms, 0)
    times = Keyword.get(opts, :times)

    handler = fn conn ->
      if delay_ms > 0, do: Process.sleep(delay_ms)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end

    if times do
      Bypass.expect_once(bypass, "POST", ~r/.*/, handler)
    else
      Bypass.expect(bypass, "POST", ~r/.*/, handler)
    end

    bypass
  end

  @doc """
  Setup a 429 rate limit response with RetryInfo.

  ## Options

  - `:retry_delay` - Retry delay string (default: "60s")
  - `:quota_metric` - Quota metric name (default: "TokensPerMinute")
  - `:quota_id` - Quota ID (default: "gemini-flash-lite-latest")
  - `:times` - Number of times to respond with 429 (default: 1)
  """
  def setup_429_response(bypass, opts \\ []) do
    retry_delay = Keyword.get(opts, :retry_delay, "60s")
    quota_metric = Keyword.get(opts, :quota_metric, "TokensPerMinute")
    quota_id = Keyword.get(opts, :quota_id, "gemini-flash-lite-latest")
    times = Keyword.get(opts, :times, 1)

    error_body = %{
      "error" => %{
        "code" => 429,
        "message" => "Resource exhausted",
        "status" => "RESOURCE_EXHAUSTED",
        "details" => [
          %{
            "@type" => "type.googleapis.com/google.rpc.RetryInfo",
            "retryDelay" => retry_delay
          },
          %{
            "@type" => "type.googleapis.com/google.rpc.QuotaFailure",
            "violations" => [
              %{
                "subject" => quota_id,
                "description" => "Quota exceeded for #{quota_metric}"
              }
            ]
          }
        ]
      }
    }

    counter = :counters.new(1, [:atomics])

    Bypass.expect(bypass, "POST", ~r/.*/, fn conn ->
      current = :counters.get(counter, 1)
      :counters.add(counter, 1, 1)

      if current < times do
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(429, Jason.encode!(error_body))
      else
        # After `times` 429s, return success
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(@default_model_response))
      end
    end)

    bypass
  end

  @doc """
  Setup a 5xx server error response.

  ## Options

  - `:status` - HTTP status code (default: 500)
  - `:message` - Error message (default: "Internal server error")
  - `:times` - Number of times to respond with error (default: unlimited)
  """
  def setup_5xx_response(bypass, opts \\ []) do
    status = Keyword.get(opts, :status, 500)
    message = Keyword.get(opts, :message, "Internal server error")
    times = Keyword.get(opts, :times)

    error_body = %{
      "error" => %{
        "code" => status,
        "message" => message,
        "status" => "INTERNAL"
      }
    }

    handler = fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(error_body))
    end

    if times do
      counter = :counters.new(1, [:atomics])

      Bypass.expect(bypass, "POST", ~r/.*/, fn conn ->
        current = :counters.get(counter, 1)
        :counters.add(counter, 1, 1)

        if current < times do
          handler.(conn)
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(@default_model_response))
        end
      end)
    else
      Bypass.expect(bypass, "POST", ~r/.*/, handler)
    end

    bypass
  end

  @doc """
  Setup adaptive response pattern that flips from success to 429 after K requests.

  ## Options

  - `:success_count` - Number of successful requests before 429 (default: 3)
  - `:retry_delay` - Retry delay for 429s (default: "5s")
  - `:recover_after` - Number of 429s before recovering (default: 2)
  """
  def setup_adaptive_pattern(bypass, opts \\ []) do
    success_count = Keyword.get(opts, :success_count, 3)
    retry_delay = Keyword.get(opts, :retry_delay, "5s")
    recover_after = Keyword.get(opts, :recover_after, 2)

    counter = :counters.new(1, [:atomics])
    state = :atomics.new(1, signed: false)
    # 0 = success phase, 1 = 429 phase

    error_body = %{
      "error" => %{
        "code" => 429,
        "message" => "Resource exhausted",
        "status" => "RESOURCE_EXHAUSTED",
        "details" => [
          %{
            "@type" => "type.googleapis.com/google.rpc.RetryInfo",
            "retryDelay" => retry_delay
          }
        ]
      }
    }

    Bypass.expect(bypass, "POST", ~r/.*/, fn conn ->
      phase = :atomics.get(state, 1)
      current = :counters.get(counter, 1)
      :counters.add(counter, 1, 1)

      cond do
        phase == 0 and current >= success_count ->
          # Switch to 429 phase
          :atomics.put(state, 1, 1)
          :counters.put(counter, 1, 1)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(429, Jason.encode!(error_body))

        phase == 1 and current >= recover_after ->
          # Switch back to success phase
          :atomics.put(state, 1, 0)
          :counters.put(counter, 1, 0)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(@default_model_response))

        phase == 1 ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(429, Jason.encode!(error_body))

        true ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(@default_model_response))
      end
    end)

    bypass
  end

  @doc """
  Setup response that tracks request count for assertions.

  Returns a counter that can be checked after tests.
  """
  def setup_with_counter(bypass, opts \\ []) do
    response = Keyword.get(opts, :response, @default_model_response)
    counter = :counters.new(1, [:atomics])

    Bypass.expect(bypass, "POST", ~r/.*/, fn conn ->
      :counters.add(counter, 1, 1)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)

    {bypass, counter}
  end

  @doc """
  Get the current count from a counter.
  """
  def get_count(counter) do
    :counters.get(counter, 1)
  end

  @doc """
  Setup response with custom usage metadata for token budgeting tests.
  """
  def setup_with_usage(bypass, input_tokens, output_tokens) do
    response = %{
      "candidates" => [
        %{
          "content" => %{
            "parts" => [%{"text" => "Response"}],
            "role" => "model"
          },
          "finishReason" => "STOP"
        }
      ],
      "usageMetadata" => %{
        "promptTokenCount" => input_tokens,
        "candidatesTokenCount" => output_tokens,
        "totalTokenCount" => input_tokens + output_tokens
      }
    }

    setup_success(bypass, response: response)
  end

  @doc """
  Get the bypass URL for configuration.
  """
  def endpoint_url(bypass) do
    "http://localhost:#{bypass.port}"
  end
end
