# Gemini Ex Examples

Comprehensive examples demonstrating all features of the Gemini Elixir client.

## Prerequisites

Set up authentication using **one** of the following methods:

### Option 1: Gemini API Key (Recommended for getting started)
```bash
export GEMINI_API_KEY="your-api-key-here"
```

### Option 2: Vertex AI (For production/enterprise)
```bash
export VERTEX_JSON_FILE="/path/to/service-account.json"
# OR
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/credentials.json"
```

## Running Examples

### Run a single example:
```bash
mix run examples/01_basic_generation.exs
```

### Run all examples:
```bash
./examples/run_all.sh
```

### Run with verbose output:
```bash
./examples/run_all.sh -v
```

## Examples Overview

| # | File | Description |
|---|------|-------------|
| 01 | `01_basic_generation.exs` | Simple text generation, configured generation, creative vs precise |
| 02 | `02_streaming.exs` | Real-time streaming with timing analysis |
| 03 | `03_chat_session.exs` | Multi-turn conversations with context retention |
| 04 | `04_embeddings.exs` | Single/batch embeddings, similarity matrices, task types |
| 05 | `05_function_calling.exs` | Tool registration, single call, automatic tool execution loops |
| 06 | `06_structured_outputs.exs` | JSON schema constraints, entity extraction, classification |
| 07 | `07_model_info.exs` | List models, get details, compare capabilities |
| 08 | `08_token_counting.exs` | Token counting, cost estimation, code vs prose |
| 09 | `09_safety_settings.exs` | Content safety filters, harm categories, thresholds |
| 10 | `10_system_instructions.exs` | Persona setup, formatting rules, domain experts |
| 11 | `11_live_text_chat.exs` | Live API multi-turn text conversations |
| 12 | `12_live_audio_streaming.exs` | Live API audio input/output streaming |
| 13 | `13_live_session_resumption.exs` | Session resume across disconnections |
| 14 | `14_live_function_calling.exs` | Tool/function calling with telemetry |

## Example Details

### 01 - Basic Generation
Demonstrates the core `Gemini.generate/2` function:
- Simple text prompts
- Generation configuration (temperature, max_tokens, top_p, top_k)
- Comparing creative (high temperature) vs precise (low temperature) outputs

```elixir
# Simple
Gemini.generate("Explain quantum computing in one sentence")

# With config
Gemini.generate(prompt, generation_config: %{temperature: 0.9, max_output_tokens: 500})
```

### 02 - Streaming
Real-time streaming with progress tracking:
- Character-by-character delivery
- Timing between chunks
- Complete text assembly

```elixir
Gemini.stream_generate(prompt, fn chunk ->
  case chunk do
    {:data, data} -> IO.write(extract_text(data))
    {:done, _} -> IO.puts("\n[DONE]")
  end
end)
```

### 03 - Chat Sessions
Stateful multi-turn conversations:
- Conversation context retention
- Message history tracking
- Follow-up questions with context

```elixir
{:ok, session} = Gemini.chat()
{:ok, response1, session} = Gemini.send_message(session, "Hi, I'm Alice")
{:ok, response2, session} = Gemini.send_message(session, "What's my name?")  # Remembers "Alice"
```

### 04 - Embeddings
Vector embeddings for semantic search and similarity:
- Single text embedding
- Batch embeddings
- Cosine similarity calculations
- Task-specific embeddings (retrieval, document, etc.)

```elixir
{:ok, embedding} = Gemini.embed("Your text here")
{:ok, embeddings} = Gemini.batch_embed(["text1", "text2", "text3"])
```

### 05 - Function Calling
Enable the model to call your functions:
- Tool/function declaration
- Single function call
- Auto tool execution (model calls, you execute, results return)

```elixir
tools = [%{
  function_declarations: [%{
    name: "get_weather",
    description: "Get weather for a location",
    parameters: %{type: "object", properties: %{location: %{type: "string"}}}
  }]
}]

Gemini.generate(prompt, tools: tools, tool_choice: :auto)
```

### 06 - Structured Outputs
JSON schema-constrained responses:
- Schema definition
- Entity extraction
- Classification with scores

```elixir
schema = %{
  "type" => "object",
  "properties" => %{
    "answer" => %{"type" => "string"},
    "confidence" => %{"type" => "number", "minimum" => 0, "maximum" => 1}
  },
  "required" => ["answer", "confidence"]
}

config = GenerationConfig.structured_json(schema)
Gemini.generate(prompt, generation_config: config)
```

### 07 - Model Information
Discover available models and capabilities:
- List all models
- Get specific model details
- Compare token limits and supported methods

```elixir
{:ok, models} = Gemini.list_models()
{:ok, model} = Gemini.get_model("models/gemini-1.5-flash")
```

### 08 - Token Counting
Estimate costs and manage context:
- Count tokens in text
- Compare code vs prose efficiency
- Understand token/character ratios

```elixir
{:ok, result} = Gemini.count_tokens("Your text here")
IO.puts("Tokens: #{result.total_tokens}")
```

### 09 - Safety Settings
Configure content filters:
- Harm categories (harassment, hate speech, explicit, dangerous)
- Threshold levels (none, low, medium, high)
- Reading safety ratings from responses

```elixir
safety_settings = [
  SafetySetting.harassment(:block_only_high),
  SafetySetting.hate_speech(:block_medium_and_above),
  SafetySetting.sexually_explicit(:block_medium_and_above),
  SafetySetting.dangerous_content(:block_medium_and_above)
]

# Or use defaults
SafetySetting.defaults()    # Medium threshold for all
SafetySetting.permissive()  # Block only high risk

Gemini.generate(prompt, safety_settings: safety_settings)
```

### 10 - System Instructions
Control model behavior and persona:
- Create custom personas
- Enforce response formatting
- Define domain expertise

```elixir
system_instruction = """
You are a helpful coding assistant. Always:
- Provide working code examples
- Explain your reasoning
- Suggest best practices
"""

Gemini.generate(prompt, system_instruction: system_instruction)
```

## Output Format

All examples follow a consistent output format:
- Clear section headers with `===` or `---`
- Labeled prompts and responses
- Success `[OK]` or error `[ERROR]` indicators
- Relevant metadata (tokens, timing, etc.)

### 11 - Live Text Chat
Real-time bidirectional text conversations with the Live API:
- Multi-turn conversations with context retention
- Automatic model resolution via `Gemini.Live.Models.resolve(:text)`
- Response timing measurements
- System instructions for persona customization

```elixir
alias Gemini.Live.{Models, Session}

{:ok, session} = Session.start_link(
  model: Models.resolve(:text),  # Auto-selects available model
  generation_config: %{response_modalities: ["TEXT"]},
  system_instruction: "You are a helpful assistant.",
  on_message: fn msg -> handle_message(msg) end
)
:ok = Session.connect(session)
:ok = Session.send_client_content(session, "Hello!")
```

### 12 - Live Audio Streaming
Audio input/output streaming for voice applications:
- Sending audio chunks (16-bit PCM, 16kHz mono)
- Receiving audio responses (24kHz PCM)
- Transcription callbacks for input/output
- Voice activity signals

```elixir
# Send audio blob
audio = %{data: pcm_data, mime_type: "audio/pcm;rate=16000"}
Session.send_realtime_input(session, audio: audio)

# Signal activity boundaries
Session.send_realtime_input(session, activity_start: true)
Session.send_realtime_input(session, activity_end: true)
```

### 13 - Live Session Resumption
Reconnect to sessions while preserving conversation context:
- Enable session resumption in config
- Save handle from `on_session_resumption` callback
- Resume with `resume_handle:` option
- Context preserved across reconnections

```elixir
alias Gemini.Live.{Models, Session}

# Enable resumption
{:ok, session} = Session.start_link(
  model: Models.resolve(:text),
  session_resumption: %{},
  on_session_resumption: fn %{handle: h} -> save_handle(h) end
)

# Later: resume with saved handle
{:ok, session2} = Session.start_link(
  model: Models.resolve(:text),
  resume_handle: saved_handle
)
```

### 14 - Live Function Calling
Tool/function calling with full telemetry observability:
- Define function declarations
- Handle tool call requests
- Send responses back to model
- Observe all events via telemetry

```elixir
tools = [%{function_declarations: [%{name: "get_weather", ...}]}]

{:ok, session} = Session.start_link(
  tools: tools,
  on_tool_call: fn %{function_calls: calls} ->
    responses = execute_calls(calls)
    Session.send_tool_response(session, responses)
  end
)
```

## Live API Examples (Legacy)

Additional Live API examples without numbered naming:

| File | Description |
|------|-------------|
| `live_api_demo.exs` | Basic Live API text session |
| `live_function_calling.exs` | Tool/function calling with Live API |
| `simple_live_test.exs` | Simple Live API tool test |
| `live_auto_tool_test.exs` | Automatic tool execution |

### Running Live API Examples

```bash
# Numbered examples (included in run_all.sh)
mix run examples/11_live_text_chat.exs
mix run examples/12_live_audio_streaming.exs
mix run examples/13_live_session_resumption.exs
mix run examples/14_live_function_calling.exs

# Legacy examples
mix run examples/live_api_demo.exs
```

**Requirements:** `GEMINI_API_KEY` environment variable

**Model Resolution:**
Use `Gemini.Live.Models.resolve/1` to automatically select an available Live model:
- `Models.resolve(:text)` - Text-only responses
- `Models.resolve(:audio)` - Native audio responses

This handles regional rollout differences and API key capabilities automatically.

### Telemetry Events

The Live API emits telemetry events you can observe:
```elixir
:telemetry.attach("my-handler", [:gemini, :live, :session, :message, :received], handler_fn, nil)
```

Available events:
- `[:gemini, :live, :session, :init]` - Session initialization
- `[:gemini, :live, :session, :ready]` - Session connected
- `[:gemini, :live, :session, :message, :sent]` - Message sent
- `[:gemini, :live, :session, :message, :received]` - Message received
- `[:gemini, :live, :session, :tool_call]` - Tool call requested
- `[:gemini, :live, :session, :close]` - Session closed
- `[:gemini, :live, :session, :error]` - Error occurred
- `[:gemini, :live, :session, :go_away]` - GoAway notice

## Advanced Examples

The `examples/` directory also contains additional specialized demos for advanced use cases:

| File | Description |
|------|-------------|
| `streaming_demo.exs` | Advanced SSE streaming patterns with detailed timing |
| `demo_unified.exs` | Multi-auth coordination demo |
| `demo.exs` | Original comprehensive demo |
| `gemini_3_demo.exs` | Gemini 3 thinking levels, built-in tools, image generation, media resolution |
| `tool_calling_demo.exs` | Extended function calling patterns |
| `auto_tool_calling_demo.exs` | Automatic tool execution loop |
| `live_auto_tool_test.exs` | Live API tool calling with real code execution |
| `telemetry_showcase.exs` | Observability and telemetry integration |
| `multi_auth_demo.exs` | Concurrent Vertex AI + Gemini API usage |
| `embedding_demo.exs` | Extended embedding examples |

## Troubleshooting

### "No authentication configured"
Make sure you've set either `GEMINI_API_KEY` or `VERTEX_JSON_FILE` environment variable.

### "API key not valid"
- Check your API key is correct
- Ensure the key has Gemini API access enabled
- Verify no extra whitespace in the environment variable

### "Model not found"
Some models may not be available in all regions. Try:
- `gemini-1.5-flash` (widely available)
- `gemini-1.5-pro` (may have restricted access)

### Rate Limiting
If you see 429 errors, the examples are running faster than your quota allows. Wait a minute and try again, or run examples individually.

## Environment Variables Reference

### Gemini API
- `GEMINI_API_KEY` - Your Gemini API key

### Vertex AI
- `VERTEX_JSON_FILE` or `VERTEX_SERVICE_ACCOUNT` - Path to service account JSON file
- `VERTEX_PROJECT_ID` or `GOOGLE_CLOUD_PROJECT` - Google Cloud project ID
- `VERTEX_LOCATION` - Google Cloud location (defaults to "us-central1")
