# Demo script for the Gemini Elixir client
# Run with: mix run examples/demo.exs
# Requires GEMINI_API_KEY environment variable

defmodule GeminiDemo do
  alias Gemini.Types.GenerationConfig

  defp format_error(error) do
    cond do
      is_map(error) and Map.has_key?(error, "message") -> error["message"]
      is_binary(error) -> error
      true -> inspect(error)
    end
  end

  defp mask_api_key(key) when is_binary(key) and byte_size(key) > 2 do
    first_two = String.slice(key, 0, 2)
    "#{first_two}***"
  end

  defp mask_api_key(_key), do: "***"

  def run do
    IO.puts("🤖 Gemini Elixir Client Demo")
    IO.puts("=" <> String.duplicate("=", 50))

    # Check if API key is configured
    case Gemini.Config.api_key() do
      nil ->
        IO.puts("❌ No API key found. Please set GEMINI_API_KEY environment variable.")
        System.halt(1)

      key ->
        IO.puts("✅ API key configured: #{mask_api_key(key)}")
    end

    demo_models()
    demo_simple_generation()
    demo_configured_generation()
    demo_chat_session()
    demo_token_counting()

    IO.puts("\n🎉 Demo completed!")
  end

  defp demo_models do
    section("Model Information")

    IO.puts("Listing available models...")

    case Gemini.list_models() do
      {:ok, response} ->
        models = Map.get(response, "models", [])
        IO.puts("Found #{length(models)} models:")

        models
        |> Enum.take(3)
        |> Enum.each(fn model ->
          display_name = Map.get(model, "displayName", "Unknown")
          name = Map.get(model, "name", "Unknown")
          input_limit = Map.get(model, "inputTokenLimit", 0)
          output_limit = Map.get(model, "outputTokenLimit", 0)
          IO.puts("  • #{display_name} (#{name})")
          IO.puts("    Input limit: #{format_number(input_limit)} tokens")
          IO.puts("    Output limit: #{format_number(output_limit)} tokens")
        end)

      {:error, error} ->
        IO.puts("❌ Error listing models: #{format_error(error)}")
    end

    IO.puts("\nChecking specific model...")

    case Gemini.get_model(Gemini.Config.get_model(:flash_lite_latest)) do
      {:ok, model} ->
        display_name = Map.get(model, "displayName", "Unknown")
        description = Map.get(model, "description", "No description")
        IO.puts("✅ Found #{display_name}")
        IO.puts("   #{description}")

      {:error, error} ->
        IO.puts("❌ Error getting model: #{format_error(error)}")
    end
  end

  defp demo_simple_generation do
    section("Simple Text Generation")

    prompts = [
      "Write a haiku about programming",
      "Explain quantum computing in one sentence",
      "What's the capital of Japan?"
    ]

    Enum.each(prompts, fn prompt ->
      IO.puts("💭 Prompt: #{prompt}")

      case Gemini.text(prompt) do
        {:ok, text} ->
          IO.puts("🤖 Response: #{text}")

        {:error, error} ->
          IO.puts("❌ Error: #{format_error(error)}")
      end

      IO.puts("")
    end)
  end

  defp demo_configured_generation do
    section("Configured Generation")

    # Creative mode
    IO.puts("🎨 Creative mode (high temperature):")
    config = GenerationConfig.creative(max_output_tokens: 100)

    case Gemini.text("Write a creative opening line for a sci-fi novel",
           generation_config: config
         ) do
      {:ok, text} ->
        IO.puts("🤖 #{text}")

      {:error, error} ->
        IO.puts("❌ Error: #{format_error(error)}")
    end

    # Precise mode
    IO.puts("\n🎯 Precise mode (low temperature):")
    config = GenerationConfig.precise(max_output_tokens: 50)

    case Gemini.text("What is 15 * 23?", generation_config: config) do
      {:ok, text} ->
        IO.puts("🤖 #{text}")

      {:error, error} ->
        IO.puts("❌ Error: #{format_error(error)}")
    end
  end

  defp demo_chat_session do
    section("Chat Session")

    {:ok, chat} = Gemini.chat()
    IO.puts("💬 Starting chat session...")

    # First message
    case Gemini.send_message(chat, "Hi! I'm learning about Elixir. Can you help?") do
      {:ok, response, chat} ->
        case Gemini.extract_text(response) do
          {:ok, text} ->
            IO.puts("🧑 User: Hi! I'm learning about Elixir. Can you help?")
            IO.puts("🤖 Assistant: #{text}")

            # Follow-up message
            case Gemini.send_message(
                   chat,
                   "What's the difference between processes and threads in Elixir?"
                 ) do
              {:ok, response, _chat} ->
                case Gemini.extract_text(response) do
                  {:ok, text} ->
                    IO.puts(
                      "\n🧑 User: What's the difference between processes and threads in Elixir?"
                    )

                    IO.puts("🤖 Assistant: #{text}")

                  {:error, error} ->
                    IO.puts("❌ Error extracting text: #{format_error(error)}")
                end

              {:error, error} ->
                IO.puts("❌ Error in follow-up message: #{format_error(error)}")
            end

          {:error, error} ->
            IO.puts("❌ Error extracting text: #{format_error(error)}")
        end

      {:error, error} ->
        IO.puts("❌ Error sending message: #{format_error(error)}")
    end
  end

  defp demo_token_counting do
    section("Token Counting")

    texts = [
      "Hello, world!",
      "This is a longer message that should use more tokens than the simple greeting above.",
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris."
    ]

    Enum.each(texts, fn text ->
      case Gemini.count_tokens(text) do
        {:ok, count} ->
          total_tokens = Map.get(count, "totalTokens", 0)

          IO.puts(
            "📝 Text: \"#{String.slice(text, 0, 50)}#{if String.length(text) > 50, do: "...", else: ""}\""
          )

          IO.puts("🔢 Tokens: #{total_tokens}")

        {:error, error} ->
          IO.puts("❌ Error counting tokens: #{format_error(error)}")
      end

      IO.puts("")
    end)
  end

  defp section(title) do
    IO.puts("\n" <> title)
    IO.puts(String.duplicate("-", String.length(title)))
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end

# Run the demo
GeminiDemo.run()
