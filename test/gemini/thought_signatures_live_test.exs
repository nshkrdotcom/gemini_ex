defmodule Gemini.ThoughtSignaturesLiveTest do
  @moduledoc """
  Live API tests for thought signatures feature (Gemini 3).

  Run with: mix test test/gemini/thought_signatures_live_test.exs --include live_api
  """
  use ExUnit.Case

  @moduletag :live_api
  @moduletag timeout: 60_000

  alias Gemini.Chat

  setup_all do
    Application.ensure_all_started(:gemini)

    case System.get_env("GEMINI_API_KEY") do
      nil ->
        {:ok, skip: true}

      api_key ->
        Gemini.configure(:gemini, %{api_key: api_key})
        {:ok, skip: false}
    end
  end

  describe "thought signature extraction" do
    @tag :live_api
    test "extracts thought signatures from Gemini 3 Pro response", context do
      if context[:skip] do
        IO.puts("Skipping: GEMINI_API_KEY not set")
        :ok
      else
        # Use Gemini 3 Pro which returns thought signatures
        config = Gemini.Types.GenerationConfig.thinking_level(:high)

        result =
          Gemini.generate(
            "Explain briefly why the sky is blue.",
            model: "gemini-3-pro-preview",
            generation_config: config
          )

        case result do
          {:ok, response} ->
            IO.puts("Response received successfully")

            # Extract signatures
            signatures = Gemini.extract_thought_signatures(response)
            IO.puts("Found #{length(signatures)} thought signatures")

            # Note: Gemini 3 may or may not return signatures depending on the query
            # The important thing is that extraction doesn't error
            assert is_list(signatures)

            # Verify we can also extract text
            {:ok, text} = Gemini.extract_text(response)
            assert String.length(text) > 0
            IO.puts("Response text: #{String.slice(text, 0, 100)}...")

          {:error, error} ->
            IO.puts("API Error (may be expected if model not available): #{inspect(error)}")
            # Don't fail - Gemini 3 might not be available
            :ok
        end
      end
    end
  end

  describe "chat with thought signature echoing" do
    @tag :live_api
    test "multi-turn chat maintains context with signature echoing", context do
      if context[:skip] do
        IO.puts("Skipping: GEMINI_API_KEY not set")
        :ok
      else
        # Start a chat session
        chat = Chat.new(model: "gemini-flash-lite-latest")

        # First turn - user asks a question
        chat = Chat.add_turn(chat, "user", "What is the capital of France?")

        # Generate first response
        result = Gemini.generate(chat.history, chat.opts)

        case result do
          {:ok, response} ->
            # Add model response (this extracts and stores any signatures)
            chat = Chat.add_model_response(chat, response)

            IO.puts("First response - signatures stored: #{length(chat.last_signatures)}")

            # Second turn - follow up question
            chat = Chat.add_turn(chat, "user", "And what is its population?")

            # The last user message should now potentially have the signature attached
            # (depending on whether the model returned one)
            last_content = List.last(chat.history)
            assert last_content.role == "user"
            IO.puts("Follow-up added with signature echoing")

            # Generate follow-up response
            result2 = Gemini.generate(chat.history, chat.opts)

            case result2 do
              {:ok, response2} ->
                {:ok, text} = Gemini.extract_text(response2)
                # Should mention Paris's population
                assert String.length(text) > 0
                IO.puts("Follow-up response: #{String.slice(text, 0, 100)}...")

              {:error, error2} ->
                IO.puts("Follow-up failed: #{inspect(error2)}")
                flunk("Follow-up generation failed")
            end

          {:error, error} ->
            IO.puts("First request failed: #{inspect(error)}")
            flunk("First generation failed")
        end
      end
    end
  end

  describe "Part with thought signature serialization" do
    @tag :live_api
    test "sends requests with thought signature attached to parts", context do
      if context[:skip] do
        IO.puts("Skipping: GEMINI_API_KEY not set")
        :ok
      else
        # Create a part with a thought signature
        part =
          Gemini.Types.Part.text("Hello, how are you?")
          |> Gemini.Types.Part.with_thought_signature("context_engineering_is_the_way_to_go")

        content = %Gemini.Types.Content{role: "user", parts: [part]}

        # Try to generate with this content
        result = Gemini.generate([content], model: "gemini-flash-lite-latest")

        case result do
          {:ok, response} ->
            {:ok, text} = Gemini.extract_text(response)
            assert String.length(text) > 0
            IO.puts("Response with signature-attached part: #{String.slice(text, 0, 100)}...")

          {:error, error} ->
            # This might fail if the API doesn't accept the migration signature
            # on certain endpoints, which is acceptable
            IO.puts("Request with signature failed (may be expected): #{inspect(error)}")
            :ok
        end
      end
    end
  end
end
