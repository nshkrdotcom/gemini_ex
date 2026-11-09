# Standalone Structured Outputs Example
# This version uses Mix.install and can be run from anywhere
#
# IMPORTANT: This example requires gemini_ex v0.4.0 or later!
# The structured_json/2 function is NEW in v0.4.0.
#
# To run during development (from the examples directory):
#   elixir structured_outputs_standalone.exs
#
# To use the published 0.19.0 release instead of this checkout:
#   {:gemini_ex, "~> 0.19.0"}

Mix.install([
  # Change to "~> 0.19.0" to use the published release
  {:gemini_ex, path: ".."},
  {:jason, "~> 1.4"}
])

defmodule BasicExample do
  alias Gemini.Config
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
           model: Config.default_model(),
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        IO.puts("✅ Answer: #{data["answer"]}")

        # Handle both integer and float confidence values
        confidence = data["confidence"]

        confidence_str =
          if is_float(confidence) do
            Float.round(confidence, 2)
          else
            confidence
          end

        IO.puts("   Confidence: #{confidence_str}")

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
