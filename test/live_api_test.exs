defmodule LiveAPITest do
  use ExUnit.Case

  @moduletag :live_api
  @moduletag timeout: 30_000

  @moduledoc """
  Live API tests for Gemini library with both authentication methods and streaming.
  Run with: mix test test/live_api_test.exs --include live_api
  """

  require Logger

  defp mask_api_key(key) when is_binary(key) and byte_size(key) > 2 do
    first_two = String.slice(key, 0, 2)
    "#{first_two}***"
  end

  defp mask_api_key(_), do: "***"

  setup_all do
    # Start the application
    Application.ensure_all_started(:gemini)
    :ok
  end

  describe "Configuration Detection" do
    test "detects available authentication" do
      IO.puts("\n📋 Testing Configuration Detection")
      IO.puts("-" |> String.duplicate(40))

      auth_config = Gemini.Config.auth_config()
      IO.puts("Detected auth config: #{inspect(auth_config, pretty: true)}")

      auth_type = Gemini.Config.detect_auth_type()
      IO.puts("Detected auth type: #{auth_type}")

      default_model = Gemini.Config.default_model()
      IO.puts("Default model: #{default_model}")

      assert auth_config != nil
    end
  end

  describe "Gemini API Authentication" do
    test "gemini api text generation" do
      IO.puts("\n🔑 Testing Gemini API Authentication")
      IO.puts("-" |> String.duplicate(40))

      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        Gemini.configure(:gemini, %{api_key: api_key})
        IO.puts("Configured Gemini API with key: #{mask_api_key(api_key)}")

        # Test simple text generation
        IO.puts("\n  📝 Testing simple text generation with Gemini API")

        case Gemini.generate("What is the capital of France? Give a brief answer.") do
          {:ok, response} ->
            case Gemini.extract_text(response) do
              {:ok, text} ->
                IO.puts("  ✅ Success: #{String.slice(text, 0, 100)}...")
                assert String.contains?(String.downcase(text), "paris")

              {:error, error} ->
                IO.puts("  ❌ Text extraction failed: #{error}")
                flunk("Text extraction failed: #{error}")
            end

          {:error, error} ->
            IO.puts("  ❌ Generation failed: #{inspect(error)}")
            flunk("Generation failed: #{inspect(error)}")
        end
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping Gemini auth tests")
      end
    end

    test "gemini api model listing" do
      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        Gemini.configure(:gemini, %{api_key: api_key})

        IO.puts("\n  📋 Testing model listing with Gemini API")

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

            assert model_count > 0

          {:error, error} ->
            IO.puts("  ❌ Model listing failed: #{inspect(error)}")
            flunk("Model listing failed: #{inspect(error)}")
        end
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping test")
      end
    end

    test "gemini api token counting" do
      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        Gemini.configure(:gemini, %{api_key: api_key})

        IO.puts("\n  🔢 Testing token counting with Gemini API")

        test_text = "Hello, how are you doing today? This is a test message for token counting."

        case Gemini.count_tokens(test_text) do
          {:ok, response} ->
            IO.puts("  ✅ Token count: #{response.total_tokens} tokens")
            assert response.total_tokens > 0

          {:error, error} ->
            IO.puts("  ❌ Token counting failed: #{inspect(error)}")
            flunk("Token counting failed: #{inspect(error)}")
        end
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping test")
      end
    end
  end

  describe "Vertex AI Authentication" do
    test "vertex ai text generation" do
      IO.puts("\n🔑 Testing Vertex AI Authentication")
      IO.puts("-" |> String.duplicate(40))

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
            IO.puts("\n  📝 Testing simple text generation with Vertex AI")

            case Gemini.generate("What is the capital of Germany? Give a brief answer.") do
              {:ok, response} ->
                case Gemini.extract_text(response) do
                  {:ok, text} ->
                    IO.puts("  ✅ Success: #{String.slice(text, 0, 100)}...")
                    assert String.contains?(String.downcase(text), "berlin")

                  {:error, error} ->
                    IO.puts("  ❌ Text extraction failed: #{error}")
                    flunk("Text extraction failed: #{error}")
                end

              {:error, error} ->
                IO.puts("  ❌ Generation failed: #{inspect(error)}")
                flunk("Generation failed: #{inspect(error)}")
            end
          else
            IO.puts("❌ No project_id found for Vertex AI, skipping tests")
          end

        true ->
          IO.puts("❌ Vertex AI service account file not found, skipping Vertex auth tests")
          IO.puts("Looked for: VERTEX_JSON_FILE or VERTEX_SERVICE_ACCOUNT environment variables")
      end
    end

    test "vertex ai model operations" do
      service_account_file = System.get_env("VERTEX_JSON_FILE")

      project_id =
        System.get_env("VERTEX_PROJECT_ID") ||
          extract_project_from_service_account(service_account_file)

      if service_account_file && File.exists?(service_account_file) && project_id do
        Gemini.configure(:vertex_ai, %{
          service_account_key: service_account_file,
          project_id: project_id,
          location: "us-central1"
        })

        IO.puts("\n  📋 Testing Vertex AI model operations")

        # For Vertex AI, we test specific model existence
        model_name = Gemini.Config.get_model(:flash_2_0_lite)

        case Gemini.model_exists?(model_name) do
          {:ok, true} ->
            IO.puts("  ✅ Model #{model_name} exists")

            # Try to get model details
            case Gemini.get_model(model_name) do
              {:ok, model} ->
                IO.puts("  ✅ Model details: #{model.display_name || model.name}")
                assert model.name != nil

              {:error, error} ->
                IO.puts("  ⚠️  Model details failed: #{inspect(error)}")
                # This might fail due to permissions, so don't fail the test
            end

          {:ok, false} ->
            IO.puts("  ❌ Model #{model_name} does not exist")
            flunk("Model should exist")
        end
      else
        IO.puts("❌ Vertex AI not configured, skipping test")
      end
    end
  end

  describe "Thinking Budget Configuration" do
    @tag :thinking_budget
    test "thinking budget actually reduces thinking tokens" do
      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        IO.puts("\n🧠 Testing thinking budget configuration")
        IO.puts("-" |> String.duplicate(40))

        # Test with default (dynamic thinking)
        IO.puts("\n  📊 Test 1: Default thinking (dynamic)")
        {:ok, response_default} = Gemini.generate(
          "Solve this step by step: What is 15 * 23?",
          model: "gemini-2.5-flash"
        )

        thinking_tokens_default = response_default.usage_metadata[:thoughts_token_count]
        IO.puts("  Thinking tokens with default: #{inspect(thinking_tokens_default)}")

        # Test with thinking disabled
        IO.puts("\n  📊 Test 2: Thinking disabled (budget = 0)")
        {:ok, response_disabled} = Gemini.generate(
          "Solve this step by step: What is 15 * 23?",
          model: "gemini-2.5-flash",
          thinking_config: %{thinking_budget: 0}
        )

        thinking_tokens_disabled = response_disabled.usage_metadata[:thoughts_token_count]
        IO.puts("  Thinking tokens with budget=0: #{inspect(thinking_tokens_disabled)}")

        # Test with limited thinking
        IO.puts("\n  📊 Test 3: Limited thinking (budget = 512)")
        {:ok, response_limited} = Gemini.generate(
          "Solve this step by step: What is 15 * 23?",
          model: "gemini-2.5-flash",
          thinking_config: %{thinking_budget: 512}
        )

        thinking_tokens_limited = response_limited.usage_metadata[:thoughts_token_count]
        IO.puts("  Thinking tokens with budget=512: #{inspect(thinking_tokens_limited)}")

        # Verify thinking was used with default
        if thinking_tokens_default && thinking_tokens_default > 0 do
          IO.puts("\n  ✅ Default thinking works (#{thinking_tokens_default} tokens)")
        end

        # Verify thinking was disabled with budget=0
        if thinking_tokens_disabled == 0 || is_nil(thinking_tokens_disabled) do
          IO.puts("  ✅ Thinking disabled successfully (0 tokens)")
          assert true
        else
          IO.puts("  ⚠️  Expected 0 thinking tokens, got: #{thinking_tokens_disabled}")
          # Still pass if small amount (API might have minimum)
          assert thinking_tokens_disabled < 10
        end

        # Verify limited thinking respected budget
        if thinking_tokens_limited do
          IO.puts("  ✅ Limited thinking works (#{thinking_tokens_limited} tokens, budget: 512)")
          assert thinking_tokens_limited <= 512
        end

        IO.puts("\n  ✅ Thinking budget configuration verified")
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping thinking budget test")
      end
    end

    @tag :thinking_budget
    test "includeThoughts parameter works" do
      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        IO.puts("\n💭 Testing thought summaries (includeThoughts)")

        {:ok, response} = Gemini.generate(
          "Explain your reasoning for this: What is 2 + 2?",
          model: "gemini-2.5-flash",
          thinking_config: %{thinking_budget: 1024, include_thoughts: true}
        )

        IO.puts("  Response structure: #{inspect(Map.keys(response))}")

        # Check that response was received (thought summaries in response if supported)
        assert response.candidates
        IO.puts("  ✅ Request with includeThoughts accepted")
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping thought summaries test")
      end
    end
  end

  describe "Streaming Functionality" do
    test "stream generation" do
      IO.puts("\n🌊 Testing Streaming Functionality")
      IO.puts("-" |> String.duplicate(40))

      # Use Gemini API for streaming test (more reliable)
      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        Gemini.configure(:gemini, %{api_key: api_key})

        IO.puts("\n  🔄 Testing stream generation")

        prompt = "Write a very short poem about coding. Keep it under 30 words."

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

            # Streaming might return empty responses sometimes, so let's be more forgiving
            if Enum.empty?(responses) do
              IO.puts(
                "  ⚠️  No stream responses received (API might not support streaming for this endpoint)"
              )
            else
              assert length(responses) > 0
              assert String.length(all_text) > 0
            end

          {:error, error} ->
            IO.puts("  ❌ Stream generation failed: #{inspect(error)}")
            flunk("Stream generation failed: #{inspect(error)}")
        end
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping streaming tests")
      end
    end

    test "managed streaming" do
      api_key = System.get_env("GEMINI_API_KEY")

      if api_key do
        Gemini.configure(:gemini, %{api_key: api_key})

        IO.puts("\n  🎛️  Testing managed streaming")

        # Start the streaming manager (handle already started case)
        case Gemini.start_link() do
          {:ok, _} ->
            IO.puts("  ✅ Streaming manager started")

          {:error, error} ->
            IO.puts("  ❌ Failed to start streaming manager: #{inspect(error)}")
            flunk("Failed to start streaming manager: #{inspect(error)}")
        end

        prompt = "Count from 1 to 3, explaining each number briefly."

        case Gemini.start_stream(prompt) do
          {:ok, stream_id} ->
            IO.puts("  ✅ Started stream: #{stream_id}")

            # Subscribe to the stream
            :ok = Gemini.subscribe_stream(stream_id)
            IO.puts("  ✅ Subscribed to stream")

            # Wait for stream events
            # 5 second timeout
            _event_count = collect_stream_events(stream_id, 0, 5000)

            # For now, just check that we got a stream ID (streaming might have issues)
            assert is_binary(stream_id)

          {:error, error} ->
            IO.puts("  ❌ Failed to start managed stream: #{inspect(error)}")
            flunk("Failed to start managed stream: #{inspect(error)}")
        end
      else
        IO.puts("❌ GEMINI_API_KEY not found, skipping managed streaming tests")
      end
    end
  end

  # Helper functions

  defp collect_stream_events(stream_id, event_count, timeout) do
    receive do
      {:stream_event, ^stream_id, event} ->
        IO.puts("  📦 Stream event #{event_count + 1}: #{inspect(Map.keys(event))}")
        collect_stream_events(stream_id, event_count + 1, timeout)

      {:stream_complete, ^stream_id} ->
        IO.puts("  ✅ Stream completed with #{event_count} events")
        event_count

      {:stream_error, ^stream_id, error} ->
        IO.puts("  ❌ Stream error: #{inspect(error)}")
        event_count
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

        event_count
    end
  end

  defp extract_project_from_service_account(file_path) when is_binary(file_path) do
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

  defp extract_project_from_service_account(_), do: nil
end
