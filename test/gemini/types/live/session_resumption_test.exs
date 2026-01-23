defmodule Gemini.Types.Live.SessionResumptionTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.{SessionResumptionConfig, SessionResumptionUpdate}

  describe "SessionResumptionConfig" do
    test "new/1 creates config for new session" do
      config = SessionResumptionConfig.new()
      assert config.handle == nil
      assert config.transparent == nil
    end

    test "new/1 creates config for resuming session" do
      config = SessionResumptionConfig.new(handle: "prev_session_handle", transparent: true)
      assert config.handle == "prev_session_handle"
      assert config.transparent == true
    end

    test "to_api/1 converts to camelCase" do
      config = SessionResumptionConfig.new(handle: "prev_handle", transparent: true)
      api_format = SessionResumptionConfig.to_api(config)

      assert api_format["handle"] == "prev_handle"
      assert api_format["transparent"] == true
    end

    test "to_api/1 excludes nil fields" do
      config = SessionResumptionConfig.new()
      api_format = SessionResumptionConfig.to_api(config)

      assert api_format == %{}
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "handle" => "session_handle",
        "transparent" => true
      }

      config = SessionResumptionConfig.from_api(api_data)

      assert config.handle == "session_handle"
      assert config.transparent == true
    end

    test "handles nil" do
      assert SessionResumptionConfig.to_api(nil) == nil
      assert SessionResumptionConfig.from_api(nil) == nil
    end
  end

  describe "SessionResumptionUpdate" do
    test "new/1 creates update" do
      update =
        SessionResumptionUpdate.new(
          new_handle: "new_session_handle",
          resumable: true,
          last_consumed_client_message_index: 42
        )

      assert update.new_handle == "new_session_handle"
      assert update.resumable == true
      assert update.last_consumed_client_message_index == 42
    end

    test "to_api/1 converts to camelCase" do
      update =
        SessionResumptionUpdate.new(
          new_handle: "new_handle",
          resumable: true,
          last_consumed_client_message_index: 10
        )

      api_format = SessionResumptionUpdate.to_api(update)

      assert api_format["newHandle"] == "new_handle"
      assert api_format["resumable"] == true
      assert api_format["lastConsumedClientMessageIndex"] == 10
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "newHandle" => "session_123",
        "resumable" => true,
        "lastConsumedClientMessageIndex" => 5
      }

      update = SessionResumptionUpdate.from_api(api_data)

      assert update.new_handle == "session_123"
      assert update.resumable == true
      assert update.last_consumed_client_message_index == 5
    end

    test "handles non-resumable state" do
      api_data = %{
        "newHandle" => "",
        "resumable" => false
      }

      update = SessionResumptionUpdate.from_api(api_data)

      assert update.new_handle == ""
      assert update.resumable == false
    end

    test "handles nil" do
      assert SessionResumptionUpdate.to_api(nil) == nil
      assert SessionResumptionUpdate.from_api(nil) == nil
    end
  end
end
