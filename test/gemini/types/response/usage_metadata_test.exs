defmodule Gemini.Types.Response.UsageMetadataTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.{ModalityTokenCount, UsageMetadata}

  describe "from_api/1" do
    test "parses new token count fields" do
      json = %{
        "totalTokenCount" => 100,
        "promptTokenCount" => 10,
        "candidatesTokenCount" => 20,
        "cachedContentTokenCount" => 5,
        "thoughtsTokenCount" => 30,
        "toolUsePromptTokenCount" => 7
      }

      metadata = UsageMetadata.from_api(json)

      assert metadata.total_token_count == 100
      assert metadata.prompt_token_count == 10
      assert metadata.candidates_token_count == 20
      assert metadata.cached_content_token_count == 5
      assert metadata.thoughts_token_count == 30
      assert metadata.tool_use_prompt_token_count == 7
    end

    test "parses token details with modality conversion" do
      json = %{
        "totalTokenCount" => 10,
        "promptTokensDetails" => [
          %{"modality" => "TEXT", "tokenCount" => 6},
          %{"modality" => "AUDIO", "tokenCount" => 4}
        ],
        "cacheTokensDetails" => [
          %{"modality" => "IMAGE", "tokenCount" => 2}
        ],
        "responseTokensDetails" => [
          %{"modality" => "TEXT", "tokenCount" => 8}
        ],
        "toolUsePromptTokensDetails" => [
          %{"modality" => "TEXT", "tokenCount" => 1}
        ],
        "trafficType" => "ON_DEMAND"
      }

      metadata = UsageMetadata.from_api(json)

      assert [
               %ModalityTokenCount{modality: :text, token_count: 6},
               %ModalityTokenCount{modality: :audio, token_count: 4}
             ] =
               metadata.prompt_tokens_details

      assert [%ModalityTokenCount{modality: :image, token_count: 2}] =
               metadata.cache_tokens_details

      assert [%ModalityTokenCount{modality: :text, token_count: 8}] =
               metadata.response_tokens_details

      assert [%ModalityTokenCount{modality: :text, token_count: 1}] =
               metadata.tool_use_prompt_tokens_details

      assert metadata.traffic_type == :on_demand
    end

    test "returns nil when input is nil" do
      assert UsageMetadata.from_api(nil) == nil
    end
  end
end
