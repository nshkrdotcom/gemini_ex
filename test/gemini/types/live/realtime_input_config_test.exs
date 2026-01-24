defmodule Gemini.Types.Live.RealtimeInputConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.RealtimeInputConfig

  test "to_api accepts maps with automatic activity detection settings" do
    config = %{automatic_activity_detection: %{disabled: true}}

    assert RealtimeInputConfig.to_api(config) == %{
             "automaticActivityDetection" => %{"disabled" => true}
           }
  end
end
