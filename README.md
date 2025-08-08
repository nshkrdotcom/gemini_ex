# Gemini Elixir Client

[![CI](https://github.com/nshkrdotcom/gemini_ex/actions/workflows/elixir.yaml/badge.svg)](https://github.com/nshkrdotcom/gemini_ex/actions/workflows/elixir.yaml)
[![Elixir](https://img.shields.io/badge/elixir-1.18.3-purple.svg)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/otp-27.3.3-blue.svg)](https://www.erlang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/gemini.svg)](https://hex.pm/packages/gemini_ex)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/gemini_ex)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/nshkrdotcom/gemini_ex/blob/main/LICENSE)

A comprehensive Elixir client for Google's Gemini AI API with dual authentication support, advanced streaming capabilities, type safety, and built-in telemetry.

## ✨ Features

- **🤖 Automatic Tool Calling**: A seamless, Python-SDK-like experience that automates the entire multi-turn tool-calling loop
- **🔐 Dual Authentication**: Seamless support for both Gemini API keys and Vertex AI OAuth/Service Accounts
- **⚡ Advanced Streaming**: Production-grade Server-Sent Events streaming with real-time processing
- **🛡️ Type Safety**: Complete type definitions with runtime validation
- **📊 Built-in Telemetry**: Comprehensive observability and metrics out of the box
- **💬 Chat Sessions**: Multi-turn conversation management with state persistence
- **🎭 Multimodal**: Full support for text, image, audio, and video content
- **⚙️ Complete Generation Config**: Full support for all 12 generation config options including structured output
- **� Producltion Ready**: Robust error handling, retry logic, and performance optimizations
- **🔧 Flexible Configuration**: Environment variables, application config, and per-request overrides

## 📦 Installation

Add `gemini` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gemini_ex, "~> 0.1.1"}
  ]
end
```

## 🚀 Quick Start

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
  model: "gemini-2.0-flash-lite",
  temperature: 0.7,
  max_output_tokens: 1000
])

# Advanced generation config with structured output
{:ok, response} = Gemini.generate("Analyze this topic and provide a summary", [
  response_schema: %{
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
  on_complete: fn -> IO.puts("\n✅ Stream complete!") end,
  on_error: fn error -> IO.puts("❌ Error: #{inspect(error)}") end
])

# Stream management
Gemini.Streaming.pause_stream(stream_id)
Gemini.Streaming.resume_stream(stream_id)
Gemini.Streaming.stop_stream(stream_id)
```

### Advanced Generation Configuration

```elixir
# Using GenerationConfig struct for complex configurations
config = %Gemini.Types.GenerationConfig{
  temperature: 0.7,
  max_output_tokens: 2000,
  response_schema: %{
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

### Multi-turn Conversations

```elixir
# Create a chat session
{:ok, session} = Gemini.create_chat_session([
  model: "gemini-2.0-flash-lite",
  system_instruction: "You are a helpful programming assistant."
])

# Send messages
{:ok, response1} = Gemini.send_message(session, "What is functional programming?")
{:ok, response2} = Gemini.send_message(session, "Show me an example in Elixir")

# Get conversation history
history = Gemini.get_conversation_history(session)
```

## 🛠️ Tool Calling (Function Calling)

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
  model: "gemini-2.0-flash-lite",
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
  model: "gemini-2.0-flash-lite"
)

# Subscribe to the stream
:ok = Gemini.subscribe_stream(stream_id)

# The subscriber will only receive the final text chunks
# All tool execution happens automatically in the background
receive do
  {:stream_chunk, ^stream_id, chunk} -> IO.write(chunk)
  {:stream_complete, ^stream_id} -> IO.puts("\n✅ Complete!")
end
```

### Manual Execution (Advanced)

For advanced use cases requiring full control over the conversation loop, custom state management, or detailed logging of tool executions:

```elixir
# Step 1: Generate content with tool declarations
{:ok, response} = Gemini.generate_content(
  "What's the weather in Paris?",
  tools: [weather_declaration],
  model: "gemini-2.0-flash-lite"
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
        model: "gemini-2.0-flash-lite"
      )
      
      {:ok, text} = Gemini.extract_text(final_response)
      IO.puts(text)
    end
end
```

This manual approach gives you complete visibility and control over each step of the tool calling process, which can be valuable for debugging, logging, or implementing custom conversation management logic.

## 🎯 Examples

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

#### 9. **`live_auto_tool_test.exs`** - Live End-to-End Tool Calling Test ⚡ **LIVE EXAMPLE**
**A comprehensive live test demonstrating real automatic tool execution with the Gemini API.**

```bash
elixir examples/live_auto_tool_test.exs
```

**Features demonstrated:**
- **Real Elixir module introspection** using `Code.ensure_loaded/1` and `Code.fetch_docs/1`
- **Live automatic tool execution** with the actual Gemini API
- **End-to-end workflow validation** from tool registration to final response
- **Comprehensive error handling** and debug output
- **Self-contained execution** with `Mix.install` dependency management
- **Professional output formatting** with step-by-step progress indicators

**What makes this special:**
- ✅ **Actually calls the Gemini API** - not a mock or simulation
- ✅ **Executes real Elixir code** - introspects modules like `Enum`, `String`, `GenServer`
- ✅ **Demonstrates the complete pipeline** - tool registration → API call → tool execution → response synthesis
- ✅ **Self-contained** - runs independently with just an API key
- ✅ **Comprehensive logging** - shows exactly what's happening at each step

**Requirements:** `GEMINI_API_KEY` environment variable (this is a live API test)

**Example output:**
```
🎉 SUCCESS! Final Response from Gemini:
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
- ✅ Success indicators for working features
- ❌ Error messages with clear explanations
- 📊 Performance metrics and timing information
- 🔧 Configuration details and detected settings
- 📡 Live telemetry events (in telemetry showcase)

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

## 🔐 Authentication

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

## 📚 Documentation

- **[API Reference](https://hexdocs.pm/gemini_ex)** - Complete function documentation
- **[Architecture Guide](https://hexdocs.pm/gemini_ex/architecture.html)** - System design and components
- **[Authentication System](https://hexdocs.pm/gemini_ex/authentication_system.html)** - Detailed auth configuration
- **[Examples](https://github.com/nshkrdotcom/gemini_ex/tree/main/examples)** - Working code examples

## 🏗️ Architecture

The library features a modular, layered architecture:

- **Authentication Layer**: Multi-strategy auth with automatic credential resolution
- **Coordination Layer**: Unified API coordinator for all operations
- **Streaming Layer**: Advanced SSE processing with state management
- **HTTP Layer**: Dual client system for standard and streaming requests
- **Type Layer**: Comprehensive schemas with runtime validation

## 🔧 Advanced Usage

### Complete Generation Configuration Support

All 12 generation config options are fully supported across all API entry points:

```elixir
# Structured output with JSON schema
{:ok, response} = Gemini.generate("Analyze this data", [
  response_schema: %{
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
{:ok, model_info} = Gemini.get_model("gemini-2.0-flash-lite")

# Count tokens
{:ok, token_count} = Gemini.count_tokens("Your text here", model: "gemini-2.0-flash-lite")
```

### Multimodal Content

```elixir
# Text with images
content = [
  %{type: "text", text: "What's in this image?"},
  %{type: "image", source: %{type: "base64", data: base64_image}}
]

{:ok, response} = Gemini.generate(content)
```

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

## 🧪 Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run integration tests (requires API key)
GEMINI_API_KEY="your_key" mix test --only integration
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/nshkrdotcom/gemini_ex/blob/main/LICENSE) file for details.

## 🙏 Acknowledgments

- Google AI team for the Gemini API
- Elixir community for excellent tooling and libraries
- Contributors and maintainers
