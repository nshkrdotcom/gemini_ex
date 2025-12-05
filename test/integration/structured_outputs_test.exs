defmodule Gemini.Integration.StructuredOutputsTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :live_api
  @moduletag timeout: 30_000

  alias Gemini.Types.GenerationConfig

  import Gemini.Test.ModelHelpers

  setup_all do
    {:ok, %{has_auth: auth_available?()}}
  end

  describe "structured outputs" do
    test "generates JSON matching simple schema", %{has_auth: has_auth} do
      unless has_auth do
        IO.puts("Skipping structured outputs test - no API key configured")
        assert true
      else
        schema = %{
          "type" => "object",
          "properties" => %{
            "answer" => %{"type" => "string"}
          },
          "required" => ["answer"]
        }

        config = GenerationConfig.structured_json(schema)

        {:ok, response} =
          Gemini.generate(
            "What is 2+2? Respond in the specified format.",
            model: default_model(),
            generation_config: config
          )

        {:ok, text} = Gemini.extract_text(response)
        {:ok, json} = Jason.decode(text)

        assert Map.has_key?(json, "answer")
        assert is_binary(json["answer"])
      end
    end

    test "handles anyOf for union types", %{has_auth: has_auth} do
      unless has_auth do
        IO.puts("Skipping structured outputs test - no API key configured")
        assert true
      else
        schema = %{
          "type" => "object",
          "properties" => %{
            "status" => %{
              "anyOf" => [
                %{
                  "type" => "object",
                  "properties" => %{"success" => %{"type" => "string"}}
                },
                %{
                  "type" => "object",
                  "properties" => %{"error" => %{"type" => "string"}}
                }
              ]
            }
          }
        }

        config = GenerationConfig.structured_json(schema)

        {:ok, response} =
          Gemini.generate(
            "Return a success status",
            model: default_model(),
            generation_config: config
          )

        {:ok, text} = Gemini.extract_text(response)
        {:ok, json} = Jason.decode(text)

        assert Map.has_key?(json, "status")
        status = json["status"]
        assert Map.has_key?(status, "success") or Map.has_key?(status, "error")
      end
    end

    test "respects numeric constraints", %{has_auth: has_auth} do
      unless has_auth do
        IO.puts("Skipping structured outputs test - no API key configured")
        assert true
      else
        schema = %{
          "type" => "object",
          "properties" => %{
            "confidence" => %{
              "type" => "number",
              "minimum" => 0.0,
              "maximum" => 1.0
            }
          }
        }

        config = GenerationConfig.structured_json(schema)

        {:ok, response} =
          Gemini.generate(
            "Rate your confidence",
            model: default_model(),
            generation_config: config
          )

        {:ok, text} = Gemini.extract_text(response)
        {:ok, json} = Jason.decode(text)

        confidence = json["confidence"]
        assert is_number(confidence)
        assert confidence >= 0.0
        assert confidence <= 1.0
      end
    end
  end

  describe "streaming with structured outputs" do
    test "streams valid partial JSON", %{has_auth: has_auth} do
      unless has_auth do
        IO.puts("Skipping structured outputs streaming test - no API key configured")
        assert true
      else
        schema = %{
          "type" => "object",
          "properties" => %{
            "story" => %{"type" => "string"}
          }
        }

        config = GenerationConfig.structured_json(schema)

        {:ok, responses} =
          Gemini.stream_generate(
            "Write a short story (2 sentences)",
            model: default_model(),
            generation_config: config
          )

        full_text =
          responses
          |> Enum.map(fn resp ->
            {:ok, text} = Gemini.extract_text(resp)
            text
          end)
          |> Enum.join()

        {:ok, json} = Jason.decode(full_text)
        assert Map.has_key?(json, "story")
        assert is_binary(json["story"])
      end
    end
  end

  # auth_available?/0 is imported from ModelHelpers
end
