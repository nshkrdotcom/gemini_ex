defmodule Gemini.Types.Live.ContextWindowCompressionTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.{ContextWindowCompression, SlidingWindow}

  describe "SlidingWindow" do
    test "new/1 creates sliding window config" do
      sw = SlidingWindow.new(target_tokens: 8000)
      assert sw.target_tokens == 8000
    end

    test "to_api/1 converts to camelCase" do
      sw = SlidingWindow.new(target_tokens: 8000)
      api_format = SlidingWindow.to_api(sw)

      assert api_format["targetTokens"] == 8000
    end

    test "from_api/1 parses API response" do
      api_data = %{"targetTokens" => 8000}
      sw = SlidingWindow.from_api(api_data)

      assert sw.target_tokens == 8000
    end

    test "handles nil" do
      assert SlidingWindow.to_api(nil) == nil
      assert SlidingWindow.from_api(nil) == nil
    end
  end

  describe "ContextWindowCompression" do
    test "new/1 creates compression config" do
      config =
        ContextWindowCompression.new(
          trigger_tokens: 16_000,
          sliding_window: %SlidingWindow{target_tokens: 8000}
        )

      assert config.trigger_tokens == 16_000
      assert config.sliding_window.target_tokens == 8000
    end

    test "to_api/1 converts to camelCase" do
      config =
        ContextWindowCompression.new(
          trigger_tokens: 16_000,
          sliding_window: %SlidingWindow{target_tokens: 8000}
        )

      api_format = ContextWindowCompression.to_api(config)

      assert api_format["triggerTokens"] == 16_000
      assert api_format["slidingWindow"]["targetTokens"] == 8000
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "triggerTokens" => 16_000,
        "slidingWindow" => %{"targetTokens" => 8000}
      }

      config = ContextWindowCompression.from_api(api_data)

      assert config.trigger_tokens == 16_000
      assert config.sliding_window.target_tokens == 8000
    end

    test "handles nil" do
      assert ContextWindowCompression.to_api(nil) == nil
      assert ContextWindowCompression.from_api(nil) == nil
    end
  end
end
