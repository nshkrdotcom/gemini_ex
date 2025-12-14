defmodule Gemini.APIs.InteractionsTest do
  use ExUnit.Case, async: false

  alias Gemini.APIs.Interactions
  alias Gemini.Error
  alias Plug.Conn

  alias Gemini.Types.Interactions.DeltaTextDelta

  alias Gemini.Types.Interactions.Events.{
    ContentDelta,
    ContentStart,
    ContentStop,
    ErrorEvent,
    InteractionEvent,
    InteractionStatusUpdate
  }

  setup do
    bypass = Bypass.open()

    :meck.new(Gemini.Auth, [:passthrough])

    on_exit(fn ->
      :meck.unload()
    end)

    %{bypass: bypass}
  end

  defp interaction_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "int_123",
        "status" => "completed",
        "model" => "models/gemini-2.0-flash",
        "created" => "2025-12-13T00:00:00Z",
        "outputs" => [
          %{"type" => "text", "text" => "Hello"}
        ],
        "usage" => %{
          "total_input_tokens" => 10,
          "total_output_tokens" => 5,
          "total_tokens" => 15
        }
      },
      overrides
    )
  end

  describe "URL building" do
    test "Gemini create ends with /v1beta/interactions" do
      assert {:ok, url} =
               Interactions.build_create_url(:gemini, %{api_key: "test"}, "v1beta")

      assert String.ends_with?(url, "/v1beta/interactions")
    end

    test "Vertex create matches aiplatform scoped path" do
      credentials = %{project_id: "proj", location: "us-central1"}

      assert {:ok, url} =
               Interactions.build_create_url(:vertex_ai, credentials, "v1beta1")

      assert url ==
               "https://us-central1-aiplatform.googleapis.com/v1beta1/projects/proj/locations/us-central1/interactions"
    end
  end

  describe "request validation" do
    test "create requires either :model or :agent" do
      assert {:error, %Error{type: :validation_error}} =
               Interactions.create("hi", auth: :gemini, api_key: "test")
    end

    test "rejects :model + :agent_config" do
      assert {:error, %Error{type: :validation_error, message: message}} =
               Interactions.create("hi",
                 auth: :gemini,
                 api_key: "test",
                 model: "models/gemini-2.0-flash",
                 agent_config: %{}
               )

      assert message =~ ":model and :agent_config"
    end

    test "rejects :agent + :generation_config" do
      assert {:error, %Error{type: :validation_error, message: message}} =
               Interactions.create("hi",
                 auth: :gemini,
                 api_key: "test",
                 agent: "agents/my-agent",
                 generation_config: %{}
               )

      assert message =~ ":agent and :generation_config"
    end

    test "get rejects :last_event_id unless :stream is true" do
      assert {:error, %Error{type: :validation_error, message: message}} =
               Interactions.get("int_123",
                 auth: :gemini,
                 api_key: "test",
                 last_event_id: "evt_1"
               )

      assert message =~ ":last_event_id"
    end
  end

  describe "non-streaming" do
    test "create decodes Interaction response", %{bypass: bypass} do
      :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
        "http://localhost:#{bypass.port}"
      end)

      Bypass.expect_once(bypass, "POST", "/v1beta/interactions", fn conn ->
        assert conn.query_string == ""

        {:ok, body, conn} = Conn.read_body(conn)
        req = Jason.decode!(body)

        assert req["input"] == "hello"
        assert req["model"] == "models/gemini-2.0-flash"
        refute Map.has_key?(req, "stream")

        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.resp(200, Jason.encode!(interaction_json()))
      end)

      assert {:ok, interaction} =
               Interactions.create("hello",
                 auth: :gemini,
                 api_key: "test",
                 model: "models/gemini-2.0-flash",
                 timeout: 2_000
               )

      assert interaction.id == "int_123"
      assert interaction.status == "completed"
    end
  end

  describe "streaming" do
    test "create streaming uses SSE transport (no alt=sse) and decodes events", %{bypass: bypass} do
      :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
        "http://localhost:#{bypass.port}"
      end)

      sse_events = [
        %{
          "event_id" => "evt_1",
          "event_type" => "interaction.start",
          "interaction" => %{"id" => "int_123", "status" => "running"}
        },
        %{
          "event_id" => "evt_2",
          "event_type" => "interaction.status_update",
          "interaction_id" => "int_123",
          "status" => "running"
        },
        %{
          "event_id" => "evt_3",
          "event_type" => "content.start",
          "index" => 0,
          "content" => %{"type" => "text", "text" => ""}
        },
        %{
          "event_id" => "evt_4",
          "event_type" => "content.delta",
          "index" => 0,
          "delta" => %{"type" => "text", "text" => "Hello"}
        },
        %{
          "event_id" => "evt_5",
          "event_type" => "content.stop",
          "index" => 0
        },
        %{
          "event_id" => "evt_6",
          "event_type" => "interaction.complete",
          "interaction" => %{"id" => "int_123", "status" => "completed"}
        },
        %{
          "event_id" => "evt_7",
          "event_type" => "error",
          "error" => %{"code" => "TEST", "message" => "Something happened"}
        }
      ]

      Bypass.expect_once(bypass, "POST", "/v1beta/interactions", fn conn ->
        refute String.contains?(conn.query_string, "alt=sse")
        assert "text/event-stream" in Conn.get_req_header(conn, "accept")

        {:ok, body, conn} = Conn.read_body(conn)
        req = Jason.decode!(body)

        assert req["stream"] == true
        assert req["model"] == "models/gemini-2.0-flash"

        conn =
          conn
          |> Conn.put_resp_content_type("text/event-stream")
          |> Conn.send_chunked(200)

        # Send one event split across chunks to validate incremental parsing.
        [first | rest] = sse_events
        first_frame = "data: " <> Jason.encode!(first) <> "\n\n"
        <<part1::binary-size(10), part2::binary>> = first_frame

        {:ok, conn} = Conn.chunk(conn, part1)
        {:ok, conn} = Conn.chunk(conn, part2)

        Enum.reduce(rest, conn, fn event, conn ->
          {:ok, conn} = Conn.chunk(conn, "data: " <> Jason.encode!(event) <> "\n\n")
          conn
        end)
        |> then(fn conn ->
          {:ok, conn} = Conn.chunk(conn, "data: [DONE]\n\n")
          conn
        end)
      end)

      assert {:ok, stream} =
               Interactions.create("hello",
                 auth: :gemini,
                 api_key: "test",
                 model: "models/gemini-2.0-flash",
                 stream: true,
                 timeout: 2_000,
                 connect_timeout: 2_000,
                 max_retries: 0
               )

      events = Enum.to_list(stream)

      assert [
               %InteractionEvent{event_id: "evt_1", event_type: "interaction.start"},
               %InteractionStatusUpdate{
                 event_id: "evt_2",
                 event_type: "interaction.status_update"
               },
               %ContentStart{event_id: "evt_3", event_type: "content.start"},
               %ContentDelta{
                 event_id: "evt_4",
                 event_type: "content.delta",
                 delta: %DeltaTextDelta{}
               },
               %ContentStop{event_id: "evt_5", event_type: "content.stop"},
               %InteractionEvent{event_id: "evt_6", event_type: "interaction.complete"},
               %ErrorEvent{event_id: "evt_7", event_type: "error"}
             ] = events
    end

    test "early termination does not crash the caller process", %{bypass: bypass} do
      :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
        "http://localhost:#{bypass.port}"
      end)

      parent = self()

      Bypass.expect_once(bypass, "POST", "/v1beta/interactions", fn conn ->
        conn =
          conn
          |> Conn.put_resp_content_type("text/event-stream")
          |> Conn.send_chunked(200)

        {:ok, conn} =
          Conn.chunk(
            conn,
            "data: " <>
              Jason.encode!(%{
                "event_id" => "evt_1",
                "event_type" => "interaction.start",
                "interaction" => %{"id" => "int_123", "status" => "running"}
              }) <> "\n\n"
          )

        send(parent, {:sse_handler, self()})

        receive do
          :finish -> conn
        after
          2_000 -> conn
        end
      end)

      assert {:ok, stream} =
               Interactions.create("hello",
                 auth: :gemini,
                 api_key: "test",
                 model: "models/gemini-2.0-flash",
                 stream: true,
                 timeout: 2_000,
                 connect_timeout: 2_000,
                 max_retries: 0
               )

      assert [%InteractionEvent{event_id: "evt_1", event_type: "interaction.start"}] =
               Enum.take(stream, 1)

      assert_receive {:sse_handler, handler_pid}, 2_000
      send(handler_pid, :finish)

      assert true
    end

    test "decodes Interactions event_id from SSE id field when missing in JSON", %{bypass: bypass} do
      :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
        "http://localhost:#{bypass.port}"
      end)

      Bypass.expect_once(bypass, "POST", "/v1beta/interactions", fn conn ->
        conn =
          conn
          |> Conn.put_resp_content_type("text/event-stream")
          |> Conn.send_chunked(200)

        {:ok, conn} =
          Conn.chunk(
            conn,
            "id: evt_from_sse\n" <>
              "data: " <>
              Jason.encode!(%{
                "event_type" => "interaction.start",
                "interaction" => %{"id" => "int_123", "status" => "running"}
              }) <> "\n\n"
          )

        {:ok, conn} = Conn.chunk(conn, "data: [DONE]\n\n")
        conn
      end)

      assert {:ok, stream} =
               Interactions.create("hello",
                 auth: :gemini,
                 api_key: "test",
                 model: "models/gemini-2.0-flash",
                 stream: true,
                 timeout: 2_000,
                 connect_timeout: 2_000,
                 max_retries: 0
               )

      assert [%InteractionEvent{event_id: "evt_from_sse", event_type: "interaction.start"}] =
               Enum.to_list(stream)
    end

    test "stream ends on [DONE] even without interaction.complete", %{bypass: bypass} do
      :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
        "http://localhost:#{bypass.port}"
      end)

      Bypass.expect_once(bypass, "POST", "/v1beta/interactions", fn conn ->
        conn =
          conn
          |> Conn.put_resp_content_type("text/event-stream")
          |> Conn.send_chunked(200)

        {:ok, conn} =
          Conn.chunk(
            conn,
            "data: " <>
              Jason.encode!(%{
                "event_id" => "evt_1",
                "event_type" => "interaction.start",
                "interaction" => %{"id" => "int_123", "status" => "running"}
              }) <> "\n\n"
          )

        {:ok, conn} = Conn.chunk(conn, "data: [DONE]\n\n")
        conn
      end)

      assert {:ok, stream} =
               Interactions.create("hello",
                 auth: :gemini,
                 api_key: "test",
                 model: "models/gemini-2.0-flash",
                 stream: true,
                 timeout: 2_000,
                 connect_timeout: 2_000,
                 max_retries: 0
               )

      assert [%InteractionEvent{event_type: "interaction.start"}] = Enum.to_list(stream)
    end

    test "get streaming supports resumption with :last_event_id", %{bypass: bypass} do
      :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
        "http://localhost:#{bypass.port}"
      end)

      Bypass.expect_once(bypass, "GET", "/v1beta/interactions/int_123", fn conn ->
        refute String.contains?(conn.query_string, "alt=sse")
        assert "text/event-stream" in Conn.get_req_header(conn, "accept")

        assert conn.params["stream"] == "true"
        assert conn.params["last_event_id"] == "evt_resume"

        conn =
          conn
          |> Conn.put_resp_content_type("text/event-stream")
          |> Conn.send_chunked(200)

        {:ok, conn} = Conn.chunk(conn, "data: [DONE]\n\n")
        conn
      end)

      assert {:ok, stream} =
               Interactions.get("int_123",
                 auth: :gemini,
                 api_key: "test",
                 stream: true,
                 last_event_id: "evt_resume",
                 timeout: 2_000,
                 connect_timeout: 2_000,
                 max_retries: 0
               )

      assert [] == Enum.to_list(stream)
    end
  end

  describe "Vertex quota project header" do
    test "sends x-goog-user-project when configured", %{bypass: bypass} do
      :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
        "http://localhost:#{bypass.port}"
      end)

      Bypass.expect_once(
        bypass,
        "POST",
        "/v1beta1/projects/proj/locations/us-central1/interactions",
        fn conn ->
          assert ["quota-proj"] == Conn.get_req_header(conn, "x-goog-user-project")

          conn
          |> Conn.put_resp_content_type("application/json")
          |> Conn.resp(200, Jason.encode!(interaction_json(%{"id" => "int_vertex"})))
        end
      )

      assert {:ok, interaction} =
               Interactions.create("hello",
                 auth: :vertex_ai,
                 access_token: "token",
                 project_id: "proj",
                 location: "us-central1",
                 quota_project_id: "quota-proj",
                 model: "models/gemini-2.0-flash",
                 timeout: 2_000
               )

      assert interaction.id == "int_vertex"
    end
  end
end
