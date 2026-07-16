defmodule Gemini.GovernedAuthorityTest do
  use ExUnit.Case, async: false

  alias Gemini.Client.{HTTP, WebSocket}
  alias Gemini.{Error, GovernedAuthority, RateLimiter}

  @env_vars ~w(
    GEMINI_API_KEY
    VERTEX_ACCESS_TOKEN
    VERTEX_SERVICE_ACCOUNT
    VERTEX_JSON_FILE
    GOOGLE_APPLICATION_CREDENTIALS_JSON
    GOOGLE_APPLICATION_CREDENTIALS
    VERTEX_PROJECT_ID
    GOOGLE_CLOUD_PROJECT
    VERTEX_LOCATION
    GOOGLE_CLOUD_LOCATION
  )

  @app_env_keys [
    {:gemini, :auth},
    {:gemini, :api_key},
    {:gemini_ex, :auth},
    {:gemini_ex, :api_key},
    {:gemini_ex, :vertex_ai},
    {:gemini_ex, :vertex_project_id},
    {:gemini_ex, :vertex_location},
    {:gemini_ex, :telemetry_enabled}
  ]

  setup do
    original_env = Enum.map(@env_vars, fn key -> {key, Gemini.Env.get(key)} end)

    original_app_env =
      Enum.map(@app_env_keys, fn {app, key} -> {app, key, Application.get_env(app, key)} end)

    Enum.each(@env_vars, &Gemini.Env.delete/1)
    Enum.each(@app_env_keys, fn {app, key} -> Application.delete_env(app, key) end)
    RateLimiter.reset_all()

    on_exit(fn ->
      Enum.each(original_env, fn
        {key, nil} -> Gemini.Env.delete(key)
        {key, value} -> Gemini.Env.put(key, value)
      end)

      Enum.each(original_app_env, fn
        {app, key, nil} -> Application.delete_env(app, key)
        {app, key, value} -> Application.put_env(app, key, value)
      end)

      RateLimiter.reset_all()
    end)

    :ok
  end

  test "governed HTTP applies isolated query material and emits only redacted telemetry" do
    bypass = Bypass.open()
    test_pid = self()
    handler_id = "governed-http-redaction-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:gemini, :request, :start],
      fn _event, _measurements, metadata, _config ->
        send(test_pid, {:request_metadata, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    Bypass.expect_once(bypass, "POST", "/v1/models/gemini-2.5-flash:generateContent", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["key"] == "authority-query-key"
      assert Plug.Conn.get_req_header(conn, "x-goog-api-key") == ["authority-header-key"]
      assert Plug.Conn.get_req_header(conn, "x-governed-target") == ["target-123"]
      refute Plug.Conn.get_req_header(conn, "authorization") == ["Bearer env-token"]

      Plug.Conn.resp(conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    Gemini.Env.put("GEMINI_API_KEY", "env-key")
    Gemini.Env.put("VERTEX_ACCESS_TOKEN", "env-token")
    Application.put_env(:gemini_ex, :api_key, "app-key")

    authority =
      authority(
        base_url: "http://localhost:#{bypass.port}/v1",
        secret_payload: %{
          headers: %{"x-goog-api-key" => "authority-header-key"},
          query_params: [{"key", "authority-query-key"}]
        }
      )

    assert {:ok, %{"ok" => true}} =
             HTTP.post("models/gemini-2.5-flash:generateContent", %{},
               governed_authority: authority
             )

    assert_receive {:request_metadata, metadata}
    assert metadata.model == "gemini-2.5-flash"
    assert metadata.governed_context.provider_account_ref == "account://google/gemini/test"
    assert metadata.governed_context.quota_scope_ref == "quota://google/project/test"
    assert metadata.url =~ "key=[REDACTED]"
    refute inspect(metadata) =~ "authority-query-key"
    refute inspect(metadata) =~ "authority-header-key"
    refute inspect(metadata) =~ "env-key"
    refute inspect(metadata) =~ "app-key"
  end

  test "governed materialization binds account endpoint generation lease authority and expiry" do
    refs = authority() |> GovernedAuthority.refs()

    assert refs.provider_ref == "provider://google/gemini"
    assert refs.provider_family == "google_gemini"
    assert refs.provider_account_ref == "account://google/gemini/test"
    assert refs.model_account_ref == "model-account://google/gemini/flash"
    assert refs.endpoint_ref == "endpoint://google/gemini/v1beta"
    assert refs.quota_scope_ref == "quota://google/project/test"
    assert refs.credential_handle_ref == "credential-handle://google/gemini/test"
    assert refs.credential_lease_ref == "credential-lease://google/gemini/test/1"
    assert refs.materialization_ref == "materialization://google/gemini/test/1"
    assert refs.authority_ref == "authority://gemini/generate/1"
    assert refs.effect_ref == "effect://gemini/generate/1"
    assert refs.operation_ref == "operation://gemini/generate/1"
    assert refs.generation == 1
    assert refs.fence == 0

    error =
      assert_raise ArgumentError, fn ->
        authority(secret_overrides: %{account_ref: "account://google/gemini/other"})
      end

    assert error.message =~ "account_ref binding"

    assert_raise ArgumentError, ~r/expired/, fn ->
      authority(
        request_overrides: %{
          issued_at: ~U[2020-01-01 00:00:00Z],
          expires_at: ~U[2020-01-01 00:01:00Z]
        }
      )
    end
  end

  test "secret material and authority redact inspection and reject durable encoding" do
    authority =
      authority(
        secret_payload: %{
          headers: %{"authorization" => "Bearer authority-token"},
          query_params: [{"key", "authority-query-key"}]
        }
      )

    inspected = inspect(authority)
    refute inspected =~ "authority-token"
    refute inspected =~ "authority-query-key"
    assert inspected =~ "authorization"
    assert inspected =~ "key"

    refute inspect(authority.secret_material) =~ "authority-token"

    assert_raise ArgumentError, ~r/transient/, fn -> Jason.encode!(authority) end
    assert_raise ArgumentError, ~r/transient/, fn -> Jason.encode!(authority.secret_material) end
  end

  test "governed HTTP rejects ambient supplementation, legacy material, URL and body smuggling" do
    Gemini.Env.put("GEMINI_API_KEY", "env-key")
    Gemini.Env.put("VERTEX_ACCESS_TOKEN", "env-token")
    Application.put_env(:gemini_ex, :api_key, "app-key")

    for {key, value} <- forbidden_http_options() do
      error =
        assert_raise ArgumentError, fn ->
          HTTP.auth_config_for_request([{key, value}, {:governed_authority, authority()}])
        end

      assert error.message =~ "governed authority"
      assert error.message =~ to_string(key)
    end

    assert_raise ArgumentError, ~r/absolute request URLs/, fn ->
      HTTP.get("https://env.example.test/v1/models", governed_authority: authority())
    end

    assert_raise ArgumentError, ~r/credential query parameter api_key/, fn ->
      HTTP.get("models/gemini-2.5-flash?api_key=smuggled", governed_authority: authority())
    end

    assert_raise ArgumentError, ~r/request body forbids credential field api_key/, fn ->
      HTTP.post("models/gemini-2.5-flash:generateContent", %{metadata: %{api_key: "smuggled"}},
        governed_authority: authority()
      )
    end

    for legacy <- [:credential_ref, :credential_headers, :credential_query_params] do
      assert_raise ArgumentError, ~r/legacy top-level/, fn ->
        authority()
        |> Map.from_struct()
        |> Map.put(legacy, "smuggled")
        |> GovernedAuthority.new!()
      end
    end

    assert_raise ArgumentError, ~r/unknown or unmanaged fields/, fn ->
      authority(api_key: "inside-authority-smuggling")
    end

    assert_raise ArgumentError, ~r/headers cannot contain credentials/, fn ->
      authority(headers: %{"x-goog-api-key" => "public-header-smuggling"})
    end
  end

  test "provider errors, exception metadata, and retry surfaces redact materialized secrets" do
    bypass = Bypass.open()
    sentinel = "sentinel-api-key-never-visible"

    Bypass.expect_once(bypass, "GET", "/v1/models", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["key"] == sentinel

      Plug.Conn.resp(
        conn,
        400,
        Jason.encode!(%{
          "error" => %{
            "message" => "provider echoed #{sentinel}",
            "api_key" => sentinel,
            "details" => [%{"retryDelay" => "1s"}]
          }
        })
      )
    end)

    result =
      HTTP.get("models",
        governed_authority:
          authority(
            base_url: "http://localhost:#{bypass.port}/v1",
            secret_payload: %{headers: %{}, query_params: [{"key", sentinel}]}
          ),
        non_blocking: true
      )

    refute inspect(result) =~ sentinel
    assert inspect(result) =~ "[REDACTED]"
  end

  test "rate retry budget and concurrency state isolate quota scopes" do
    model = "gemini-2.5-flash"

    rate_limited = fn ->
      {:error,
       %Error{
         type: :api_error,
         message: "limited",
         http_status: 429,
         details: %{"retryDelay" => "60s", "quotaId" => "quota-a"}
       }}
    end

    assert {:error, {:rate_limited, _retry_at, _details}} =
             RateLimiter.execute(rate_limited, model,
               rate_limit_scope: "quota://account/a",
               non_blocking: true
             )

    assert {:rate_limited, _retry_at, _details} =
             RateLimiter.check_status(model,
               rate_limit_scope: "quota://account/a",
               non_blocking: true
             )

    assert :ok =
             RateLimiter.check_status(model,
               rate_limit_scope: "quota://account/b",
               non_blocking: true
             )

    assert {:rate_limited, _retry_at, _details} =
             RateLimiter.check_status(model,
               account_namespace: "account://different",
               rate_limit_scope: "quota://account/a",
               non_blocking: true
             )
  end

  test "standalone direct auth remains available only outside governed mode" do
    Gemini.Env.put("GEMINI_API_KEY", "env-key")

    assert %{type: :gemini, credentials: %{api_key: "request-key"}} =
             HTTP.auth_config_for_request(api_key: "request-key")

    assert %{type: :gemini, credentials: %{api_key: "env-key"}} =
             HTTP.auth_config_for_request([])
  end

  test "governed WebSocket consumes materialized query params and redacts its path" do
    conn = %WebSocket{
      auth_strategy: :governed_authority,
      model: "gemini-2.5-flash",
      governed_authority:
        authority(secret_payload: %{headers: %{}, query_params: [{"key", "authority-key"}]})
    }

    path = WebSocket.redacted_websocket_path(conn)

    assert path == "/ws/governed?key=[REDACTED]"
    refute path =~ "authority-key"
  end

  test "governed WebSocket rejects unmanaged per-connection credentials" do
    assert {:error, {:governed_authority_forbidden_option, :api_key}} =
             WebSocket.connect(:governed_authority,
               model: "gemini-2.5-flash",
               governed_authority: authority(),
               api_key: "raw-key"
             )
  end

  defp forbidden_http_options do
    [
      auth: :gemini,
      api_key: "raw-api-key",
      access_token: "raw-access-token",
      service_account: "/tmp/service-account.json",
      service_account_key: "/tmp/service-account.json",
      service_account_data: %{"client_email" => "service@example.test"},
      project_id: "raw-project",
      location: "raw-location",
      quota_project_id: "raw-quota",
      base_url: "https://env.example.test",
      headers: [{"authorization", "Bearer raw"}],
      credential_materialization: %{payload: "raw"},
      credential_headers: %{"authorization" => "Bearer raw"},
      credential_query_params: [{"key", "raw"}],
      account_namespace: "raw-account",
      rate_limit_scope: "raw-quota-scope",
      concurrency_key: "raw-concurrency",
      disable_rate_limiter: true
    ]
  end

  defp authority(overrides \\ []) do
    account_overrides = Keyword.get(overrides, :account_overrides, %{})
    request_overrides = Keyword.get(overrides, :request_overrides, %{})
    secret_overrides = Keyword.get(overrides, :secret_overrides, %{})

    account =
      %{
        provider_family: "google_gemini",
        account_ref: "account://google/gemini/test",
        tenant_id: "tenant-123",
        connection_id: "connection-123",
        endpoint_ref: "endpoint://google/gemini/v1beta",
        quota_scope_ref: "quota://google/project/test",
        generation: 1,
        fence: 0
      }
      |> Map.merge(account_overrides)

    request =
      %{
        materialization_ref: "materialization://google/gemini/test/1",
        lease_id: "credential-lease://google/gemini/test/1",
        account: account,
        effect_ref: "effect://gemini/generate/1",
        operation_ref: "operation://gemini/generate/1",
        authority_ref: "authority://gemini/generate/1",
        endpoint_ref: account.endpoint_ref,
        target_ref: "target://gemini/api",
        issued_at: ~U[2026-07-15 00:00:00Z],
        expires_at: ~U[2099-07-15 00:00:00Z]
      }
      |> Map.merge(request_overrides)

    secret =
      %{
        materialization_ref: request.materialization_ref,
        provider_family: account.provider_family,
        account_ref: account.account_ref,
        generation: account.generation,
        payload:
          Keyword.get(overrides, :secret_payload, %{
            headers: %{"authorization" => "Bearer authority-token"},
            query_params: []
          })
      }
      |> Map.merge(secret_overrides)

    [
      base_url: "wss://governed.example.test",
      websocket_path: "/ws/governed",
      provider_ref: "provider://google/gemini",
      model_account_ref: "model-account://google/gemini/flash",
      credential_handle_ref: "credential-handle://google/gemini/test",
      operation_policy_ref: "operation-policy://gemini/generate",
      redaction_ref: "redaction://gemini/default",
      headers: %{"x-governed-target" => "target-123"},
      materialization_request: request,
      secret_material: secret
    ]
    |> Keyword.merge(
      Keyword.drop(overrides, [
        :account_overrides,
        :request_overrides,
        :secret_overrides,
        :secret_payload
      ])
    )
    |> GovernedAuthority.new!()
  end
end
