# Safety Settings Example
# Run with: mix run examples/09_safety_settings.exs
#
# Demonstrates:
# - Configuring content safety filters
# - Understanding harm categories
# - Working with safety ratings in responses

defmodule SafetySettingsExample do
  alias Gemini.Types.SafetySetting

  def run do
    print_header("SAFETY SETTINGS")

    check_auth!()

    demo_default_safety()
    demo_custom_safety()
    demo_safety_categories()

    print_footer()
  end

  # ============================================================
  # Demo 1: Default Safety Behavior
  # ============================================================
  defp demo_default_safety do
    print_section("1. Default Safety Behavior")

    prompt = "Explain the history of cryptography and its importance in security."

    IO.puts("PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    case Gemini.generate(prompt) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("RESPONSE (first 200 chars):")
        IO.puts("  #{String.slice(text, 0, 200)}...")
        IO.puts("")

        # Show safety ratings if present
        if response.candidates && length(response.candidates) > 0 do
          candidate = hd(response.candidates)

          if candidate.safety_ratings && length(candidate.safety_ratings) > 0 do
            IO.puts("SAFETY RATINGS:")

            Enum.each(candidate.safety_ratings, fn rating ->
              category = rating.category || "UNKNOWN"
              probability = rating.probability || "UNKNOWN"
              IO.puts("  #{category}: #{probability}")
            end)
          else
            IO.puts("SAFETY RATINGS: (none returned)")
          end
        end

        IO.puts("")
        IO.puts("[OK] Default safety check complete")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Custom Safety Settings
  # ============================================================
  defp demo_custom_safety do
    print_section("2. Custom Safety Configuration")

    prompt = "Write a factual paragraph about medical symptoms of common cold."

    # Configure custom safety settings using convenience functions
    safety_settings = [
      SafetySetting.harassment(:block_only_high),
      SafetySetting.hate_speech(:block_only_high),
      SafetySetting.sexually_explicit(:block_medium_and_above),
      SafetySetting.dangerous_content(:block_medium_and_above)
    ]

    IO.puts("PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")
    IO.puts("SAFETY SETTINGS:")

    Enum.each(safety_settings, fn setting ->
      IO.puts("  #{setting.category}: #{setting.threshold}")
    end)

    IO.puts("")

    case Gemini.generate(prompt, safety_settings: safety_settings) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")
        IO.puts("[OK] Custom safety settings applied successfully")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 3: Safety Categories Explained
  # ============================================================
  defp demo_safety_categories do
    print_section("3. Safety Categories Reference")

    categories = [
      {:harassment, "Content that harasses or bullies individuals or groups"},
      {:hate_speech, "Content promoting hatred based on identity"},
      {:sexually_explicit, "Sexual content or nudity"},
      {:dangerous_content, "Content promoting harmful activities"}
    ]

    thresholds = [
      {:block_none, "No blocking (use with caution)"},
      {:block_only_high, "Block only high probability harmful content"},
      {:block_medium_and_above, "Block medium and high probability (default)"},
      {:block_low_and_above, "Block low, medium, and high probability"}
    ]

    IO.puts("HARM CATEGORIES:")
    IO.puts("")

    Enum.each(categories, fn {cat, desc} ->
      IO.puts("  #{cat}")
      IO.puts("    #{desc}")
      IO.puts("")
    end)

    IO.puts("THRESHOLD LEVELS:")
    IO.puts("")

    Enum.each(thresholds, fn {threshold, desc} ->
      IO.puts("  #{threshold}")
      IO.puts("    #{desc}")
      IO.puts("")
    end)

    IO.puts("EXAMPLE CONFIGURATION:")
    IO.puts("")

    example = """
      # Using convenience functions
      safety_settings = [
        SafetySetting.harassment(:block_only_high),
        SafetySetting.hate_speech(:block_medium_and_above),
        SafetySetting.sexually_explicit(:block_medium_and_above),
        SafetySetting.dangerous_content(:block_low_and_above)
      ]

      # Or use pre-configured defaults
      SafetySetting.defaults()    # Medium threshold for all categories
      SafetySetting.permissive()  # Block only high risk content

      Gemini.generate(prompt, safety_settings: safety_settings)
    """

    IO.puts(example)
    IO.puts("[OK] Safety reference complete")
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

SafetySettingsExample.run()
