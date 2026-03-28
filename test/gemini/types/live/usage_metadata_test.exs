defmodule Gemini.Types.Live.UsageMetadataTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.UsageMetadata

  describe "from_api/1" do
    test "parses Gemini Live response token fields into canonical output fields" do
      metadata =
        UsageMetadata.from_api(%{
          "promptTokenCount" => 100,
          "responseTokenCount" => 50,
          "responseTokensDetails" => [
            %{"modality" => "TEXT", "tokenCount" => 50}
          ]
        })

      assert metadata.prompt_token_count == 100
      assert metadata.response_token_count == 50
      assert metadata.candidates_token_count == 50
      assert metadata.response_tokens_details == [%{modality: "TEXT", token_count: 50}]
      assert metadata.candidates_tokens_details == [%{modality: "TEXT", token_count: 50}]
      assert UsageMetadata.output_token_count(metadata) == 50

      assert UsageMetadata.output_tokens_details(metadata) == [
               %{modality: "TEXT", token_count: 50}
             ]
    end

    test "parses Vertex Live candidates token fields and preserves legacy aliases" do
      metadata =
        UsageMetadata.from_api(%{
          "promptTokenCount" => 120,
          "candidatesTokenCount" => 60,
          "candidatesTokensDetails" => [
            %{"modality" => "TEXT", "tokenCount" => 60}
          ]
        })

      assert metadata.prompt_token_count == 120
      assert metadata.candidates_token_count == 60
      assert metadata.response_token_count == 60
      assert metadata.candidates_tokens_details == [%{modality: "TEXT", token_count: 60}]
      assert metadata.response_tokens_details == [%{modality: "TEXT", token_count: 60}]
      assert UsageMetadata.output_token_count(metadata) == 60

      assert UsageMetadata.output_tokens_details(metadata) == [
               %{modality: "TEXT", token_count: 60}
             ]
    end
  end

  describe "to_api/1" do
    test "serializes output token metadata using canonical candidates fields" do
      metadata =
        UsageMetadata.new(
          prompt_token_count: 100,
          response_token_count: 50,
          response_tokens_details: [%{modality: "TEXT", token_count: 50}]
        )

      assert %{
               "promptTokenCount" => 100,
               "candidatesTokenCount" => 50,
               "candidatesTokensDetails" => [%{"modality" => "TEXT", "tokenCount" => 50}]
             } = UsageMetadata.to_api(metadata)
    end
  end
end
