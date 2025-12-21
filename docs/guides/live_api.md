# Live API Guide

The Gemini Live API enables real-time, bidirectional streaming communication with Gemini models through WebSocket connections. This allows for interactive conversations with low latency, supporting text, audio, and video inputs.

## Overview

The Live API is ideal for:

- Interactive chatbots and virtual assistants
- Real-time voice conversations
- Live video analysis
- Multi-turn conversations with tool calling
- Low-latency applications requiring immediate responses

## Key Features

- **Bidirectional Streaming**: Send and receive messages in real-time
- **Multi-Modal Support**: Text, audio, and video inputs
- **Tool Calling**: Execute functions during conversations
- **Automatic Reconnection**: Built-in reconnection logic with exponential backoff
- **Event-Driven**: Callback-based architecture for handling responses

## Getting Started

### Basic Setup

```elixir
alias Gemini.Live.Session

# Start a session
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",
  on_message: fn message ->
    IO.inspect(message, label: "Received")
  end
)

# Connect to the Live API
:ok = Session.connect(session)

# Send a message
:ok = Session.send(session, "Hello! How are you?")

# Close when done
Session.close(session)
```

### With Callbacks

The session supports several callbacks for handling different events:

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",

  # Called when successfully connected
  on_connect: fn ->
    IO.puts("🟢 Connected to Live API")
  end,

  # Called when a message is received
  on_message: fn message ->
    case message do
      %{server_content: content} ->
        handle_model_response(content)

      %{tool_call: calls} ->
        handle_function_calls(calls)

      %{setup_complete: _} ->
        IO.puts("✅ Setup complete")
    end
  end,

  # Called when disconnected
  on_disconnect: fn reason ->
    IO.puts("🔴 Disconnected: #{inspect(reason)}")
  end,

  # Called on errors
  on_error: fn error ->
    IO.puts("❌ Error: #{inspect(error)}")
  end
)

Session.connect(session)
```

## Sending Messages

### Simple Text Messages

```elixir
# Send a simple text message
Session.send(session, "What is the capital of France?")
```

### Structured Content

```elixir
# Send structured content with multiple turns
Session.send_client_content(session, [
  %{role: "user", parts: [%{text: "I'm going to tell you a story."}]},
  %{role: "user", parts: [%{text: "Once upon a time..."}]}
], true) # true = turn_complete
```

### Real-Time Audio Input

```elixir
# Send audio chunks for real-time transcription
audio_data = File.read!("audio.pcm")

Session.send_realtime_input(session, [
  %{
    data: Base.encode64(audio_data),
    mime_type: "audio/pcm"
  }
])
```

## Receiving Messages

Messages are received through the `on_message` callback. The message structure depends on the type:

### Setup Complete

```elixir
%Gemini.Live.Message.ServerMessage{
  setup_complete: %{message: "Setup complete"}
}
```

### Model Response

```elixir
%Gemini.Live.Message.ServerMessage{
  server_content: %{
    model_turn: %{
      role: "model",
      parts: [%{text: "Paris is the capital of France."}]
    },
    turn_complete: true
  }
}
```

### Tool/Function Call

```elixir
%Gemini.Live.Message.ServerMessage{
  tool_call: %{
    function_calls: [
      %{
        name: "get_weather",
        args: %{location: "San Francisco"}
      }
    ]
  }
}
```

## Function Calling

The Live API supports tool calling during conversations:

```elixir
# Define tools
tools = [
  %{
    function_declarations: [
      %{
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: %{
          type: "object",
          properties: %{
            location: %{
              type: "string",
              description: "City name"
            }
          },
          required: ["location"]
        }
      }
    ]
  }
]

# Start session with tools
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",
  tools: tools,
  on_message: &handle_message/1
)

Session.connect(session)
Session.send(session, "What's the weather in Tokyo?")

# In your message handler, respond to tool calls
def handle_message(%{tool_call: %{function_calls: calls}}) do
  # Execute the function
  results = Enum.map(calls, fn call ->
    case call["name"] do
      "get_weather" ->
        location = call["args"]["location"]
        weather = get_weather_data(location)

        %{
          name: call["name"],
          response: weather
        }
    end
  end)

  # Send the results back
  Session.send_tool_response(session, results)
end
```

## Configuration Options

### Generation Config

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",
  generation_config: %{
    temperature: 0.8,
    top_p: 0.95,
    top_k: 40,
    max_output_tokens: 1024
  }
)
```

### System Instructions

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",
  system_instruction: "You are a helpful travel assistant. Always provide concise recommendations."
)
```

### Safety Settings

```elixir
alias Gemini.Types.SafetySetting

{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",
  safety_settings: [
    %SafetySetting{
      category: :harassment,
      threshold: :block_medium_and_above
    }
  ]
)
```

## Advanced Usage

### Streaming Audio Conversations

```elixir
defmodule VoiceAssistant do
  alias Gemini.Live.Session

  def start do
    {:ok, session} = Session.start_link(
      model: "gemini-2.5-flash",
      generation_config: %{
        response_modalities: ["AUDIO"],
        speech_config: %{
          voice_config: %{
            prebuilt_voice_config: %{
              voice_name: "Kore"
            }
          }
        }
      },
      on_message: &handle_audio_response/1
    )

    Session.connect(session)

    # Start capturing audio from microphone
    stream_audio_input(session)
  end

  defp stream_audio_input(session) do
    # Continuously stream audio chunks
    audio_stream = capture_microphone()

    Enum.each(audio_stream, fn chunk ->
      Session.send_realtime_input(session, [
        %{data: Base.encode64(chunk), mime_type: "audio/pcm"}
      ])
    end)
  end

  defp handle_audio_response(%{server_content: content}) do
    # Extract and play audio response
    case content do
      %{model_turn: %{parts: parts}} ->
        Enum.each(parts, fn part ->
          if part["inlineData"] do
            audio_data = Base.decode64!(part["inlineData"]["data"])
            play_audio(audio_data)
          end
        end)
    end
  end
end
```

### Multi-Turn Conversations with Context

```elixir
defmodule ConversationManager do
  alias Gemini.Live.Session

  def start_conversation do
    {:ok, session} = Session.start_link(
      model: "gemini-2.5-flash",
      system_instruction: "You are a math tutor helping students learn algebra.",
      on_message: &handle_response/1
    )

    Session.connect(session)

    # Multi-turn conversation
    Session.send(session, "I'm having trouble with quadratic equations.")

    # Wait for response, then continue
    receive do
      {:response, _} ->
        Session.send(session, "Can you give me an example?")
    end

    session
  end

  defp handle_response(message) do
    case message do
      %{server_content: %{model_turn: turn}} ->
        send(self(), {:response, turn})
    end
  end
end
```

### Handling Reconnection

The session automatically handles reconnection with exponential backoff:

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",

  on_connect: fn ->
    IO.puts("Connected - ready to send messages")
  end,

  on_disconnect: fn reason ->
    IO.puts("Disconnected: #{inspect(reason)}")
    IO.puts("Automatic reconnection will be attempted...")
  end
)

# Connection is automatically restored on network issues
# Messages sent during disconnection are queued
```

## Error Handling

### Common Errors

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",

  on_error: fn error ->
    case error do
      {:authentication_failed, _} ->
        IO.puts("Check your API key configuration")

      {:rate_limit_exceeded, _} ->
        IO.puts("Rate limit hit - backing off...")

      {:invalid_message, _} ->
        IO.puts("Message format error")

      other ->
        IO.puts("Unexpected error: #{inspect(other)}")
    end
  end
)
```

### Timeouts and Retries

```elixir
defmodule ResilientChat do
  alias Gemini.Live.Session

  def send_with_retry(session, message, retries \\ 3) do
    case Session.send(session, message) do
      :ok ->
        :ok

      {:error, :not_connected} when retries > 0 ->
        # Wait for reconnection
        Process.sleep(1000)
        send_with_retry(session, message, retries - 1)

      error ->
        error
    end
  end
end
```

## Best Practices

### 1. Always Handle Callbacks

```elixir
# Good: Handle all message types
on_message: fn message ->
  case message do
    %{setup_complete: _} -> handle_setup()
    %{server_content: content} -> handle_content(content)
    %{tool_call: calls} -> handle_tools(calls)
    _ -> Logger.warn("Unhandled message: #{inspect(message)}")
  end
end
```

### 2. Manage Session Lifecycle

```elixir
defmodule MyApp.ChatServer do
  use GenServer
  alias Gemini.Live.Session

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    {:ok, session} = Session.start_link(
      model: "gemini-2.5-flash",
      on_message: fn msg -> send(self(), {:live_message, msg}) end
    )

    Session.connect(session)

    {:ok, %{session: session}}
  end

  def terminate(_reason, state) do
    Session.close(state.session)
    :ok
  end
end
```

### 3. Use Structured Logging

```elixir
require Logger

{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",

  on_connect: fn ->
    Logger.info("Live API session connected")
  end,

  on_message: fn message ->
    Logger.debug("Received message", message: inspect(message))
  end,

  on_error: fn error ->
    Logger.error("Live API error", error: inspect(error))
  end
)
```

### 4. Rate Limiting Awareness

```elixir
defmodule RateLimitedChat do
  use GenServer
  alias Gemini.Live.Session

  @max_messages_per_minute 60

  def send_message(pid, message) do
    GenServer.call(pid, {:send, message})
  end

  def handle_call({:send, message}, _from, state) do
    if can_send?(state) do
      Session.send(state.session, message)
      {:reply, :ok, update_rate_limit(state)}
    else
      {:reply, {:error, :rate_limited}, state}
    end
  end

  defp can_send?(state) do
    length(state.recent_messages) < @max_messages_per_minute
  end
end
```

## API Reference

For detailed API documentation, see:

- `Gemini.Live.Session` - Main session management
- `Gemini.Live.Message` - Message types and serialization
- `Gemini.Types.Live` - Configuration types

## Troubleshooting

### Connection Issues

```elixir
# Check authentication
config = Application.get_env(:gemini_ex, :api_key)
IO.inspect(config, label: "API Key configured?")

# Enable debug logging
Logger.configure(level: :debug)

# Test basic connectivity
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",
  on_error: fn error -> IO.inspect(error, label: "Error") end
)
```

### Message Not Received

```elixir
# Ensure callbacks are configured
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash",
  on_message: fn msg ->
    IO.inspect(msg, label: "Message received", limit: :infinity)
  end
)

# Check session status
Session.status(session)
# => :connected (or :disconnected, :connecting, :error)
```

### Tool Calls Not Working

```elixir
# Verify tool declaration format
tools = [
  %{
    function_declarations: [
      %{
        name: "my_function",
        description: "Clear description here",
        parameters: %{
          type: "object",
          properties: %{
            param: %{type: "string"}
          },
          required: ["param"]
        }
      }
    ]
  }
]

# Ensure you're responding to tool calls
on_message: fn
  %{tool_call: calls} ->
    # Execute and respond
    Session.send_tool_response(session, results)

  _ ->
    :ok
end
```

## Examples

See the [examples directory](https://github.com/nshkrdotcom/gemini_ex/tree/main/examples) for complete working examples:

- `examples/live_chat.exs` - Interactive chat session
- `examples/live_voice.exs` - Voice conversation
- `examples/live_tools.exs` - Function calling with Live API

## Related Documentation

- [Function Calling Guide](function_calling.md)
- [Authentication System](../../AUTHENTICATION_SYSTEM.md)
- [Streaming Architecture](../../STREAMING_ARCHITECTURE.md)
