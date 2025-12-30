<p align="center">
  <img src="assets/logo.svg" alt="Gemini Elixir Client Logo" width="200" height="200">
</p>

# Gemini Elixir Client

[![CI](https://github.com/nshkrdotcom/gemini_ex/actions/workflows/elixir.yaml/badge.svg)](https://github.com/nshkrdotcom/gemini_ex/actions/workflows/elixir.yaml)
[![Elixir](https://img.shields.io/badge/elixir-1.18.3-purple.svg)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/otp-27.3.3-blue.svg)](https://www.erlang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/gemini_ex.svg)](https://hex.pm/packages/gemini_ex)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/gemini_ex)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/nshkrdotcom/gemini_ex/blob/main/LICENSE)

A comprehensive Elixir client for Google's Gemini AI API with dual authentication support, advanced streaming capabilities, type safety, and built-in telemetry.

## Features

- **Automatic Tool Calling**: A seamless, Python-SDK-like experience that automates the entire multi-turn tool-calling loop
- **Built-in Tools (Gemini 3)**: Google Search, URL Context, and Code Execution via `tools:`
- **Dual Authentication**: Seamless support for both Gemini API keys and Vertex AI OAuth/Service Accounts
- **Application Default Credentials (ADC)**: Zero-config GCP auth with automatic discovery and token refresh (NEW in v0.8.x!)
- **Advanced Streaming**: Production-grade Server-Sent Events streaming with real-time processing
- **Interactions API**: Stateful interactions (CRUD), background execution, SSE streaming, and resumption
- **Live API (WebSocket)**: Bidirectional, low-latency sessions with real-time input/output (NEW in v0.8.x!)
- **Automatic Rate Limiting**: Built-in rate limit handling with retries, concurrency gating, and adaptive backoff
- **Files API**: Upload, manage, and use files with Gemini models for multimodal content (NEW in v0.7.0!)
- **File Search Stores**: RAG store creation, ingestion, and semantic search (NEW in v0.8.x!)
- **Documents API**: Manage indexed documents inside stores for RAG workflows (NEW in v0.7.0!)
- **Batches API**: Submit large numbers of requests with 50% cost savings (NEW in v0.7.0!)
- **Operations API**: Track long-running operations like video generation (NEW in v0.7.0!)
- **Tunings (Fine-Tuning)**: Create, monitor, and manage tuned models (NEW in v0.8.x!)
- **Image & Video Generation**: Imagen/Veo APIs for text-to-image, editing, upscaling, and video generation (NEW in v0.8.x!)
- **Embeddings with MRL**: Text embeddings with Matryoshka Representation Learning, normalization, and distance metrics
- **Async Batch Embeddings**: Production-scale embedding generation with 50% cost savings
- **Type Safety**: Complete type definitions with runtime validation
- **Built-in Telemetry**: Comprehensive observability and metrics out of the box
- **Chat Sessions & System Instructions**: Multi-turn conversation management with persistent guardrails
- **Flexible Multimodal Input**: Intuitive formats for images/text with automatic MIME detection
- **Thinking Budget Control**: Optimize costs by controlling thinking token usage
- **Gemini 3 Support**: `thinking_level` (`:minimal`, `:low`, `:medium`, `:high`), image generation, media resolution, thought signatures (NEW in v0.5.x!)
- **Context Caching**: Cache large contexts once and reuse by ID (NEW in v0.6.0!)
- **Complete Generation Config**: Full support for all generation config options including structured output
- **Production Ready**: Robust error handling, retry logic, and performance optimizations
- **Flexible Configuration**: Environment variables, application config, and per-request overrides

## ALTAR Integration: The Path to Production

`gemini_ex` is the first project to integrate with the **ALTAR Productivity Platform**, a system designed to bridge the gap between local AI development and enterprise-grade production deployment.

We've adopted ALTAR's `LATER` protocol to provide a best-in-class local tool-calling experience. This is the first step in a long-term vision to offer a seamless "promotion path" for your AI tools, from local testing to a secure, scalable, and governed production environment via ALTAR's `GRID` protocol.

**[Learn the full story behind our integration in `ALTAR_INTEGRATION.md`](ALTAR_INTEGRATION.md)**

## Installation

Add `gemini` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini_ex, "~> 0.8.8"}
  ]
end
```

## Quick Start

### Basic Configuration

Configure your API key in `config/runtime.exs`:

```elixir
import Config

config :gemini_ex,
  api_key: System.get_env("GEMINI_API_KEY")
```

Or set the environment variable:

```bash
export GEMINI_API_KEY="your_api_key_here"
```

### Simple Content Generation

```elixir
# Basic text generation
{:ok, response} = Gemini.generate("Tell me about Elixir programming")
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)

# With options
{:ok, response} = Gemini.generate("Explain quantum computing", [
  model: "gemini-flash-lite-latest",
  temperature: 0.7,
  max_output_tokens: 1000
])

# Advanced generation config with structured output
{:ok, response} = Gemini.generate("Analyze this topic and provide a summary", [
  response_json_schema: %{
    "type" => "object",
    "properties" => %{
      "summary" => %{"type" => "string"},
      "key_points" => %{"type" => "array", "items" => %{"type" => "string"}},
      "confidence" => %{"type" => "number"}
    }
  },
  response_mime_type: "application/json",
  temperature: 0.3
])
```

### System Instructions

Set persistent guardrails that apply across an entire call or chat session without bloating your message history:

```elixir
{:ok, response} =
  Gemini.generate("List three tips for interviewing junior engineers",
    system_instruction: "Be concise, avoid markdown, and keep answers under 40 words."
  )

{:ok, text} = Gemini.extract_text(response)
# Works the same with `Gemini.create_chat_session/1` and streaming calls via the `system_instruction:` option.
```

### Simple Tool Calling

```elixir
# Define a simple tool
defmodule WeatherTool do
  def get_weather(%{"location" => location}) do
    %{location: location, temperature: 22, condition: "sunny"}
  end
end

# Create and register the tool
{:ok, weather_declaration} = Altar.ADM.new_function_declaration(%{
  name: "get_weather",
  description: "Gets weather for a location",
  parameters: %{
    type: "object",
    properties: %{location: %{type: "string", description: "City name"}},
    required: ["location"]
  }
})

Gemini.Tools.register(weather_declaration, &WeatherTool.get_weather/1)

# Use the tool automatically - the model will call it as needed
{:ok, response} = Gemini.generate_content_with_auto_tools(
  "What's the weather like in Tokyo?",
  tools: [weather_declaration]
)

{:ok, text} = Gemini.extract_text(response)
IO.puts(text) # "The weather in Tokyo is sunny with a temperature of 22°C."
```

### Advanced Streaming

```elixir
# Start a streaming session
{:ok, stream_id} = Gemini.stream_generate("Write a long story about AI", [
  on_chunk: fn chunk -> IO.write(chunk) end,
  on_complete: fn -> IO.puts("\nStream complete!") end,
  on_error: fn error -> IO.puts("Error: #{inspect(error)}") end
])

# Stream management
Gemini.Streaming.pause_stream(stream_id)
Gemini.Streaming.resume_stream(stream_id)
Gemini.Streaming.stop_stream(stream_id)
```

Streaming knobs: pass `timeout:` (per attempt, default `config :gemini_ex, :timeout` = 120_000), `max_retries:` (default 3), `max_backoff_ms:` (default 10_000), and `connect_timeout:` (default 5_000). Manager cleanup delay can be tuned via `config :gemini_ex, :streaming, cleanup_delay_ms: ...`.

### Interactions Quick Start

```elixir
alias Gemini.APIs.Interactions
alias Gemini.Types.Interactions.Events.ContentDelta
alias Gemini.Types.Interactions.DeltaTextDelta

{:ok, stream} =
  Interactions.create("Write a short poem about Elixir",
    model: "gemini-2.5-flash",
    stream: true
  )

for event <- stream do
  case event do
    %ContentDelta{delta: %DeltaTextDelta{text: text}} when is_binary(text) ->
      IO.write(text)

    _ ->
      :ok
  end
end
```

See `docs/guides/interactions.md` for CRUD, resumption (`last_event_id`), and background/cancel/delete examples.

### Live API (WebSocket) (New in v0.8.x!)

Bidirectional, low-latency sessions for voice, multimodal, and interactive apps.

```elixir
alias Gemini.Live.Session

{:ok, pid} =
  Session.start_link(
    model: "gemini-2.5-flash",
    auth: :vertex_ai,
    on_message: fn msg -> IO.inspect(msg, label: "live message") end,
    on_error: fn err -> IO.inspect(err, label: "live error") end
  )

:ok = Session.connect(pid)

# Send text turns or structured client content
:ok = Session.send(pid, "Streamed hello from Elixir")
:ok = Session.send_client_content(pid, [%{role: "user", parts: [%{text: "Add a title"}]}])

# Stream real-time inputs (audio/video chunks) and tool responses
:ok =
  Session.send_realtime_input(pid, [
    %{data: audio_chunk, mime_type: "audio/pcm"}
  ])

:ok =
  Session.send_tool_response(pid, [
    %{name: "get_weather", response: %{temperature: 72, condition: "sunny"}}
  ])

# Close when finished
:ok = Session.close(pid)
```

Features: connection lifecycle management, automatic message parsing/building, backpressure-aware streaming, and unified telemetry. Available on Vertex AI models that expose the Live API—call `connect/1` after `start_link/1` to open the WebSocket.

### Rate Limiting & Concurrency (built-in)

- Enabled by default: atomic budget reservations happen before dispatch; non-blocking mode returns `{:error, {:rate_limited, retry_at, details}}` with `retry_at` set to the window end.
- Oversized requests (estimate exceeds budget) return `reason: :over_budget, request_too_large: true` immediately—no retry loop; surplus budget is returned after responses, shortfalls are charged.
- Shared retry window with jittered release for 429s; telemetry fires `retry_window_set/hit/release` so callers can fan out retries safely.
- Cached context tokens are counted toward budgets. When you precompute cache size, you can pass `estimated_cached_tokens:` alongside `estimated_input_tokens:` to budget correctly before the API reports usage.
- Optional `max_budget_wait_ms` caps how long blocking calls sleep for a full window; if the cap is hit and the window is still full, you get a `rate_limited` error with `retry_at` set to the actual window end.
- Concurrency gate: serialized permits via `max_concurrency_per_model` plus `permit_timeout_ms` (default `:infinity`, per-call override). `non_blocking: true` is the fail-fast path (returns `{:error, :no_permit_available}` immediately).
- Streaming uses the same limiter: permits are held for the full stream, and streams may return `{:error, {:rate_limited, retry_at, details}}` if over budget or out of permits.
- Partition the gate with `concurrency_key:` (e.g., tenant/location) to avoid cross-tenant starvation; default key is the model name.
- Permit leak protection: holders are monitored; if a holder dies without releasing, its permits are reclaimed automatically.

Model aliases: resolve the built-in use-case aliases via `Gemini.Config.model_for_use_case/2` (e.g., `:cache_context`, `:report_section`, `:fast_path`) to avoid scattering raw model strings and to respect the recommended token minima for each use case.

### Timeouts (HTTP & Streaming)

- Global HTTP/stream timeout default is 120_000ms via `config :gemini_ex, :timeout`.
- Per-call override: `timeout:` on any request/stream.
- Streaming extras: `max_retries`, `max_backoff_ms` (default 10_000), `connect_timeout` (default 5_000).

### Advanced Generation Configuration

```elixir
# Using GenerationConfig struct for complex configurations
config = %Gemini.Types.GenerationConfig{
  temperature: 0.7,
  max_output_tokens: 2000,
  response_json_schema: %{
    "type" => "object",
    "properties" => %{
      "analysis" => %{"type" => "string"},
      "recommendations" => %{"type" => "array", "items" => %{"type" => "string"}}
    }
  },
  response_mime_type: "application/json",
  stop_sequences: ["END", "COMPLETE"],
  presence_penalty: 0.5,
  frequency_penalty: 0.3
}

{:ok, response} = Gemini.generate("Analyze market trends", generation_config: config)

# All generation config options are supported:
{:ok, response} = Gemini.generate("Creative writing task", [
  temperature: 0.9,           # Creativity level
  top_p: 0.8,                # Nucleus sampling
  top_k: 40,                 # Top-k sampling
  candidate_count: 3,        # Multiple responses
  response_logprobs: true,   # Include probabilities
  logprobs: 5               # Token probabilities
])
```

### Structured JSON Outputs

Generate responses that guarantee adherence to a specific JSON Schema:

```elixir
# Define your schema
schema = %{
  "type" => "object",
  "properties" => %{
    "answer" => %{"type" => "string"},
    "confidence" => %{
      "type" => "number",
      "minimum" => 0.0,
      "maximum" => 1.0
    }
  }
}

# Use the convenient helper
config = Gemini.Types.GenerationConfig.structured_json(schema)

{:ok, response} = Gemini.generate(
  "What is the capital of France?",
  model: "gemini-2.5-flash",
  generation_config: config
)

{:ok, text} = Gemini.extract_text(response)
{:ok, data} = Jason.decode(text)
# => %{"answer" => "Paris", "confidence" => 0.99}
```

`GenerationConfig.structured_json/2` uses `response_json_schema` (standard JSON Schema)
by default. If you need Gemini's internal schema format, pass `schema_type: :response_schema`:

```elixir
config =
  GenerationConfig.structured_json(%{"type" => "OBJECT"}, schema_type: :response_schema)
```

**New Features (November 2025):**
- `anyOf` for union types
- `$ref` for recursive schemas
- `minimum`/`maximum` for numeric constraints
- `prefixItems` for tuple-like arrays

For Gemini 2.0 models, add explicit property ordering:

```elixir
config =
  GenerationConfig.structured_json(schema)
  |> GenerationConfig.property_ordering(["answer", "confidence"])
```

See [Structured Outputs Guide](docs/guides/structured_outputs.md) for details.

## Context Caching (New in v0.6.0!)

Cache large prompts/contexts once and reuse the cache ID to avoid resending bytes:

```elixir
alias Gemini.Types.Content

# Create a cache from your content (supports system_instruction, tools, fileUri)
{:ok, cache} =
  Gemini.create_cache(
    [
      Content.text("long document or conversation history"),
      %Content{role: "user", parts: [%{file_uri: "gs://cloud-samples-data/generative-ai/pdf/scene.pdf"}]}
    ],
    display_name: "My Cache",
    model: "gemini-2.5-flash",  # Use models that support caching
    system_instruction: "Answer in one concise paragraph."
  )

# Use cached content by name (e.g., "cachedContents/123")
{:ok, response} =
  Gemini.generate("Summarize the cached content",
    cached_content: cache.name,
    model: "gemini-2.5-flash"
  )
```

**TTL defaults:** The default cache TTL is configurable via `config :gemini_ex, :context_cache, default_ttl_seconds: ...` (defaults to 3_600). You can also override per call with `default_ttl_seconds:` or pass `:ttl`/`:expire_time` explicitly.

**Models that support explicit caching:**
- `gemini-2.5-flash`
- `gemini-2.5-flash-lite`
- `gemini-2.5-pro`
- `gemini-2.0-flash-001`
- `gemini-2.0-flash-lite-001`
- `gemini-3-pro-preview`
- `gemini-3-flash-preview`

You can list, get, update TTL, and delete caches via the top-level `Gemini.*cache*` helpers or `Gemini.APIs.ContextCache.*`. Vertex AI names are auto-expanded when `auth: :vertex_ai` or configured credentials are present.

## Files API (New in v0.7.0!)

Upload and manage files for use with Gemini models. Perfect for multimodal content generation with images, videos, audio, and documents.

```elixir
alias Gemini.APIs.Files
alias Gemini.Types.File

# Upload a file
{:ok, file} = Files.upload("path/to/image.png")

# Wait for processing (videos/large files)
{:ok, ready} = Files.wait_for_processing(file.name)

# Use in content generation
{:ok, response} = Gemini.generate([
  "What's in this image?",
  %{file_uri: ready.uri, mime_type: ready.mime_type}
])

# List all files
{:ok, files} = Files.list_all()

# Clean up
:ok = Files.delete(file.name)
```

**Key Features:**
- Resumable uploads with progress tracking
- Support for images, videos, audio, and documents
- Automatic MIME type detection
- 48-hour file expiration

See [Files API Guide](docs/guides/files.md) for complete documentation.

## File Search Stores (New in v0.8.x!)

Create semantic search stores for RAG and ground model responses with your own data (Vertex AI only).

```elixir
alias Gemini.APIs.FileSearchStores
alias Gemini.Types.CreateFileSearchStoreConfig

# Create and activate a store
config = %CreateFileSearchStoreConfig{display_name: "Support KB"}
{:ok, store} = FileSearchStores.create(config, auth: :vertex_ai)
{:ok, active_store} = FileSearchStores.wait_for_active(store.name)

# Upload documents directly to the store and wait for indexing
{:ok, doc} =
  FileSearchStores.upload_to_store(active_store.name, "docs/faq.pdf",
    display_name: "Support FAQ",
    auth: :vertex_ai
  )

{:ok, _} = FileSearchStores.wait_for_document(doc.name, auth: :vertex_ai)

# Use the store to ground a generation request
{:ok, response} =
  Gemini.generate_content(
    "What is the warranty policy for the Pro model?",
    tools: [%{file_search_stores: [active_store.name]}],
    auth: :vertex_ai
  )
```

Key features: automatic chunking/indexing, upload/import existing Files API uploads or GCS URIs, list/delete stores, and helpers to wait for readiness.

## Documents API (New in v0.7.0!)

Manage the documents inside your File Search Stores.

```elixir
alias Gemini.APIs.Documents

# List and inspect documents
{:ok, page} = Documents.list("ragStores/support-kb", auth: :vertex_ai)
{:ok, doc} = Documents.get("ragStores/support-kb/documents/doc123", auth: :vertex_ai)

# Wait for processing and clean up
{:ok, ready_doc} = Documents.wait_for_processing(doc.name, on_status: &IO.inspect/1, auth: :vertex_ai)
:ok = Documents.delete(ready_doc.name, auth: :vertex_ai)
```

List helpers (`list_all/2`) collapse pagination, and wait helpers make it easy to block until documents are indexed.

## Batches API (New in v0.7.0!)

Submit large batches of requests with 50% cost savings. Ideal for bulk processing, overnight jobs, and high-volume workloads.

```elixir
alias Gemini.APIs.{Files, Batches}
alias Gemini.Types.BatchJob

# 1. Upload input file (JSONL format)
{:ok, input} = Files.upload("requests.jsonl")

# 2. Create batch job
{:ok, batch} = Batches.create("gemini-2.5-flash",
  file_name: input.name,
  display_name: "My Batch"
)

# 3. Wait for completion with progress
{:ok, completed} = Batches.wait(batch.name,
  on_progress: fn b ->
    if progress = BatchJob.get_progress(b) do
      IO.puts("Progress: #{Float.round(progress, 1)}%")
    end
  end
)

# 4. Check results
if BatchJob.succeeded?(completed) do
  IO.puts("Completed #{completed.completion_stats.success_count} requests")
end
```

**Key Features:**
- 50% cost savings vs interactive API
- File-based or inline request input
- GCS and BigQuery integration (Vertex AI)
- Comprehensive job management

See [Batches API Guide](docs/guides/batches.md) for complete documentation.

## Operations API (New in v0.7.0!)

Track and manage long-running operations like video generation, file imports, and model tuning.

```elixir
alias Gemini.APIs.Operations
alias Gemini.Types.Operation

# Check operation status
{:ok, op} = Operations.get("operations/abc123")
IO.puts("Done: #{op.done}")

# Wait for completion with exponential backoff
{:ok, completed} = Operations.wait_with_backoff("operations/abc123",
  initial_delay: 1_000,
  max_delay: 60_000,
  timeout: 3_600_000,
  on_progress: fn op ->
    if progress = Operation.get_progress(op) do
      IO.puts("Progress: #{progress}%")
    end
  end
)

if Operation.succeeded?(completed) do
  IO.inspect(completed.response)
end
```

**Key Features:**
- Simple and exponential backoff polling
- Progress tracking callbacks
- Cancel and delete operations
- Comprehensive state helpers

See [Operations API Guide](docs/guides/operations.md) for complete documentation.

## Tunings API (New in v0.8.x!)

Fine-tune base models with supervised datasets (Vertex AI).

```elixir
alias Gemini.APIs.Tunings
alias Gemini.Types.Tuning.CreateTuningJobConfig

config = %CreateTuningJobConfig{
  base_model: "gemini-2.5-flash-001",
  tuned_model_display_name: "support-bot",
  training_dataset_uri: "gs://bucket/train.jsonl",
  validation_dataset_uri: "gs://bucket/val.jsonl",
  epoch_count: 3,
  learning_rate_multiplier: 1.0,
  adapter_size: "x1"
}

{:ok, job} = Tunings.tune(config, auth: :vertex_ai)
{:ok, completed} = Tunings.wait_for_completion(job.name, auth: :vertex_ai)
IO.puts("Tuned model: #{completed.tuned_model}")
```

You also get `list/1`, `list_all/1`, `get/2`, and `cancel/2` helpers plus polling and progress callbacks.

### Multi-turn Conversations

```elixir
# Create a chat session
{:ok, session} = Gemini.create_chat_session([
  model: "gemini-flash-lite-latest",
  system_instruction: "You are a helpful programming assistant."
])

# Send messages
{:ok, response1} = Gemini.send_message(session, "What is functional programming?")
{:ok, response2} = Gemini.send_message(session, "Show me an example in Elixir")

# Get conversation history
history = Gemini.get_conversation_history(session)
```

## Tool Calling (Function Calling)

Tool calling enables the Gemini model to interact with external functions and APIs, making it possible to build powerful agents that can perform actions, retrieve real-time data, and integrate with your systems. This transforms the model from a text generator into an intelligent agent capable of complex workflows.

### Automatic Execution (Recommended)

The automatic tool calling system provides the easiest and most robust way to use tools. It handles the entire multi-turn conversation loop automatically, executing tool calls and managing the conversation state behind the scenes.

#### Step 1: Define & Register Your Tools

```elixir
# Define your tool functions
defmodule DemoTools do
  def get_weather(%{"location" => location}) do
    # Your weather API integration here
    %{
      location: location,
      temperature: 22,
      condition: "sunny",
      humidity: 65
    }
  end

  def calculate(%{"operation" => op, "a" => a, "b" => b}) do
    result = case op do
      "add" -> a + b
      "multiply" -> a * b
      "divide" when b != 0 -> a / b
      _ -> {:error, "Invalid operation"}
    end
    
    %{operation: op, result: result}
  end
end

# Create function declarations
{:ok, weather_declaration} = Altar.ADM.new_function_declaration(%{
  name: "get_weather",
  description: "Gets current weather information for a specified location",
  parameters: %{
    type: "object",
    properties: %{
      location: %{
        type: "string",
        description: "The location to get weather for (e.g., 'San Francisco')"
      }
    },
    required: ["location"]
  }
})

{:ok, calc_declaration} = Altar.ADM.new_function_declaration(%{
  name: "calculate",
  description: "Performs basic mathematical calculations",
  parameters: %{
    type: "object",
    properties: %{
      operation: %{type: "string", enum: ["add", "multiply", "divide"]},
      a: %{type: "number", description: "First operand"},
      b: %{type: "number", description: "Second operand"}
    },
    required: ["operation", "a", "b"]
  }
})

# Register the tools
Gemini.Tools.register(weather_declaration, &DemoTools.get_weather/1)
Gemini.Tools.register(calc_declaration, &DemoTools.calculate/1)
```

#### Step 2: Call the Model

```elixir
# Single call with automatic tool execution
{:ok, response} = Gemini.generate_content_with_auto_tools(
  "What's the weather like in Tokyo? Also calculate 15 * 23.",
  tools: [weather_declaration, calc_declaration],
  model: "gemini-flash-lite-latest",
  temperature: 0.1
)
```

#### Step 3: Get the Final Result

```elixir
# Extract the final text response
{:ok, text} = Gemini.extract_text(response)
IO.puts(text)
# Output: "The weather in Tokyo is sunny with 22°C and 65% humidity. 
#          The calculation of 15 * 23 equals 345."
```

The model automatically:
- Determines which tools to call based on your prompt
- Executes the necessary function calls
- Processes the results
- Provides a natural language response incorporating all the data

#### Streaming with Automatic Execution

For real-time responses with tool calling:

```elixir
# Start streaming with automatic tool execution
{:ok, stream_id} = Gemini.stream_generate_with_auto_tools(
  "Check the weather in London and calculate the tip for a $50 meal",
  tools: [weather_declaration, calc_declaration],
  model: "gemini-flash-lite-latest"
)

# Subscribe to the stream
:ok = Gemini.subscribe_stream(stream_id)

# The subscriber will only receive the final text chunks
# All tool execution happens automatically in the background
receive do
  {:stream_event, ^stream_id, event} -> 
    case Gemini.extract_text(event) do
      {:ok, text} -> IO.write(text)
      _ -> :ok
    end
  {:stream_complete, ^stream_id} -> IO.puts("\n✅ Complete!")
end
```

### Built-in Tools (Gemini 3)

Gemini 3 models can call built-in tools for Google Search, URL Context, and Code Execution.
Enable them in `tools:` and optionally combine with structured outputs:

```elixir
{:ok, response} =
  Gemini.generate(
    "Find the latest Elixir release notes and summarize the key changes.",
    model: "gemini-3-flash-preview",
    tools: [:google_search, :url_context],
    response_mime_type: "application/json",
    response_json_schema: %{
      "type" => "object",
      "properties" => %{
        "summary" => %{"type" => "string"},
        "sources" => %{"type" => "array", "items" => %{"type" => "string"}}
      },
      "required" => ["summary"]
    }
  )
```

Built-in tools can be mixed with your own function declarations in the same `tools:` list.

### Manual Execution (Advanced)

For advanced use cases requiring full control over the conversation loop, custom state management, or detailed logging of tool executions:

```elixir
# Step 1: Generate content with tool declarations
{:ok, response} = Gemini.generate_content(
  "What's the weather in Paris?",
  tools: [weather_declaration],
  model: "gemini-flash-lite-latest"
)

# Step 2: Check for function calls in the response
case response.candidates do
  [%{content: %{parts: parts}}] ->
    function_calls = Enum.filter(parts, &match?(%{function_call: _}, &1))
    
    if function_calls != [] do
      # Step 3: Execute the function calls
      {:ok, tool_results} = Gemini.Tools.execute_calls(function_calls)
      
      # Step 4: Create content from tool results
      tool_content = Gemini.Types.Content.from_tool_results(tool_results)
      
      # Step 5: Continue the conversation with results
      conversation_history = [
        %{role: "user", parts: [%{text: "What's the weather in Paris?"}]},
        response.candidates |> hd() |> Map.get(:content),
        tool_content
      ]
      
      {:ok, final_response} = Gemini.generate_content(
        conversation_history,
        model: "gemini-flash-lite-latest"
      )
      
      {:ok, text} = Gemini.extract_text(final_response)
      IO.puts(text)
    end
end
```

This manual approach gives you complete visibility and control over each step of the tool calling process, which can be valuable for debugging, logging, or implementing custom conversation management logic.

## Embeddings (New in v0.3.0!)

Generate semantic embeddings for text to power RAG systems, semantic search, classification, and more.

### Quick Start

```elixir
# Generate an embedding
{:ok, response} = Gemini.embed_content("Hello, world!")
values = response.embedding.values  # [0.123, -0.456, ...]

# Compute similarity
alias Gemini.Types.Response.ContentEmbedding

{:ok, resp1} = Gemini.embed_content("The cat sat on the mat")
{:ok, resp2} = Gemini.embed_content("A feline rested on the rug")

# Normalize for accurate similarity (required for non-3072 dimensions)
norm1 = ContentEmbedding.normalize(resp1.embedding)
norm2 = ContentEmbedding.normalize(resp2.embedding)

similarity = ContentEmbedding.cosine_similarity(norm1, norm2)
# => 0.85 (high similarity)
```

### MRL (Matryoshka Representation Learning)

The `gemini-embedding-001` model supports flexible dimensions (128-3072) with minimal quality loss:

```elixir
# 768 dimensions - RECOMMENDED (25% storage, 0.26% quality loss)
{:ok, response} = Gemini.embed_content(
  "Your text",
  model: "gemini-embedding-001",
  output_dimensionality: 768
)

# 1536 dimensions - High quality (50% storage, same MTEB score as 3072!)
{:ok, response} = Gemini.embed_content(
  "Your text",
  output_dimensionality: 1536
)
```

**MTEB Benchmark Scores:**
- 3072d: 68.17 (100% storage, pre-normalized)
- 1536d: 68.17 (50% storage, **same quality!**)
- 768d: 67.99 (25% storage, -0.26% loss)
- 512d: 67.55 (17% storage, -0.91% loss)

### Task Types for Better Quality

Optimize embeddings for your specific use case:

```elixir
# For knowledge base documents
{:ok, doc_emb} = Gemini.embed_content(
  document_text,
  task_type: "RETRIEVAL_DOCUMENT",
  title: "Document Title"  # Improves quality!
)

# For search queries
{:ok, query_emb} = Gemini.embed_content(
  user_query,
  task_type: "RETRIEVAL_QUERY"
)

# For classification
{:ok, emb} = Gemini.embed_content(
  text,
  task_type: "CLASSIFICATION"
)
```

### Distance Metrics

```elixir
alias Gemini.Types.Response.ContentEmbedding

# Cosine similarity (higher = more similar, -1 to 1)
similarity = ContentEmbedding.cosine_similarity(emb1, emb2)

# Euclidean distance (lower = more similar, 0 to ∞)
distance = ContentEmbedding.euclidean_distance(emb1, emb2)

# Dot product (equals cosine for normalized embeddings)
dot = ContentEmbedding.dot_product(emb1, emb2)

# L2 norm (should be ~1.0 after normalization)
norm = ContentEmbedding.norm(embedding)
```

### Batch Embedding

Efficient for multiple texts:

```elixir
texts = ["Text 1", "Text 2", "Text 3"]
{:ok, response} = Gemini.batch_embed_contents(
  "gemini-embedding-001",
  texts,
  task_type: "RETRIEVAL_DOCUMENT"
)

# Access embeddings
embeddings = response.embeddings  # List of ContentEmbedding structs
```

### Advanced Use Cases

Complete production-ready examples in `examples/use_cases/`:

- **`mrl_normalization_demo.exs`** - MRL concepts, MTEB scores, normalization, distance metrics
- **`rag_demo.exs`** - Complete RAG pipeline with knowledge base indexing and retrieval
- **`search_reranking.exs`** - Semantic reranking for improved search relevance
- **`classification.exs`** - K-NN classification with few-shot learning

See [examples/EMBEDDINGS.md](examples/EMBEDDINGS.md) for comprehensive documentation.

### Critical: Normalization

**IMPORTANT:** Only 3072-dimensional embeddings are pre-normalized. All other dimensions MUST be normalized before computing similarity:

```elixir
# WRONG - Produces incorrect similarity scores
similarity = ContentEmbedding.cosine_similarity(emb1, emb2)

# CORRECT - Normalize first for non-3072 dimensions
norm1 = ContentEmbedding.normalize(emb1)
norm2 = ContentEmbedding.normalize(emb2)
similarity = ContentEmbedding.cosine_similarity(norm1, norm2)
```

### Async Batch Embedding (New in v0.3.1!)

For production-scale embedding generation with **50% cost savings**:

```elixir
# Submit large batch asynchronously
{:ok, batch} = Gemini.async_batch_embed_contents(
  texts,
  display_name: "Knowledge Base Index",
  task_type: :retrieval_document,
  output_dimensionality: 768
)

# Poll for completion with progress tracking
{:ok, completed_batch} = Gemini.await_batch_completion(
  batch.name,
  poll_interval: 10_000,  # 10 seconds
  timeout: 30 * 60 * 1000,  # 30 minutes
  on_progress: fn b ->
    progress = b.batch_stats.successful_request_count / b.batch_stats.request_count * 100
    IO.puts("Progress: #{Float.round(progress, 1)}%")
  end
)

# Retrieve embeddings
{:ok, embeddings} = Gemini.get_batch_embeddings(completed_batch)
```

**When to use:**
- Large-scale indexing (1000s-millions of documents)
- RAG system setup and knowledge base building
- Non-urgent embedding generation
- Cost-sensitive workflows (50% savings!)

**Live Examples:**
```bash
mix run examples/async_batch_embedding_demo.exs
mix run examples/async_batch_production_demo.exs
```

See [examples/ASYNC_BATCH_EMBEDDINGS.md](examples/ASYNC_BATCH_EMBEDDINGS.md) for complete guide.

## Examples

The repository includes comprehensive examples demonstrating all library features. All examples are ready to run and include proper error handling.

### Running Examples

All examples use the same execution method:

```bash
mix run examples/[example_name].exs
```

### Available Examples

#### 1. **`demo.exs`** - Comprehensive Feature Showcase
**The main library demonstration covering all core features.**

```bash
mix run examples/demo.exs
```

**Features demonstrated:**
- Model listing and information retrieval
- Simple text generation with various prompts
- Configured generation (creative vs precise modes)
- Multi-turn chat sessions with context
- Token counting for different text lengths

**Requirements:** `GEMINI_API_KEY` environment variable

---

#### 2. **`streaming_demo.exs`** - Real-time Streaming
**Live demonstration of Server-Sent Events streaming with progressive text delivery.**

```bash
mix run examples/streaming_demo.exs
```

**Features demonstrated:**
- Real-time progressive text streaming
- Stream subscription and event handling
- Authentication detection (Gemini API or Vertex AI)
- Stream status monitoring

**Requirements:** `GEMINI_API_KEY` or Vertex AI credentials

---

#### 3. **`demo_unified.exs`** - Multi-Auth Architecture
**Showcases the unified architecture supporting multiple authentication methods.**

```bash
mix run examples/demo_unified.exs
```

**Features demonstrated:**
- Configuration system and auth detection
- Authentication strategy switching
- Streaming manager capabilities
- Backward compatibility verification

**Requirements:** None (works with or without credentials)

---

#### 4. **`multi_auth_demo.exs`** - Concurrent Authentication
**Demonstrates concurrent usage of multiple authentication strategies.**

```bash
mix run examples/multi_auth_demo.exs
```

**Features demonstrated:**
- Concurrent Gemini API and Vertex AI requests
- Authentication failure handling
- Per-request auth strategy selection
- Error handling for invalid credentials

**Requirements:** `GEMINI_API_KEY` recommended (demonstrates Vertex AI auth failure)

---

#### 5. **`telemetry_showcase.exs`** - Comprehensive Telemetry System
**Complete demonstration of the built-in telemetry and observability features.**

```bash
mix run examples/telemetry_showcase.exs
```

**Features demonstrated:**
- Real-time telemetry event monitoring
- 7 event types: request start/stop/exception, stream start/chunk/stop/exception
- Telemetry helper functions (stream IDs, content classification, metadata)
- Live performance measurement and analysis
- Configuration management for telemetry

**Requirements:** `GEMINI_API_KEY` for live telemetry (works without for utilities demo)

---

#### 6. **`auto_tool_calling_demo.exs`** - Automatic Tool Execution (Recommended)
**Demonstrates the powerful automatic tool calling system for building intelligent agents.**

```bash
mix run examples/auto_tool_calling_demo.exs
```

**Features demonstrated:**
- Tool function definition and registration
- Automatic multi-turn tool execution
- Multiple tool types (weather, calculator, time)
- Function declaration creation with JSON schemas
- Streaming with automatic tool execution

**Requirements:** `GEMINI_API_KEY` for live tool execution

---

#### 7. **`tool_calling_demo.exs`** - Manual Tool Execution
**Shows manual control over the tool calling conversation loop for advanced use cases.**

```bash
mix run examples/tool_calling_demo.exs
```

**Features demonstrated:**
- Manual tool execution workflow
- Step-by-step conversation management
- Custom tool result processing
- Advanced debugging and logging capabilities

**Requirements:** `GEMINI_API_KEY` for live tool execution

---

#### 8. **`manual_tool_calling_demo.exs`** - Advanced Manual Tool Control
**Comprehensive manual tool calling patterns for complex agent workflows.**

```bash
mix run examples/manual_tool_calling_demo.exs
```

**Features demonstrated:**
- Complex multi-step tool workflows
- Custom conversation state management
- Error handling in tool execution
- Integration patterns for external APIs

**Requirements:** `GEMINI_API_KEY` for live tool execution

---

#### 9. **`live_auto_tool_test.exs`** - Live End-to-End Tool Calling Test **LIVE EXAMPLE**
**A comprehensive live test demonstrating real automatic tool execution with the Gemini API.**

```bash
mix run examples/live_auto_tool_test.exs
```

**Features demonstrated:**
- **Real Elixir module introspection** using `Code.ensure_loaded/1` and `Code.fetch_docs/1`
- **Live automatic tool execution** with the actual Gemini API
- **End-to-end workflow validation** from tool registration to final response
- **Comprehensive error handling** and debug output
- **Self-contained execution** with `Mix.install` dependency management
- **Professional output formatting** with step-by-step progress indicators

**What makes this special:**
- **Actually calls the Gemini API** - not a mock or simulation
- **Executes real Elixir code** - introspects modules like `Enum`, `String`, `GenServer`
- **Demonstrates the complete pipeline** - tool registration -> API call -> tool execution -> response synthesis
- **Self-contained** - runs independently with just an API key
- **Comprehensive logging** - shows exactly what's happening at each step

**Requirements:** `GEMINI_API_KEY` environment variable (this is a live API test)

**Example output:**
```
SUCCESS! Final Response from Gemini:
The `Enum` module in Elixir is a powerful tool for working with collections...
Based on the information retrieved using `get_elixir_module_info`, here's a breakdown:
1. Main Purpose: Provides consistent iteration over enumerables (lists, maps, ranges)
2. Common Functions: map/2, filter/2, reduce/3, sum/1, sort/1...
3. Usefulness: Unified interface, functional programming, high performance...
```

---

#### 10. **`live_api_test.exs`** - API Testing and Validation
**Comprehensive testing utility for validating both authentication methods.**

```bash
mix run examples/live_api_test.exs
```

**Features demonstrated:**
- Full API testing suite for both auth methods
- Configuration detection and validation
- Model operations (listing, details, existence checks)
- Streaming functionality testing
- Performance monitoring

**Requirements:** `GEMINI_API_KEY` and/or Vertex AI credentials

### Example Output

Each example provides detailed output with:
- Success indicators for working features
- Error messages with clear explanations
- Performance metrics and timing information
- Configuration details and detected settings
- Live telemetry events (in telemetry showcase)

### Setting Up Authentication

For the examples to work with live API calls, set up authentication:

```bash
# For Gemini API (recommended for examples)
export GEMINI_API_KEY="your_gemini_api_key"

# For Vertex AI (optional, for multi-auth demos)
export VERTEX_JSON_FILE="/path/to/service-account.json"
export VERTEX_PROJECT_ID="your-gcp-project-id"
```

### Example Development Pattern

The examples follow a consistent pattern:
- **Self-contained**: Each example runs independently
- **Well-documented**: Clear inline comments and descriptions
- **Error-resilient**: Graceful handling of missing credentials
- **Informative output**: Detailed logging of operations and results

## Authentication

### Gemini API Key (Recommended for Development)

```elixir
# Environment variable (recommended)
export GEMINI_API_KEY="your_api_key"

# Application config
config :gemini_ex, api_key: "your_api_key"

# Per-request override
Gemini.generate("Hello", api_key: "specific_key")
```

### Vertex AI (Recommended for Production)

```elixir
# Service Account JSON file
export VERTEX_SERVICE_ACCOUNT="/path/to/service-account.json"
export VERTEX_PROJECT_ID="your-gcp-project"
export VERTEX_LOCATION="us-central1"

# Application config
config :gemini_ex, :auth,
  type: :vertex_ai,
  credentials: %{
    service_account_key: System.get_env("VERTEX_SERVICE_ACCOUNT"),
    project_id: System.get_env("VERTEX_PROJECT_ID"),
    location: "us-central1"
  }
```

### Application Default Credentials (ADC)

Zero-config GCP authentication with automatic credential discovery and token refresh.

```elixir
# Works on GCE/Cloud Run/GKE with no extra setup
{:ok, response} = Gemini.generate("Hello from Vertex AI", auth: :vertex_ai)

# Or point to a service account key
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service_account.json"
{:ok, response} = Gemini.generate("Hello", auth: :vertex_ai)
```

The client checks `GOOGLE_APPLICATION_CREDENTIALS`, gcloud user credentials, and metadata server endpoints, caching access tokens for you via ETS.

## Model Configuration System

The library includes an intelligent model registry that handles the differences between Gemini API (AI Studio) and Vertex AI.

### Auth-Aware Model Defaults

Default models are automatically selected based on detected authentication:

```elixir
# With GEMINI_API_KEY set:
Gemini.Config.default_model()        #=> "gemini-flash-lite-latest"
Gemini.Config.default_embedding_model()  #=> "gemini-embedding-001"

# With VERTEX_PROJECT_ID set (no GEMINI_API_KEY):
Gemini.Config.default_model()        #=> "gemini-2.5-flash-lite"
Gemini.Config.default_embedding_model()  #=> "embeddinggemma"
```

### Model Compatibility

Models are organized by API compatibility:

| Category | Example Models | Gemini API | Vertex AI |
|----------|---------------|------------|-----------|
| **Universal** | `gemini-2.5-flash`, `gemini-3-flash-preview` | ✓ | ✓ |
| **AI Studio Only** | `gemini-flash-lite-latest`, `gemini-pro-latest` | ✓ | ✗ |
| **Vertex AI Only** | `embeddinggemma`, `embeddinggemma-300m` | ✗ | ✓ |

```elixir
# Check model availability
Gemini.Config.model_available?(:flash_2_5, :vertex_ai)     #=> true
Gemini.Config.model_available?(:flash_lite_latest, :vertex_ai) #=> false

# Get models for a specific API
Gemini.Config.models_for(:vertex_ai)  # All Vertex-compatible models
Gemini.Config.models_for(:both)       # Only universal models

# Get model by key with validation
Gemini.Config.get_model(:flash_2_5)  #=> "gemini-2.5-flash"
Gemini.Config.get_model(:flash_2_5, api: :vertex_ai)  # Validates compatibility
```

### Embedding Model Differences

Embedding models differ significantly between APIs:

| Model | API | Default Dims | Task Type Handling |
|-------|-----|--------------|-------------------|
| `gemini-embedding-001` | Gemini API | 3072 | `taskType` parameter |
| `embeddinggemma` | Vertex AI | 768 | Prompt prefixes |

```elixir
# Gemini API - uses taskType parameter
{:ok, emb} = Gemini.embed_content("Search query",
  task_type: :retrieval_query  # Sent as API parameter
)

# Vertex AI with EmbeddingGemma - task embedded in prompt
{:ok, emb} = Gemini.embed_content("Search query",
  task_type: :retrieval_query  # Becomes: "task: search result | query: Search query"
)
```

The library handles this automatically based on detected authentication.

### Custom Model Configuration

Override defaults in your application config:

```elixir
config :gemini_ex,
  default_model: "gemini-2.5-flash",
  default_embedding_model: "gemini-embedding-001"
```

Or specify per-request:

```elixir
Gemini.generate("Hello", model: "gemini-3-pro-preview")
Gemini.embed_content("Text", model: "gemini-embedding-001")
```

## Documentation

- **[API Reference](https://hexdocs.pm/gemini_ex)** - Complete function documentation
- **[Architecture Guide](https://hexdocs.pm/gemini_ex/architecture.html)** - System design and components
- **[Authentication System](https://hexdocs.pm/gemini_ex/authentication_system.html)** - Detailed auth configuration
- **[Examples](https://github.com/nshkrdotcom/gemini_ex/tree/main/examples)** - Working code examples
- **Guides (docs/guides/...)**:
  - `adc.md` - Application Default Credentials
  - `batches.md` - Batches API
  - `file_search_stores.md` - RAG stores and document ingestion
  - `files.md` - Files API
  - `function_calling.md` - Tool/function calling patterns
  - `image_generation.md` - Imagen text-to-image/edit/upscale
  - `live_api.md` - WebSocket Live API
  - `operations.md` - Long-running operations and polling
  - `rate_limiting.md` - Limiter configuration and tuning
  - `structured_outputs.md` - JSON schema and property ordering
  - `system_instructions.md` - Persistent guardrails
  - `tunings.md` - Fine-tuning jobs
  - `video_generation.md` - Veo text-to-video

## Architecture

The library features a modular, layered architecture:

- **Authentication Layer**: Multi-strategy auth with automatic credential resolution
- **Coordination Layer**: Unified API coordinator for all operations
- **Streaming Layer**: Advanced SSE processing with state management
- **HTTP Layer**: Dual client system for standard and streaming requests
- **Type Layer**: Comprehensive schemas with runtime validation

## Advanced Usage

### Complete Generation Configuration Support

All generation config options are fully supported across all API entry points:

```elixir
# Structured output with JSON schema
{:ok, response} = Gemini.generate("Analyze this data", [
  response_json_schema: %{
    "type" => "object",
    "properties" => %{
      "summary" => %{"type" => "string"},
      "insights" => %{"type" => "array", "items" => %{"type" => "string"}}
    }
  },
  response_mime_type: "application/json"
])

# Creative writing with advanced controls
{:ok, response} = Gemini.generate("Write a story", [
  temperature: 0.9,
  top_p: 0.8,
  top_k: 40,
  presence_penalty: 0.6,
  frequency_penalty: 0.4,
  stop_sequences: ["THE END", "EPILOGUE"]
])
```

### Custom Model Configuration

```elixir
# List available models
{:ok, models} = Gemini.list_models()

# Get model details
{:ok, model_info} = Gemini.get_model("gemini-flash-lite-latest")

# Count tokens
{:ok, token_count} = Gemini.count_tokens("Your text here", model: "gemini-flash-lite-latest")
```

**Model quick picks**
- `gemini-flash-lite-latest` (default; fastest + most cost-efficient)
- `gemini-2.5-flash` (balanced price/performance for high-volume workloads)
- `gemini-3-flash-preview` (fast Gemini 3 with full thinking levels + built-in tools)
- `gemini-3-pro-preview` (most capable multimodal reasoning)

### Multimodal Content (New in v0.2.2!)

The library now accepts multiple intuitive input formats for images and text:

```elixir
# Anthropic-style format (flexible and intuitive)
content = [
  %{type: "text", text: "What's in this image?"},
  %{type: "image", source: %{type: "base64", data: base64_image}}
]

{:ok, response} = Gemini.generate(content)

# Automatic MIME type detection from image data
{:ok, image_data} = File.read("photo.png")
content = [
  %{type: "text", text: "Describe this photo"},
  %{type: "image", source: %{type: "base64", data: Base.encode64(image_data)}}
  # No mime_type needed - auto-detected as image/png!
]

# Or use the original Content struct format
alias Gemini.Types.{Content, Part}

content = [
  Content.text("What is this?"),
  Content.image("path/to/image.png")
]

{:ok, response} = Gemini.generate(content)

# Mix and match formats in a single request
content = [
  "Describe this image:",                    # Simple string
  %{type: "image", source: %{...}},          # Anthropic-style
  %Content{role: "user", parts: [...]}       # Content struct
]
```

**Supported image formats:** PNG, JPEG, GIF, WebP (auto-detected from magic bytes)

### Image Generation API (Imagen, New in v0.8.x!)

Use the dedicated Imagen endpoints for text-to-image, editing, and upscaling (Vertex AI).

```elixir
alias Gemini.APIs.Images
alias Gemini.Types.Generation.Image.{ImageGenerationConfig, EditImageConfig, UpscaleImageConfig}

# Text-to-image
{:ok, images} =
  Images.generate(
    "An isometric illustration of a futuristic Elixir server farm",
    %ImageGenerationConfig{
      number_of_images: 2,
      aspect_ratio: "16:9",
      safety_filter_level: :standard
    },
    auth: :vertex_ai
  )

# Inpainting / editing with masks
{:ok, edited} =
  Images.edit(
    "Remove the logos and brighten the lighting",
    File.read!("assets/sample.png"),
    File.read!("assets/mask.png"),
    %EditImageConfig{edit_mode: :inpainting},
    auth: :vertex_ai
  )

# Upscale existing images (2x or 4x)
{:ok, sharp} =
  Images.upscale(
    File.read!("assets/sample.png"),
    %UpscaleImageConfig{upscale_factor: :x4},
    auth: :vertex_ai
  )
```

The API returns base64 image data plus metadata; you can also pull from GCS/HTTP URIs and control person_generation, safety filters, and aspect ratios.

### Video Generation API (Veo, New in v0.8.x!)

Generate short-form videos with Veo via Vertex AI.

```elixir
alias Gemini.APIs.Videos
alias Gemini.Types.Generation.Video.VideoGenerationConfig

{:ok, op} =
  Videos.generate(
    "A cinematic drone shot over misty mountains at sunrise",
    %VideoGenerationConfig{duration_seconds: 6, aspect_ratio: "16:9"},
    auth: :vertex_ai
  )

{:ok, completed} = Videos.wait_for_completion(op.name, auth: :vertex_ai)
IO.inspect(completed.response)
```

Use `get_operation/2` or `list_operations/1` to poll or enumerate jobs, and `cancel/2` to stop a run mid-flight.

### Inline Image Generation (Gemini 3 models)

Generate images with aspect ratio and resolution control:

```elixir
config = Gemini.Types.GenerationConfig.image_config(
  aspect_ratio: "16:9",
  image_size: "4K"
)

{:ok, response} =
  Gemini.generate("A sunrise over the mountains",
    model: "gemini-3-pro-image-preview",
    generation_config: config
  )

images = Gemini.Types.Response.Image.extract_base64(response)
```

### Cost Optimization with Thinking Budgets (New in v0.2.2!)

Gemini 2.5 series models use internal "thinking" for complex reasoning. Control thinking token usage to optimize costs:

```elixir
# Disable thinking for simple tasks (save costs)
{:ok, response} = Gemini.generate(
  "What is 2 + 2?",
  model: "gemini-2.5-flash",
  thinking_config: %{thinking_budget: 0}
)
# Result: No thinking tokens charged!

# Set fixed budget (balance cost and quality)
{:ok, response} = Gemini.generate(
  "Write a Python function to sort a list",
  model: "gemini-2.5-flash",
  thinking_config: %{thinking_budget: 1024}
)

# Dynamic thinking (model decides - default behavior)
{:ok, response} = Gemini.generate(
  "Solve this complex problem...",
  model: "gemini-2.5-flash",
  thinking_config: %{thinking_budget: -1}
)

# Get thought summaries (see model's reasoning)
{:ok, response} = Gemini.generate(
  "Explain your reasoning step by step",
  model: "gemini-2.5-flash",
  thinking_config: %{
    thinking_budget: 2048,
    include_thoughts: true
  }
)

# Using GenerationConfig struct
alias Gemini.Types.GenerationConfig

config = GenerationConfig.new()
|> GenerationConfig.thinking_budget(1024)
|> GenerationConfig.include_thoughts(true)
|> GenerationConfig.temperature(0.7)

{:ok, response} = Gemini.generate("prompt", generation_config: config)
```

**Budget ranges by model:**
- **Gemini 2.5 Pro:** 128-32,768 (cannot disable)
- **Gemini 2.5 Flash:** 0-24,576 (can disable with 0)
- **Gemini 2.5 Flash Lite:** 0 or 512-24,576

**Special values:**
- `0`: Disable thinking entirely (Flash/Lite only)
- `-1`: Dynamic thinking (model decides budget)

## Rate Limiting and Retries (Default ON)

- Concurrency gating per model (default 4)
- Retries on 429 using server `RetryInfo.retryDelay`; falls back to 60s if missing
- Retries on 5xx/network with exponential backoff (`base_backoff_ms * 2^(attempt-1)` ± jitter)
- Adaptive concurrency option reacts to 429s

Configure in `config :gemini_ex, :rate_limiter`:

```elixir
config :gemini_ex, :rate_limiter,
  max_concurrency_per_model: 4,
  max_attempts: 3,
  base_backoff_ms: 1000,
  jitter_factor: 0.25,
  adaptive_concurrency: false,
  adaptive_ceiling: 8
```

Per-call overrides:
- `disable_rate_limiter: true` — bypass all gating/retry
- `non_blocking: true` — return immediately on 429 with `{:error, {:rate_limited, retry_at, details}}`

### Error Handling

```elixir
case Gemini.generate("Hello world") do
  {:ok, response} -> 
    # Handle success
    {:ok, text} = Gemini.extract_text(response)
    
  {:error, %Gemini.Error{type: :rate_limit} = error} -> 
    # Handle rate limiting
    IO.puts("Rate limited. Retry after: #{error.retry_after}")
    
  {:error, %Gemini.Error{type: :authentication} = error} -> 
    # Handle auth errors
    IO.puts("Auth error: #{error.message}")
    
  {:error, error} -> 
    # Handle other errors
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run integration tests (requires API key)
GEMINI_API_KEY="your_key" mix test --only integration
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/nshkrdotcom/gemini_ex/blob/main/LICENSE) file for details.

## Acknowledgments

- Google AI team for the Gemini API
- Elixir community for excellent tooling and libraries
- Contributors and maintainers
