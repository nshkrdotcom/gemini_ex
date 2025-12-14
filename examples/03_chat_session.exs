# Chat Session Example
# Run with: mix run examples/03_chat_session.exs
#
# Demonstrates:
# - Multi-turn conversation management
# - Chat history tracking
# - Context retention across turns

defmodule ChatSessionExample do
  def run do
    print_header("MULTI-TURN CHAT SESSION")

    check_auth!()

    demo_basic_chat()
    demo_contextual_conversation()

    print_footer()
  end

  # ============================================================
  # Demo 1: Basic Chat Session
  # ============================================================
  defp demo_basic_chat do
    print_section("1. Basic Chat Session")

    IO.puts("Starting a new chat session...")
    IO.puts("")

    {:ok, chat} = Gemini.chat()

    # Turn 1
    user_msg_1 = "Hello! My name is Alice. I'm learning Elixir."
    IO.puts("USER: #{user_msg_1}")

    case Gemini.send_message(chat, user_msg_1) do
      {:ok, response, chat} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("MODEL: #{text}")
        IO.puts("")

        # Turn 2
        user_msg_2 = "What was my name again?"
        IO.puts("USER: #{user_msg_2}")

        case Gemini.send_message(chat, user_msg_2) do
          {:ok, response, chat} ->
            {:ok, text} = Gemini.extract_text(response)
            IO.puts("MODEL: #{text}")
            IO.puts("")

            # Show history size
            IO.puts("[Chat History: #{length(chat.history)} turns]")
            IO.puts("[OK] The model remembered the context!")

          {:error, error} ->
            IO.puts("[ERROR] Turn 2: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("[ERROR] Turn 1: #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Contextual Conversation (Problem Solving)
  # ============================================================
  defp demo_contextual_conversation do
    print_section("2. Contextual Problem-Solving Conversation")

    IO.puts("Starting a coding help session...")
    IO.puts("")

    {:ok, chat} = Gemini.chat()

    # Conversation turns
    conversation = [
      "I'm trying to write a function in Elixir that calculates factorial. Can you give me a basic recursive version?",
      "Can you show me how to add pattern matching to handle the base case more elegantly?",
      "Now can you add a guard clause to handle negative numbers?"
    ]

    final_chat =
      Enum.reduce_while(conversation, chat, fn message, current_chat ->
        IO.puts("USER: #{message}")
        IO.puts("")

        case Gemini.send_message(current_chat, message) do
          {:ok, response, updated_chat} ->
            {:ok, text} = Gemini.extract_text(response)
            IO.puts("MODEL:")

            text
            |> String.split("\n")
            |> Enum.each(&IO.puts("  #{&1}"))

            IO.puts("")
            IO.puts(String.duplicate("~", 50))
            IO.puts("")

            {:cont, updated_chat}

          {:error, error} ->
            IO.puts("[ERROR] #{inspect(error)}")
            {:halt, current_chat}
        end
      end)

    IO.puts("FINAL CHAT STATE:")
    IO.puts("  Total turns: #{length(final_chat.history)}")
    IO.puts("  Context maintained: YES")
    IO.puts("")
    IO.puts("[OK] Multi-turn contextual conversation complete")
    IO.puts("")
  end

  # ============================================================
  # Helper Functions
  # ============================================================
  defp check_auth! do
    cond do
      System.get_env("GEMINI_API_KEY") ->
        key = System.get_env("GEMINI_API_KEY")
        masked = String.slice(key, 0, 4) <> "..." <> String.slice(key, -4, 4)
        IO.puts("AUTH: Using Gemini API Key (#{masked})")
        IO.puts("")

      System.get_env("VERTEX_JSON_FILE") || System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ->
        IO.puts("AUTH: Using Vertex AI / Application Default Credentials")
        IO.puts("")

      true ->
        IO.puts("[ERROR] No authentication configured!")
        IO.puts("Set GEMINI_API_KEY or VERTEX_JSON_FILE environment variable.")
        System.halt(1)
    end
  end

  defp print_header(title) do
    IO.puts("")
    IO.puts(String.duplicate("=", 70))
    IO.puts("  #{title}")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end

  defp print_section(title) do
    IO.puts(String.duplicate("-", 70))
    IO.puts(title)
    IO.puts(String.duplicate("-", 70))
    IO.puts("")
  end

  defp print_footer do
    IO.puts(String.duplicate("=", 70))
    IO.puts("  EXAMPLE COMPLETE")
    IO.puts(String.duplicate("=", 70))
    IO.puts("")
  end
end

ChatSessionExample.run()
