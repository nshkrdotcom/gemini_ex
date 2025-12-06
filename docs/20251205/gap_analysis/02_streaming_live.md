# Gap Analysis: Streaming & Live Capabilities

## Executive Summary

The Python genai SDK uses **WebSocket-based bidirectional streaming** for real-time interaction, while the Elixir implementation uses **SSE (Server-Sent Events)** for one-way streaming. This represents a fundamental architectural difference.

## Feature Comparison Table

| Feature | Python genai | Elixir | Gap Level |
|---------|-------------|--------|-----------|
| **Connection Type** | WebSocket (BidiGenerateContent) | HTTP/SSE | CRITICAL |
| **Bidirectional** | ✅ Yes | ❌ No | CRITICAL |
| **Session Persistence** | ✅ Yes (session IDs) | ❌ No | HIGH |
| **Session Resumption** | ✅ Yes | ❌ No | HIGH |
| **Live Audio Input** | ✅ Yes (PCM with rate) | ❌ No | CRITICAL |
| **Live Video Input** | ✅ Yes (frame streaming) | ❌ No | CRITICAL |
| **Voice Activity Detection** | ✅ Yes (VAD) | ❌ No | HIGH |
| **Real-time Text Input** | ✅ Yes | ❌ No | HIGH |
| **Audio Transcription** | ✅ Yes (input/output) | ❌ No | MEDIUM |
| **Live Music Generation** | ✅ Yes | ❌ No | LOW |
| **Music Control** | Play/Pause/Stop/Reset | ❌ No | LOW |
| **Activity Markers** | ✅ Yes (start/end) | ❌ No | MEDIUM |
| **Tool Use (Real-time)** | ✅ Yes (streaming) | ✅ Yes (orchestrator) | CLOSED |
| **Connection Persistence** | ✅ Yes | ❌ No | HIGH |
| **Context Compression** | ✅ Yes | ❌ No | MEDIUM |
| **Proactivity Config** | ✅ Yes | ❌ No | LOW |

## Python Live Architecture

### Core Components (live.py)

**Real-Time Bidirectional Communication:**
- WebSocket-based connections using `websockets` library
- Full duplex: simultaneous send/receive capability
- Session-based architecture with session IDs and resumption

**Three Distinct Send Methods:**
1. `send_client_content()` - Turn-based non-realtime (processed in order)
2. `send_realtime_input()` - True realtime with VAD support
3. `send_tool_response()` - Function call responses

**Supported Input Types:**
- Audio streams (PCM format with rate specification)
- Video frames (images)
- Text
- Activity markers (start/end)
- Media from PIL, file paths, or binary blobs

### Live Music (live_music.py)

**Capabilities:**
- `AsyncLiveMusic` with `set_weighted_prompts()`
- Music generation config control
- Playback control (play, pause, stop, reset_context)
- Continues while prompts are updated

### Session Management

**Features:**
- Session IDs for long-lived conversations
- Session resumption with handles
- Context window compression
- Input/output audio transcription
- Proactivity settings

## Elixir Streaming Architecture

### Current Implementation

**SSE Parser (`sse/parser.ex`):**
- Stateful buffer management
- Incremental chunk parsing
- Event extraction and delivery

**Streaming Manager (`streaming/manager_v2.ex`, `unified_manager.ex`):**
- GenServer-based lifecycle management
- Subscriber pattern for event distribution
- Stream tracking and cleanup
- Multi-auth routing support

**Tool Orchestrator (`streaming/tool_orchestrator.ex`):**
- Automatic function calling during streams
- Multi-turn tool execution
- Result aggregation

### Limitations

- One-directional: receive only
- HTTP-based request-response pattern
- No WebSocket support
- No session-based architecture
- No connection persistence
- No live audio/video streaming

## Critical Gaps

### 1. WebSocket Support (HIGHEST PRIORITY)
- **Current:** HTTP/SSE one-way
- **Needed:** WebSocket integration for bidirectional communication
- **Effort:** HIGH - requires architectural change
- **Impact:** Enables all real-time features

### 2. Real-Time Audio/Video Streaming (HIGH)
- **Current:** None
- **Needed:** Blob streaming for audio chunks and video frames
- **Effort:** HIGH - requires codec support and frame handling
- **Impact:** Critical for voice interaction

### 3. Session Management (HIGH)
- **Current:** Per-stream tracking only
- **Needed:** Session IDs, resumption, context persistence
- **Effort:** MEDIUM
- **Impact:** Enables long-lived conversations

### 4. Voice Activity Detection (MEDIUM)
- **Current:** Not implemented
- **Needed:** Audio analysis for automatic response triggering
- **Effort:** HIGH
- **Impact:** Improves UX for voice applications

### 5. Live Music Generation (LOW)
- **Current:** Not implemented
- **Needed:** Dedicated music streaming with config control
- **Effort:** MEDIUM
- **Impact:** Niche but valuable for music apps

## Implementation Roadmap

### Phase 1: WebSocket Foundation (v0.8)
- Add `websockets_client` dependency
- Create WebSocket connection manager
- Implement bidirectional message protocol
- Add session management layer

### Phase 2: Real-Time Media (v0.9)
- Implement audio chunk streaming (PCM)
- Add video frame streaming
- Create media buffer handling
- Integration with existing streaming parser

### Phase 3: Voice Features (v1.0)
- Audio transcription support
- Voice activity detection
- Proactivity configuration
- Connection persistence

### Phase 4: Music & Extensions (v1.1)
- Live music generation module
- Music control API
- Music config management
- Weighted prompts support

## Conclusion

The Elixir implementation excels at **simple SSE streaming** but lacks the **bidirectional, session-based, media-aware** capabilities of Python's live API. The gap is architectural, requiring WebSocket support as the foundation for advanced live capabilities.

**Estimated Effort:** 15-25 developer days for Phases 1-3
