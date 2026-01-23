defmodule Gemini.Types.Live.GoAwayTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.GoAway

  describe "new/1" do
    test "creates go away message" do
      msg = GoAway.new(time_left: "30s")
      assert msg.time_left == "30s"
    end

    test "creates empty go away message" do
      msg = GoAway.new()
      assert msg.time_left == nil
    end
  end

  describe "to_api/1" do
    test "converts to camelCase" do
      msg = GoAway.new(time_left: "30s")
      api_format = GoAway.to_api(msg)

      assert api_format["timeLeft"] == "30s"
    end

    test "excludes nil fields" do
      msg = GoAway.new()
      api_format = GoAway.to_api(msg)

      assert api_format == %{}
    end

    test "handles nil input" do
      assert GoAway.to_api(nil) == nil
    end
  end

  describe "from_api/1" do
    test "parses API response" do
      api_data = %{"timeLeft" => "60s"}
      msg = GoAway.from_api(api_data)

      assert msg.time_left == "60s"
    end

    test "parses snake_case response" do
      api_data = %{"time_left" => "45s"}
      msg = GoAway.from_api(api_data)

      assert msg.time_left == "45s"
    end

    test "handles nil input" do
      assert GoAway.from_api(nil) == nil
    end
  end
end
