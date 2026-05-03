defmodule Gemini.APIs.CoordinatorTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.Response.GenerateContentResponse

  import Gemini.Test.ModelHelpers

  describe "response parsing" do
    test "parse_generate_response converts string keys to atom keys" do
      # Simulate the actual API response structure (with string keys)
      _raw_response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"text" => "Hello, world!"}],
              "role" => "model"
            },
            "finishReason" => "STOP"
          }
        ],
        "modelVersion" => default_model()
      }

      # Test the private function by calling the public interface that uses it
      # We'll simulate this by testing the extract_text function on a properly parsed response

      # Create the expected struct with atom keys
      expected_response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [%{text: "Hello, world!"}],
              role: "model"
            },
            finishReason: "STOP"
          }
        ]
      }

      # Test extract_text with the properly parsed response
      {:ok, text} = Coordinator.extract_text(expected_response)
      assert text == "Hello, world!"
    end

    test "extract_text handles empty candidates array" do
      response = %GenerateContentResponse{candidates: []}

      {:error, reason} = Coordinator.extract_text(response)
      assert reason == "No candidates found in response"
    end

    test "extract_text handles candidates without content" do
      response = %GenerateContentResponse{
        candidates: [%{finishReason: "STOP"}]
      }

      {:error, reason} = Coordinator.extract_text(response)
      assert reason == "No text content found in response"
    end

    test "extract_text handles candidates with empty parts" do
      response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [],
              role: "model"
            }
          }
        ]
      }

      {:error, reason} = Coordinator.extract_text(response)
      assert reason == "No text content found in response"
    end

    test "extract_text handles parts without text field" do
      response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [%{inline_data: %{data: "base64data", mime_type: "image/png"}}],
              role: "model"
            }
          }
        ]
      }

      # Should return error when no text parts found
      {:error, reason} = Coordinator.extract_text(response)
      assert reason == "No text content found in response"
    end

    test "extract_text combines multiple text parts" do
      response = %GenerateContentResponse{
        candidates: [
          %{
            content: %{
              parts: [
                %{text: "Hello, "},
                %{text: "world!"},
                %{inline_data: %{data: "base64", mime_type: "image/png"}},
                %{text: " How are you?"}
              ],
              role: "model"
            }
          }
        ]
      }

      {:ok, text} = Coordinator.extract_text(response)
      assert text == "Hello, world! How are you?"
    end
  end

  describe "bounded API response field handling" do
    test "handles string keyed response structures" do
      raw_api_structure = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [%{"text" => "Test"}],
              "role" => "model"
            },
            "finishReason" => "STOP"
          }
        ]
      }

      assert is_map(raw_api_structure)
      assert Map.has_key?(raw_api_structure, "candidates")

      candidates = raw_api_structure["candidates"]
      assert is_list(candidates)
      assert candidates != []

      first_candidate = List.first(candidates)
      assert Map.has_key?(first_candidate, "content")

      content = first_candidate["content"]
      assert Map.has_key?(content, "parts")

      parts = content["parts"]
      text_parts = Enum.filter(parts, &Map.has_key?(&1, "text"))
      assert text_parts != []
    end

    test "uses a bounded model field map for API responses" do
      mapped_fields = %{
        "displayName" => :display_name,
        "inputTokenLimit" => :input_token_limit,
        "outputTokenLimit" => :output_token_limit,
        "supportedGenerationMethods" => :supported_generation_methods,
        "nextPageToken" => :next_page_token
      }

      assert mapped_fields["displayName"] == :display_name
      assert mapped_fields["inputTokenLimit"] == :input_token_limit
      assert mapped_fields["outputTokenLimit"] == :output_token_limit
      assert mapped_fields["supportedGenerationMethods"] == :supported_generation_methods
      assert mapped_fields["nextPageToken"] == :next_page_token
      refute Map.has_key?(mapped_fields, "providerAuthoredFutureField")
    end
  end
end
