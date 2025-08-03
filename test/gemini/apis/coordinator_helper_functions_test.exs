defmodule Gemini.APIs.CoordinatorHelperFunctionsTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.GenerationConfig

  # Test helper module that implements the same functions for testing
  defmodule TestHelper do
    @spec convert_to_camel_case(atom()) :: String.t()
    def convert_to_camel_case(atom_key) when is_atom(atom_key) do
      atom_key
      |> Atom.to_string()
      |> String.split("_")
      |> case do
        [first | rest] ->
          first <> Enum.map_join(rest, "", &String.capitalize/1)

        [] ->
          ""
      end
    end

    @spec struct_to_api_map(GenerationConfig.t()) :: map()
    def struct_to_api_map(%GenerationConfig{} = config) do
      config
      |> Map.from_struct()
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        camel_key = convert_to_camel_case(key)
        Map.put(acc, camel_key, value)
      end)
      |> filter_nil_values()
    end

    @spec filter_nil_values(map()) :: map()
    def filter_nil_values(map) when is_map(map) do
      map
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})
    end
  end

  describe "convert_to_camel_case/1" do
    test "converts simple snake_case to camelCase" do
      assert TestHelper.convert_to_camel_case(:response_schema) == "responseSchema"
      assert TestHelper.convert_to_camel_case(:response_mime_type) == "responseMimeType"
      assert TestHelper.convert_to_camel_case(:max_output_tokens) == "maxOutputTokens"
      assert TestHelper.convert_to_camel_case(:stop_sequences) == "stopSequences"
    end

    test "handles single word atoms" do
      assert TestHelper.convert_to_camel_case(:temperature) == "temperature"
      assert TestHelper.convert_to_camel_case(:logprobs) == "logprobs"
    end

    test "handles multiple underscores" do
      assert TestHelper.convert_to_camel_case(:presence_penalty) == "presencePenalty"
      assert TestHelper.convert_to_camel_case(:frequency_penalty) == "frequencyPenalty"
      assert TestHelper.convert_to_camel_case(:response_logprobs) == "responseLogprobs"
    end

    test "handles atoms with numbers" do
      assert TestHelper.convert_to_camel_case(:top_p) == "topP"
      assert TestHelper.convert_to_camel_case(:top_k) == "topK"
    end

    test "handles candidate_count" do
      assert TestHelper.convert_to_camel_case(:candidate_count) == "candidateCount"
    end
  end

  describe "filter_nil_values/1" do
    test "removes nil values from map" do
      input = %{
        "temperature" => 0.7,
        "maxOutputTokens" => nil,
        "topP" => 0.9,
        "responseSchema" => nil,
        "stopSequences" => []
      }

      expected = %{
        "temperature" => 0.7,
        "topP" => 0.9,
        "stopSequences" => []
      }

      assert TestHelper.filter_nil_values(input) == expected
    end

    test "handles empty map" do
      assert TestHelper.filter_nil_values(%{}) == %{}
    end

    test "handles map with all nil values" do
      input = %{
        "a" => nil,
        "b" => nil,
        "c" => nil
      }

      assert TestHelper.filter_nil_values(input) == %{}
    end

    test "handles map with no nil values" do
      input = %{
        "temperature" => 0.7,
        "topP" => 0.9,
        "stopSequences" => []
      }

      assert TestHelper.filter_nil_values(input) == input
    end

    test "preserves falsy values that are not nil" do
      input = %{
        "temperature" => 0,
        "enabled" => false,
        "empty_list" => [],
        "nil_value" => nil
      }

      expected = %{
        "temperature" => 0,
        "enabled" => false,
        "empty_list" => []
      }

      assert TestHelper.filter_nil_values(input) == expected
    end
  end

  describe "struct_to_api_map/1" do
    test "converts GenerationConfig struct to API map with camelCase keys" do
      config = %GenerationConfig{
        temperature: 0.7,
        max_output_tokens: 1000,
        top_p: 0.9,
        top_k: 40,
        response_schema: %{"type" => "object"},
        response_mime_type: "application/json",
        stop_sequences: ["END", "STOP"],
        candidate_count: 1,
        presence_penalty: 0.1,
        frequency_penalty: 0.2,
        response_logprobs: true,
        logprobs: 5
      }

      result = TestHelper.struct_to_api_map(config)

      expected = %{
        "temperature" => 0.7,
        "maxOutputTokens" => 1000,
        "topP" => 0.9,
        "topK" => 40,
        "responseSchema" => %{"type" => "object"},
        "responseMimeType" => "application/json",
        "stopSequences" => ["END", "STOP"],
        "candidateCount" => 1,
        "presencePenalty" => 0.1,
        "frequencyPenalty" => 0.2,
        "responseLogprobs" => true,
        "logprobs" => 5
      }

      assert result == expected
    end

    test "filters out nil values from struct" do
      config = %GenerationConfig{
        temperature: 0.7,
        max_output_tokens: nil,
        top_p: nil,
        response_schema: %{"type" => "string"},
        response_mime_type: nil
      }

      result = TestHelper.struct_to_api_map(config)

      expected = %{
        "temperature" => 0.7,
        "responseSchema" => %{"type" => "string"},
        # Default empty list is preserved
        "stopSequences" => []
      }

      assert result == expected
    end

    test "handles struct with all default/nil values" do
      config = %GenerationConfig{}

      result = TestHelper.struct_to_api_map(config)

      # Only non-nil default values should remain
      expected = %{
        # Default empty list
        "stopSequences" => []
      }

      assert result == expected
    end

    test "preserves falsy values that are not nil" do
      config = %GenerationConfig{
        temperature: 0.0,
        response_logprobs: false,
        candidate_count: 0
      }

      result = TestHelper.struct_to_api_map(config)

      expected = %{
        "temperature" => 0.0,
        "responseLogprobs" => false,
        "candidateCount" => 0,
        "stopSequences" => []
      }

      assert result == expected
    end
  end
end
