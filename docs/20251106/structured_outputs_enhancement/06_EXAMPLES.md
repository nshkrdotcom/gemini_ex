# Examples - Structured Outputs Enhancement

**Document:** Code Examples
**Initiative:** `structured_outputs_enhancement`
**Date:** November 6, 2025

---

## Overview

This document contains complete, runnable examples demonstrating all structured outputs features. Each example is production-ready and includes error handling.

---

## Example 1: Basic Structured Output

**File:** `examples/structured_outputs_basic.exs`

```elixir
Mix.install([
  {:gemini_ex, "~> 0.4.0"},
  {:jason, "~> 1.4"}
])

defmodule BasicStructuredOutput do
  @moduledoc """
  Basic example of structured outputs using the Gemini API.

  This example demonstrates:
  - Simple schema definition
  - Using the structured_json helper
  - Parsing and validating results
  """

  alias Gemini.Types.GenerationConfig

  def run do
    IO.puts("\n🚀 Basic Structured Outputs Example\n")

    # Example 1: Simple Q&A with confidence
    example_qa()

    # Example 2: Person extraction
    example_person()

    # Example 3: Product review analysis
    example_review()
  end

  defp example_qa do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Example 1: Q&A with Confidence")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "answer" => %{
          "type" => "string",
          "description" => "The answer to the question"
        },
        "confidence" => %{
          "type" => "number",
          "minimum" => 0.0,
          "maximum" => 1.0,
          "description" => "Confidence score from 0 to 1"
        }
      },
      "required" => ["answer", "confidence"]
    }

    config = GenerationConfig.structured_json(schema)

    case Gemini.generate(
           "What is the capital of France? Rate your confidence.",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        IO.puts("\n✅ Response:")
        IO.puts("   Answer: #{data["answer"]}")
        IO.puts("   Confidence: #{Float.round(data["confidence"], 2)}")

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end

  defp example_person do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Example 2: Person Extraction")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{
          "type" => "string",
          "description" => "Full name"
        },
        "age" => %{
          "type" => "integer",
          "minimum" => 0,
          "maximum" => 120,
          "description" => "Age in years"
        },
        "email" => %{
          "type" => "string",
          "format" => "email",
          "description" => "Email address"
        },
        "location" => %{
          "type" => "string",
          "description" => "City and country"
        }
      },
      "required" => ["name"]
    }

    config = GenerationConfig.structured_json(schema)

    text = "John Smith is 35 years old. He lives in Paris, France and his email is john@example.com"

    case Gemini.generate(
           "Extract person information: #{text}",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, person} = Jason.decode(text)

        IO.puts("\n✅ Extracted Person:")
        IO.puts("   Name: #{person["name"]}")
        IO.puts("   Age: #{person["age"]}")
        IO.puts("   Email: #{person["email"]}")
        IO.puts("   Location: #{person["location"]}")

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end

  defp example_review do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Example 3: Product Review Analysis")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "sentiment" => %{
          "type" => "string",
          "enum" => ["very_negative", "negative", "neutral", "positive", "very_positive"],
          "description" => "Overall sentiment"
        },
        "rating" => %{
          "type" => "integer",
          "minimum" => 1,
          "maximum" => 5,
          "description" => "Star rating 1-5"
        },
        "pros" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Positive aspects"
        },
        "cons" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Negative aspects"
        }
      },
      "required" => ["sentiment", "rating"]
    }

    config = GenerationConfig.structured_json(schema)

    review = """
    I absolutely love this product! The quality is outstanding and it exceeded my expectations.
    The only minor issue is that it took a while to arrive, but it was worth the wait.
    """

    case Gemini.generate(
           "Analyze this review: #{review}",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, analysis} = Jason.decode(text)

        IO.puts("\n✅ Review Analysis:")
        IO.puts("   Sentiment: #{analysis["sentiment"]}")
        IO.puts("   Rating: #{String.duplicate("⭐", analysis["rating"])}")
        IO.puts("   Pros: #{Enum.join(analysis["pros"] || [], ", ")}")
        IO.puts("   Cons: #{Enum.join(analysis["cons"] || [], ", ")}")

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end
end

# Run if executed directly
if System.get_env("GEMINI_API_KEY") do
  BasicStructuredOutput.run()
else
  IO.puts("⚠️  Set GEMINI_API_KEY environment variable to run this example")
end
```

---

## Example 2: Advanced Features

**File:** `examples/structured_outputs_advanced.exs`

```elixir
Mix.install([
  {:gemini_ex, "~> 0.4.0"},
  {:jason, "~> 1.4"}
])

defmodule AdvancedStructuredOutput do
  @moduledoc """
  Advanced examples demonstrating new JSON Schema features.

  Demonstrates:
  - Union types with anyOf
  - Recursive schemas with $ref
  - Numeric constraints
  - Tuple arrays with prefixItems
  - Nullable fields
  """

  alias Gemini.Types.GenerationConfig

  def run do
    IO.puts("\n🚀 Advanced Structured Outputs Example\n")

    example_union_types()
    example_recursive_schema()
    example_numeric_constraints()
    example_tuple_arrays()
  end

  defp example_union_types do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Example 1: Union Types with anyOf")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "result" => %{
          "anyOf" => [
            # Success case
            %{
              "type" => "object",
              "properties" => %{
                "status" => %{"type" => "string", "const" => "success"},
                "data" => %{"type" => "string"}
              },
              "required" => ["status", "data"]
            },
            # Error case
            %{
              "type" => "object",
              "properties" => %{
                "status" => %{"type" => "string", "const" => "error"},
                "error_message" => %{"type" => "string"}
              },
              "required" => ["status", "error_message"]
            }
          ]
        }
      }
    }

    config = GenerationConfig.structured_json(schema)

    # Try with a successful scenario
    case Gemini.generate(
           "Process this request successfully: 'Calculate 2+2'",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        IO.puts("\n✅ Union Type Response:")

        case data["result"] do
          %{"status" => "success", "data" => result} ->
            IO.puts("   Status: Success")
            IO.puts("   Data: #{result}")

          %{"status" => "error", "error_message" => msg} ->
            IO.puts("   Status: Error")
            IO.puts("   Message: #{msg}")
        end

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end

  defp example_recursive_schema do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Example 2: Recursive Schema with $ref")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "$defs" => %{
        "Comment" => %{
          "type" => "object",
          "properties" => %{
            "author" => %{"type" => "string"},
            "text" => %{"type" => "string"},
            "replies" => %{
              "type" => "array",
              "items" => %{"$ref" => "#/$defs/Comment"}
            }
          },
          "required" => ["author", "text"]
        }
      },
      "type" => "object",
      "properties" => %{
        "thread" => %{"$ref" => "#/$defs/Comment"}
      }
    }

    config = GenerationConfig.structured_json(schema)

    prompt = """
    Create a comment thread:
    - Alice says "Great post!"
    - Bob replies to Alice "Thanks!"
    - Carol also replies to Alice "I agree!"
    """

    case Gemini.generate(prompt, model: "gemini-2.5-flash", generation_config: config) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        IO.puts("\n✅ Recursive Structure:")
        print_comment(data["thread"], 0)

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end

  defp print_comment(comment, indent) do
    prefix = String.duplicate("  ", indent)
    IO.puts("#{prefix}#{comment["author"]}: #{comment["text"]}")

    (comment["replies"] || [])
    |> Enum.each(&print_comment(&1, indent + 1))
  end

  defp example_numeric_constraints do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Example 3: Numeric Constraints")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "age" => %{
          "type" => "integer",
          "minimum" => 0,
          "maximum" => 120,
          "description" => "Age in years"
        },
        "score" => %{
          "type" => "integer",
          "minimum" => 0,
          "maximum" => 100,
          "description" => "Test score percentage"
        },
        "confidence" => %{
          "type" => "number",
          "minimum" => 0.0,
          "maximum" => 1.0,
          "description" => "Confidence level"
        },
        "price" => %{
          "type" => "number",
          "minimum" => 0,
          "exclusiveMinimum" => true,
          "description" => "Price must be positive"
        }
      }
    }

    config = GenerationConfig.structured_json(schema)

    case Gemini.generate(
           "Generate sample data: age 25, score 85/100, confidence 0.9, price $29.99",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        IO.puts("\n✅ Constrained Numbers:")
        IO.puts("   Age: #{data["age"]} (must be 0-120)")
        IO.puts("   Score: #{data["score"]} (must be 0-100)")
        IO.puts("   Confidence: #{data["confidence"]} (must be 0.0-1.0)")
        IO.puts("   Price: $#{data["price"]} (must be > 0)")

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end

  defp example_tuple_arrays do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Example 4: Tuple Arrays with prefixItems")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "location" => %{
          "type" => "array",
          "prefixItems" => [
            %{
              "type" => "number",
              "minimum" => -90,
              "maximum" => 90,
              "description" => "Latitude"
            },
            %{
              "type" => "number",
              "minimum" => -180,
              "maximum" => 180,
              "description" => "Longitude"
            }
          ],
          "items" => false,
          "minItems" => 2,
          "maxItems" => 2
        },
        "color" => %{
          "type" => "array",
          "prefixItems" => [
            %{"type" => "integer", "minimum" => 0, "maximum" => 255},
            %{"type" => "integer", "minimum" => 0, "maximum" => 255},
            %{"type" => "integer", "minimum" => 0, "maximum" => 255}
          ],
          "items" => false
        }
      }
    }

    config = GenerationConfig.structured_json(schema)

    case Gemini.generate(
           "Generate: Paris coordinates (48.8566, 2.3522) and blue color RGB (0, 0, 255)",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, data} = Jason.decode(text)

        [lat, lon] = data["location"]
        [r, g, b] = data["color"]

        IO.puts("\n✅ Tuple Arrays:")
        IO.puts("   Location: [#{lat}, #{lon}] (latitude, longitude)")
        IO.puts("   Color: RGB(#{r}, #{g}, #{b})")

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end
end

# Run if executed directly
if System.get_env("GEMINI_API_KEY") do
  AdvancedStructuredOutput.run()
else
  IO.puts("⚠️  Set GEMINI_API_KEY environment variable to run this example")
end
```

---

## Example 3: Real-World Use Cases

**File:** `examples/structured_outputs_real_world.exs`

```elixir
Mix.install([
  {:gemini_ex, "~> 0.4.0"},
  {:jason, "~> 1.4"}
])

defmodule RealWorldExamples do
  @moduledoc """
  Production-ready examples for common use cases.

  Includes:
  - Invoice extraction
  - Content moderation
  - Sentiment analysis
  - Resume parsing
  """

  alias Gemini.Types.GenerationConfig

  def run do
    IO.puts("\n🚀 Real-World Structured Outputs Examples\n")

    example_invoice()
    example_content_moderation()
    example_resume_parsing()
  end

  defp example_invoice do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Use Case 1: Invoice Extraction")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "invoice_number" => %{"type" => "string"},
        "date" => %{"type" => "string", "format" => "date"},
        "vendor" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "address" => %{"type" => "string"}
          }
        },
        "total" => %{
          "type" => "number",
          "minimum" => 0
        },
        "items" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "description" => %{"type" => "string"},
              "quantity" => %{"type" => "integer", "minimum" => 1},
              "unit_price" => %{"type" => "number", "minimum" => 0},
              "total" => %{"type" => "number", "minimum" => 0}
            },
            "required" => ["description", "quantity", "unit_price"]
          }
        }
      },
      "required" => ["invoice_number", "total"]
    }

    config = GenerationConfig.structured_json(schema)

    invoice_text = """
    INVOICE #INV-2024-001
    Date: 2024-11-06

    From: Acme Corporation, 123 Main St, New York, NY 10001

    Items:
    - Widget Pro (Qty: 5) @ $29.99 each = $149.95
    - Service Fee (Qty: 1) @ $50.00 each = $50.00

    Total: $199.95
    """

    case Gemini.generate(
           "Extract invoice details:\n#{invoice_text}",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, invoice} = Jason.decode(text)

        IO.puts("\n✅ Extracted Invoice:")
        IO.puts("   Number: #{invoice["invoice_number"]}")
        IO.puts("   Date: #{invoice["date"]}")
        IO.puts("   Vendor: #{invoice["vendor"]["name"]}")
        IO.puts("   Total: $#{invoice["total"]}")
        IO.puts("\n   Items:")

        Enum.each(invoice["items"], fn item ->
          IO.puts(
            "   - #{item["description"]}: #{item["quantity"]} × $#{item["unit_price"]} = $#{item["total"]}"
          )
        end)

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end

  defp example_content_moderation do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Use Case 2: Content Moderation")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "is_safe" => %{"type" => "boolean"},
        "confidence" => %{
          "type" => "number",
          "minimum" => 0,
          "maximum" => 1
        },
        "categories" => %{
          "type" => "array",
          "items" => %{
            "type" => "string",
            "enum" => ["harassment", "hate_speech", "violence", "sexual", "spam", "self_harm"]
          }
        },
        "severity" => %{
          "type" => "string",
          "enum" => ["low", "medium", "high", "critical"]
        },
        "explanation" => %{"type" => "string"}
      },
      "required" => ["is_safe", "confidence"]
    }

    config = GenerationConfig.structured_json(schema)

    contents = [
      "This is a great product! Highly recommend.",
      "Click here to win a FREE iPhone now!!!",
      "I hate everyone and everything."
    ]

    Enum.each(contents, fn content ->
      case Gemini.generate(
             "Moderate this content:\n#{content}",
             model: "gemini-2.5-flash",
             generation_config: config
           ) do
        {:ok, response} ->
          {:ok, text} = Gemini.extract_text(response)
          {:ok, result} = Jason.decode(text)

          IO.puts("\n📝 Content: \"#{String.slice(content, 0..50)}...\"")
          IO.puts("   Safe: #{if result["is_safe"], do: "✅", else: "❌"}")
          IO.puts("   Confidence: #{Float.round(result["confidence"], 2)}")

          if result["categories"] && length(result["categories"]) > 0 do
            IO.puts("   Categories: #{Enum.join(result["categories"], ", ")}")
            IO.puts("   Severity: #{result["severity"]}")
          end

        {:error, error} ->
          IO.puts("\n❌ Error: #{inspect(error)}")
      end
    end)

    IO.puts("\n")
  end

  defp example_resume_parsing do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Use Case 3: Resume Parsing")
    IO.puts("=" |> String.duplicate(60))

    schema = %{
      "type" => "object",
      "properties" => %{
        "personal" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "email" => %{"type" => "string", "format" => "email"},
            "phone" => %{"type" => "string"}
          }
        },
        "experience" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "company" => %{"type" => "string"},
              "title" => %{"type" => "string"},
              "years" => %{"type" => "integer", "minimum" => 0}
            }
          }
        },
        "skills" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "education" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "degree" => %{"type" => "string"},
              "institution" => %{"type" => "string"},
              "year" => %{"type" => "integer"}
            }
          }
        }
      }
    }

    config = GenerationConfig.structured_json(schema)

    resume = """
    John Smith
    Email: john.smith@example.com | Phone: (555) 123-4567

    Experience:
    - Senior Developer at TechCorp (5 years)
    - Developer at StartupXYZ (3 years)

    Skills: Elixir, Python, JavaScript, PostgreSQL, Docker

    Education:
    - BS Computer Science, State University, 2015
    """

    case Gemini.generate(
           "Parse this resume:\n#{resume}",
           model: "gemini-2.5-flash",
           generation_config: config
         ) do
      {:ok, response} ->
        {:ok, text} = Gemini.extract_text(response)
        {:ok, parsed} = Jason.decode(text)

        IO.puts("\n✅ Parsed Resume:")
        IO.puts("   Name: #{parsed["personal"]["name"]}")
        IO.puts("   Email: #{parsed["personal"]["email"]}")
        IO.puts("\n   Experience:")

        Enum.each(parsed["experience"], fn job ->
          IO.puts("   - #{job["title"]} at #{job["company"]} (#{job["years"]} years)")
        end)

        IO.puts("\n   Skills: #{Enum.join(parsed["skills"], ", ")}")

      {:error, error} ->
        IO.puts("\n❌ Error: #{inspect(error)}")
    end

    IO.puts("\n")
  end
end

# Run if executed directly
if System.get_env("GEMINI_API_KEY") do
  RealWorldExamples.run()
else
  IO.puts("⚠️  Set GEMINI_API_KEY environment variable to run this example")
end
```

---

## Running the Examples

### Setup

```bash
# Set your API key
export GEMINI_API_KEY="your_api_key_here"

# Run basic example
mix run examples/structured_outputs_basic.exs

# Run advanced example
mix run examples/structured_outputs_advanced.exs

# Run real-world example
mix run examples/structured_outputs_real_world.exs
```

### Expected Output

Each example will:
1. Print a header for each demonstration
2. Make API calls with structured schemas
3. Display formatted results
4. Handle errors gracefully

---

## Example Summary

| File | Purpose | Features Demonstrated |
|------|---------|----------------------|
| `structured_outputs_basic.exs` | Getting started | Simple schemas, helper usage, basic types |
| `structured_outputs_advanced.exs` | New features | anyOf, $ref, constraints, tuples |
| `structured_outputs_real_world.exs` | Production use | Invoice, moderation, resume parsing |

---

**Next Document:** `07_MIGRATION_GUIDE.md` - Migration guide for existing users
