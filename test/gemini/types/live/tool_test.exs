defmodule Gemini.Types.Live.ToolTest do
  use ExUnit.Case, async: true

  alias Gemini.Types.Live.{ToolCall, ToolCallCancellation, ToolResponse}

  describe "ToolCall" do
    test "new/1 creates tool call" do
      call =
        ToolCall.new(
          function_calls: [
            %{id: "call_1", name: "get_weather", args: %{"location" => "Seattle"}}
          ]
        )

      assert length(call.function_calls) == 1
      assert hd(call.function_calls).name == "get_weather"
    end

    test "to_api/1 converts to camelCase" do
      call =
        ToolCall.new(
          function_calls: [
            %{id: "call_1", name: "get_weather", args: %{"location" => "Seattle"}}
          ]
        )

      api_format = ToolCall.to_api(call)

      assert length(api_format["functionCalls"]) == 1
      assert hd(api_format["functionCalls"])["name"] == "get_weather"
      assert hd(api_format["functionCalls"])["id"] == "call_1"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "functionCalls" => [
          %{"id" => "call_1", "name" => "get_weather", "args" => %{"location" => "Seattle"}}
        ]
      }

      call = ToolCall.from_api(api_data)

      assert length(call.function_calls) == 1
      assert hd(call.function_calls).name == "get_weather"
      assert hd(call.function_calls).args == %{"location" => "Seattle"}
    end

    test "handles nil" do
      assert ToolCall.to_api(nil) == nil
      assert ToolCall.from_api(nil) == nil
    end
  end

  describe "ToolCallCancellation" do
    test "new/1 creates cancellation" do
      cancel = ToolCallCancellation.new(ids: ["call_1", "call_2"])
      assert cancel.ids == ["call_1", "call_2"]
    end

    test "to_api/1 converts to API format" do
      cancel = ToolCallCancellation.new(ids: ["call_1", "call_2"])
      api_format = ToolCallCancellation.to_api(cancel)

      assert api_format["ids"] == ["call_1", "call_2"]
    end

    test "from_api/1 parses API response" do
      api_data = %{"ids" => ["call_1", "call_2"]}
      cancel = ToolCallCancellation.from_api(api_data)

      assert cancel.ids == ["call_1", "call_2"]
    end

    test "handles nil" do
      assert ToolCallCancellation.to_api(nil) == nil
      assert ToolCallCancellation.from_api(nil) == nil
    end
  end

  describe "ToolResponse" do
    test "new/1 creates tool response" do
      response =
        ToolResponse.new(
          function_responses: [
            %{id: "call_1", name: "get_weather", response: %{content: %{temperature: 72}}}
          ]
        )

      assert length(response.function_responses) == 1
      assert hd(response.function_responses).name == "get_weather"
    end

    test "to_api/1 converts to camelCase" do
      response =
        ToolResponse.new(
          function_responses: [
            %{id: "call_1", name: "get_weather", response: %{content: %{temperature: 72}}}
          ]
        )

      api_format = ToolResponse.to_api(response)

      assert length(api_format["functionResponses"]) == 1
      assert hd(api_format["functionResponses"])["name"] == "get_weather"
    end

    test "from_api/1 parses API response" do
      api_data = %{
        "functionResponses" => [
          %{"id" => "call_1", "name" => "get_weather", "response" => %{"content" => %{}}}
        ]
      }

      response = ToolResponse.from_api(api_data)

      assert length(response.function_responses) == 1
      assert hd(response.function_responses).name == "get_weather"
    end

    test "handles nil" do
      assert ToolResponse.to_api(nil) == nil
      assert ToolResponse.from_api(nil) == nil
    end
  end
end
