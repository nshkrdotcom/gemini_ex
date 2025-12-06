defmodule Gemini.Types.Response.SafetyRatingTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Response.SafetyRating

  describe "from_api/1" do
    test "parses new score fields" do
      payload = %{
        "category" => "HARM_CATEGORY_HATE_SPEECH",
        "probability" => "HIGH",
        "probabilityScore" => 0.9,
        "severity" => "harm_severity_high",
        "severityScore" => 0.8,
        "blocked" => true
      }

      rating = SafetyRating.from_api(payload)

      assert rating.category == "HARM_CATEGORY_HATE_SPEECH"
      assert rating.probability == "HIGH"
      assert rating.probability_score == 0.9
      assert rating.severity == "harm_severity_high"
      assert rating.severity_score == 0.8
      assert rating.blocked == true
    end

    test "returns nil for nil input" do
      assert SafetyRating.from_api(nil) == nil
    end
  end
end
