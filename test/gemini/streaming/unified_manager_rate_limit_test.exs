defmodule Gemini.Streaming.UnifiedManagerRateLimitTest do
  use ExUnit.Case, async: false

  import Gemini.Test.ModelHelpers

  alias Gemini.{GovernedAuthority, RateLimiter}
  alias Gemini.Streaming.UnifiedManager

  setup do
    RateLimiter.reset_all()

    :meck.new(Gemini.Auth.MultiAuthCoordinator, [:non_strict])
    :meck.new(Gemini.Client.HTTPStreaming, [:non_strict])

    :meck.expect(Gemini.Auth.MultiAuthCoordinator, :coordinate_auth, fn _strategy, _config ->
      {:ok, :gemini, []}
    end)

    :meck.expect(Gemini.Auth.MultiAuthCoordinator, :get_credentials, fn _strategy, _config ->
      {:ok, %{project_id: "test", location: "us"}}
    end)

    on_exit(fn ->
      :meck.unload()
    end)

    :ok
  end

  test "streaming respects concurrency gate in non_blocking mode" do
    test_pid = self()

    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     stream_id,
                                                                     manager_pid ->
      pid =
        spawn(fn ->
          send(test_pid, {:stream_started, stream_id, manager_pid, self()})

          receive do
            :finish ->
              send(manager_pid, {:stream_complete, stream_id})
          end
        end)

      {:ok, pid}
    end)

    model = default_model()

    {:ok, stream_id} =
      UnifiedManager.start_stream("hello", [model: model, max_concurrency_per_model: 1], self())

    assert_receive {:stream_started, ^stream_id, _manager_pid, stream_pid}

    result =
      UnifiedManager.start_stream(
        "world",
        [model: model, max_concurrency_per_model: 1, non_blocking: true],
        self()
      )

    assert {:error, {:rate_limited, nil, %{reason: :no_permit_available}}} = result

    send(stream_pid, :finish)
    assert_receive {:stream_complete, ^stream_id}

    {:ok, _stream_id2} =
      UnifiedManager.start_stream(
        "again",
        [model: model, max_concurrency_per_model: 1, non_blocking: true],
        self()
      )

    assert :meck.num_calls(Gemini.Client.HTTPStreaming, :stream_to_process, :_) >= 2
  end

  test "streaming enforces token budget preflight" do
    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     _stream_id,
                                                                     _manager_pid ->
      flunk("stream_to_process should not be called when over budget")
    end)

    model = default_model()

    assert {:error, {:rate_limited, _retry_at, %{reason: :over_budget}}} =
             UnifiedManager.start_stream(model, %{contents: [%{parts: [%{text: "too big"}]}]},
               token_budget_per_window: 5,
               estimated_input_tokens: 10,
               non_blocking: true
             )
  end

  test "concurrency permit released on manual stop" do
    test_pid = self()

    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     stream_id,
                                                                     _manager_pid ->
      pid =
        spawn(fn ->
          send(test_pid, {:stream_started, stream_id, self()})

          receive do
            :finish -> :ok
          end
        end)

      {:ok, pid}
    end)

    model = default_model()

    {:ok, stream_id} =
      UnifiedManager.start_stream("hello", [model: model, max_concurrency_per_model: 1], self())

    assert_receive {:stream_started, ^stream_id, stream_pid}

    :ok = UnifiedManager.stop_stream(stream_id)
    assert_receive {:stream_cancelled, ^stream_id}
    refute Process.alive?(stream_pid)

    {:ok, _new_stream} =
      UnifiedManager.start_stream(
        "next",
        [model: model, max_concurrency_per_model: 1, non_blocking: true],
        self()
      )
  end

  test "governed streams derive quota-scoped concurrency before admission" do
    test_pid = self()

    :meck.expect(Gemini.Client.HTTPStreaming, :stream_to_process, fn _url,
                                                                     _headers,
                                                                     _body,
                                                                     stream_id,
                                                                     manager_pid,
                                                                     _opts ->
      pid =
        spawn(fn ->
          send(test_pid, {:governed_stream_started, stream_id, self()})

          receive do
            :finish -> send(manager_pid, {:stream_complete, stream_id})
          end
        end)

      {:ok, pid}
    end)

    model = "gemini-2.5-flash"
    request = %{contents: [%{parts: [%{text: "hello"}]}]}
    authority_a = governed_authority("account-a", "quota-a")
    authority_b = governed_authority("account-b", "quota-b")

    assert {:ok, stream_a} =
             UnifiedManager.start_stream(model, request,
               model: model,
               governed_authority: authority_a,
               max_concurrency_per_model: 1
             )

    assert_receive {:governed_stream_started, ^stream_a, stream_a_pid}
    assert :ok = UnifiedManager.subscribe(stream_a, self())

    assert {:ok, stream_b} =
             UnifiedManager.start_stream(model, request,
               model: model,
               governed_authority: authority_b,
               max_concurrency_per_model: 1,
               non_blocking: true
             )

    assert_receive {:governed_stream_started, ^stream_b, _stream_b_pid}

    assert {:error, {:rate_limited, nil, %{reason: :no_permit_available}}} =
             UnifiedManager.start_stream(model, request,
               model: model,
               governed_authority: authority_a,
               max_concurrency_per_model: 1,
               non_blocking: true
             )

    send(stream_a_pid, :finish)
    assert_receive {:stream_complete, ^stream_a}

    manager_state = :sys.get_state(UnifiedManager)
    terminal_config = manager_state.streams[stream_a].config
    refute Keyword.has_key?(terminal_config, :governed_authority)
    refute Keyword.has_key?(terminal_config, :redaction_values)

    assert :ok = UnifiedManager.stop_stream(stream_b)
  end

  defp governed_authority(account_suffix, quota_suffix) do
    account_ref = "account://google/gemini/#{account_suffix}"
    quota_scope_ref = "quota://google/gemini/#{quota_suffix}"
    materialization_ref = "materialization://google/gemini/#{account_suffix}/1"

    GovernedAuthority.new!(
      base_url: "https://governed.example.test/v1",
      provider_ref: "provider://google/gemini",
      model_account_ref: "model-account://google/gemini/flash",
      credential_handle_ref: "credential-handle://google/gemini/#{account_suffix}",
      operation_policy_ref: "operation-policy://gemini/generate",
      headers: %{},
      materialization_request: %{
        materialization_ref: materialization_ref,
        lease_id: "credential-lease://google/gemini/#{account_suffix}/1",
        account: %{
          provider_family: "google_gemini",
          account_ref: account_ref,
          tenant_id: "tenant-123",
          connection_id: "connection-#{account_suffix}",
          endpoint_ref: "endpoint://google/gemini/v1",
          quota_scope_ref: quota_scope_ref,
          generation: 1,
          fence: 0
        },
        effect_ref: "effect://gemini/#{account_suffix}/1",
        operation_ref: "operation://gemini/#{account_suffix}/1",
        authority_ref: "authority://gemini/#{account_suffix}/1",
        endpoint_ref: "endpoint://google/gemini/v1",
        target_ref: "target://gemini/api",
        issued_at: ~U[2026-07-15 00:00:00Z],
        expires_at: ~U[2099-07-15 00:00:00Z]
      },
      secret_material: %{
        materialization_ref: materialization_ref,
        provider_family: "google_gemini",
        account_ref: account_ref,
        generation: 1,
        payload: %{headers: %{"x-goog-api-key" => "secret-#{account_suffix}"}, query_params: []}
      }
    )
  end
end
