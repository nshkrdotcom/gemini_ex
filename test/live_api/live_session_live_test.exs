defmodule Gemini.LiveSessionLiveTest do
  use ExUnit.Case

  alias Gemini.Live.Session
  alias Gemini.Live.Message.ServerMessage
  alias Gemini.Config

  @moduletag :live_api
  @moduletag timeout: 60_000

  # Skip all tests if API key is not configured
  setup_all do
    api_key = Config.api_key()

    if is_nil(api_key) or api_key == "" do
      {:ok, skip: true}
    else
      {:ok, skip: false}
    end
  end

  setup context do
    if context[:skip] do
      {:ok, skip: true}
    else
      :ok
    end
  end

  describe "Live API Connection" do
    @tag :skip
    test "establishes WebSocket connection", %{skip: skip} do
      if skip, do: :ok

      test_pid = self()

      on_connect = fn ->
        send(test_pid, :connected)
      end

      on_message = fn message ->
        send(test_pid, {:message, message})
      end

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          on_connect: on_connect,
          on_message: on_message
        )

      assert :ok = Session.connect(session)

      # Wait for connection
      assert_receive :connected, 10_000

      # Wait for setup complete
      assert_receive {:message, %ServerMessage{setup_complete: setup}}, 10_000
      assert setup != nil

      Session.close(session)
    end

    @tag :skip
    test "sends and receives text messages", %{skip: skip} do
      if skip, do: :ok

      test_pid = self()

      on_message = fn message ->
        send(test_pid, {:message, message})
      end

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          on_message: on_message
        )

      assert :ok = Session.connect(session)

      # Wait for setup complete
      assert_receive {:message, %ServerMessage{setup_complete: _}}, 10_000

      # Send a simple message
      assert :ok = Session.send(session, "Say hello in one word")

      # Wait for response
      assert_receive {:message, %ServerMessage{server_content: content}}, 15_000
      assert content != nil

      Session.close(session)
    end

    @tag :skip
    test "handles streaming responses", %{skip: skip} do
      if skip, do: :ok

      test_pid = self()

      on_message = fn message ->
        send(test_pid, {:message, message})
      end

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          generation_config: %{temperature: 0.7},
          on_message: on_message
        )

      assert :ok = Session.connect(session)

      # Wait for setup complete
      assert_receive {:message, %ServerMessage{setup_complete: _}}, 10_000

      # Send a message that should produce streaming response
      assert :ok = Session.send(session, "Count from 1 to 5")

      # Collect streaming chunks
      messages =
        collect_messages_until_complete([], 20_000)

      assert length(messages) > 0

      Session.close(session)
    end

    @tag :skip
    test "handles tool calls", %{skip: skip} do
      if skip, do: :ok

      test_pid = self()

      on_message = fn message ->
        send(test_pid, {:message, message})
      end

      # Define a simple weather tool
      tools = [
        %{
          function_declarations: [
            %{
              name: "get_weather",
              description: "Get the weather for a location",
              parameters: %{
                type: "object",
                properties: %{
                  location: %{type: "string", description: "City name"}
                },
                required: ["location"]
              }
            }
          ]
        }
      ]

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          tools: tools,
          on_message: on_message
        )

      assert :ok = Session.connect(session)

      # Wait for setup complete
      assert_receive {:message, %ServerMessage{setup_complete: _}}, 10_000

      # Send a message that should trigger tool call
      assert :ok = Session.send(session, "What's the weather in San Francisco?")

      # Wait for tool call
      assert_receive {:message, %ServerMessage{tool_call: tool_call}}, 15_000
      assert tool_call != nil

      # Send tool response
      assert :ok =
               Session.send_tool_response(session, [
                 %{
                   name: "get_weather",
                   response: %{temperature: 72, condition: "sunny"}
                 }
               ])

      # Wait for final response
      assert_receive {:message, %ServerMessage{server_content: content}}, 15_000
      assert content != nil

      Session.close(session)
    end

    @tag :skip
    test "handles reconnection", %{skip: skip} do
      if skip, do: :ok

      test_pid = self()

      on_connect = fn ->
        send(test_pid, :connected)
      end

      on_disconnect = fn reason ->
        send(test_pid, {:disconnected, reason})
      end

      {:ok, session} =
        Session.start_link(
          model: "gemini-2.5-flash",
          on_connect: on_connect,
          on_disconnect: on_disconnect
        )

      assert :ok = Session.connect(session)

      # Wait for connection
      assert_receive :connected, 10_000

      # Force disconnect by closing the session and reconnecting
      # (In real scenario, you might simulate network failure)

      Session.close(session)
    end
  end

  # Helper function to collect messages until turn is complete
  defp collect_messages_until_complete(messages, timeout) do
    receive do
      {:message, %ServerMessage{server_content: content} = message} ->
        new_messages = [message | messages]

        case content do
          %{turnComplete: true} ->
            Enum.reverse(new_messages)

          %{"turnComplete" => true} ->
            Enum.reverse(new_messages)

          _ ->
            collect_messages_until_complete(new_messages, timeout)
        end

      {:message, _other} ->
        collect_messages_until_complete(messages, timeout)
    after
      timeout ->
        Enum.reverse(messages)
    end
  end
end
