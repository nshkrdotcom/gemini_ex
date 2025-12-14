# Token Counting Example
# Run with: mix run examples/08_token_counting.exs
#
# Demonstrates:
# - Counting tokens in text
# - Understanding token usage for cost estimation
# - Comparing token counts across different content types

defmodule TokenCountingExample do
  def run do
    print_header("TOKEN COUNTING")

    check_auth!()

    demo_basic_counting()
    demo_text_lengths()
    demo_code_vs_prose()

    print_footer()
  end

  # ============================================================
  # Demo 1: Basic Token Counting
  # ============================================================
  defp demo_basic_counting do
    print_section("1. Basic Token Counting")

    texts = [
      "Hello, world!",
      "What is the meaning of life?",
      "Elixir is a functional programming language built on the Erlang VM."
    ]

    IO.puts("COUNTING TOKENS IN SAMPLE TEXTS:")
    IO.puts("")

    Enum.each(texts, fn text ->
      IO.puts("TEXT: \"#{text}\"")

      case Gemini.count_tokens(text) do
        {:ok, result} ->
          total = result.total_tokens || result["totalTokens"] || 0
          char_count = String.length(text)
          chars_per_token = if total > 0, do: Float.round(char_count / total, 1), else: 0

          IO.puts("  Characters: #{char_count}")
          IO.puts("  Tokens: #{total}")
          IO.puts("  Chars/Token: #{chars_per_token}")

        {:error, error} ->
          IO.puts("  [ERROR] #{inspect(error)}")
      end

      IO.puts("")
    end)

    IO.puts("[OK] Basic counting complete")
    IO.puts("")
  end

  # ============================================================
  # Demo 2: Text Length Comparison
  # ============================================================
  defp demo_text_lengths do
    print_section("2. Token Count vs Text Length")

    # Generate texts of increasing length
    base = "The quick brown fox jumps over the lazy dog. "

    lengths = [1, 5, 10, 20]

    IO.puts("Comparing token counts for repeated sentences:")
    IO.puts("")
    IO.puts("  Repetitions  |  Characters  |  Tokens  |  Tokens/100chars")
    IO.puts("  " <> String.duplicate("-", 55))

    Enum.each(lengths, fn reps ->
      text = String.duplicate(base, reps)
      char_count = String.length(text)

      case Gemini.count_tokens(text) do
        {:ok, result} ->
          total = result.total_tokens || result["totalTokens"] || 0
          tokens_per_100 = Float.round(total / char_count * 100, 1)

          IO.puts(
            "  #{String.pad_leading(Integer.to_string(reps), 10)}  |  " <>
              "#{String.pad_leading(Integer.to_string(char_count), 10)}  |  " <>
              "#{String.pad_leading(Integer.to_string(total), 6)}  |  " <>
              "#{tokens_per_100}"
          )

        {:error, _} ->
          IO.puts("  #{reps}  |  ERROR")
      end
    end)

    IO.puts("")

    IO.puts(
      "NOTE: Token efficiency varies by content - repetitive text may tokenize differently."
    )

    IO.puts("")
    IO.puts("[OK] Length comparison complete")
    IO.puts("")
  end

  # ============================================================
  # Demo 3: Code vs Prose
  # ============================================================
  defp demo_code_vs_prose do
    print_section("3. Code vs Prose Token Comparison")

    prose = """
    To calculate the factorial of a number, you multiply that number by every positive
    integer less than itself down to one. For example, the factorial of five is calculated
    by multiplying five times four times three times two times one, which equals one hundred
    twenty. This mathematical operation is commonly used in statistics and combinatorics.
    """

    code = """
    defmodule Math do
      def factorial(0), do: 1
      def factorial(n) when n > 0 do
        n * factorial(n - 1)
      end
    end

    # Example: Math.factorial(5) => 120
    """

    comparisons = [
      {"Prose (English text)", String.trim(prose)},
      {"Code (Elixir)", String.trim(code)}
    ]

    IO.puts("Comparing token efficiency for different content types:")
    IO.puts("")

    Enum.each(comparisons, fn {label, text} ->
      IO.puts("#{label}:")
      IO.puts(String.duplicate("-", 40))

      # Show first 100 chars
      preview = String.slice(text, 0, 80) |> String.replace("\n", " ")
      IO.puts("  Preview: \"#{preview}...\"")

      case Gemini.count_tokens(text) do
        {:ok, result} ->
          total = result.total_tokens || result["totalTokens"] || 0
          char_count = String.length(text)
          word_count = text |> String.split(~r/\s+/) |> length()

          IO.puts("  Characters: #{char_count}")
          IO.puts("  Words: #{word_count}")
          IO.puts("  Tokens: #{total}")
          IO.puts("  Chars/Token: #{Float.round(char_count / max(total, 1), 1)}")
          IO.puts("  Words/Token: #{Float.round(word_count / max(total, 1), 2)}")

        {:error, error} ->
          IO.puts("  [ERROR] #{inspect(error)}")
      end

      IO.puts("")
    end)

    IO.puts("INSIGHT:")
    IO.puts("  Code often has higher token density due to special characters,")
    IO.puts("  indentation, and symbolic names. Consider this for cost estimation.")
    IO.puts("")
    IO.puts("[OK] Comparison complete")
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

TokenCountingExample.run()
