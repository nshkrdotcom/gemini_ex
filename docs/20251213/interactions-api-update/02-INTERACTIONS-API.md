# Interactions API - Complete Documentation

**Source:** `python-genai/google/genai/_interactions/`
**Status:** Experimental (as of v1.55.0)

---

## Overview

The Interactions API is a new paradigm for building conversational AI applications. Unlike `generate_content` which is stateless, Interactions provides:

- **Server-side state management** - No need to pass full conversation history
- **Background execution** - Long-running tasks that can be polled
- **Agent orchestration** - Built-in agent patterns
- **Rich streaming** - Fine-grained content deltas with resumption
- **Automatic tool execution** - Built-in tools like Google Search, Code Execution

---

## API Reference

### `interactions.create()`

Creates a new interaction with the model or agent.

#### Signature (Model-based)

```python
def create(
    *,
    input: Input,                                    # Required - The user input
    model: ModelParam,                               # Required - Model to use
    api_version: str | None = None,                  # API version (default: v1beta)
    background: bool = False,                        # Run in background
    generation_config: GenerationConfigParam = None, # Config options
    previous_interaction_id: str = None,             # Chain to previous
    response_format: object = None,                  # JSON schema
    response_mime_type: str = None,                  # Required if response_format set
    response_modalities: List["text"|"image"|"audio"] = None,
    store: bool = False,                             # Store for later retrieval
    stream: bool = False,                            # Enable streaming
    system_instruction: str = None,                  # System prompt
    tools: Iterable[ToolParam] = None,               # Tool declarations
) -> Interaction | Stream[InteractionSSEEvent]
```

**Validation (Python SDK):**
- Rejects specifying both `model` and `agent_config` (use `generation_config` with `model` instead).
- Rejects specifying both `agent` and `generation_config` (use `agent_config` with `agent` instead).

See `python-genai/google/genai/_interactions/resources/interactions.py:412`.

#### Signature (Agent-based)

```python
def create(
    *,
    agent: str,                                      # Required - Agent name
    input: Input,                                    # Required - The user input
    agent_config: AgentConfig = None,                # Agent-specific config
    # ... same optional params as model-based
) -> Interaction | Stream[InteractionSSEEvent]
```

#### Input Types

The `input` parameter accepts multiple formats:

```python
# String
input = "Hello, how are you?"

# Single content block
input = TextContent(type="text", text="Hello")
input = ImageContent(type="image", data="base64...", mime_type="image/png")

# List of content blocks
input = [
    TextContent(type="text", text="Describe this image"),
    ImageContent(type="image", uri="gs://bucket/image.jpg")
]

# List of turns (for multi-turn)
input = [
    Turn(role="user", content="Hello"),
    Turn(role="model", content="Hi there!"),
    Turn(role="user", content="What's the weather?")
]
```

#### Example Usage

```python
from google import genai

client = genai.Client(api_key='...')

# Simple text generation
response = client.interactions.create(
    model='gemini-2.5-flash',
    input='What is the capital of France?'
)
print(response.outputs)

# Streaming with tools
for event in client.interactions.create(
    model='gemini-2.5-flash',
    input='Search for the latest news about AI',
    tools=[{'type': 'google_search'}],
    stream=True
):
    if hasattr(event, 'delta'):
        print(event.delta.text, end='')

# Background execution
interaction = client.interactions.create(
    agent='deep-research-pro-preview-12-2025',
    input='Research the history of quantum computing',
    background=True
)
# Poll for completion
result = client.interactions.get(interaction.id)
```

---

### `interactions.get()`

Retrieves an interaction by ID, optionally with streaming.

#### Signature

```python
def get(
    id: str,                            # Required - Interaction ID
    *,
    api_version: str | None = None,
    last_event_id: str = None,          # Resume from event
    stream: bool = False,               # Stream remaining content
) -> Interaction | Stream[InteractionSSEEvent]
```

#### Resumable Streaming

The `last_event_id` enables resumption of interrupted streams:

```python
# Initial streaming
stream = client.interactions.create(
    model='gemini-2.5-flash',
    input='Write a long story',
    stream=True
)

interaction_id = None
last_id = None
try:
    for event in stream:
        if getattr(event, "event_type", None) == "interaction.start":
            interaction_id = event.interaction.id
        last_id = event.event_id
        process(event)
except ConnectionError:
    pass  # Connection lost

# Resume from where we left off
if interaction_id and last_id:
    resumed = client.interactions.get(
        interaction_id,
        last_event_id=last_id,
        stream=True
    )
    for event in resumed:
        process(event)
```

---

### `interactions.cancel()`

Cancels a background interaction.

#### Signature

```python
def cancel(
    id: str,                            # Required - Interaction ID
    *,
    api_version: str | None = None,
) -> Interaction
```

Only applicable to background interactions that are still running (status: `in_progress`).

---

### `interactions.delete()`

Deletes an interaction.

#### Signature

```python
def delete(
    id: str,                            # Required - Interaction ID
    *,
    api_version: str | None = None,
) -> object  # Empty response
```

---

## Interaction Resource

The `Interaction` is the core response type:

```python
class Interaction:
    id: str                              # Unique identifier
    status: Literal[
        "in_progress",
        "requires_action",
        "completed",
        "failed",
        "cancelled"
    ]

    # Optional fields
    agent: str | None                    # Agent name if agent-based
    model: Model | None                  # Model info if model-based
    created: datetime | None
    updated: datetime | None
    object: Literal["interaction"] = "interaction"
    outputs: List[Output] | None         # Response content blocks
    previous_interaction_id: str | None  # Chained interaction
    role: str | None                     # "model" for responses
    usage: Usage | None                  # Token statistics
```

### Interaction Status Flow

```
┌──────────────┐
│  in_progress │ ←── create() with background=True
└──────┬───────┘
       │
       ├──────────────────────────────────────┐
       ▼                                      ▼
┌──────────────┐                      ┌───────────────┐
│  completed   │                      │requires_action│
└──────────────┘                      └───────────────┘
       ▲                                      │
       │         ┌───────────┐                │
       └─────────│  cancel() │◄───────────────┘
                 └─────┬─────┘
                       │
                       ▼
               ┌───────────────┐
               │   cancelled   │
               └───────────────┘

┌──────────────┐
│    failed    │ ←── Error during processing
└──────────────┘
```

---

## Generation Configuration

The Interactions API has its own generation config:

```python
class GenerationConfig:
    max_output_tokens: int | None
    seed: int | None
    speech_config: List[SpeechConfig] | None
    stop_sequences: List[str] | None
    temperature: float | None
    thinking_level: ThinkingLevel | None      # "low" | "high"
    thinking_summaries: Literal["auto", "none"] | None
    tool_choice: ToolChoice | None
    top_p: float | None
```

### ThinkingLevel Options

```python
ThinkingLevel = Literal["low", "high"]
```

---

## Tool Definitions

The Interactions API supports rich tool declarations:

### Function Tool

```python
{
    "type": "function",
    "name": "get_weather",
    "description": "Get current weather",
    "parameters": {
        "type": "object",
        "properties": {
            "location": {"type": "string"}
        },
        "required": ["location"]
    }
}
```

### Built-in Tools

```python
# Google Search
{"type": "google_search"}

# Code Execution
{"type": "code_execution"}

# URL Context
{"type": "url_context"}

# Computer Use (browser automation)
{
    "type": "computer_use",
    "environment": "browser",
    "excluded_predefined_functions": ["scroll_page"]  # Optional
}

# MCP Server
{
    "type": "mcp_server",
    "name": "my-mcp-server",
    "url": "https://api.example.com/mcp",
    "headers": {"Authorization": "Bearer ..."},
    "allowed_tools": [{"mode": "auto", "tools": ["search"]}]
}

# File Search
{
    "type": "file_search",
    "file_search_store_names": ["my-store"],
    "metadata_filter": "category='docs'",
    "top_k": 10
}
```

---

## Agent Support

### Deep Research Agent

```python
result = client.interactions.create(
    agent='deep-research-pro-preview-12-2025',
    input='Research quantum computing breakthroughs in 2024',
    agent_config={
        "type": "deep-research",
        "thinking_summaries": "auto",
    },
    background=True  # Recommended for long research
)
```

### Dynamic Agent

```python
result = client.interactions.create(
    agent='my-dynamic-agent',
    input='Process this data',
    agent_config={
        'type': 'dynamic',
        # Dynamic agents accept arbitrary additional properties
        'custom_param': 'value'
    }
)
```

---

## Conversation Chaining

Chain interactions for multi-turn conversations:

```python
# First turn
turn1 = client.interactions.create(
    model='gemini-2.5-flash',
    input='What is machine learning?',
    store=True  # Recommended if you want later retrieval
)

# Second turn - references the first
turn2 = client.interactions.create(
    model='gemini-2.5-flash',
    input='Can you give me an example?',
    previous_interaction_id=turn1.id,
    store=True  # Recommended if you want later retrieval
)

# Third turn - references the second (includes full history)
turn3 = client.interactions.create(
    model='gemini-2.5-flash',
    input='How does that relate to neural networks?',
    previous_interaction_id=turn2.id
)
```

---

## Response Modalities

Request specific output modalities:

```python
# Text and image response
result = client.interactions.create(
    model='gemini-2.5-flash',
    input='Draw a cat and describe it',
    response_modalities=['text', 'image']
)

# Audio response (for supported models)
result = client.interactions.create(
    model='gemini-2.5-flash',
    input='Speak this text aloud',
    response_modalities=['audio'],
    generation_config={
        'speech_config': [{'voice': 'alloy'}]
    }
)
```

---

## Structured Output

Enforce JSON schema compliance:

```python
from pydantic import BaseModel

class Person(BaseModel):
    name: str
    age: int

result = client.interactions.create(
    model='gemini-2.5-flash',
    input='Generate a random person',
    response_format=Person.model_json_schema(),
    response_mime_type='application/json'
)

person = Person.model_validate_json(result.outputs[0].text)
```

---

## Error Handling

### Error Events in Streaming

```python
for event in client.interactions.create(..., stream=True):
    if event.event_type == 'error':
        print(f"Error: {event.error.message}")
        break
```

### API Errors

The SDK provides typed exceptions:
- `BadRequestError` (400)
- `AuthenticationError` (401)
- `PermissionDeniedError` (403)
- `NotFoundError` (404)
- `ConflictError` (409)
- `RateLimitError` (429)
- `InternalServerError` (500+)

---

## Elixir Implementation Notes

### Implemented Module Structure (gemini_ex)

```elixir
lib/gemini/
├── apis/
│   └── interactions.ex     # Gemini.APIs.Interactions (create/get/cancel/delete + streaming)
└── types/
    └── interactions/       # Gemini.Types.Interactions.* (Interaction/Turn/Content/Tool/Delta/Events/etc)
```

### Key Implementation Considerations

1. **Lazy Client Initialization** - Python uses `@cached_property` for lazy init
2. **Experimental Warning** - Log warning on first use
3. **Vertex AI Path Building** - Need `_build_maybe_vertex_path` equivalent
4. **Stream Resumption** - Track `event_id` for each event
5. **Type Discrimination** - All content uses `type` field for discrimination

## Revision Notes

- Added Python-side validation rules for `model`/`agent_config` and `agent`/`generation_config` (`python-genai/google/genai/_interactions/resources/interactions.py:412`).
- Fixed `ThinkingLevel` to `"low" | "high"` per `python-genai/google/genai/_interactions/types/thinking_level.py:22`.
- Corrected Deep Research agent config discriminator to `"deep-research"` (not `deep_research`) per `python-genai/google/genai/_interactions/types/deep_research_agent_config_param.py:31`.
- Corrected MCP Server `allowed_tools` shape to `{mode, tools}` per `python-genai/google/genai/_interactions/types/allowed_tools_param.py:28`.
- Updated resumable streaming example to obtain `interaction_id` from the `interaction.start` event (`python-genai/google/genai/_interactions/types/interaction_event.py:34`).
- Updated model examples to `gemini-2.5-flash` to reflect that Interactions model availability can vary and some `gemini-2.0-*` families may be rejected.
- Updated the Elixir module layout section to match the implemented `Gemini.APIs.Interactions` + `Gemini.Types.Interactions.*` structure.
