defmodule Gemini.APIs.CoordinatorModelPathBuildingTest do
  use ExUnit.Case, async: false

  alias Gemini.APIs.Coordinator
  alias Plug.Conn

  setup do
    bypass = Bypass.open()

    original_auth = Application.get_env(:gemini_ex, :auth)

    original_env =
      Map.new(
        ["GEMINI_API_KEY", "VERTEX_PROJECT_ID", "VERTEX_LOCATION", "VERTEX_ACCESS_TOKEN"],
        fn key -> {key, System.get_env(key)} end
      )

    :meck.new(Gemini.Auth, [:passthrough])

    on_exit(fn ->
      :meck.unload()

      if is_nil(original_auth) do
        Application.delete_env(:gemini_ex, :auth)
      else
        Application.put_env(:gemini_ex, :auth, original_auth)
      end

      Enum.each(original_env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    %{bypass: bypass}
  end

  test "Gemini API preserves user model with endpoint suffix", %{bypass: bypass} do
    :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
      "http://localhost:#{bypass.port}"
    end)

    System.put_env("GEMINI_API_KEY", "test-key")
    System.delete_env("VERTEX_PROJECT_ID")
    System.delete_env("VERTEX_LOCATION")
    System.delete_env("VERTEX_ACCESS_TOKEN")

    Application.put_env(:gemini_ex, :auth, %{type: :gemini, credentials: %{api_key: "test"}})

    Bypass.expect_once(
      bypass,
      "POST",
      "/models/gemini-3-pro-image-preview:generateContent",
      fn conn ->
        Conn.resp(conn, 200, ~s({"candidates":[]}))
      end
    )

    {:ok, _} =
      Coordinator.generate_content(
        "describe a banana",
        model: "gemini-3-pro-image-preview:generateContent",
        disable_rate_limiter: true
      )
  end

  test "Vertex AI preserves user model with endpoint suffix", %{bypass: bypass} do
    :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
      "http://localhost:#{bypass.port}"
    end)

    System.delete_env("GEMINI_API_KEY")
    System.put_env("VERTEX_PROJECT_ID", "proj")
    System.put_env("VERTEX_LOCATION", "loc")
    System.put_env("VERTEX_ACCESS_TOKEN", "token")

    Application.put_env(:gemini_ex, :auth, %{
      type: :vertex_ai,
      credentials: %{project_id: "proj", location: "loc", access_token: "token"}
    })

    Bypass.expect_once(
      bypass,
      "POST",
      "/projects/proj/locations/loc/publishers/google/models/gemini-3-pro-image-preview:generateContent",
      fn conn ->
        Conn.resp(conn, 200, ~s({"candidates":[]}))
      end
    )

    {:ok, _} =
      Coordinator.generate_content(
        "describe a banana",
        model: "gemini-3-pro-image-preview:generateContent",
        disable_rate_limiter: true
      )
  end

  test "Vertex AI list_models uses publisher models endpoint", %{bypass: bypass} do
    :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
      "http://localhost:#{bypass.port}/v1"
    end)

    System.delete_env("GEMINI_API_KEY")
    System.put_env("VERTEX_PROJECT_ID", "proj")
    System.put_env("VERTEX_LOCATION", "loc")
    System.put_env("VERTEX_ACCESS_TOKEN", "token")

    Application.put_env(:gemini_ex, :auth, %{
      type: :vertex_ai,
      credentials: %{project_id: "proj", location: "loc", access_token: "token"}
    })

    Bypass.expect_once(
      bypass,
      "GET",
      "/v1beta1/publishers/google/models",
      fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["pageSize"] == "5"
        assert query["pageToken"] == "cursor-1"

        Conn.resp(
          conn,
          200,
          ~s({"publisherModels":[{"name":"publishers/google/models/gemini-2.5-flash-native-audio-latest","displayName":"Live Model"}]})
        )
      end
    )

    assert {:ok, response} =
             Coordinator.list_models(
               auth: :vertex_ai,
               page_size: 5,
               page_token: "cursor-1",
               disable_rate_limiter: true
             )

    assert Enum.any?(response.models, fn model ->
             model.name == "models/gemini-2.5-flash-native-audio-latest"
           end)
  end

  test "Vertex AI get_model normalizes full resource model names", %{bypass: bypass} do
    :meck.expect(Gemini.Auth, :get_base_url, fn _type, _creds ->
      "http://localhost:#{bypass.port}/v1"
    end)

    System.delete_env("GEMINI_API_KEY")
    System.put_env("VERTEX_PROJECT_ID", "proj")
    System.put_env("VERTEX_LOCATION", "loc")
    System.put_env("VERTEX_ACCESS_TOKEN", "token")

    Application.put_env(:gemini_ex, :auth, %{
      type: :vertex_ai,
      credentials: %{project_id: "proj", location: "loc", access_token: "token"}
    })

    Bypass.expect_once(
      bypass,
      "GET",
      "/v1/publishers/google/models/gemini-2.5-flash",
      fn conn ->
        Conn.resp(
          conn,
          200,
          ~s({"name":"publishers/google/models/gemini-2.5-flash","displayName":"Gemini 2.5 Flash"})
        )
      end
    )

    assert {:ok, model} =
             Coordinator.get_model(
               "projects/proj/locations/loc/publishers/google/models/gemini-2.5-flash",
               auth: :vertex_ai,
               disable_rate_limiter: true
             )

    assert model[:name] == "publishers/google/models/gemini-2.5-flash"
  end
end
