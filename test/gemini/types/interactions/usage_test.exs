defmodule Gemini.Types.Interactions.UsageTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Interactions.Usage

  describe "from_api/1" do
    test "parses total_thought_tokens" do
      data = %{"total_thought_tokens" => 150}
      usage = Usage.from_api(data)

      assert usage.total_thought_tokens == 150
    end
  end

  describe "to_api/1" do
    test "serializes total_thought_tokens" do
      usage = %Usage{total_thought_tokens: 42}
      api = Usage.to_api(usage)

      assert api["total_thought_tokens"] == 42
    end
  end
end
