# System Instructions Example
# Run with: mix run examples/10_system_instructions.exs
#
# Demonstrates:
# - Setting system-level instructions
# - Controlling model behavior and persona
# - Consistent response formatting

defmodule SystemInstructionsExample do
  def run do
    print_header("SYSTEM INSTRUCTIONS")

    check_auth!()

    demo_persona_instruction()
    demo_formatting_instruction()
    demo_expert_instruction()

    print_footer()
  end

  # ============================================================
  # Demo 1: Persona-Based System Instruction
  # ============================================================
  defp demo_persona_instruction do
    print_section("1. Persona-Based Instruction")

    system_instruction = """
    You are a friendly pirate captain named Captain Code. You always:
    - Speak in pirate dialect (arrr, matey, ye, etc.)
    - Reference sailing and the sea in your explanations
    - End responses with a pirate saying
    Keep responses brief and fun.
    """

    prompt = "Explain what a variable is in programming."

    IO.puts("SYSTEM INSTRUCTION:")
    IO.puts("  #{String.trim(system_instruction)}")
    IO.puts("")
    IO.puts("USER PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    case Gemini.generate(prompt, system_instruction: system_instruction) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")
        IO.puts("[OK] Persona instruction applied successfully")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Formatting Instruction
  # ============================================================
  defp demo_formatting_instruction do
    print_section("2. Response Formatting Instruction")

    system_instruction = """
    Always format your responses as follows:
    1. Start with a one-line SUMMARY in bold (use **text**)
    2. Follow with DETAILS in bullet points
    3. End with a KEY TAKEAWAY section
    Be concise and technical.
    """

    prompt = "What is recursion in programming?"

    IO.puts("SYSTEM INSTRUCTION:")
    IO.puts("  #{String.trim(system_instruction)}")
    IO.puts("")
    IO.puts("USER PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    case Gemini.generate(prompt, system_instruction: system_instruction) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("RESPONSE:")

        text
        |> String.split("\n")
        |> Enum.each(&IO.puts("  #{&1}"))

        IO.puts("")
        IO.puts("[OK] Formatting instruction applied successfully")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 3: Expert Domain Instruction
  # ============================================================
  defp demo_expert_instruction do
    print_section("3. Domain Expert Instruction")

    system_instruction = """
    You are a senior Elixir developer with 10 years of experience. You:
    - Provide idiomatic Elixir code examples
    - Explain OTP patterns when relevant
    - Consider performance and scalability
    - Reference official Elixir documentation patterns
    - Use proper @doc and @spec annotations in examples
    """

    prompt = "How do I implement a GenServer that caches API responses?"

    IO.puts("SYSTEM INSTRUCTION:")
    IO.puts("  #{String.trim(system_instruction)}")
    IO.puts("")
    IO.puts("USER PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    case Gemini.generate(prompt, system_instruction: system_instruction) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("RESPONSE:")
        IO.puts("")

        text
        |> String.split("\n")
        |> Enum.each(&IO.puts("  #{&1}"))

        IO.puts("")
        IO.puts("[OK] Domain expert instruction applied successfully")

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

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

SystemInstructionsExample.run()
