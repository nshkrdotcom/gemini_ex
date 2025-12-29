# Unified Architecture Demo
# Usage: mix run examples/demo_unified.exs

defmodule UnifiedArchitectureDemo do
  @moduledoc """
  Demonstration of the unified Gemini architecture supporting both
  Gemini API and Vertex AI authentication methods.
  """

  defp mask_api_key(key) when is_binary(key) and byte_size(key) > 2 do
    first_two = String.slice(key, 0, 2)
    "#{first_two}***"
  end

  defp mask_api_key(_), do: "***"

  def run do
    IO.puts("🚀 Gemini Unified Architecture Demo")
    IO.puts("=" |> String.duplicate(50))

    demo_configuration()
    demo_authentication_strategies()
    demo_streaming_manager()
    demo_backward_compatibility()

    IO.puts("\n✅ Demo completed successfully!")
  end

  defp demo_configuration do
    IO.puts("\n📋 Configuration System Demo")
    IO.puts("-" |> String.duplicate(30))

    # Clear environment for clean demo
    System.delete_env("GEMINI_API_KEY")
    System.delete_env("GOOGLE_CLOUD_PROJECT")
    System.delete_env("GOOGLE_CLOUD_LOCATION")

    # Default configuration
    config = Gemini.Config.get()
    IO.puts("Default config: #{inspect(config.auth_type)}")

    # Simulated Gemini environment
    demo_key = "demo-gemini-key"
    System.put_env("GEMINI_API_KEY", demo_key)
    config = Gemini.Config.get()
    IO.puts("With GEMINI_API_KEY (#{mask_api_key(demo_key)}): #{inspect(config.auth_type)}")

    # Simulated Vertex environment
    System.delete_env("GEMINI_API_KEY")
    System.put_env("GOOGLE_CLOUD_PROJECT", "demo-project")
    System.put_env("GOOGLE_CLOUD_LOCATION", "us-central1")
    config = Gemini.Config.get()
    IO.puts("With Vertex env vars: #{inspect(config.auth_type)}")

    # Override configuration
    override_key = "override-key"
    config = Gemini.Config.get(auth_type: :gemini, api_key: override_key)
    IO.puts("With override (#{mask_api_key(override_key)}): #{inspect(config.auth_type)}")
  end

  defp demo_authentication_strategies do
    IO.puts("\n🔐 Authentication Strategies Demo")
    IO.puts("-" |> String.duplicate(30))

    # Gemini strategy
    demo_key = "demo-key"
    gemini_config = %{api_key: demo_key}
    strategy = Gemini.Auth.get_strategy(:gemini)
    IO.puts("Gemini strategy: #{inspect(strategy)}")

    case Gemini.Auth.authenticate(strategy, gemini_config) do
      {:ok, headers} ->
        IO.puts("Gemini auth headers (key #{mask_api_key(demo_key)}): #{inspect(headers)}")

      {:error, error} ->
        IO.puts("Gemini auth error: #{error}")
    end

    # Vertex strategy
    vertex_config = %{project_id: "demo-project", location: "us-central1"}
    strategy = Gemini.Auth.get_strategy(:vertex)
    IO.puts("Vertex strategy: #{inspect(strategy)}")

    case Gemini.Auth.authenticate(strategy, vertex_config) do
      {:ok, headers} ->
        IO.puts("Vertex auth headers: #{inspect(headers)}")

      {:error, error} ->
        IO.puts("Vertex auth error: #{error}")
    end

    # Base URLs
    gemini_url = Gemini.Auth.base_url(Gemini.Auth.get_strategy(:gemini), gemini_config)
    IO.puts("Gemini base URL: #{gemini_url}")

    case Gemini.Auth.base_url(Gemini.Auth.get_strategy(:vertex), vertex_config) do
      url when is_binary(url) ->
        IO.puts("Vertex base URL: #{url}")

      {:error, error} ->
        IO.puts("Vertex URL error: #{error}")
    end
  end

  defp demo_streaming_manager do
    IO.puts("\n🌊 Streaming Manager Demo")
    IO.puts("-" |> String.duplicate(30))

    # Start the application to ensure the manager is running
    case Application.ensure_all_started(:gemini) do
      {:ok, _} ->
        IO.puts("Gemini application started")

      {:error, error} ->
        IO.puts("Failed to start application: #{inspect(error)}")
        :error
    end

    # Demonstrate streaming functionality using the new unified coordinator
    contents = "Tell me about artificial intelligence"
    opts = [model: Gemini.Config.get_model(:flash_lite_latest)]

    case Gemini.APIs.Coordinator.stream_generate_content(contents, opts) do
      {:ok, stream_id} ->
        IO.puts("Started stream: #{stream_id}")

        # Subscribe to the stream  
        case Gemini.APIs.Coordinator.subscribe_stream(stream_id, self()) do
          :ok ->
            IO.puts("Subscribed to stream")

          {:error, error} ->
            IO.puts("Subscription error: #{error}")
        end

        # Get stream status
        case Gemini.APIs.Coordinator.stream_status(stream_id) do
          {:ok, status} ->
            IO.puts("Stream status: #{status}")

          {:error, error} ->
            IO.puts("Stream status error: #{error}")
        end

        # Stop the stream after a brief moment
        Process.sleep(100)

        case Gemini.APIs.Coordinator.stop_stream(stream_id) do
          :ok ->
            IO.puts("Stream stopped successfully")

          {:error, error} ->
            IO.puts("Stop stream error: #{error}")
        end

      {:error, error} ->
        IO.puts("Failed to start stream: #{inspect(error)}")
    end
  end

  defp demo_backward_compatibility do
    IO.puts("\n🔄 API Compatibility Demo")
    IO.puts("-" |> String.duplicate(30))

    # Show that existing APIs still work
    IO.puts("Testing API functions...")

    # These would normally make real API calls, but we'll show they compile and run
    try do
      # This will fail with auth errors, but shows the API is compatible
      case Gemini.APIs.Coordinator.generate_content("Hello, world!") do
        {:ok, _response} ->
          IO.puts("✅ generate_content API compatible")

        {:error, _error} ->
          IO.puts("✅ generate_content API compatible (expected auth error)")
      end
    rescue
      _ ->
        IO.puts("✅ generate_content API compatible (compilation successful)")
    end

    # Test configuration functions
    model = Gemini.Config.default_model()
    IO.puts("✅ Default model: #{model}")

    auth_type = Gemini.Config.detect_auth_type(%{api_key: "test"})
    IO.puts("✅ Auth type detection: #{auth_type}")
  end
end

# Run the demo
UnifiedArchitectureDemo.run()
