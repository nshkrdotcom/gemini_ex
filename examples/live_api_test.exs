# Live API Tests for Gemini Elixir Library
# Tests both Gemini API and Vertex AI authentication, plus streaming
# Usage: mix run examples/live_api_test.exs

require Logger

defmodule LiveAPITest do
  @moduledoc """
  Live API tests for Gemini library with both authentication methods and streaming.
  """

  def run_all_tests do
    IO.puts("\n🚀 Starting Live API Tests for Gemini Library")
    IO.puts("=" |> String.duplicate(60))

    # Test configuration detection
    test_config_detection()

    # Test Gemini API authentication
    test_gemini_auth()

    # Test Vertex AI authentication
    test_vertex_auth()

    # Test streaming functionality
    test_streaming()

    IO.puts("\n✅ All live API tests completed!")
  end

  defp test_config_detection do
    IO.puts("\n📋 Testing Configuration Detection")
    IO.puts("-" |> String.duplicate(40))

    auth_config = Gemini.Config.auth_config()
    IO.puts("Detected auth config: #{inspect(auth_config, pretty: true)}")

    auth_type = Gemini.Config.detect_auth_type()
    IO.puts("Detected auth type: #{auth_type}")

    default_model = Gemini.Config.default_model()
    IO.puts("Default model: #{default_model}")
  end

  defp test_gemini_auth do
    IO.puts("\n🔑 Testing Gemini API Authentication")
    IO.puts("-" |> String.duplicate(40))

    # Configure for Gemini API
    api_key = System.get_env("GEMINI_API_KEY")

    if api_key do
      Gemini.configure(:gemini, %{api_key: api_key})
      IO.puts("Configured Gemini API with key: #{String.slice(api_key, 0, 8)}***")

      # Test simple text generation
      test_simple_generation("Gemini API")

      # Test model listing
      test_model_listing("Gemini API")

      # Test token counting
      test_token_counting("Gemini API")
    else
      IO.puts("❌ GEMINI_API_KEY not found, skipping Gemini auth tests")
    end
  end

  defp test_vertex_auth do
    IO.puts("\n🔑 Testing Vertex AI Authentication")
    IO.puts("-" |> String.duplicate(40))

    # Check for Vertex AI credentials
    service_account_file =
      System.get_env("VERTEX_JSON_FILE") || System.get_env("VERTEX_SERVICE_ACCOUNT")

    project_id = System.get_env("VERTEX_PROJECT_ID") || System.get_env("GOOGLE_CLOUD_PROJECT")

    cond do
      service_account_file && File.exists?(service_account_file) ->
        IO.puts("Found service account file: #{service_account_file}")

        # Try to extract project_id from service account file if not set
        project_id = project_id || extract_project_from_service_account(service_account_file)

        if project_id do
          # Configure for Vertex AI
          Gemini.configure(:vertex_ai, %{
            service_account_key: service_account_file,
            project_id: project_id,
            location: "us-central1"
          })

          IO.puts("Configured Vertex AI with project: #{project_id}")

          # Test simple text generation
          test_simple_generation("Vertex AI")

          # Test model listing (different for Vertex AI)
          test_vertex_model_operations()
        else
          IO.puts("❌ No project_id found for Vertex AI, skipping tests")
        end

      true ->
        IO.puts("❌ Vertex AI service account file not found, skipping Vertex auth tests")
        IO.puts("Looked for: VERTEX_JSON_FILE or VERTEX_SERVICE_ACCOUNT environment variables")
    end
  end

  defp test_simple_generation(auth_type) do
    IO.puts("\n  📝 Testing simple text generation with #{auth_type}")

    case Gemini.generate("What is the capital of France? Give a brief answer.") do
      {:ok, response} ->
        case Gemini.extract_text(response) do
          {:ok, text} ->
            IO.puts("  ✅ Success: #{String.slice(text, 0, 100)}...")

          {:error, error} ->
            IO.puts("  ❌ Text extraction failed: #{error}")
        end

      {:error, error} ->
        IO.puts("  ❌ Generation failed: #{inspect(error)}")
    end
  end

  defp test_model_listing(auth_type) do
    IO.puts("\n  📋 Testing model listing with #{auth_type}")

    case Gemini.list_models() do
      {:ok, response} ->
        model_count = length(response.models)
        IO.puts("  ✅ Found #{model_count} models")

        # Show first few model names
        model_names =
          response.models
          |> Enum.take(3)
          |> Enum.map(& &1.name)

        IO.puts("  First models: #{inspect(model_names)}")

      {:error, error} ->
        IO.puts("  ❌ Model listing failed: #{inspect(error)}")
    end
  end

  defp test_vertex_model_operations do
    IO.puts("\n  📋 Testing Vertex AI model operations")

    # For Vertex AI, we test specific model existence
    model_name = "gemini-flash-lite-latest"

    case Gemini.model_exists?(model_name) do
      {:ok, true} ->
        IO.puts("  ✅ Model #{model_name} exists")

        # Try to get model details
        case Gemini.get_model(model_name) do
          {:ok, model} ->
            IO.puts("  ✅ Model details: #{model.display_name || model.name}")

          {:error, error} ->
            IO.puts("  ⚠️  Model details failed: #{inspect(error)}")
        end

      {:ok, false} ->
        IO.puts("  ❌ Model #{model_name} does not exist")
    end
  end

  defp test_token_counting(auth_type) do
    IO.puts("\n  🔢 Testing token counting with #{auth_type}")

    test_text = "Hello, how are you doing today? This is a test message for token counting."

    case Gemini.count_tokens(test_text) do
      {:ok, response} ->
        IO.puts("  ✅ Token count: #{response.total_tokens} tokens")

      {:error, error} ->
        IO.puts("  ❌ Token counting failed: #{inspect(error)}")
    end
  end

  defp test_streaming do
    IO.puts("\n🌊 Testing Streaming Functionality")
    IO.puts("-" |> String.duplicate(40))

    # Test streaming with current auth config
    test_stream_generation()

    # Test managed streaming
    test_managed_streaming()
  end

  defp test_stream_generation do
    IO.puts("\n  🔄 Testing stream generation")

    prompt = "Write a very short poem about coding. Keep it under 50 words."

    case Gemini.stream_generate(prompt) do
      {:ok, responses} ->
        IO.puts("  ✅ Received #{length(responses)} stream responses")

        # Combine all text from stream
        all_text =
          responses
          |> Enum.map(&Gemini.extract_text/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, text} -> text end)
          |> Enum.join("")

        IO.puts("  📝 Streamed text: #{String.slice(all_text, 0, 200)}...")

      {:error, error} ->
        IO.puts("  ❌ Stream generation failed: #{inspect(error)}")
    end
  end

  defp test_managed_streaming do
    IO.puts("\n  🎛️  Testing managed streaming")

    # Start the streaming manager
    case Gemini.start_link() do
      {:ok, _} ->
        IO.puts("  ✅ Streaming manager started")

        prompt = "Count from 1 to 5, explaining each number briefly."

        case Gemini.start_stream(prompt) do
          {:ok, stream_id} ->
            IO.puts("  ✅ Started stream: #{stream_id}")

            # Subscribe to the stream
            :ok = Gemini.subscribe_stream(stream_id)
            IO.puts("  ✅ Subscribed to stream")

            # Wait for stream events
            # 5 second timeout
            collect_stream_events(stream_id, 0, 5000)

          {:error, error} ->
            IO.puts("  ❌ Failed to start managed stream: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("  ❌ Failed to start streaming manager: #{inspect(error)}")
    end
  end

  defp collect_stream_events(stream_id, event_count, timeout) do
    receive do
      {:stream_event, ^stream_id, event} ->
        # Show actual content instead of just keys
        content =
          case event do
            %{data: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}}]}} ->
              text

            %{data: data} ->
              "Data: #{inspect(data)}"

            %{error: error} ->
              "Error: #{inspect(error)}"

            _ ->
              "Event: #{inspect(event)}"
          end

        IO.puts(
          "  📦 Stream event #{event_count + 1}: #{String.slice(content, 0, 100)}#{if String.length(content) > 100, do: "...", else: ""}"
        )

        collect_stream_events(stream_id, event_count + 1, timeout)

      {:stream_complete, ^stream_id} ->
        IO.puts("  ✅ Stream completed with #{event_count} events")

      {:stream_error, ^stream_id, error} ->
        IO.puts("  ❌ Stream error: #{inspect(error)}")
    after
      timeout ->
        IO.puts("  ⏰ Stream timeout after #{event_count} events")

        # Check stream status
        case Gemini.get_stream_status(stream_id) do
          {:ok, status} ->
            IO.puts("  📊 Final stream status: #{status}")

          {:error, _} ->
            IO.puts("  📊 Stream status unavailable")
        end
    end
  end

  defp extract_project_from_service_account(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"project_id" => project_id}} -> project_id
          _ -> nil
        end

      _ ->
        nil
    end
  end
end

# Run all tests
LiveAPITest.run_all_tests()
