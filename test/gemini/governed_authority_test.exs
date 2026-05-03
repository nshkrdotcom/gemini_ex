defmodule Gemini.GovernedAuthorityTest do
  use ExUnit.Case, async: false

  alias Gemini.Client.{HTTP, WebSocket}
  alias Gemini.GovernedAuthority

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
    {:gemini_ex, :vertex_location}
  ]

  setup do
    original_env = Enum.map(@env_vars, fn key -> {key, System.get_env(key)} end)

    original_app_env =
      Enum.map(@app_env_keys, fn {app, key} -> {app, key, Application.get_env(app, key)} end)

    Enum.each(@env_vars, &System.delete_env/1)
    Enum.each(@app_env_keys, fn {app, key} -> Application.delete_env(app, key) end)

    on_exit(fn ->
      Enum.each(original_env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      Enum.each(original_app_env, fn
        {app, key, nil} -> Application.delete_env(app, key)
        {app, key, value} -> Application.put_env(app, key, value)
      end)
    end)

    :ok
  end

  test "governed HTTP request materializes authority base URL and credential headers" do
    bypass = Bypass.open()

    Bypass.expect_once(bypass, "POST", "/v1/models/gemini-2.5-flash:generateContent", fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-goog-api-key") == ["authority-key"]
      assert Plug.Conn.get_req_header(conn, "x-governed-target") == ["target-123"]
      refute Plug.Conn.get_req_header(conn, "authorization") == ["Bearer env-token"]

      Plug.Conn.resp(conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    authority =
      authority(
        base_url: "http://localhost:#{bypass.port}/v1",
        credential_headers: %{"x-goog-api-key" => "authority-key"}
      )

    assert {:ok, %{"ok" => true}} =
             HTTP.post("models/gemini-2.5-flash:generateContent", %{},
               governed_authority: authority
             )
  end

  test "governed HTTP rejects unmanaged env, app env, request credentials, and absolute URLs" do
    System.put_env("GEMINI_API_KEY", "env-key")
    System.put_env("VERTEX_ACCESS_TOKEN", "env-token")
    Application.put_env(:gemini_ex, :api_key, "app-key")

    for {key, value} <- forbidden_http_options() do
      error =
        assert_raise ArgumentError, fn ->
          HTTP.auth_config_for_request([{key, value}, {:governed_authority, authority()}])
        end

      assert error.message =~ "governed authority"
      assert error.message =~ to_string(key)
    end

    assert_raise ArgumentError, fn ->
      HTTP.get("https://env.example.test/v1/models", governed_authority: authority())
    end
  end

  test "standalone direct auth remains compatible outside governed mode" do
    System.put_env("GEMINI_API_KEY", "env-key")

    assert %{type: :gemini, credentials: %{api_key: "request-key"}} =
             HTTP.auth_config_for_request(api_key: "request-key")

    assert %{type: :gemini, credentials: %{api_key: "env-key"}} =
             HTTP.auth_config_for_request([])
  end

  test "governed WebSocket path uses authority query params and redacts them" do
    conn = %WebSocket{
      auth_strategy: :governed_authority,
      model: "gemini-2.5-flash",
      governed_authority: authority(credential_query_params: [{"key", "authority-key"}])
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
      headers: [{"authorization", "Bearer raw"}]
    ]
  end

  defp authority(overrides \\ []) do
    [
      base_url: "wss://governed.example.test",
      websocket_path: "/ws/governed",
      credential_ref: "credential-123",
      credential_lease_ref: "lease-123",
      target_ref: "target-123",
      redaction_ref: "redaction-123",
      headers: %{"x-governed-target" => "target-123"},
      credential_headers: %{"authorization" => "Bearer authority-token"},
      credential_query_params: []
    ]
    |> Keyword.merge(overrides)
    |> GovernedAuthority.new!()
  end
end
