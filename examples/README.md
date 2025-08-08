# Gemini Elixir Client - Examples

This directory contains a collection of runnable scripts demonstrating the various features and capabilities of the Gemini Elixir library. Each example is designed to showcase specific functionality, from basic text generation to advanced streaming and tool calling features.

**Prerequisites:** Most examples require a valid Gemini API Key or Vertex AI credentials to be configured in your environment.

## How to Run Examples

There are two primary ways to run the example scripts:

### Using `elixir` (for scripts with `Mix.install`)
For scripts that manage their own dependencies and include `Mix.install` at the top:

```shell
elixir examples/auto_tool_calling_demo.exs
```

### Using `mix run` (for scripts without `Mix.install`)
For scripts that rely on the project's mix dependencies:

```shell
mix run examples/demo.exs
```

## Examples Index

### `auto_tool_calling_demo.exs`

Demonstrates the high-level **automatic tool-calling** feature, where the library handles the entire multi-turn conversation automatically.

**To run:**
```shell
elixir examples/auto_tool_calling_demo.exs
```

**Notes:** This script registers mock tools (weather, time, calculator) and shows the complete setup. The final API call is commented out and requires a valid API key to run. Showcases the streamlined approach to tool calling without manual conversation management.

### `manual_tool_calling_demo.exs`

Demonstrates the manual, step-by-step tool-calling loop using the Chat and Tools modules.

**To run:**
```shell
elixir examples/manual_tool_calling_demo.exs
```

**Notes:** Shows how to manually manage the tool-calling conversation flow, including registering tools, creating chat sessions, simulating model responses, and executing function calls. Perfect for understanding the underlying mechanics of tool calling.

### `tool_calling_demo.exs`

Demonstrates the deserialization and serialization of tool calling data structures.

**To run:**
```shell
elixir examples/tool_calling_demo.exs
```

**Notes:** Focuses on parsing API responses with function calls, creating tool results, and handling malformed data. Essential for understanding the data flow in tool calling scenarios.

### `streaming_demo.exs`

Showcases the library's real-time streaming capabilities with live API connectivity.

**To run:**
```shell
mix run examples/streaming_demo.exs
```

**Notes:** Requires a valid API key (GEMINI_API_KEY or Vertex AI credentials) to demonstrate live streaming. Shows authentication detection, stream management, and real-time text generation.

### `demo.exs`

Comprehensive demonstration of core library features including text generation, chat sessions, and token counting.

**To run:**
```shell
mix run examples/demo.exs
```

**Notes:** Requires GEMINI_API_KEY environment variable. Covers model listing, simple and configured generation, chat sessions, and token counting. Great starting point for new users.

### `demo_unified.exs`

Demonstrates the unified architecture supporting both Gemini API and Vertex AI authentication methods.

**To run:**
```shell
mix run examples/demo_unified.exs
```

**Notes:** Shows configuration system, authentication strategies, streaming manager, and backward compatibility. Excellent for understanding the library's architecture and multi-auth support.

### `live_api_test.exs`

Tests live API connectivity for both Gemini and Vertex AI authentication methods, plus streaming functionality.

**To run:**
```shell
mix run examples/live_api_test.exs
```

**Notes:** Comprehensive test suite that validates both authentication methods. Requires either GEMINI_API_KEY or Vertex AI credentials (VERTEX_JSON_FILE, VERTEX_PROJECT_ID). Includes streaming tests and performance validation.

### `telemetry_showcase.exs`

Comprehensive demonstration of the library's telemetry and observability system.

**To run:**
```shell
mix run examples/telemetry_showcase.exs
```

**Notes:** Shows telemetry event handling, real-time monitoring, performance measurement, and analysis capabilities. Includes both mock demonstrations and live API telemetry (requires API key for full functionality).

## Environment Variables

The examples use the following environment variables for authentication:

### Gemini API
- `GEMINI_API_KEY` - Your Gemini API key

### Vertex AI
- `VERTEX_JSON_FILE` or `VERTEX_SERVICE_ACCOUNT` - Path to service account JSON file
- `VERTEX_PROJECT_ID` or `GOOGLE_CLOUD_PROJECT` - Google Cloud project ID
- `VERTEX_LOCATION` - Google Cloud location (defaults to "us-central1")

## Getting Started

1. **For basic functionality:** Start with `demo.exs` to see core features
2. **For tool calling:** Try `auto_tool_calling_demo.exs` for the high-level approach
3. **For streaming:** Run `streaming_demo.exs` to see real-time generation
4. **For architecture understanding:** Explore `demo_unified.exs`
5. **For testing:** Use `live_api_test.exs` to validate your setup

Each example includes detailed output and explanations to help you understand the library's capabilities and how to integrate them into your own applications.