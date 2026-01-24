# System Instructions Guide

System instructions allow you to set persistent context that guides the model's behavior across all interactions in a session.

## Overview

System instructions are different from user messages:

- **Persistent**: Applied to every request without repeating in conversation history
- **Higher priority**: Model treats system instructions as authoritative context
- **Token efficient**: Only sent once per request, not duplicated in history
- **Structured**: Can include complex formatting, rules, and examples

## Quick Start

```elixir
alias Gemini.APIs.Coordinator

# Simple string system instruction
{:ok, response} = Coordinator.generate_content(
  "Explain photosynthesis",
  system_instruction: "You are a biology teacher for 8th grade students. Use simple language and real-world examples."
)

{:ok, text} = Coordinator.extract_text(response)
IO.puts(text)
```

## System Instruction Formats

### String Format

The simplest form - just a text string:

```elixir
{:ok, response} = Coordinator.generate_content(
  "Write a poem about the ocean",
  system_instruction: "You are a poet who writes in the style of Emily Dickinson."
)
```

### Content Struct Format

For more complex instructions with multiple parts:

```elixir
alias Gemini.Types.Content

system_content = %Content{
  role: "user",
  parts: [
    %Gemini.Types.Part{text: "You are a helpful coding assistant."},
    %Gemini.Types.Part{text: "Always include code examples in your responses."},
    %Gemini.Types.Part{text: "Use TypeScript for all examples unless asked otherwise."}
  ]
}

{:ok, response} = Coordinator.generate_content(
  "How do I sort an array?",
  system_instruction: system_content
)
```

### Map Format

For structured instructions:

```elixir
{:ok, response} = Coordinator.generate_content(
  "Summarize this document",
  system_instruction: %{
    parts: [
      %{text: """
      You are a document summarizer with these rules:
      1. Keep summaries under 200 words
      2. Use bullet points for key facts
      3. Include a "Key Takeaway" at the end
      """}
    ]
  }
)
```

## Use Cases

### Persona Setting

Define how the model should behave:

```elixir
# Customer service agent
{:ok, _} = Coordinator.generate_content(
  "I can't find my order",
  system_instruction: """
  You are a friendly customer service agent for ShopMart.
  - Always greet customers warmly
  - Ask for order number if not provided
  - Offer solutions, not excuses
  - End with "Is there anything else I can help with?"
  """
)
```

### Response Format Control

Ensure consistent output format:

```elixir
# JSON response format
{:ok, response} = Coordinator.generate_content(
  "List 3 fruits",
  system_instruction: """
  Always respond with valid JSON in this format:
  {
    "items": ["item1", "item2", ...],
    "count": <number>
  }
  Do not include any text outside the JSON.
  """,
  response_mime_type: "application/json"
)
```

### Domain Expertise

Set up domain-specific knowledge:

```elixir
# Legal assistant
{:ok, _} = Coordinator.generate_content(
  "What is a tort?",
  system_instruction: """
  You are a legal research assistant specializing in U.S. law.

  When explaining legal concepts:
  1. Start with a plain English definition
  2. Provide the formal legal definition
  3. Give an example case
  4. Note any relevant statutes

  Always include a disclaimer that this is not legal advice.
  """
)
```

### Safety and Boundaries

Set appropriate boundaries:

```elixir
# Child-safe content
{:ok, _} = Coordinator.generate_content(
  "Tell me a story",
  system_instruction: """
  You create content for children ages 5-8.

  Rules:
  - Use age-appropriate language
  - Avoid scary or violent themes
  - Include positive messages
  - Keep stories under 300 words
  """
)
```

## Multi-Turn Conversations

System instructions persist across the conversation:

```elixir
alias Gemini.Chat

# Start chat with system instruction
{:ok, chat} = Chat.start_chat(
  system_instruction: "You are a math tutor. Walk through problems step by step."
)

# All messages inherit the system instruction
{:ok, response1} = Chat.send_message(chat, "What is 15% of 80?")
# Model responds with step-by-step explanation

{:ok, response2} = Chat.send_message(chat, "Now what is 20% of the same number?")
# Model continues with consistent tutoring style
```

## Combining with Other Features

### With Tools

System instructions can guide tool usage:

```elixir
{:ok, response} = Coordinator.generate_content(
  "What's the weather like for a picnic?",
  system_instruction: """
  You are a helpful assistant with access to weather data.

  When asked about weather:
  1. Always check the current weather first
  2. Provide practical advice based on conditions
  3. Suggest alternatives if weather is bad
  """,
  tools: [weather_function]
)
```

### With Generation Config

Combine with generation parameters:

```elixir
{:ok, response} = Coordinator.generate_content(
  "Write a tagline",
  system_instruction: "You are a marketing copywriter. Be creative and punchy.",
  temperature: 0.9,
  max_output_tokens: 50
)
```

### With Structured Output

Enforce both behavior and format:

```elixir
{:ok, response} = Coordinator.generate_content(
  "Analyze this product review",
  system_instruction: """
  You are a sentiment analysis expert.
  Analyze reviews for:
  - Overall sentiment (positive/negative/neutral)
  - Key themes mentioned
  - Suggested improvements
  """,
  response_mime_type: "application/json",
  response_json_schema: %{
    "type" => "object",
    "properties" => %{
      "sentiment" => %{"type" => "string", "enum" => ["positive", "negative", "neutral"]},
      "themes" => %{"type" => "array", "items" => %{"type" => "string"}},
      "improvements" => %{"type" => "array", "items" => %{"type" => "string"}}
    }
  }
)
```

## Best Practices

### 1. Be Specific

```elixir
# Good: Specific instructions
system_instruction: """
You are a technical writer for software documentation.
- Use present tense
- Write in second person ("you")
- Include code examples for every concept
- Keep sentences under 25 words
"""

# Avoid: Vague instructions
system_instruction: "Be helpful and write well."
```

### 2. Use Structure

```elixir
# Good: Organized sections
system_instruction: """
## Role
You are a financial advisor.

## Guidelines
- Always ask about risk tolerance
- Explain fees clearly
- Never guarantee returns

## Response Format
1. Summary of advice
2. Detailed explanation
3. Next steps
"""
```

### 3. Include Examples

```elixir
system_instruction: """
Format responses as haiku (5-7-5 syllables).

Example:
User: What is spring?
Assistant:
Cherry blossoms fall
Gentle rain awakens earth
New life emerges
"""
```

### 4. Keep it Focused

Don't overload with too many instructions. Focus on the key behaviors you need.

### 5. Test Variations

Different phrasings can produce different results. Test your system instructions with various inputs.

## Limitations

- System instructions count toward the context window
- Very long instructions may reduce space for conversation
- Model may occasionally deviate from instructions
- Some instructions may conflict with safety guidelines

## Token Efficiency

System instructions are more token-efficient than repeating context:

```elixir
# Efficient: System instruction (sent once per request)
{:ok, _} = Coordinator.generate_content(
  "Question here",
  system_instruction: "You are an expert..."
)

# Less efficient: Context in every message
{:ok, _} = Coordinator.generate_content([
  %{role: "user", parts: [%{text: "Context: You are an expert... Question here"}]}
])
```

## See Also

- [Function Calling Guide](function_calling.md) - Integrating external tools
- [Structured Outputs Guide](structured_outputs.md) - Getting JSON responses
- [Chat Module](../readme.html#chat) - Multi-turn conversations
