# Live API Guide

The Live API enables low-latency, real-time voice and video interactions with Gemini. It processes continuous streams of audio, video, or text to deliver immediate, human-like spoken responses, creating a natural conversational experience.

## Table of Contents

1. [Overview](#overview)
2. [Implementation Approaches](#implementation-approaches)
3. [WebSocket Connection](#websocket-connection)
4. [Supported Modalities](#supported-modalities)
5. [Models and Response Modalities](#models-and-response-modalities)
6. [Establishing a Session](#establishing-a-session)
7. [Sending Content](#sending-content)
8. [Receiving Responses](#receiving-responses)
9. [Voice Activity Detection](#voice-activity-detection)
10. [Native Audio Features](#native-audio-features)
11. [Tool Use and Function Calling](#tool-use-and-function-calling)
12. [Session Management](#session-management)
13. [Ephemeral Tokens](#ephemeral-tokens)
14. [Limitations](#limitations)
15. [Examples](#examples)

## Overview

The Live API is a stateful, bidirectional streaming API built on WebSockets. Unlike the standard `generateContent` API, the Live API maintains a persistent connection where you can:

- Send text, audio, or video continuously to the Gemini server
- Receive audio, text, or function call requests from the Gemini server
- Interrupt model responses mid-generation
- Resume sessions after disconnection
- Use automatic voice activity detection for hands-free conversations

### Key Features

- **Voice Activity Detection (VAD)**: Automatic detection of when users start and stop speaking
- **Tool Use and Function Calling**: Execute functions during real-time conversations
- **Session Management**: Resume sessions, compress context windows, handle graceful disconnections
- **Ephemeral Tokens**: Secure client-side authentication for browser/mobile applications
- **Native Audio**: Natural speech output with affective dialog and proactive responses (v1alpha)

## Implementation Approaches

When integrating with the Live API, choose between:

### Server-to-Server

Your backend connects to the Live API using WebSockets. The client sends stream data (audio, video, text) to your server, which then forwards it to the Live API.

```
Client App -> Your Backend -> Live API
```

### Client-to-Server

Your frontend connects directly to the Live API using WebSockets, bypassing your backend.

```
Client App -> Live API
```

Client-to-server offers better performance for streaming audio and video since it eliminates the hop through your backend. However, for production environments, use [ephemeral tokens](#ephemeral-tokens) instead of standard API keys to mitigate security risks.

## WebSocket Connection

### Endpoint

The Live API uses WebSocket connections to the following endpoints:

**Gemini API (AI Studio):**
```
wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent
```

**Vertex AI:**
```
wss://{location}-aiplatform.googleapis.com/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent
```

### API Version

The standard API version is `v1beta`. Some features require `v1alpha`:
- Affective dialog
- Proactive audio
- Ephemeral tokens

Set the API version per session:

```elixir
alias Gemini.Live.Models

{:ok, session} = Session.start_link(
  model: Models.resolve(:audio),
  auth: :gemini,
  api_version: "v1alpha",      # required for native audio extras
  generation_config: %{response_modalities: ["AUDIO"]}
)
```

This library abstracts the WebSocket connection details. You interact through the `Gemini.Live.Session` module.

### Session Configuration

The initial message after establishing the WebSocket connection sets the session configuration:

```elixir
alias Gemini.Live.Models

%{
  model: Models.resolve(:audio),
  generation_config: %{
    response_modalities: ["AUDIO"],  # or ["TEXT"]
    temperature: 0.7,
    speech_config: %{voice_config: %{prebuilt_voice_config: %{voice_name: "Kore"}}}
  },
  system_instruction: "You are a helpful assistant.",
  tools: [%{function_declarations: [...]}]
}
```

Configuration cannot be updated while the connection is open. However, you can change parameters (except the model) when resuming via session resumption.

## Supported Modalities

### Input Modalities

| Modality | Format | Notes |
|----------|--------|-------|
| Audio | 16-bit PCM, little-endian | Input natively at 16kHz; the API resamples other rates. MIME type: `audio/pcm;rate=16000` |
| Video | JPEG/PNG frames | Sent as base64-encoded blobs |
| Text | UTF-8 string | Via `clientContent` or `realtimeInput` |

### Output Modalities

| Modality | Format | Notes |
|----------|--------|-------|
| Audio | 16-bit PCM, 24kHz | Native audio output models only |
| Text | UTF-8 string | All Live API models |

**Important:** You can only set one response modality (`TEXT` or `AUDIO`) per session. Setting both results in a configuration error.

## Models and Response Modalities

### Native Audio Models (Recommended for Voice)

Native audio output provides natural, realistic-sounding speech with improved multilingual performance. Use these models when you need audio responses:

```elixir
alias Gemini.Live.Models

# Resolve a Live audio model available for this key
model = Models.resolve(:audio)
```

Native audio models support:
- 128k token context window
- Affective (emotion-aware) dialogue (v1alpha)
- Proactive audio responses (v1alpha)
- Thinking capabilities

### General-Purpose Live Models

For text-only responses or lower latency requirements:

```elixir
alias Gemini.Live.Models

# Resolve a Live text model available for this key
model = Models.resolve(:text)
```

General-purpose Live API models have a 32k token context window.

### Model Availability and Rollout Variability

Live API model availability can vary by project and rollout. The canonical
Live docs may list newer models that are not yet enabled for your API key.
When that happens, the Live API returns a `1008` close error like:

```
models/gemini-live-2.5-flash-preview is not found for API version v1beta,
or is not supported for bidiGenerateContent
```

To make this robust, this library resolves a Live model at runtime based on
your key's `list_models` results.

Use the resolver:

```elixir
alias Gemini.Live.Models

text_model = Models.resolve(:text)
audio_model = Models.resolve(:audio)
```

The resolver prefers newer Live models when available, and falls back to the
older rollout-safe models:

- Text fallback: `gemini-2.0-flash-exp`
- Image fallback: `gemini-2.0-flash-exp-image-generation`
- Audio fallback: `gemini-2.5-flash-native-audio-preview-12-2025`

If the audio model is not present in your Live-capable model list, audio
sessions will not work for that key yet.

You can inspect what your key supports:

```bash
GEMINI_API_KEY=YOUR_KEY mix run -e 'alias Gemini.APIs.Coordinator; {:ok, resp}=Coordinator.list_models(); resp.models |> Enum.filter(&Enum.member?(&1.supported_generation_methods, "bidiGenerateContent")) |> Enum.each(fn m -> IO.puts(m.name) end)'
```

If you want to hardcode a model, prefer the resolver's fallback choices when
newer Live models are not present in that list.

### Session Limits

| Configuration | Duration Limit |
|---------------|----------------|
| Audio only | 15 minutes |
| Audio + Video | 2 minutes |

Use [context window compression](#context-window-compression) or [session resumption](#session-resumption) to extend beyond these limits.

## Establishing a Session

### Basic Setup

```elixir
alias Gemini.Live.Models
alias Gemini.Live.Session

# Resolve a model that is available for this API key
model = Models.resolve(:text)

{:ok, session} = Session.start_link(
  model: model,
  auth: :gemini,  # or :vertex_ai
  generation_config: %{
    response_modalities: ["TEXT"]
  },
  on_message: fn message ->
    IO.inspect(message, label: "Received")
  end
)

# Connect to the Live API
:ok = Session.connect(session)

# Session is now ready for messages
```

### Full Configuration Options

```elixir
alias Gemini.Live.Models

{:ok, session} = Session.start_link(
  # Required
  model: Models.resolve(:audio),

  # Authentication
  auth: :gemini,  # or :vertex_ai
  project_id: "your-project",  # required for :vertex_ai
  location: "us-central1",     # optional, default: "us-central1"
  api_version: "v1alpha",

  # Generation configuration
  generation_config: %{
    response_modalities: ["AUDIO"],  # or ["TEXT"]
    temperature: 0.7,
    top_p: 0.95,
    speech_config: %{
      voice_config: %{
        prebuilt_voice_config: %{voice_name: "Kore"}
      }
    }
  },

  # System instruction
  system_instruction: "You are a helpful voice assistant.",

  # Tools for function calling
  tools: [%{function_declarations: [...]}],

  # Realtime input configuration
  realtime_input_config: %{
    automatic_activity_detection: %{
      disabled: false,  # true for manual VAD
      start_of_speech_sensitivity: "START_SENSITIVITY_HIGH",
      end_of_speech_sensitivity: "END_SENSITIVITY_HIGH"
    }
  },

  # Session management
  session_resumption: %{},           # Enable session resumption
  resume_handle: "previous-handle",  # Resume from previous session
  context_window_compression: %{sliding_window: %{}},

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

The Live API provides two methods for sending content, each with different semantics:

### clientContent (Ordered, Explicit Turns)

Use `send_client_content/3` for text input where ordering matters. This method:
- Adds content to the conversation history in order
- Interrupts any current model generation
- Requires explicit turn completion signal

```elixir
# Simple text message
Session.send_client_content(session, "What is the capital of France?")

# Incremental content (turn_complete: false to continue building)
Session.send_client_content(session, "Part 1 of my question...", turn_complete: false)
Session.send_client_content(session, "Part 2...", turn_complete: true)

# Multi-turn context restoration
Session.send_client_content(session, [
  %{role: "user", parts: [%{text: "What is the capital of France?"}]},
  %{role: "model", parts: [%{text: "Paris"}]},
  %{role: "user", parts: [%{text: "What about Germany?"}]}
], turn_complete: true)
```

### realtimeInput (Streaming, Optimized for Speed)

Use `send_realtime_input/2` for continuous streaming data (audio, video, text). This method:
- Streams data without interrupting model generation
- Optimizes for low latency at the expense of deterministic ordering
- Derives turn boundaries from activity detection (VAD)
- Processes data incrementally before turn completion

```elixir
# Send audio chunk (16-bit PCM, 16kHz mono)
Session.send_realtime_input(session, audio: %{
  data: pcm_data,  # binary data, will be Base64 encoded
  mime_type: "audio/pcm;rate=16000"
})

# Send video frame
Session.send_realtime_input(session, video: %{
  data: jpeg_data,
  mime_type: "image/jpeg"
})

# Send text via realtime input
Session.send_realtime_input(session, text: "Hello")

# Manual activity signaling (when automatic VAD is disabled)
Session.send_realtime_input(session, activity_start: true)
# ... send audio chunks ...
Session.send_realtime_input(session, activity_end: true)

# Signal audio stream pause (for automatic VAD)
Session.send_realtime_input(session, audio_stream_end: true)
```

### Ordering Considerations

- `clientContent` messages are added to context in order
- `realtimeInput` is optimized for responsiveness; ordering across modalities is not guaranteed
- If you mix `clientContent` and `realtimeInput`, the server attempts to optimize but provides no ordering guarantees

## Receiving Responses

Responses are delivered through the `on_message` callback. The server sends `BidiGenerateContentServerMessage` which may contain:

### Message Types

| Field | Description |
|-------|-------------|
| `setup_complete` | Session setup successful |
| `server_content` | Model response content |
| `tool_call` | Function call request |
| `tool_call_cancellation` | Cancelled tool calls (due to interruption) |
| `go_away` | Session ending soon notice |
| `session_resumption_update` | New resumption handle |
| `voice_activity` | Voice activity signals |
| `usage_metadata` | Token usage information |

### Server Content

```elixir
on_message: fn message ->
  case message do
    %{server_content: content} when not is_nil(content) ->
      # Extract text
      if text = Gemini.Types.Live.ServerContent.extract_text(content) do
        IO.write(text)
      end

      # Handle audio output
      if content.model_turn && content.model_turn.parts do
        for part <- content.model_turn.parts do
          if audio_data = part[:inline_data] do
            # Process audio (24kHz PCM)
            play_audio(audio_data.data)
          end
        end
      end

      # Turn completion signals
      if content.turn_complete do
        IO.puts("\n[Turn complete]")
      end

      # Generation complete (before turn_complete when streaming)
      if content.generation_complete do
        IO.puts("[Generation complete]")
      end

      # Handle interruption
      if content.interrupted do
        IO.puts("[Interrupted by user]")
        clear_audio_queue()
      end

    _ -> :ok
  end
end
```

### Transcription

When transcription is enabled, you receive transcriptions separately from content:

```elixir
on_transcription: fn
  {:input, %{"text" => text}} ->
    IO.puts("User said: #{text}")

  {:output, %{"text" => text}} ->
    IO.puts("Model said: #{text}")
end
```

## Voice Activity Detection

VAD allows the model to recognize when a person is speaking, enabling natural interruptions.

### Automatic VAD (Default)

When automatic VAD is enabled, the model automatically detects speech and triggers responses:

```elixir
alias Gemini.Live.Models

{:ok, session} = Session.start_link(
  model: Models.resolve(:audio),
  auth: :gemini,
  generation_config: %{response_modalities: ["AUDIO"]},
  # VAD is enabled by default
  on_message: fn message ->
    case message do
      %{server_content: %{interrupted: true}} ->
        # User interrupted - clear playback queue
        clear_audio_playback()
      _ -> :ok
    end
  end
)
```

When the audio stream is paused (e.g., microphone turned off), send `audio_stream_end` to flush cached audio:

```elixir
Session.send_realtime_input(session, audio_stream_end: true)
```

### VAD Configuration

Fine-tune VAD behavior:

```elixir
realtime_input_config: %{
  automatic_activity_detection: %{
    disabled: false,
    start_of_speech_sensitivity: "START_SENSITIVITY_LOW",  # or HIGH
    end_of_speech_sensitivity: "END_SENSITIVITY_LOW",      # or HIGH
    prefix_padding_ms: 20,      # Audio to keep before speech detection
    silence_duration_ms: 100    # Silence required for end-of-speech
  }
}
```

### Manual VAD

For push-to-talk or custom VAD implementations:

```elixir
alias Gemini.Live.Models

{:ok, session} = Session.start_link(
  model: Models.resolve(:audio),
  auth: :gemini,
  generation_config: %{response_modalities: ["AUDIO"]},
  realtime_input_config: %{
    automatic_activity_detection: %{disabled: true}
  }
)

# When user presses talk button
Session.send_realtime_input(session, activity_start: true)

# Stream audio while talking
for chunk <- audio_chunks do
  Session.send_realtime_input(session, audio: %{
    data: chunk,
    mime_type: "audio/pcm;rate=16000"
  })
end

# When user releases talk button
Session.send_realtime_input(session, activity_end: true)
```

## Native Audio Features

Native audio models support advanced features (requires `v1alpha` API version for some features).

### Voice Selection

```elixir
generation_config: %{
  response_modalities: ["AUDIO"],
  speech_config: %{
    voice_config: %{
      prebuilt_voice_config: %{voice_name: "Kore"}
    }
  }
}
```

Available voices include: Kore, Puck, Charon, Fenrir, Aoede, and others. Listen to voices in [AI Studio](https://aistudio.google.com/app/live).

### Affective Dialog (v1alpha)

Adapts response style to input expression and tone:

```elixir
alias Gemini.Live.Models

# Note: Requires v1alpha API version
{:ok, session} = Session.start_link(
  model: Models.resolve(:audio),
  auth: :gemini,
  api_version: "v1alpha",
  generation_config: %{response_modalities: ["AUDIO"]},
  enable_affective_dialog: true
)
```

### Proactive Audio (v1alpha)

Allows the model to decide not to respond if content is irrelevant:

```elixir
alias Gemini.Live.Models

# Note: Requires v1alpha API version
{:ok, session} = Session.start_link(
  model: Models.resolve(:audio),
  auth: :gemini,
  api_version: "v1alpha",
  generation_config: %{response_modalities: ["AUDIO"]},
  proactivity: %{proactive_audio: true}
)
```

### Thinking

Native audio models support thinking capabilities:

```elixir
alias Gemini.Live.Models

{:ok, session} = Session.start_link(
  model: Models.resolve(:audio),
  auth: :gemini,
  api_version: "v1alpha",
  generation_config: %{
    response_modalities: ["AUDIO"],
    thinking_config: %{
      thinking_budget: 1024,     # Token budget for thinking
      include_thoughts: true     # Include thought summaries
    }
  }
)
```

## Tool Use and Function Calling

The Live API supports function calling, but unlike `generateContent`, you must handle tool responses manually.

### Defining Tools

```elixir
tools = [
  %{
    function_declarations: [
      %{
        name: "get_weather",
        description: "Get current weather for a location",
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
```

### Handling Tool Calls

```elixir
alias Gemini.Live.Models

{:ok, session} = Session.start_link(
  model: Models.resolve(:text),
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  tools: tools,

  on_tool_call: fn %{function_calls: calls} ->
    responses = Enum.map(calls, fn call ->
      result = case call.name do
        "get_weather" ->
          location = call.args["location"]
          get_weather_data(location)  # Your implementation
        _ ->
          %{error: "Unknown function"}
      end

      %{id: call.id, name: call.name, response: result}
    end)

    # Return responses to send automatically
    {:tool_response, responses}
  end
)
```

Alternatively, send tool responses manually:

```elixir
Session.send_tool_response(session, [
  %{id: "call_123", name: "get_weather", response: %{temp: 72}}
])
```

### Asynchronous Function Calling

For non-blocking function execution:

```elixir
tools = [
  %{
    function_declarations: [
      %{
        name: "long_running_task",
        behavior: "NON_BLOCKING"  # Execute asynchronously
      }
    ]
  }
]

# Control response timing with scheduling
Session.send_tool_response(session, [
  %{
    id: "call_123",
    name: "long_running_task",
    response: %{result: "done"},
    scheduling: :interrupt   # or :when_idle, :silent
  }
])
```

Scheduling options:
- `:interrupt` - Interrupt current generation immediately
- `:when_idle` - Wait until current turn completes
- `:silent` - Don't generate a response

### Tool Call Cancellation

When the user interrupts during function execution, the server sends cancellation:

```elixir
on_tool_call_cancellation: fn cancelled_ids ->
  IO.puts("Cancelled: #{inspect(cancelled_ids)}")
  # Attempt to undo side effects if possible
end
```

## Session Management

### Session Resumption

Resume sessions after disconnection to preserve conversation context:

```elixir
alias Gemini.Live.Models

# First session - enable resumption
{:ok, session1} = Session.start_link(
  model: Models.resolve(:text),
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  session_resumption: %{},
  on_session_resumption: fn %{handle: handle, resumable: true} ->
    # Store handle for later use
    save_handle(handle)
  end
)

:ok = Session.connect(session1)
:ok = Session.send_client_content(session1, "Remember: my name is Alice.")
Process.sleep(3000)

# Get handle before closing
handle = Session.get_session_handle(session1)
Session.close(session1)

# Later - resume with saved handle
{:ok, session2} = Session.start_link(
  model: Models.resolve(:text),
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  resume_handle: handle,
  session_resumption: %{}
)

:ok = Session.connect(session2)
:ok = Session.send_client_content(session2, "What's my name?")
# Model should remember: Alice
```

Resumption tokens are valid for 2 hours after the last session termination.

### Context Window Compression

Enable sliding window compression for long sessions:

```elixir
alias Gemini.Live.Models

{:ok, session} = Session.start_link(
  model: Models.resolve(:text),
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  context_window_compression: %{
    sliding_window: %{
      target_tokens: 16000  # Target after compression
    },
    trigger_tokens: 24000   # When to trigger compression
  }
)
```

Compression extends session duration indefinitely but may affect response quality as older context is discarded.

### GoAway Notice

The server sends a GoAway message before disconnecting:

```elixir
on_go_away: fn %{time_left_ms: time_left, handle: handle} ->
  IO.puts("Session ending in #{time_left}ms")

  # Save handle for resumption
  if handle, do: save_handle(handle)

  # Prepare for reconnection
  schedule_reconnect()
end
```

### Generation Complete

The server sends `generation_complete` when the model finishes generating (before `turn_complete`):

```elixir
on_message: fn message ->
  case message do
    %{server_content: %{generation_complete: true}} ->
      IO.puts("[Model finished generating]")

    %{server_content: %{turn_complete: true}} ->
      IO.puts("[Turn complete - ready for next input]")

    _ -> :ok
  end
end
```

## Ephemeral Tokens

Ephemeral tokens are short-lived authentication tokens for client-to-server implementations. They enhance security by:

- Expiring quickly (default: 30 minutes)
- Limiting the number of sessions they can create
- Optionally constraining configuration options

### Token Constraints

Ephemeral tokens require `v1alpha` API version and are only compatible with the Live API.

**Token Properties:**
- `expire_time`: When messages will be rejected (default: 30 minutes)
- `new_session_expire_time`: When new sessions will be rejected (default: 1 minute)
- `uses`: Number of sessions the token can start (default: 1)

### Creating Tokens (Server-Side)

Create tokens on your backend and pass them to clients:

```elixir
# This would typically be done via the REST API on your backend
# The token is then passed to the client application

# Example token structure returned from API:
%{
  "name" => "ephemeral-token-string",  # Use this as the API key
  "expireTime" => "2025-01-23T12:00:00Z",
  "newSessionExpireTime" => "2025-01-23T11:31:00Z"
}
```

### Using Tokens (Client-Side)

The client uses the token as if it were an API key:

```javascript
// In browser/mobile client
const session = await ai.live.connect({
  model: 'gemini-2.5-flash-native-audio-preview-12-2025',
  apiKey: ephemeralToken.name,  // Use token instead of API key
  config: { responseModalities: ['AUDIO'] }
});
```

### Token with Configuration Constraints

Lock tokens to specific configurations for additional security:

```elixir
# Server-side token creation with constraints
token_config = %{
  uses: 1,
  live_connect_constraints: %{
    model: "gemini-2.5-flash-native-audio-preview-12-2025",
    config: %{
      session_resumption: %{},
      temperature: 0.7,
      response_modalities: ["AUDIO"]
    }
  }
}
```

### Best Practices

1. Set short expiration times
2. Verify secure authentication on your backend before issuing tokens
3. Don't use ephemeral tokens for server-to-server connections (unnecessary overhead)
4. Use `sessionResumption` within a token's `expireTime` to reconnect without consuming additional uses

## Limitations

### Response Modalities

Only one response modality (`TEXT` or `AUDIO`) per session. You cannot receive both text and audio in the same session.

### Session Duration

Without compression:
- Audio-only: 15 minutes
- Audio + Video: 2 minutes

### Context Window

- Native audio models: 128k tokens
- Other Live API models: 32k tokens

### Authentication

Standard API keys should not be used in client-side code. Use [ephemeral tokens](#ephemeral-tokens) for client-to-server implementations.

### Supported Languages

Native audio models automatically detect language and don't support explicit language codes. See the [canonical documentation](https://ai.google.dev/gemini-api/docs/live-guide#supported-languages) for the full list of supported languages.

## Examples

### Text Chat Session

```elixir
alias Gemini.Live.Session
alias Gemini.Live.Models

model = Models.resolve(:text)

{:ok, session} = Session.start_link(
  model: model,
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  system_instruction: "You are a helpful assistant.",
  on_message: fn
    %{server_content: content} when not is_nil(content) ->
      if text = Gemini.Types.Live.ServerContent.extract_text(content) do
        IO.write(text)
      end
      if content.turn_complete, do: IO.puts("\n")
    _ -> :ok
  end
)

:ok = Session.connect(session)

Session.send_client_content(session, "What is machine learning?")
Process.sleep(5000)

Session.close(session)
```

### Audio Streaming

```elixir
alias Gemini.Live.Session
alias Gemini.Live.Models

model = Models.resolve(:audio)

{:ok, session} = Session.start_link(
  model: model,
  auth: :gemini,
  api_version: "v1alpha",
  generation_config: %{
    response_modalities: ["AUDIO"],
    speech_config: %{voice_config: %{prebuilt_voice_config: %{voice_name: "Kore"}}}
  },
  input_audio_transcription: %{},
  output_audio_transcription: %{},
  on_message: fn
    %{server_content: content} when not is_nil(content) ->
      # Handle audio output
      if content.model_turn && content.model_turn.parts do
        for part <- content.model_turn.parts do
          if part[:inline_data], do: play_audio(part.inline_data.data)
        end
      end
    _ -> :ok
  end,
  on_transcription: fn
    {:input, t} -> IO.puts("User: #{t["text"]}")
    {:output, t} -> IO.puts("Model: #{t["text"]}")
  end
)

:ok = Session.connect(session)

# Send audio chunks (16kHz PCM)
for chunk <- audio_chunks do
  Session.send_realtime_input(session, audio: %{
    data: chunk,
    mime_type: "audio/pcm;rate=16000"
  })
end

Process.sleep(5000)
Session.close(session)
```

### Function Calling

```elixir
alias Gemini.Live.Session
alias Gemini.Live.Models

tools = [
  %{
    function_declarations: [
      %{
        name: "get_stock_price",
        description: "Get current stock price",
        parameters: %{
          type: "object",
          properties: %{symbol: %{type: "string"}},
          required: ["symbol"]
        }
      }
    ]
  }
]

{:ok, session} = Session.start_link(
  model: Models.resolve(:text),
  auth: :gemini,
  generation_config: %{response_modalities: ["TEXT"]},
  tools: tools,
  on_tool_call: fn %{function_calls: calls} ->
    responses = Enum.map(calls, fn call ->
      result = case call.name do
        "get_stock_price" -> %{price: 178.50, currency: "USD"}
        _ -> %{error: "Unknown function"}
      end
      %{id: call.id, name: call.name, response: result}
    end)
    {:tool_response, responses}
  end,
  on_message: fn
    %{server_content: c} when not is_nil(c) ->
      if text = Gemini.Types.Live.ServerContent.extract_text(c), do: IO.write(text)
      if c.turn_complete, do: IO.puts("\n")
    _ -> :ok
  end
)

:ok = Session.connect(session)
Session.send_client_content(session, "What's Apple's stock price?")
Process.sleep(10000)
Session.close(session)
```

### Session Resumption

See `examples/13_live_session_resumption.exs` for a complete example.

## Further Reading

- [Example Files](https://github.com/nshkrdotcom/gemini_ex/tree/main/examples)
  - `11_live_text_chat.exs` - Multi-turn text conversations
  - `12_live_audio_streaming.exs` - Audio input/output
  - `13_live_session_resumption.exs` - Session resumption
  - `14_live_function_calling.exs` - Tool use with telemetry
- [Google's Live API Documentation](https://ai.google.dev/gemini-api/docs/live)
- [WebSocket API Reference](https://ai.google.dev/api/live)
