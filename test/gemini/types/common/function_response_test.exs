defmodule Gemini.Types.FunctionResponseTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.FunctionResponse

  describe "from_api/1" do
    test "parses camelCase keys" do
      payload = %{
        "name" => "lookup",
        "response" => %{"result" => "ok"},
        "id" => "call-1",
        "willContinue" => true,
        "scheduling" => "WHEN_IDLE"
      }

      resp = FunctionResponse.from_api(payload)

      assert resp.name == "lookup"
      assert resp.response == %{"result" => "ok"}
      assert resp.id == "call-1"
      assert resp.will_continue == true
      assert resp.scheduling == :when_idle
    end

    test "returns nil for nil input" do
      assert FunctionResponse.from_api(nil) == nil
    end
  end

  describe "to_api/1" do
    test "converts atoms and booleans to API format" do
      struct = %FunctionResponse{
        name: "lookup",
        response: %{"result" => "ok"},
        id: "call-1",
        will_continue: false,
        scheduling: :when_idle
      }

      assert FunctionResponse.to_api(struct) == %{
               "name" => "lookup",
               "response" => %{"result" => "ok"},
               "willContinue" => false,
               "scheduling" => "WHEN_IDLE"
             }
    end
  end
end
