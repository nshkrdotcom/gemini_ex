defmodule Gemini.APIs.FilesContractTest do
  use ExUnit.Case, async: false

  alias Gemini.APIs.Files
  alias Gemini.Error

  @fixture_path "test/fixtures/test_document.txt"
  @auth_env_vars [
    "GEMINI_API_KEY",
    "VERTEX_ACCESS_TOKEN",
    "VERTEX_SERVICE_ACCOUNT",
    "VERTEX_JSON_FILE",
    "VERTEX_QUOTA_PROJECT_ID",
    "GOOGLE_CLOUD_QUOTA_PROJECT",
    "VERTEX_PROJECT_ID",
    "GOOGLE_CLOUD_PROJECT",
    "VERTEX_LOCATION",
    "GOOGLE_CLOUD_LOCATION"
  ]

  setup do
    original_env = Map.new(@auth_env_vars, &{&1, System.get_env(&1)})
    original_auth = Application.get_env(:gemini_ex, :auth)
    original_legacy_auth = Application.get_env(:gemini, :auth)

    on_exit(fn ->
      Enum.each(original_env, fn {var, value} -> restore_env(var, value) end)

      if is_nil(original_auth) do
        Application.delete_env(:gemini_ex, :auth)
      else
        Application.put_env(:gemini_ex, :auth, original_auth)
      end

      if is_nil(original_legacy_auth) do
        Application.delete_env(:gemini, :auth)
      else
        Application.put_env(:gemini, :auth, original_legacy_auth)
      end

      :meck.unload()
    end)

    :ok
  end

  test "upload/2 uses the resolved Gemini API key and omits output-only mimeType metadata" do
    System.put_env("GEMINI_API_KEY", "env-api-key")
    Application.delete_env(:gemini_ex, :auth)

    :meck.new(Req, [:non_strict, :passthrough])

    test_pid = self()

    :meck.expect(Req, :post, fn url, opts ->
      send(test_pid, {:req_request, {:start, url, opts}})

      assert url ==
               "https://generativelanguage.googleapis.com/upload/v1beta/files?key=override-api-key"

      metadata =
        opts
        |> Keyword.fetch!(:body)
        |> Jason.decode!()

      assert metadata == %{
               "file" => %{
                 "displayName" => "test_document.txt"
               }
             }

      {:ok,
       %Req.Response{
         status: 200,
         headers: [{"x-goog-upload-url", "https://upload.example/files/test"}],
         body: %{}
       }}
    end)

    :meck.expect(Req, :post, fn req ->
      send(test_pid, {:req_request, {:upload, req}})

      assert request_url(req) == "https://upload.example/files/test"
      assert request_body(req) == File.read!(@fixture_path)
      assert request_header(req, "x-goog-upload-command") == ["upload, finalize"]
      assert request_header(req, "x-goog-upload-offset") == ["0"]

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "file" => %{
             "name" => "files/test-document",
             "displayName" => "test_document.txt",
             "mimeType" => "text/plain",
             "uri" => "https://generativelanguage.googleapis.com/v1beta/files/test-document",
             "state" => "ACTIVE"
           }
         }
       }}
    end)

    assert {:ok, file} = Files.upload(@fixture_path, auth: :gemini, api_key: "override-api-key")

    assert file.name == "files/test-document"
    assert file.mime_type == "text/plain"

    assert_receive {:req_request, _start_request}
    assert_receive {:req_request, _upload_request}
  end

  test "upload_data/2 rejects Vertex AI auth before attempting a request" do
    :meck.new(Req, [:non_strict, :passthrough])

    :meck.expect(Req, :post, fn _req ->
      flunk("Files.upload_data/2 should not issue Req.post/1 when auth: :vertex_ai is used")
    end)

    :meck.expect(Req, :post, fn _url, _opts ->
      flunk("Files.upload_data/2 should not issue Req.post/2 when auth: :vertex_ai is used")
    end)

    assert {:error, %Error{type: :config_error, message: message}} =
             Files.upload_data("hello", mime_type: "text/plain", auth: :vertex_ai)

    assert message =~ "Gemini Developer API"
    assert message =~ "Vertex AI"
  end

  test "upload_data/2 returns a config error when no auth is configured" do
    Enum.each(@auth_env_vars, &System.delete_env/1)
    Application.delete_env(:gemini_ex, :auth)
    Application.delete_env(:gemini, :auth)

    :meck.new(Req, [:non_strict, :passthrough])

    :meck.expect(Req, :post, fn _req ->
      flunk("Files.upload_data/2 should not issue Req.post/1 when auth is missing")
    end)

    :meck.expect(Req, :post, fn _url, _opts ->
      flunk("Files.upload_data/2 should not issue Req.post/2 when auth is missing")
    end)

    assert {:error, %Error{type: :config_error, message: message}} =
             Files.upload_data("hello", mime_type: "text/plain")

    assert message =~ "Gemini Developer API credentials"
    assert message =~ "GEMINI_API_KEY"
  end

  test "get/2 rejects Vertex AI auth before issuing HTTP.get" do
    :meck.new(Gemini.Client.HTTP, [:non_strict, :passthrough])

    :meck.expect(Gemini.Client.HTTP, :get, fn _path, _opts ->
      flunk("Files.get/2 should not call HTTP.get/2 when auth: :vertex_ai is used")
    end)

    assert {:error, %Error{type: :config_error, message: message}} =
             Files.get("files/test-document", auth: :vertex_ai)

    assert message =~ "Gemini Developer API"
    assert message =~ "Vertex AI"
  end

  defp request_url(%{url: %URI{} = uri}), do: URI.to_string(uri)
  defp request_url(%{url: url}) when is_binary(url), do: url

  defp request_body(%{body: body}) when is_binary(body), do: body
  defp request_body(%{body: body}) when is_list(body), do: IO.iodata_to_binary(body)

  defp request_header(%{headers: headers}, header_name) do
    headers
    |> Enum.filter(fn {name, _value} -> String.downcase(name) == String.downcase(header_name) end)
    |> Enum.map(fn {_name, value} -> value end)
    |> List.flatten()
  end

  defp restore_env(var, nil), do: System.delete_env(var)
  defp restore_env(var, value), do: System.put_env(var, value)
end
