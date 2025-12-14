# Basic Text Generation Example
# Run with: mix run examples/01_basic_generation.exs
#
# Demonstrates:
# - Simple text generation
# - Different generation configurations
# - Error handling patterns

defmodule BasicGenerationExample do
  alias Gemini.Types.GenerationConfig

  def run do
    print_header("BASIC TEXT GENERATION")

    check_auth!()

    demo_simple_generation()
    demo_configured_generation()
    demo_creative_vs_precise()

    print_footer()
  end

  # ============================================================
  # Demo 1: Simple Text Generation
  # ============================================================
  defp demo_simple_generation do
    print_section("1. Simple Text Generation")

    prompt = "Explain what Elixir programming language is in 2-3 sentences."

    IO.puts("PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    case Gemini.text(prompt) do
      {:ok, text} ->
        IO.puts("RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")
        IO.puts("[OK] Simple generation successful")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Configured Generation with Options
  # ============================================================
  defp demo_configured_generation do
    print_section("2. Generation with Configuration Options")

    prompt = "Write a haiku about functional programming."

    config = %GenerationConfig{
      temperature: 0.7,
      max_output_tokens: 100,
      top_p: 0.9
    }

    IO.puts("PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")
    IO.puts("CONFIG:")
    IO.puts("  temperature: #{config.temperature}")
    IO.puts("  max_output_tokens: #{config.max_output_tokens}")
    IO.puts("  top_p: #{config.top_p}")
    IO.puts("")

    case Gemini.generate(prompt, generation_config: config) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")

        # Show usage metadata if available
        if response.usage_metadata do
          IO.puts("USAGE METADATA:")
          IO.puts("  Prompt tokens: #{response.usage_metadata.prompt_token_count || "N/A"}")
          IO.puts("  Response tokens: #{response.usage_metadata.candidates_token_count || "N/A"}")
          IO.puts("  Total tokens: #{response.usage_metadata.total_token_count || "N/A"}")
        end

        IO.puts("")
        IO.puts("[OK] Configured generation successful")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 3: Creative vs Precise Mode
  # ============================================================
  defp demo_creative_vs_precise do
    print_section("3. Creative vs Precise Mode Comparison")

    prompt = "What is 15 multiplied by 7?"

    # Precise mode (low temperature)
    IO.puts("--- PRECISE MODE (temperature: 0.1) ---")
    precise_config = GenerationConfig.precise(max_output_tokens: 50)

    case Gemini.text(prompt, generation_config: precise_config) do
      {:ok, text} ->
        IO.puts("RESPONSE: #{text}")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")

    # Creative mode (high temperature)
    creative_prompt = "Describe a sunset in a creative, poetic way."

    IO.puts("--- CREATIVE MODE (temperature: 0.9) ---")
    IO.puts("PROMPT: #{creative_prompt}")
    creative_config = GenerationConfig.creative(max_output_tokens: 150)

    case Gemini.text(creative_prompt, generation_config: creative_config) do
      {:ok, text} ->
        IO.puts("RESPONSE: #{text}")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
    IO.puts("[OK] Creative vs precise comparison complete")
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

BasicGenerationExample.run()
