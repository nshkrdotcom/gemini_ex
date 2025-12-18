# Function Calling Guide

Function calling enables Gemini to interact with external systems by generating structured function calls that your application executes.

## Overview

Function calling works in three steps:

1. **Declare functions** - Tell Gemini what functions are available
2. **Receive calls** - Gemini generates function calls in its response
3. **Return results** - Execute functions and return results to continue the conversation

## Quick Start

```elixir
alias Altar.ADM.FunctionDeclaration
alias Gemini.Tools.Executor
alias Gemini.APIs.Coordinator

# 1. Declare your function
{:ok, weather_fn} = FunctionDeclaration.new(
  name: "get_weather",
  description: "Get the current weather for a location",
  parameters: %{
    type: "object",
    properties: %{
      "location" => %{type: "string", description: "City name or coordinates"}
    },
    required: ["location"]
  }
)

# 2. Create a function registry
registry = Executor.create_registry(
  get_weather: fn args ->
    location = args["location"]
    # Your actual weather API call here
    "Sunny, 72°F in #{location}"
  end
)

# 3. Generate with tools
{:ok, response} = Coordinator.generate_content(
  "What's the weather in San Francisco?",
  tools: [weather_fn]
)

# 4. Check for function calls
if Coordinator.has_function_calls?(response) do
  calls = Coordinator.extract_function_calls(response)
  results = Executor.execute_all(calls, registry)
  IO.inspect(results)
end
```

## Built-in Tools (Gemini 3)

Gemini 3 models support built-in tools for Google Search, URL context, and code execution.
You can enable them in `tools:` alongside your own function declarations:

```elixir
{:ok, response} =
  Gemini.generate(
    "Find the latest news about Elixir and summarize it.",
    model: "gemini-3-pro-preview",
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

## Defining Functions

### Using FunctionDeclaration

The `Altar.ADM.FunctionDeclaration` struct defines a function's contract:

```elixir
{:ok, fn_decl} = FunctionDeclaration.new(
  name: "search_database",
  description: "Search the product database",
  parameters: %{
    type: "object",
    properties: %{
      "query" => %{
        type: "string",
        description: "Search query"
      },
      "limit" => %{
        type: "integer",
        description: "Maximum results to return"
      },
      "category" => %{
        type: "string",
        description: "Filter by category",
        enum: ["electronics", "clothing", "home"]
      }
    },
    required: ["query"]
  }
)
```

### Using Schema Type

For more complex schemas, use `Gemini.Types.Schema`:

```elixir
alias Gemini.Types.Schema

# Simple string parameter
name_schema = Schema.string("Person's full name")

# Object with nested properties
address_schema = Schema.object(%{
  "street" => Schema.string("Street address"),
  "city" => Schema.string("City name"),
  "zip" => Schema.string("ZIP code")
}, required: ["city"])

# Array of items
tags_schema = Schema.array(
  Schema.string("Tag name"),
  "List of tags"
)

# Complex nested schema
person_schema = Schema.object(%{
  "name" => name_schema,
  "address" => address_schema,
  "tags" => tags_schema
}, required: ["name"])

# Convert to API format for function parameters
params = Schema.to_api_map(person_schema)
```

## Executing Function Calls

### Manual Execution

```elixir
alias Gemini.Tools.Executor

# Create registry
registry = %{
  "get_weather" => fn args -> fetch_weather(args["location"]) end,
  "search" => fn args -> search_database(args["query"]) end
}

# Execute calls
{:ok, response} = Coordinator.generate_content("...", tools: tools)
calls = Coordinator.extract_function_calls(response)

for call <- calls do
  case Executor.execute(call, registry) do
    {:ok, result} ->
      IO.puts("#{call.name}: #{inspect(result)}")
    {:error, reason} ->
      IO.puts("Error in #{call.name}: #{inspect(reason)}")
  end
end
```

### Batch Execution

```elixir
# Sequential execution
results = Executor.execute_all(calls, registry)

# Parallel execution (for I/O-bound operations)
results = Executor.execute_all_parallel(calls, registry)
```

### Building Responses

After executing functions, build responses for the next API call:

```elixir
responses = Executor.build_responses(calls, results)

# responses is a list of FunctionResponse structs
# Use these to continue the conversation
```

## Automatic Function Calling (AFC)

AFC automatically handles the execute-and-continue loop:

```elixir
alias Gemini.Tools.AutomaticFunctionCalling, as: AFC

# Configure AFC
config = AFC.config(
  max_calls: 10,           # Maximum function calls before stopping
  parallel_execution: true  # Execute calls in parallel
)

# Define generate function
generate_fn = fn contents, opts ->
  Coordinator.generate_content(contents, opts)
end

# Initial request
{:ok, response} = Coordinator.generate_content(
  "What's the weather in NYC and LA?",
  tools: tools
)

# Run AFC loop
{final_response, call_count, history} = AFC.loop(
  response,
  [%{role: "user", parts: [%{text: "What's the weather in NYC and LA?"}]}],
  registry,
  config,
  0,    # initial call count
  [],   # initial history
  generate_fn,
  [tools: tools]  # opts for generate_fn
)

IO.puts("Made #{call_count} function calls")
IO.puts("Final response: #{inspect(final_response)}")
```

## Multi-Turn Conversations

Function calling naturally fits into multi-turn conversations:

```elixir
# Turn 1: User asks a question
{:ok, response1} = Coordinator.generate_content(
  "What's the weather like?",
  tools: tools
)

# Turn 2: Execute function calls and continue
if Coordinator.has_function_calls?(response1) do
  calls = Coordinator.extract_function_calls(response1)
  results = Executor.execute_all(calls, registry)

  # Build conversation history
  user_content = %{role: "user", parts: [%{text: "What's the weather like?"}]}
  model_content = %{role: "model", parts: response1.candidates |> hd() |> Map.get(:content) |> Map.get(:parts)}
  function_content = AFC.build_function_response_content(calls, results)

  # Continue conversation
  {:ok, response2} = Coordinator.generate_content(
    [user_content, model_content, function_content],
    tools: tools
  )
end
```

## Error Handling

### Unknown Functions

```elixir
case Executor.execute(call, registry) do
  {:ok, result} ->
    # Success
    result

  {:error, {:unknown_function, name}} ->
    # Function not in registry
    Logger.error("Unknown function: #{name}")

  {:error, {:execution_error, exception}} ->
    # Function raised an exception
    Logger.error("Execution error: #{Exception.message(exception)}")
end
```

### AFC Limits

```elixir
config = AFC.config(max_calls: 5)

{response, call_count, _} = AFC.loop(...)

if call_count >= 5 do
  Logger.warn("AFC loop reached maximum calls")
end
```

## Best Practices

### 1. Keep Functions Focused

Each function should do one thing well:

```elixir
# Good: Focused functions
{:ok, _} = FunctionDeclaration.new(
  name: "get_user",
  description: "Get a user by ID",
  parameters: %{type: "object", properties: %{"user_id" => %{type: "string"}}}
)

# Avoid: Functions that do too much
# "manage_user" that creates, updates, and deletes
```

### 2. Write Clear Descriptions

Gemini uses descriptions to understand when to call functions:

```elixir
# Good: Clear, specific description
{:ok, _} = FunctionDeclaration.new(
  name: "search_orders",
  description: "Search customer orders by date range, status, or order ID. Returns order summaries including total, items, and shipping status.",
  parameters: %{...}
)

# Avoid: Vague descriptions
# description: "Search stuff"
```

### 3. Validate Parameters

The Schema type enforces constraints:

```elixir
# Use enum for known values
status_schema = Schema.string("Order status", enum: ["pending", "shipped", "delivered"])

# Use minimum/maximum for ranges
count_schema = Schema.integer("Item count", minimum: 1, maximum: 100)
```

### 4. Handle Errors Gracefully

Always handle execution errors in responses:

```elixir
# The Executor automatically builds error responses
responses = Executor.build_responses(calls, results)
# Error results become: %{error: "Error message"}
```

## Complete Example

Here's a complete example with a calculator agent:

```elixir
defmodule CalculatorAgent do
  alias Altar.ADM.FunctionDeclaration
  alias Gemini.Tools.{Executor, AutomaticFunctionCalling}
  alias Gemini.APIs.Coordinator

  def run(question) do
    tools = build_tools()
    registry = build_registry()
    config = AutomaticFunctionCalling.config(max_calls: 5)

    {:ok, response} = Coordinator.generate_content(
      question,
      tools: tools
    )

    generate_fn = fn contents, opts ->
      Coordinator.generate_content(contents, opts)
    end

    {final_response, _, _} = AutomaticFunctionCalling.loop(
      response,
      [%{role: "user", parts: [%{text: question}]}],
      registry,
      config,
      0,
      [],
      generate_fn,
      [tools: tools]
    )

    case Coordinator.extract_text(final_response) do
      {:ok, text} -> text
      _ -> "Unable to get response"
    end
  end

  defp build_tools do
    [
      elem(FunctionDeclaration.new(
        name: "add",
        description: "Add two numbers",
        parameters: %{
          type: "object",
          properties: %{
            "a" => %{type: "number"},
            "b" => %{type: "number"}
          },
          required: ["a", "b"]
        }
      ), 1),
      elem(FunctionDeclaration.new(
        name: "multiply",
        description: "Multiply two numbers",
        parameters: %{
          type: "object",
          properties: %{
            "a" => %{type: "number"},
            "b" => %{type: "number"}
          },
          required: ["a", "b"]
        }
      ), 1)
    ]
  end

  defp build_registry do
    Executor.create_registry(
      add: fn args -> args["a"] + args["b"] end,
      multiply: fn args -> args["a"] * args["b"] end
    )
  end
end

# Usage
result = CalculatorAgent.run("What is 5 + 3 multiplied by 2?")
IO.puts(result)
```

## See Also

- [System Instructions Guide](system_instructions.md) - Setting persistent system prompts
- [Structured Outputs Guide](structured_outputs.md) - Getting structured JSON responses
- [Streaming Guide](../STREAMING.md) - Real-time streaming responses
