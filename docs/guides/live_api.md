# Live API Guide

The Gemini Live API enables real-time, bidirectional streaming communication with Gemini models through WebSocket connections. This allows for interactive conversations with low latency, supporting text, audio, and video inputs.

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Session Configuration](#session-configuration)
4. [Sending Content](#sending-content)
5. [Receiving Responses](#receiving-responses)
6. [Function Calling](#function-calling)
7. [Voice Activity Detection](#voice-activity-detection)
8. [Audio Handling](#audio-handling)
9. [Session Management](#session-management)
10. [Error Handling](#error-handling)
11. [Best Practices](#best-practices)

## Overview

The Live API is ideal for:

- Interactive chatbots and virtual assistants
- Real-time voice conversations
- Live video analysis
- Multi-turn conversations with tool calling
- Low-latency applications requiring immediate responses

### Key Features

- **Bidirectional Streaming**: Send and receive messages in real-time
- **Multi-Modal Support**: Text, audio, and video inputs
- **Tool Calling**: Execute functions during conversations
- **Voice Activity Detection (VAD)**: Automatic or manual speech detection
- **Session Resumption**: Resume sessions after disconnection
- **Context Window Compression**: Automatic context management for long sessions
- **Audio Transcription**: Input/output transcription support
- **Event-Driven**: Callback-based architecture for handling responses

### Supported Models

| Model | Description |
|-------|-------------|
| `gemini-2.5-flash-native-audio-preview-12-2025` | Recommended for voice/audio applications |
| `gemini-2.0-flash-live-001` | General-purpose Live API model |

### Audio Format Requirements

| Direction | Format | Sample Rate | Channels |
|-----------|--------|-------------|----------|
| Input | 16-bit PCM | 16kHz | Mono |
| Output | 16-bit PCM | 24kHz | Mono |

## Getting Started

### Prerequisites

- Elixir 1.14+
- Valid Gemini API key or Vertex AI credentials
- A Live API compatible model

### Basic Setup

```elixir
alias Gemini.Live.Session

# Start a session
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  on_message: fn message ->
    IO.inspect(message, label: "Received")
  end
)

# Connect to the Live API
:ok = Session.connect(session)

# Send a text message
:ok = Session.send_client_content(session, "Hello! How are you?")

# Wait for response (delivered via callback)
Process.sleep(5000)

# Close when done
Session.close(session)
```

### With Callbacks

The session supports several callbacks for handling different events:

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},

  # Called when a message is received
  on_message: fn message ->
    case message do
      %{server_content: content} when not is_nil(content) ->
        handle_model_response(content)

      %{tool_call: tc} when not is_nil(tc) ->
        handle_function_calls(tc)

      %{setup_complete: _} ->
        IO.puts("✅ Setup complete")

      _ ->
        :ok
    end
  end,

  # Called on errors
  on_error: fn error ->
    IO.puts("❌ Error: #{inspect(error)}")
  end,

  # Called when session closes
  on_close: fn reason ->
    IO.puts("🔴 Closed: #{inspect(reason)}")
  end,

  # Called specifically for tool calls
  on_tool_call: fn tool_call ->
    IO.puts("Tool call: #{inspect(tool_call)}")
  end,

  # Called for transcription events
  on_transcription: fn {:input | :output, transcription} ->
    IO.puts("Transcription: #{inspect(transcription)}")
  end,

  # Called when session is about to close (GoAway notice)
  on_go_away: fn %{time_left_ms: time_left} ->
    IO.puts("Session ending in #{time_left}ms")
  end
)

:ok = Session.connect(session)
```

## Session Configuration

### Generation Config

Configure response modality and generation parameters:

```elixir
generation_config = %{
  response_modalities: ["TEXT"],  # or ["AUDIO"] for voice output
  temperature: 0.7,
  top_p: 0.95,
  top_k: 40,
  max_output_tokens: 1024
}
```

### Full Configuration Options

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,  # or :vertex_ai
  project_id: "your-project",  # required for Vertex AI
  location: "us-central1",     # for Vertex AI, default: us-central1

  # Generation
  generation_config: %{response_modalities: ["TEXT"]},
  system_instruction: "You are a helpful assistant.",

  # Tools
  tools: [%{function_declarations: [...]}],

  # Session features
  session_resumption: %{},                      # Enable session resumption
  resume_handle: "previous-session-handle",    # Resume from previous session
  context_window_compression: %{sliding_window: %{}},  # Compression

  # Audio transcription
  input_audio_transcription: %{},
  output_audio_transcription: %{},

  # Callbacks
  on_message: &handle_message/1,
  on_error: &handle_error/1,
  on_close: &handle_close/1,
  on_tool_call: &handle_tool_call/1,
  on_tool_call_cancellation: &handle_cancellation/1,
  on_transcription: &handle_transcription/1,
  on_voice_activity: &handle_voice_activity/1,
  on_session_resumption: &handle_resumption/1,
  on_go_away: &handle_go_away/1
)
```

## Sending Content

### Simple Text Messages

```elixir
# Send a simple text message
Session.send_client_content(session, "What is the capital of France?")
```

### Structured Content

```elixir
# Send structured content with multiple turns
Session.send_client_content(session, [
  %{role: "user", parts: [%{text: "I'm going to tell you a story."}]},
  %{role: "user", parts: [%{text: "Once upon a time..."}]}
], turn_complete: true)

# Incremental content (for streaming)
Session.send_client_content(session, "Part 1...", turn_complete: false)
Session.send_client_content(session, "Part 2...", turn_complete: true)
```

### Real-Time Audio Input

```elixir
# Send audio chunks (16-bit PCM, 16kHz mono)
audio_data = File.read!("audio.pcm")

Session.send_realtime_input(session, audio: %{
  data: audio_data,  # raw binary, will be Base64 encoded automatically
  mime_type: "audio/pcm;rate=16000"
})

# Signal manual voice activity (when not using automatic VAD)
Session.send_realtime_input(session, activity_start: true)
# ... send audio chunks ...
Session.send_realtime_input(session, activity_end: true)

# Signal end of audio stream
Session.send_realtime_input(session, audio_stream_end: true)
```

### Real-Time Video Input

```elixir
# Send video frames
Session.send_realtime_input(session, video: %{
  data: frame_data,
  mime_type: "image/jpeg"
})
```

## Receiving Messages

Messages are received through the `on_message` callback. Messages are parsed into `Gemini.Types.Live.ServerMessage` structs.

### Message Types

| Field | Type | Description |
|-------|------|-------------|
| `setup_complete` | `SetupComplete.t()` | Session setup successful |
| `server_content` | `ServerContent.t()` | Model response content |
| `tool_call` | `ToolCall.t()` | Function call request |
| `tool_call_cancellation` | `ToolCallCancellation.t()` | Cancelled tool calls |
| `go_away` | `GoAway.t()` | Session ending soon |
| `session_resumption_update` | `map()` | Session resumption handle |
| `voice_activity` | `map()` | Voice activity signal |

### Setup Complete

```elixir
%Gemini.Types.Live.ServerMessage{
  setup_complete: %Gemini.Types.Live.SetupComplete{}
}
```

### Model Response

```elixir
%Gemini.Types.Live.ServerMessage{
  server_content: %Gemini.Types.Live.ServerContent{
    model_turn: %{
      role: "model",
      parts: [%{text: "Paris is the capital of France."}]
    },
    turn_complete: true,
    input_transcription: nil,
    output_transcription: nil
  }
}

# Extract text from server content
alias Gemini.Types.Live.ServerContent

if text = ServerContent.extract_text(server_content) do
  IO.puts("Model: #{text}")
end
```

### Tool/Function Call

```elixir
%Gemini.Types.Live.ServerMessage{
  tool_call: %Gemini.Types.Live.ToolCall{
    function_calls: [
      %{
        id: "call_123",
        name: "get_weather",
        args: %{"location" => "San Francisco"}
      }
    ]
  }
}
```

### GoAway Notice

```elixir
%Gemini.Types.Live.ServerMessage{
  go_away: %Gemini.Types.Live.GoAway{
    time_left: "30s"  # Time until session closes
  }
}
```

## Function Calling

The Live API supports tool calling during conversations. Use the `on_tool_call` callback for specialized handling, or handle within the general `on_message` callback.

```elixir
alias Gemini.Live.Session

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

# Start session with tools and tool call handler
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  tools: tools,

  # Specialized tool call handler
  on_tool_call: fn %{function_calls: calls} ->
    # Execute each function call
    results = Enum.map(calls, fn call ->
      result = case call.name do
        "get_weather" ->
          location = call.args["location"]
          get_weather_data(location)  # Your implementation

        _ ->
          %{error: "Unknown function"}
      end

      %{
        id: call.id,
        name: call.name,
        response: result
      }
    end)

    # Send the results back
    Session.send_tool_response(session, results)
  end,

  on_message: fn msg ->
    case msg do
      %{server_content: c} when not is_nil(c) ->
        if text = Gemini.Types.Live.ServerContent.extract_text(c) do
          IO.puts("Model: #{text}")
        end
      _ -> :ok
    end
  end
)

:ok = Session.connect(session)
:ok = Session.send_client_content(session, "What's the weather in Tokyo?")
```

### Tool Response Scheduling

Control when tool responses are processed:

```elixir
# Interrupt current generation immediately
Session.send_tool_response(session, [
  %{id: "call_1", name: "get_weather", response: result, scheduling: :interrupt}
])

# Wait until current turn is complete
Session.send_tool_response(session, [
  %{id: "call_1", name: "get_weather", response: result, scheduling: :when_idle}
])

# Silent (no model response generated)
Session.send_tool_response(session, [
  %{id: "call_1", name: "get_weather", response: result, scheduling: :silent}
])
```

## Voice Activity Detection

The Live API supports automatic voice activity detection (VAD) for hands-free voice interactions.

### Automatic VAD (Default)

When automatic VAD is enabled, the model automatically detects when the user starts and stops speaking:

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["AUDIO"]},

  # Voice activity callback
  on_voice_activity: fn activity ->
    case activity do
      %{"speechStarted" => true} -> IO.puts("User started speaking")
      %{"speechEnded" => true} -> IO.puts("User stopped speaking")
      _ -> :ok
    end
  end
)
```

### Manual Activity Signaling

For push-to-talk or custom VAD implementations:

```elixir
# Signal start of user activity
Session.send_realtime_input(session, activity_start: true)

# Send audio while speaking
Session.send_realtime_input(session, audio: %{data: chunk, mime_type: "audio/pcm;rate=16000"})

# Signal end of user activity
Session.send_realtime_input(session, activity_end: true)
```

## Audio Handling

### Audio Transcription

Enable transcription of input and output audio:

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["AUDIO"]},

  # Enable transcription
  input_audio_transcription: %{},
  output_audio_transcription: %{},

  # Handle transcriptions
  on_transcription: fn
    {:input, transcription} ->
      IO.puts("User said: #{transcription["text"]}")

    {:output, transcription} ->
      IO.puts("Model said: #{transcription["text"]}")
  end
)
```

### Voice Configuration

Configure the model's voice for audio responses:

```elixir
generation_config = %{
  response_modalities: ["AUDIO"],
  speech_config: %{
    voice_config: %{
      prebuilt_voice_config: %{
        voice_name: "Kore"  # or "Puck", "Charon", "Fenrir", "Aoede"
      }
    }
  }
}
```

## Session Management

### Session Status

Check the current session status:

```elixir
status = Session.status(session)
# => :disconnected | :connecting | :setup_pending | :ready | :closing
```

### Session Resumption

Enable and handle session resumption for recovering from disconnections:

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},

  # Enable session resumption
  session_resumption: %{},

  # Get notified of session handles
  on_session_resumption: fn %{handle: handle, resumable: true} ->
    # Store handle for later resumption
    save_session_handle(handle)
  end
)

# Get the current session handle
handle = Session.get_session_handle(session)

# Later, resume the session
{:ok, resumed} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  resume_handle: handle  # Resume from previous session
)
```

### Context Window Compression

Enable sliding window compression for long sessions:

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},

  # Enable context compression
  context_window_compression: %{sliding_window: %{}}
)
```

### Graceful Shutdown

Handle impending session termination:

```elixir
{:ok, session} = Session.start_link(
  # ...
  on_go_away: fn %{time_left_ms: time_left, handle: handle} ->
    IO.puts("Session ending in #{time_left}ms")
    if handle do
      IO.puts("Can resume with handle: #{handle}")
    end
    # Perform cleanup or prepare for reconnection
  end
)
```

## Error Handling

### Common Errors

```elixir
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},

  on_error: fn error ->
    case error do
      {:authentication_failed, _} ->
        IO.puts("Check your API key configuration")

      {:connection_down, reason} ->
        IO.puts("Connection lost: #{inspect(reason)}")

      {:setup_failed, reason} ->
        IO.puts("Setup failed: #{inspect(reason)}")

      other ->
        IO.puts("Unexpected error: #{inspect(other)}")
    end
  end
)
```

### Session State Errors

```elixir
# Attempting to send before connection is ready
case Session.send_client_content(session, "Hello") do
  :ok -> IO.puts("Message sent")
  {:error, {:not_ready, status}} -> IO.puts("Session not ready: #{status}")
  {:error, reason} -> IO.puts("Send failed: #{inspect(reason)}")
end
```

### Timeouts and Retries

```elixir
defmodule ResilientChat do
  alias Gemini.Live.Session

  def send_with_retry(session, message, retries \\ 3) do
    case Session.send_client_content(session, message) do
      :ok ->
        :ok

      {:error, {:not_ready, _status}} when retries > 0 ->
        # Wait and retry
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
    %{server_content: content} when not is_nil(content) -> handle_content(content)
    %{tool_call: tc} when not is_nil(tc) -> handle_tools(tc)
    %{go_away: _} -> handle_shutdown()
    _ -> Logger.debug("Other message: #{inspect(message)}")
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
      model: "gemini-2.5-flash-native-audio-preview-12-2025",
      auth: :gemini,
      generation_config: %{response_modalities: ["TEXT"]},
      on_message: fn msg -> send(self(), {:live_message, msg}) end
    )

    :ok = Session.connect(session)

    {:ok, %{session: session}}
  end

  def handle_info({:live_message, msg}, state) do
    # Process message
    {:noreply, state}
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
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},

  on_message: fn message ->
    Logger.debug("Received message", message: inspect(message))
  end,

  on_error: fn error ->
    Logger.error("Live API error", error: inspect(error))
  end,

  on_close: fn reason ->
    Logger.info("Session closed", reason: inspect(reason))
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
      Session.send_client_content(state.session, message)
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
- `Gemini.Types.Live.ServerMessage` - Server message types
- `Gemini.Types.Live.ServerContent` - Response content
- `Gemini.Types.Live.ToolCall` - Tool call requests
- `Gemini.Types.Live.Setup` - Session setup configuration

## Troubleshooting

### Connection Issues

```elixir
# Check authentication
api_key = System.get_env("GEMINI_API_KEY")
IO.inspect(api_key != nil, label: "API Key configured?")

# Enable debug logging
Logger.configure(level: :debug)

# Test basic connectivity
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  on_error: fn error -> IO.inspect(error, label: "Error") end
)

case Session.connect(session) do
  :ok -> IO.puts("Connected successfully")
  {:error, reason} -> IO.puts("Connection failed: #{inspect(reason)}")
end
```

### Message Not Received

```elixir
# Ensure callbacks are configured and session is ready
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  on_message: fn msg ->
    IO.inspect(msg, label: "Message received", limit: :infinity)
  end
)

:ok = Session.connect(session)

# Check session status
status = Session.status(session)
IO.puts("Session status: #{status}")
# => :ready (when connected and setup complete)
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

# Use on_tool_call callback for cleaner handling
{:ok, session} = Session.start_link(
  model: "gemini-2.5-flash-native-audio-preview-12-2025",
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  tools: tools,

  on_tool_call: fn %{function_calls: calls} ->
    results = Enum.map(calls, fn call ->
      %{id: call.id, name: call.name, response: execute_function(call)}
    end)
    Session.send_tool_response(session, results)
  end
)
```

## Examples

See the [examples directory](https://github.com/nshkrdotcom/gemini_ex/tree/main/examples) for complete working examples:

- `examples/live_api_demo.exs` - Basic text chat session
- `examples/live_function_calling.exs` - Tool calling with Live API
- `examples/live_tools.exs` - Function calling with Live API

## Related Documentation

- [Function Calling Guide](function_calling.md)
- [Authentication System](../../AUTHENTICATION_SYSTEM.md)
- [Streaming Architecture](../../STREAMING_ARCHITECTURE.md)
