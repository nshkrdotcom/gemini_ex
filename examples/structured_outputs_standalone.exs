# Standalone Structured Outputs Example
# This version uses Mix.install and can be run from anywhere
# Run with: elixir structured_outputs_standalone.exs
#
# Note: Change the gemini_ex dependency to use the published version:
# {:gemini_ex, "~> 0.4.0"}

Mix.install([
  {:gemini_ex, "~> 0.3.1"},  # Update to 0.4.0 when published
  {:jason, "~> 1.4"}
])

defmodule BasicExample do
  alias Gemini.Types.GenerationConfig

  def run do
    IO.puts("\n🚀 Basic Structured Outputs Example\n")

    # Example 1: Simple Q&A
    schema = %{
      "type" => "object",
      "properties" => %{
        "answer" => %{"type" => "string"},
        "confidence" => %{"type" => "number", "minimum" => 0, "maximum" => 1}
      }
    }

    config = GenerationConfig.structured_json(schema)

    case Gemini.generate(
           "What is 2+2? Rate confidence.",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        IO.puts("✅ Answer: #{data["answer"]}")
        IO.puts("   Confidence: #{Float.round(data["confidence"], 2)}")

      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end
end

if System.get_env("GEMINI_API_KEY") do
  BasicExample.run()
else
  IO.puts("⚠️  Set GEMINI_API_KEY to run")
end
