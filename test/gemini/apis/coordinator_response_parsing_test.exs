defmodule Gemini.APIs.CoordinatorResponseParsingTest do
  use ExUnit.Case, async: true

  alias Gemini.APIs.Coordinator
  alias Gemini.Types.Response.GenerateContentResponse

  test "__test_parse_generate_response__/1 populates new fields" do
    api_response = %{
      "responseId" => "resp-123",
      "modelVersion" => "gemini-2.0-flash-exp-001",
      "createTime" => "2025-12-05T10:15:30Z",
      "usageMetadata" => %{
        "totalTokenCount" => 20,
        "thoughtsTokenCount" => 5
      },
      "promptFeedback" => %{
        "blockReason" => "SAFETY",
        "blockReasonMessage" => "Blocked"
      },
      "candidates" => [
        %{
          "index" => 0,
          "finishReason" => "STOP",
          "finishMessage" => "done",
          "avgLogprobs" => -0.12,
          "content" => %{
            "role" => "model",
            "parts" => [
              %{
                "text" => "Hi",
                "thought" => true,
                "fileData" => %{"fileUri" => "gs://bucket/audio.mp3", "mimeType" => "audio/mpeg"},
                "functionResponse" => %{"name" => "lookup", "response" => %{"result" => "ok"}}
              }
            ]
          },
          "safetyRatings" => [
            %{
              "category" => "HARM_CATEGORY_HATE_SPEECH",
              "probability" => "LOW",
              "probabilityScore" => 0.1,
              "severity" => "harm_severity_low",
              "severityScore" => 0.05
            }
          ]
        }
      ]
    }

    assert {:ok, %GenerateContentResponse{} = response} =
             Coordinator.__test_parse_generate_response__(api_response)

    assert response.response_id == "resp-123"
    assert response.model_version == "gemini-2.0-flash-exp-001"
    assert %DateTime{} = response.create_time
    assert response.usage_metadata.thoughts_token_count == 5

    candidate = hd(response.candidates)
    assert candidate.finish_message == "done"
    assert candidate.avg_logprobs == -0.12
    assert candidate.index == 0
    assert candidate.content.parts |> hd() |> Map.get(:thought) == true

    part = hd(candidate.content.parts)
    assert part.file_data.file_uri == "gs://bucket/audio.mp3"
    assert part.function_response.name == "lookup"

    rating = hd(candidate.safety_ratings)
    assert rating.probability_score == 0.1
    assert rating.severity == "harm_severity_low"
    assert rating.severity_score == 0.05

    assert response.prompt_feedback.block_reason_message == "Blocked"
  end
end
