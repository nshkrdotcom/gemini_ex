defmodule Gemini.APIs.CoordinatorModelWithEndpointTest do
  @moduledoc """
  Reproduces the reported issue where passing a model string that already includes
  `:generateContent` (e.g. `gemini-3-pro-image-preview:generateContent`) silently
  falls back to the default model, so no image-preview request is sent.
  """

  use ExUnit.Case, async: false

  alias Gemini.APIs.Coordinator
  alias Gemini.Config

  setup do
    original_key = System.get_env("GEMINI_API_KEY")
    original_auth = Application.get_env(:gemini_ex, :auth)

    System.put_env("GEMINI_API_KEY", "dummy-key")

    Application.put_env(:gemini_ex, :auth, %{
      type: :gemini,
      credentials: %{api_key: "test-api-key"}
    })

    :meck.new(Req, [:non_strict, :passthrough])

    test_pid = self()

    :meck.expect(Req, :request, fn req_opts ->
      send(test_pid, {:req_url, req_opts[:url]})
      {:ok, %Req.Response{status: 200, body: %{}}}
    end)

    on_exit(fn ->
      if is_nil(original_key) do
        System.delete_env("GEMINI_API_KEY")
      else
        System.put_env("GEMINI_API_KEY", original_key)
      end

      if is_nil(original_auth) do
        Application.delete_env(:gemini_ex, :auth)
      else
        Application.put_env(:gemini_ex, :auth, original_auth)
      end

      :meck.unload()
    end)

    :ok
  end

  test "model values that already contain :generateContent do not drop the explicit model" do
    user_model = "gemini-3-pro-image-preview:generateContent"
    default_model = Config.default_model()

    # Matches the user-provided example: the model already includes the endpoint suffix.
    {:ok, _response} =
      Coordinator.generate_content(
        [
          %{type: "text", text: "describe the banana"},
          %{type: "image", source: %{type: "base64", data: Base.encode64("fake-image")}}
        ],
        model: user_model,
        disable_rate_limiter: true
      )

    assert_receive {:req_url, url}

    # Expected: the generated URL should include the caller-provided model.
    assert String.contains?(url, "gemini-3-pro-image-preview"),
           """
           Request URL should preserve the explicit model when it already includes :generateContent
           (otherwise we silently hit the default model and nothing logs for the image-preview call).
           URL: #{url}
           """

    refute String.contains?(url, default_model),
           "Request unexpectedly fell back to the default model #{default_model}"

    refute String.contains?(url, ":generateContent:generateContent"),
           "Request should not double-append the endpoint"
  end

  test "invalid model strings raise instead of silently falling back" do
    assert_raise ArgumentError, fn ->
      Coordinator.generate_content("hello", model: "gemini-3-pro-image-preview?foo=1")
    end
  end
end
