# Implementation Priorities

**Date:** 2025-12-06
**Goal:** Close critical gaps to achieve production parity with Python SDK

---

## Priority Tiers

### Tier 1: Quick Wins (High Impact, Low Effort)

These can be completed immediately with minimal risk.

#### 1.1 System Instruction Support
**Effort:** 2-4 hours | **Impact:** High | **Risk:** Low

```elixir
# Current: lib/gemini/types/request/generate_content_request.ex
defmodule Gemini.Types.Request.GenerateContentRequest do
  defstruct [
    :model,
    :contents,
    :generation_config,
    :safety_settings,
    :system_instruction  # ADD THIS
  ]
end
```

**Tasks:**
- [ ] Add `system_instruction` field to GenerateContentRequest
- [ ] Update request building in Coordinator
- [ ] Add type spec for Content type
- [ ] Test with simple system prompts
- [ ] Update documentation

#### 1.2 Missing GenerationConfig Fields
**Effort:** 2-4 hours | **Impact:** Medium | **Risk:** Low

**Add these fields:**
```elixir
defmodule Gemini.Types.Request.GenerationConfig do
  defstruct [
    :temperature,
    :top_p,
    :top_k,
    :max_output_tokens,
    :stop_sequences,
    :candidate_count,
    :response_mime_type,       # ADD
    :response_schema,          # ADD
    :presence_penalty,         # ADD
    :frequency_penalty,        # ADD
    :response_logprobs,        # ADD
    :logprobs                  # ADD
  ]
end
```

#### 1.3 Response Field Extraction
**Effort:** 2-4 hours | **Impact:** Medium | **Risk:** Low

**Add helper functions:**
```elixir
defmodule Gemini.Response do
  def extract_function_calls(response)
  def extract_finish_reason(response)
  def extract_safety_ratings(response)
  def extract_usage_metadata(response)
  def extract_grounding_metadata(response)
end
```

---

### Tier 2: Function Calling Foundation (Critical Path)

This is the most impactful work for AI agent use cases.

#### 2.1 Complete Tool Types
**Effort:** 1 week | **Impact:** Critical | **Risk:** Medium

**Files to create/update:**
```
lib/gemini/types/content/
├── tool.ex              # UPDATE
├── function_declaration.ex  # CREATE
├── function_call.ex     # CREATE
├── function_response.ex # CREATE
└── schema.ex            # CREATE
```

**Type definitions needed:**
```elixir
defmodule Gemini.Types.Content.FunctionDeclaration do
  @type t :: %__MODULE__{
    name: String.t(),
    description: String.t(),
    parameters: Schema.t() | nil,
    response: Schema.t() | nil
  }
end

defmodule Gemini.Types.Content.Schema do
  @type t :: %__MODULE__{
    type: :string | :number | :integer | :boolean | :array | :object,
    description: String.t() | nil,
    enum: [String.t()] | nil,
    items: t() | nil,
    properties: %{String.t() => t()} | nil,
    required: [String.t()] | nil
  }
end
```

#### 2.2 Function Call Execution
**Effort:** 1 week | **Impact:** Critical | **Risk:** Medium

**Create function execution module:**
```elixir
defmodule Gemini.Tools.Executor do
  @moduledoc """
  Executes function calls and returns results.
  """

  @type function_registry :: %{String.t() => function()}
  @type execution_result :: {:ok, term()} | {:error, term()}

  @spec execute(FunctionCall.t(), function_registry()) :: execution_result()
  def execute(%FunctionCall{name: name, args: args}, registry) do
    case Map.get(registry, name) do
      nil -> {:error, {:unknown_function, name}}
      func -> apply_function(func, args)
    end
  end

  @spec build_response(String.t(), term()) :: FunctionResponse.t()
  def build_response(name, result) do
    %FunctionResponse{name: name, response: %{"result" => result}}
  end
end
```

#### 2.3 Automatic Function Calling
**Effort:** 1 week | **Impact:** High | **Risk:** Medium

**Create AFC loop module:**
```elixir
defmodule Gemini.Tools.AutomaticFunctionCalling do
  @moduledoc """
  Implements the automatic function calling loop.
  """

  @type afc_config :: %{
    disable: boolean(),
    maximum_remote_calls: non_neg_integer(),
    ignore_call_history: boolean()
  }

  @spec generate_with_tools(request(), function_registry(), afc_config()) ::
    {:ok, response()} | {:error, term()}
  def generate_with_tools(request, registry, config \\ %{}) do
    loop(request, registry, config, 0, [])
  end

  defp loop(request, registry, config, call_count, history) do
    # 1. Send request
    # 2. Check for function calls in response
    # 3. If no function calls, return response
    # 4. Execute function calls
    # 5. Append results to history
    # 6. Check call count limit
    # 7. Loop with updated request
  end
end
```

---

### Tier 3: Live/Real-time API (WebSocket)

Enables voice and real-time applications.

#### 3.1 WebSocket Client
**Effort:** 1 week | **Impact:** High | **Risk:** High

**Dependencies:**
- Add `websockex` or `gun` for WebSocket support
- Create connection manager

**Create:**
```elixir
defmodule Gemini.Live.Connection do
  use WebSockex

  def start_link(url, opts) do
    WebSockex.start_link(url, __MODULE__, opts)
  end

  def handle_frame({:text, msg}, state) do
    # Parse and dispatch message
  end

  def send_message(pid, message) do
    WebSockex.send_frame(pid, {:text, Jason.encode!(message)})
  end
end
```

#### 3.2 Live Session Management
**Effort:** 1 week | **Impact:** High | **Risk:** Medium

**Create:**
```elixir
defmodule Gemini.Live.Session do
  use GenServer

  defstruct [:connection, :config, :state, :handlers]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def send(session, message) do
    GenServer.call(session, {:send, message})
  end

  def receive(session) do
    GenServer.call(session, :receive, :infinity)
  end
end
```

#### 3.3 Audio Codec Support
**Effort:** 1 week | **Impact:** Medium | **Risk:** High

**Consider:**
- PCM audio encoding/decoding
- Opus codec support (optional)
- Audio buffering and chunking

---

### Tier 4: Type System Expansion

Improve type coverage for better compile-time guarantees.

#### 4.1 Request Type Completion
**Effort:** 3-5 days | **Impact:** Medium | **Risk:** Low

**Files to update:**
```
lib/gemini/types/request/
├── generate_content_request.ex  # Add missing fields
├── generation_config.ex         # Add all Python fields
├── safety_setting.ex            # Complete harm categories
├── tool_config.ex               # CREATE
└── caching_config.ex            # CREATE
```

#### 4.2 Response Type Completion
**Effort:** 3-5 days | **Impact:** Medium | **Risk:** Low

**Files to update:**
```
lib/gemini/types/response/
├── generate_content_response.ex  # Add usage_metadata, etc.
├── candidate.ex                  # Add grounding_metadata
├── safety_rating.ex              # Complete categories
├── grounding_metadata.ex         # CREATE
└── citation_metadata.ex          # CREATE
```

#### 4.3 Grounding Types
**Effort:** 3-5 days | **Impact:** Medium | **Risk:** Low

**Create:**
```
lib/gemini/types/grounding/
├── google_search.ex
├── google_search_retrieval.ex
├── dynamic_retrieval_config.ex
├── grounding_chunk.ex
├── grounding_support.ex
└── search_entry_point.ex
```

---

### Tier 5: Model Tuning API

Enterprise feature for custom models.

#### 5.1 Tuning Types
**Effort:** 3-5 days | **Impact:** Medium | **Risk:** Low

**Create:**
```
lib/gemini/types/tuning/
├── tuned_model.ex
├── tuning_job.ex
├── tuning_task.ex
├── tuning_dataset.ex
├── hyperparameters.ex
└── tuning_example.ex
```

#### 5.2 Tuning API Module
**Effort:** 1 week | **Impact:** Medium | **Risk:** Medium

**Create:**
```elixir
defmodule Gemini.APIs.Tunings do
  @spec create(TunedModel.t(), keyword()) :: {:ok, TuningJob.t()} | {:error, Error.t()}
  def create(tuned_model, opts \\ [])

  @spec get(String.t(), keyword()) :: {:ok, TunedModel.t()} | {:error, Error.t()}
  def get(name, opts \\ [])

  @spec list(keyword()) :: {:ok, [TunedModel.t()]} | {:error, Error.t()}
  def list(opts \\ [])

  @spec delete(String.t(), keyword()) :: :ok | {:error, Error.t()}
  def delete(name, opts \\ [])
end
```

---

### Tier 6: Image/Video Generation

Creative and multimodal output.

#### 6.1 Image Generation
**Effort:** 1 week | **Impact:** Medium | **Risk:** Medium

**Add to models.ex:**
```elixir
@spec generate_images(String.t(), String.t(), keyword()) ::
  {:ok, GenerateImagesResponse.t()} | {:error, Error.t()}
def generate_images(model, prompt, opts \\ [])
```

#### 6.2 Video Generation
**Effort:** 1 week | **Impact:** Medium | **Risk:** Medium

**Add to models.ex:**
```elixir
@spec generate_videos(String.t(), String.t(), keyword()) ::
  {:ok, Operation.t()} | {:error, Error.t()}
def generate_videos(model, prompt, opts \\ [])
```

---

## Implementation Roadmap

```
Phase 1: Foundation (Weeks 1-2)
├── [Week 1] Quick Wins (Tier 1)
│   ├── System instruction
│   ├── GenerationConfig fields
│   └── Response helpers
└── [Week 2] Function Calling Types (Tier 2.1)
    ├── FunctionDeclaration
    ├── FunctionCall
    ├── FunctionResponse
    └── Schema

Phase 2: Core Features (Weeks 3-4)
├── [Week 3] Function Execution (Tier 2.2)
│   ├── Executor module
│   ├── Registry pattern
│   └── Error handling
└── [Week 4] Automatic FC (Tier 2.3)
    ├── AFC loop
    ├── Call limits
    └── History management

Phase 3: Real-time (Weeks 5-7)
├── [Week 5] WebSocket Client (Tier 3.1)
├── [Week 6] Session Management (Tier 3.2)
└── [Week 7] Audio Support (Tier 3.3)

Phase 4: Polish (Weeks 8-10)
├── [Week 8] Type Expansion (Tier 4)
├── [Week 9] Model Tuning (Tier 5)
└── [Week 10] Image/Video (Tier 6)
```

---

## Risk Assessment

| Work Item | Technical Risk | Integration Risk | Mitigation |
|-----------|---------------|------------------|------------|
| System Instruction | Low | Low | Simple field addition |
| Function Types | Low | Medium | Follow Python patterns exactly |
| Function Execution | Medium | Medium | Comprehensive testing |
| AFC Loop | Medium | High | Careful state management |
| Live API | High | High | Use proven WebSocket libs |
| Model Tuning | Low | Medium | Standard REST patterns |
| Image/Video | Medium | Medium | Long-running operation handling |

---

## Success Metrics

### Phase 1 Complete
- [ ] System instruction works in generation requests
- [ ] All GenerationConfig fields supported
- [ ] Response helpers extract all metadata

### Phase 2 Complete
- [ ] Can declare and use function tools
- [ ] Functions execute correctly
- [ ] AFC loop handles multi-step calls
- [ ] Example: Calculator agent works

### Phase 3 Complete
- [ ] WebSocket connection established
- [ ] Can send/receive live messages
- [ ] Audio streaming works
- [ ] Example: Voice assistant works

### Phase 4 Complete
- [ ] 90%+ type coverage
- [ ] Model tuning creates/manages models
- [ ] Image generation works
- [ ] Video generation (operation) works

---

## Dependencies

### External Packages Needed
```elixir
# mix.exs
defp deps do
  [
    # Existing
    {:jason, "~> 1.4"},
    {:req, "~> 0.4"},
    {:typed_struct, "~> 0.3"},

    # Add for Live API
    {:websockex, "~> 0.4"},  # WebSocket client

    # Optional for audio
    {:membrane_core, "~> 1.0"},  # Audio processing
  ]
end
```

### Internal Dependencies
```
Function Calling Types → Function Execution → AFC Loop
                                           ↘
WebSocket Client → Session Management → Audio Support
```

---

## Testing Strategy

### Unit Tests
- Each type module has dedicated tests
- Function executor tested with mocks
- AFC loop tested with simulated responses

### Integration Tests
- Live API tests against real endpoint (with mocks available)
- Function calling end-to-end tests
- Multi-auth with tools tests

### Example Applications
- Calculator agent (function calling)
- Voice assistant (live API)
- Image generator (multimodal output)

---

*This document should be updated as implementation progresses.*
