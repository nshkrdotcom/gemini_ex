# Telemetry Showcase Demo
# Demonstrates the comprehensive telemetry system in the Gemini library
# Usage: mix run examples/telemetry_showcase.exs

require Logger

defmodule TelemetryShowcase do
  @moduledoc """
  Comprehensive demonstration of the Gemini library's telemetry system.

  This example shows:
  - Telemetry event attachment and handling
  - Real-time monitoring of API requests and streaming
  - Telemetry helper functions and utilities
  - Performance measurement and analysis
  - Different content type classification
  """

  def run do
    IO.puts("🔍 Gemini Telemetry System Showcase")
    IO.puts("=" |> String.duplicate(60))

    # Enable telemetry for this demo
    Application.put_env(:gemini, :telemetry_enabled, true)

    # Attach comprehensive telemetry handlers
    attach_telemetry_handlers()

    # Demonstrate telemetry configuration
    demo_telemetry_configuration()

    # Demonstrate helper functions
    demo_helper_functions()

    # Demonstrate real API telemetry (if API key available)
    demo_real_api_telemetry()

    # Demonstrate streaming telemetry (if API key available)
    demo_streaming_telemetry()

    # Show telemetry analysis
    demo_telemetry_analysis()

    # Clean up handlers
    detach_telemetry_handlers()

    IO.puts("\n✅ Telemetry showcase completed!")
    IO.puts("\n💡 Key takeaways:")
    IO.puts("   • Telemetry provides comprehensive observability into Gemini operations")
    IO.puts("   • All events include standardized metadata for analysis")
    IO.puts("   • Streaming operations are tracked with unique IDs")
    IO.puts("   • Content types are automatically classified")
    IO.puts("   • Performance metrics are captured automatically")
  end

  defp attach_telemetry_handlers do
    IO.puts("\n📡 Attaching Telemetry Handlers")
    IO.puts("-" |> String.duplicate(40))

    # Define all telemetry events we want to monitor
    events = [
      [:gemini, :request, :start],
      [:gemini, :request, :stop],
      [:gemini, :request, :exception],
      [:gemini, :stream, :start],
      [:gemini, :stream, :chunk],
      [:gemini, :stream, :stop],
      [:gemini, :stream, :exception]
    ]

    # Attach handler for each event type
    Enum.each(events, fn event ->
      :telemetry.attach(
        "showcase-#{Enum.join(event, "-")}",
        event,
        &__MODULE__.handle_telemetry_event/4,
        %{event_name: Enum.join(event, ":")}
      )
    end)

    IO.puts("✅ Attached handlers for #{length(events)} event types:")

    Enum.each(events, fn event ->
      IO.puts("   • #{Enum.join(event, ":")}")
    end)
  end

  def handle_telemetry_event(event, measurements, metadata, config) do
    event_name = config[:event_name] || Enum.join(event, ":")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    # Format output based on event type
    case event do
      [:gemini, :request, :start] ->
        IO.puts("🚀 [#{timestamp}] #{event_name}")
        IO.puts("   🌐 URL: #{metadata[:url]}")
        IO.puts("   📊 Method: #{metadata[:method]}")
        IO.puts("   🤖 Model: #{metadata[:model]}")
        IO.puts("   🔧 Function: #{metadata[:function]}")
        IO.puts("   📝 Content Type: #{metadata[:contents_type]}")

      [:gemini, :request, :stop] ->
        duration = measurements[:duration] || 0
        status = measurements[:status] || "unknown"
        IO.puts("✅ [#{timestamp}] #{event_name}")
        IO.puts("   ⏱️  Duration: #{duration}ms")
        IO.puts("   📈 Status: #{status}")
        IO.puts("   🌐 URL: #{metadata[:url]}")

      [:gemini, :request, :exception] ->
        IO.puts("❌ [#{timestamp}] #{event_name}")
        IO.puts("   🚨 Error: #{metadata[:error] || "unknown"}")
        IO.puts("   🌐 URL: #{metadata[:url]}")

      [:gemini, :stream, :start] ->
        IO.puts("🌊 [#{timestamp}] #{event_name}")
        IO.puts("   🆔 Stream ID: #{metadata[:stream_id]}")
        IO.puts("   🌐 URL: #{metadata[:url]}")
        IO.puts("   🤖 Model: #{metadata[:model]}")

      [:gemini, :stream, :chunk] ->
        size = measurements[:chunk_size] || 0
        chunk_number = measurements[:chunk_number] || 0
        IO.puts("📦 [#{timestamp}] #{event_name}")
        IO.puts("   🆔 Stream ID: #{metadata[:stream_id]}")
        IO.puts("   📏 Chunk ##{chunk_number}: #{size} bytes")

      [:gemini, :stream, :stop] ->
        duration = measurements[:duration] || 0
        total_chunks = measurements[:total_chunks] || 0
        IO.puts("🏁 [#{timestamp}] #{event_name}")
        IO.puts("   🆔 Stream ID: #{metadata[:stream_id]}")
        IO.puts("   ⏱️  Total Duration: #{duration}ms")
        IO.puts("   📦 Total Chunks: #{total_chunks}")

      [:gemini, :stream, :exception] ->
        IO.puts("💥 [#{timestamp}] #{event_name}")
        IO.puts("   🆔 Stream ID: #{metadata[:stream_id]}")
        IO.puts("   🚨 Error: #{metadata[:error] || "unknown"}")

      _ ->
        IO.puts("📋 [#{timestamp}] #{event_name}")
        IO.puts("   📊 Measurements: #{inspect(measurements, pretty: true)}")
        IO.puts("   📋 Metadata: #{inspect(metadata, pretty: true)}")
    end

    IO.puts("")
  end

  defp demo_telemetry_configuration do
    IO.puts("\n⚙️  Telemetry Configuration Demo")
    IO.puts("-" |> String.duplicate(40))

    # Show current telemetry status
    IO.puts("Current telemetry status: #{Gemini.Config.telemetry_enabled?()}")

    # Demonstrate disabling/enabling
    IO.puts("\nTesting telemetry toggle:")

    # Disable telemetry
    Application.put_env(:gemini, :telemetry_enabled, false)
    IO.puts("• After disabling: #{Gemini.Config.telemetry_enabled?()}")

    # Test event emission when disabled (should not show output)
    IO.puts("• Testing event emission when disabled (no output expected):")
    Gemini.Telemetry.execute([:test, :disabled], %{value: 1}, %{source: "demo"})

    # Re-enable telemetry
    Application.put_env(:gemini, :telemetry_enabled, true)
    IO.puts("• After re-enabling: #{Gemini.Config.telemetry_enabled?()}")

    # Test event emission when enabled
    IO.puts("• Testing event emission when enabled:")
    Gemini.Telemetry.execute([:test, :enabled], %{value: 42}, %{source: "demo"})
  end

  defp demo_helper_functions do
    IO.puts("\n🔧 Telemetry Helper Functions Demo")
    IO.puts("-" |> String.duplicate(40))

    # Stream ID generation
    IO.puts("Stream ID Generation:")
    stream_ids = Enum.map(1..3, fn _ -> Gemini.Telemetry.generate_stream_id() end)

    Enum.with_index(stream_ids, 1)
    |> Enum.each(fn {id, index} ->
      IO.puts("  #{index}. #{id} (length: #{byte_size(id)})")
    end)

    IO.puts("  ✅ All IDs are unique: #{length(Enum.uniq(stream_ids)) == 3}")

    # Content classification
    IO.puts("\nContent Type Classification:")

    test_contents = [
      {"Simple text", "Hello, world!"},
      {"Text list", [%{parts: [%{text: "Hello"}]}]},
      {"Multimodal", [%{parts: [%{text: "Hello"}, %{image: "base64data"}]}]},
      {"Unknown", %{random: "structure"}}
    ]

    Enum.each(test_contents, fn {description, content} ->
      type = Gemini.Telemetry.classify_contents(content)
      IO.puts("  • #{description}: #{type}")
    end)

    # Model extraction
    IO.puts("\nModel Extraction:")

    test_opts = [
      {[model: "gemini-pro"], "with explicit model"},
      {[function: :generate], "without model (uses default)"},
      {%{not: "keyword_list"}, "invalid opts (uses default)"}
    ]

    Enum.each(test_opts, fn {opts, description} ->
      model = Gemini.Telemetry.extract_model(opts)
      IO.puts("  • #{description}: #{model}")
    end)

    # Metadata building
    IO.puts("\nMetadata Building:")

    request_metadata =
      Gemini.Telemetry.build_request_metadata(
        "https://api.example.com/generate",
        :post,
        model: "gemini-flash-lite-latest",
        function: :generate_content,
        contents_type: :text
      )

    IO.puts("  • Request metadata keys: #{Map.keys(request_metadata) |> Enum.join(", ")}")

    stream_id = Gemini.Telemetry.generate_stream_id()

    stream_metadata =
      Gemini.Telemetry.build_stream_metadata(
        "https://api.example.com/stream",
        :post,
        stream_id,
        model: "gemini-flash-lite-latest"
      )

    IO.puts("  • Stream metadata keys: #{Map.keys(stream_metadata) |> Enum.join(", ")}")
    IO.puts("  • Stream ID: #{stream_metadata.stream_id}")

    # Duration calculation
    IO.puts("\nDuration Calculation:")
    start_time = System.monotonic_time()
    # Sleep for 50ms
    :timer.sleep(50)
    duration = Gemini.Telemetry.calculate_duration(start_time)
    IO.puts("  • Measured 50ms sleep: #{duration}ms (should be ~50ms)")
  end

  defp demo_real_api_telemetry do
    IO.puts("\n🌐 Real API Telemetry Demo")
    IO.puts("-" |> String.duplicate(40))

    case System.get_env("GEMINI_API_KEY") do
      nil ->
        IO.puts("❌ No GEMINI_API_KEY found, skipping real API telemetry demo")
        IO.puts("💡 Set GEMINI_API_KEY to see live telemetry events")

      _api_key ->
        IO.puts("✅ API key found, demonstrating live telemetry...")
        IO.puts("Watch for telemetry events below:")
        IO.puts("")

        # Make a real API request to trigger telemetry
        case Gemini.text("What is 2+2? Answer briefly.") do
          {:ok, response} ->
            IO.puts("🎯 API Response received: #{String.slice(response, 0, 100)}...")

          {:error, error} ->
            IO.puts("❌ API Error: #{inspect(error)}")
        end
    end
  end

  defp demo_streaming_telemetry do
    IO.puts("\n🌊 Streaming Telemetry Demo")
    IO.puts("-" |> String.duplicate(40))

    case System.get_env("GEMINI_API_KEY") do
      nil ->
        IO.puts("❌ No GEMINI_API_KEY found, skipping streaming telemetry demo")

      _api_key ->
        IO.puts("✅ Starting streaming request to generate telemetry events...")
        IO.puts("Watch for stream telemetry events below:")
        IO.puts("")

        case Gemini.start_stream("Count from 1 to 3 briefly.") do
          {:ok, stream_id} ->
            IO.puts("🌊 Started stream: #{stream_id}")

            # Subscribe to stream to trigger events
            :ok = Gemini.subscribe_stream(stream_id)

            # Let stream run for a bit to collect events
            receive do
              {:stream_complete, ^stream_id} ->
                IO.puts("✅ Stream completed successfully")
            after
              5000 ->
                IO.puts("⏰ Stream timeout, stopping...")
                Gemini.APIs.Coordinator.stop_stream(stream_id)
            end

          {:error, error} ->
            IO.puts("❌ Failed to start stream: #{inspect(error)}")
        end
    end
  end

  defp demo_telemetry_analysis do
    IO.puts("\n📊 Telemetry Analysis Demo")
    IO.puts("-" |> String.duplicate(40))

    IO.puts("This demonstrates how telemetry data could be analyzed:")
    IO.puts("")

    # Simulate some telemetry data for analysis
    measurements = [
      %{duration: 150, status: 200, chunk_size: 256},
      %{duration: 89, status: 200, chunk_size: 412},
      %{duration: 234, status: 200, chunk_size: 189},
      %{duration: 445, status: 500, chunk_size: 0},
      %{duration: 67, status: 200, chunk_size: 345}
    ]

    successful_requests = Enum.filter(measurements, &(&1.status == 200))

    avg_duration =
      Enum.map(successful_requests, & &1.duration)
      |> Enum.sum()
      |> div(length(successful_requests))

    avg_chunk_size =
      Enum.map(successful_requests, & &1.chunk_size)
      |> Enum.sum()
      |> div(length(successful_requests))

    error_rate = (length(measurements) - length(successful_requests)) / length(measurements) * 100

    IO.puts("📈 Sample Analysis Results:")
    IO.puts("  • Total requests: #{length(measurements)}")
    IO.puts("  • Successful requests: #{length(successful_requests)}")
    IO.puts("  • Error rate: #{Float.round(error_rate, 1)}%")
    IO.puts("  • Average response time: #{avg_duration}ms")
    IO.puts("  • Average chunk size: #{avg_chunk_size} bytes")
    IO.puts("")
    IO.puts("💡 In production, this data would be collected by your telemetry system")
    IO.puts("   (e.g., Prometheus, DataDog, New Relic, etc.)")
  end

  defp detach_telemetry_handlers do
    IO.puts("\n🔌 Detaching Telemetry Handlers")
    IO.puts("-" |> String.duplicate(40))

    # Detach all handlers
    [
      [:gemini, :request, :start],
      [:gemini, :request, :stop],
      [:gemini, :request, :exception],
      [:gemini, :stream, :start],
      [:gemini, :stream, :chunk],
      [:gemini, :stream, :stop],
      [:gemini, :stream, :exception]
    ]
    |> Enum.each(fn event ->
      :telemetry.detach("showcase-#{Enum.join(event, "-")}")
    end)

    # Also detach test handlers
    try do
      :telemetry.detach("test-enabled")
      :telemetry.detach("test-disabled")
    rescue
      _ -> :ok
    end

    IO.puts("✅ All telemetry handlers detached")
  end
end

# Run the showcase
TelemetryShowcase.run()
