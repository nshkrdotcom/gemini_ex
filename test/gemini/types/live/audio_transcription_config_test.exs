defmodule Gemini.Types.Live.AudioTranscriptionConfigTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.AudioTranscriptionConfig

  test "to_api accepts plain maps" do
    assert AudioTranscriptionConfig.to_api(%{}) == %{}
  end
end
