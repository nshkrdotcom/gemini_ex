# Structured Outputs (JSON Schema) Example
# Run with: mix run examples/06_structured_outputs.exs
#
# Demonstrates:
# - JSON schema-constrained outputs
# - Structured data extraction
# - Type-safe responses

defmodule StructuredOutputsExample do
  alias Gemini.Types.GenerationConfig

  def run do
    print_header("STRUCTURED OUTPUTS (JSON SCHEMA)")

    check_auth!()

    demo_simple_schema()
    demo_entity_extraction()
    demo_classification()

    print_footer()
  end

  # ============================================================
  # Demo 1: Simple Schema (Q&A with Confidence)
  # ============================================================
  defp demo_simple_schema do
    print_section("1. Simple Schema - Q&A with Confidence")

    schema = %{
      "type" => "object",
      "properties" => %{
        "answer" => %{"type" => "string", "description" => "The answer to the question"},
        "confidence" => %{
          "type" => "number",
          "minimum" => 0,
          "maximum" => 1,
          "description" => "Confidence score 0-1"
        },
        "reasoning" => %{"type" => "string", "description" => "Brief explanation"}
      },
      "required" => ["answer", "confidence"]
    }

    IO.puts("JSON SCHEMA:")
    IO.puts("  #{Jason.encode!(schema, pretty: false) |> String.slice(0, 100)}...")
    IO.puts("")

    prompt = "What is the capital of France? Provide your answer with a confidence score."

    IO.puts("PROMPT:")
    IO.puts("  #{prompt}")
    IO.puts("")

    config = GenerationConfig.structured_json(schema)

    case Gemini.generate(prompt, generation_config: config) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        IO.puts("RAW JSON RESPONSE:")
        IO.puts("  #{text}")
        IO.puts("")

        case Jason.decode(text) do
          {:ok, data} ->
            IO.puts("PARSED DATA:")
            IO.puts("  Answer: #{data["answer"]}")
            IO.puts("  Confidence: #{data["confidence"]}")
            IO.puts("  Reasoning: #{Map.get(data, "reasoning", "N/A")}")
            IO.puts("")
            IO.puts("[OK] Structured output parsed successfully")

          {:error, _} ->
            IO.puts("[ERROR] Failed to parse JSON")
        end

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 2: Entity Extraction
  # ============================================================
  defp demo_entity_extraction do
    print_section("2. Entity Extraction from Text")

    schema = %{
      "type" => "object",
      "properties" => %{
        "people" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "role" => %{"type" => "string"}
            }
          }
        },
        "organizations" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "locations" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "dates" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        }
      }
    }

    text = """
    On January 15, 2024, CEO Sarah Johnson announced that TechCorp Inc. would be
    opening a new headquarters in Austin, Texas. The company, founded by John Smith
    in San Francisco, has been expanding rapidly since its Series B funding from
    Acme Ventures last March.
    """

    prompt =
      "Extract all entities (people, organizations, locations, dates) from this text:\n\n#{text}"

    IO.puts("INPUT TEXT:")
    IO.puts("  #{String.trim(text)}")
    IO.puts("")

    config = GenerationConfig.structured_json(schema)

    case Gemini.generate(prompt, generation_config: config) do
      {:ok, response} ->
        {:ok, json} = Gemini.extract_text(response)

        case Jason.decode(json) do
          {:ok, entities} ->
            IO.puts("EXTRACTED ENTITIES:")
            IO.puts("")

            IO.puts("  People:")

            (entities["people"] || [])
            |> Enum.each(fn person ->
              IO.puts("    - #{person["name"]} (#{person["role"] || "unknown role"})")
            end)

            IO.puts("")
            IO.puts("  Organizations:")
            (entities["organizations"] || []) |> Enum.each(&IO.puts("    - #{&1}"))

            IO.puts("")
            IO.puts("  Locations:")
            (entities["locations"] || []) |> Enum.each(&IO.puts("    - #{&1}"))

            IO.puts("")
            IO.puts("  Dates:")
            (entities["dates"] || []) |> Enum.each(&IO.puts("    - #{&1}"))

            IO.puts("")
            IO.puts("[OK] Entity extraction complete")

          {:error, _} ->
            IO.puts("[ERROR] Failed to parse JSON")
        end

      {:error, error} ->
        IO.puts("[ERROR] #{inspect(error)}")
    end

    IO.puts("")
  end

  # ============================================================
  # Demo 3: Classification with Scores
  # ============================================================
  defp demo_classification do
    print_section("3. Text Classification with Scores")

    schema = %{
      "type" => "object",
      "properties" => %{
        "sentiment" => %{
          "type" => "string",
          "enum" => ["positive", "negative", "neutral", "mixed"]
        },
        "sentiment_score" => %{
          "type" => "number",
          "minimum" => -1,
          "maximum" => 1
        },
        "topics" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "urgency" => %{
          "type" => "string",
          "enum" => ["low", "medium", "high", "critical"]
        }
      },
      "required" => ["sentiment", "sentiment_score", "topics", "urgency"]
    }

    texts = [
      "I absolutely love this product! It exceeded all my expectations.",
      "The service was okay, nothing special but got the job done.",
      "URGENT: Server is down! Production systems affected. Need immediate help!"
    ]

    config = GenerationConfig.structured_json(schema)

    Enum.with_index(texts, 1)
    |> Enum.each(fn {text, idx} ->
      IO.puts("TEXT #{idx}:")
      IO.puts("  \"#{text}\"")
      IO.puts("")

      prompt = "Classify this text for sentiment, topics, and urgency:\n\n#{text}"

      case Gemini.generate(prompt, generation_config: config) do
        {:ok, response} ->
          {:ok, json} = Gemini.extract_text(response)

          case Jason.decode(json) do
            {:ok, classification} ->
              IO.puts("  CLASSIFICATION:")

              IO.puts(
                "    Sentiment: #{classification["sentiment"]} (#{classification["sentiment_score"]})"
              )

              IO.puts("    Topics: #{Enum.join(classification["topics"] || [], ", ")}")
              IO.puts("    Urgency: #{classification["urgency"]}")

            {:error, _} ->
              IO.puts("  [ERROR] Failed to parse JSON")
          end

        {:error, error} ->
          IO.puts("  [ERROR] #{inspect(error)}")
      end

      IO.puts("")
    end)

    IO.puts("[OK] Classification complete")
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

StructuredOutputsExample.run()
