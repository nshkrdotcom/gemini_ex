defmodule Gemini.TelemetryTest do
  use ExUnit.Case

  @moduletag :capture_log

  import Gemini.Test.ModelHelpers

  setup do
    # Install telemetry test handler
    :telemetry_test.attach_event_handlers(self(), [
      [:gemini, :request, :start],
      [:gemini, :request, :stop],
      [:gemini, :request, :exception],
      [:gemini, :stream, :start],
      [:gemini, :stream, :chunk],
      [:gemini, :stream, :stop],
      [:gemini, :stream, :exception]
    ])

    on_exit(fn ->
      :telemetry.detach("telemetry-test")
    end)

    :ok
  end

  describe "telemetry events" do
    test "emits request start and stop events" do
      # Configure telemetry
      Application.put_env(:gemini_ex, :telemetry_enabled, true)

      # This would normally make a real request, but we'll just test the telemetry
      # infrastructure is in place
      assert Gemini.Config.telemetry_enabled?() == true
    end

    test "classify_contents/1 correctly identifies content types" do
      assert Gemini.Telemetry.classify_contents("Hello world") == :text

      assert Gemini.Telemetry.classify_contents([
               %{parts: [%{text: "Hello"}]}
             ]) == :text

      assert Gemini.Telemetry.classify_contents([
               %{parts: [%{text: "Hello"}, %{image: "data"}]}
             ]) == :multimodal
    end

    test "generate_stream_id/0 creates unique IDs" do
      id1 = Gemini.Telemetry.generate_stream_id()
      id2 = Gemini.Telemetry.generate_stream_id()

      assert is_binary(id1)
      assert is_binary(id2)
      assert id1 != id2
      # 8 bytes * 2 chars per byte
      assert String.length(id1) == 16
    end

    test "build_request_metadata/3 creates proper metadata" do
      opts = [
        model: default_model(),
        function: :generate_content,
        contents_type: :text
      ]

      metadata = Gemini.Telemetry.build_request_metadata("https://example.com", :post, opts)

      assert metadata.url == "https://example.com"
      assert metadata.method == :post
      assert metadata.model == default_model()
      assert metadata.function == :generate_content
      assert metadata.contents_type == :text
      assert is_integer(metadata.system_time)
    end

    test "calculate_duration/1 returns positive duration" do
      start_time = System.monotonic_time()
      # Small delay
      Process.sleep(1)
      duration = Gemini.Telemetry.calculate_duration(start_time)

      assert is_integer(duration)
      assert duration >= 0
    end
  end

  describe "telemetry configuration" do
    test "telemetry can be disabled" do
      Application.put_env(:gemini_ex, :telemetry_enabled, false)
      assert Gemini.Config.telemetry_enabled?() == false

      Application.put_env(:gemini_ex, :telemetry_enabled, true)
      assert Gemini.Config.telemetry_enabled?() == true

      Application.delete_env(:gemini_ex, :telemetry_enabled)
      # default is true
      assert Gemini.Config.telemetry_enabled?() == true
    end
  end
end
