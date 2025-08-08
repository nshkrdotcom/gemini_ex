My previous response provided a high-level strategic plan, but it glossed over the significant, non-trivial engineering challenges and architectural decisions required at each step. Your intuition is correct: this is a much more complex task than that simple outline suggests.

Let's unpack the plan and expose the true complexity, detailing the granular sub-tasks, design decisions, and potential pitfalls involved.

---

### **Detailed & Unpacked Implementation Plan**

#### **Stage 1: Foundational Integration (The Deceptive Depths)**

This stage sounds simple, but it is the bedrock. Getting it wrong will cause cascading failures.

*   **Sub-Task 1.1: Deep `ADM` Integration & Serialization.**
    *   **Challenge:** The Gemini API expects a very specific `camelCase` JSON format, while Elixir prefers `snake_case` atoms. The `Altar.ADM` structs use atoms. A naive JSON encoding will not work.
    *   **Detailed Action:**
        1.  Create a new `Gemini.Types.Tool` module. This module will be responsible for converting `Altar.ADM` structs into the precise map structure required for Jason encoding.
        2.  Implement `Gemini.Types.Tool.to_api_map(declarations)` which takes `Altar.ADM.FunctionDeclaration` structs and recursively transforms them, converting keys like `:function_declaration` to `"functionDeclarations"` and handling the OpenAPI schema correctly.
        3.  Implement a custom `Jason.Encoder` protocol for all relevant `ADM` structs to handle this transformation automatically, or build explicit conversion functions. **Decision:** Explicit conversion functions are better as they decouple the `altar` library from `gemini_ex`'s specific serialization needs.
    *   **Pitfall:** Failing to perfectly match the Gemini API's OpenAPI schema requirements for the `parameters` block. This requires careful validation and mapping of Elixir types to JSON Schema types.

*   **Sub-Task 1.2: Advanced Response Deserialization & Validation.**
    *   **Challenge:** The API's response is not a simple `%{function_calls: [...]}`. The `functionCall` is a *type of part* within the `content` block of a `candidate`. The parsing logic must be sophisticated enough to handle multi-part content where one part is text and another is a function call.
    *   **Detailed Action:**
        1.  Modify the `parse_part` function (likely in `Gemini.Generate` or a response parsing module). It currently handles `text` and `inlineData`. It must now handle a `functionCall` key.
        2.  When a `functionCall` part is found, its contents must be passed to `Altar.ADM.FunctionCall.new/1`.
        3.  **Crucially, what do you do if `Altar.ADM.FunctionCall.new/1` returns `{:error, reason}`?** The API sent us invalid data. The library must have a defined error handling strategy. **Decision:** It should probably return `{:error, %Gemini.Error{type: :invalid_response, message: "Model returned malformed FunctionCall: #{reason}"}}`. This is a non-trivial error path that must be implemented and tested.

*   **Sub-Task 1.3: Refactoring the `GenerateContentRequest` Builder.**
    *   **Challenge:** The existing request builders are optimized for simple text or multimodal content. Adding `tools` and `tool_config` requires significant refactoring.
    *   **Detailed Action:**
        1.  The `Gemini.Generate.build_generate_request/2` function needs to be updated.
        2.  It will now take the `:tools` option, map the list of `Altar.ADM.FunctionDeclaration`s through the new `Gemini.Types.Tool.to_api_map/1` serializer, and inject the resulting map list into the request payload.
        3.  It will do the same for `:tool_config`, serializing the `Altar.ADM.ToolConfig` struct into the required `%{functionCallingConfig: %{...}}` map.

---

#### **Stage 2: Manual Loop (The State Management Nightmare)**

This stage introduces the complexity of managing the conversational history correctly.

*   **Sub-Task 2.1: The `Gemini.Tools` Module - A Stateful Facade?**
    *   **Challenge:** Should this module just be a collection of helper functions, or should it be a stateful process that encapsulates the `Registry` and the conversation history?
    *   **Decision:** For the manual loop, it should be stateless helpers. But this foreshadows the need for a stateful "session" or "chat" object.

*   **Sub-Task 2.2: The Immutable History Problem.**
    *   **Challenge:** The core of the tool calling loop is appending turns to the history. Each API call requires the *entire previous history*. If handled improperly, this can be inefficient and error-prone.
    *   **Detailed Action:**
        1.  Create a formal `Gemini.Chat` struct or module. Currently, the chat functionality in `Gemini.Generate` is a simple map. This needs to be formalized.
        2.  The `Gemini.Chat` struct will hold `history: [Gemini.Types.Content.t()]` and all other relevant configs.
        3.  Create functions like `Gemini.Chat.add_user_turn(chat, message)`, `Gemini.Chat.add_model_function_call_turn(chat, function_calls)`, and `Gemini.Chat.add_user_function_response_turn(chat, tool_results)`. These functions will return a **new, updated chat struct**, preserving immutability.
        4.  This makes the manual loop more robust: `chat |> Gemini.Chat.add_user_turn(...) |> Gemini.generate_content() |> ...`

*   **Sub-Task 2.3: `Content.from_tool_results` - The Other Serializer.**
    *   **Challenge:** Just like serializing the tool *declarations*, serializing the tool *results* into a `FunctionResponse` part is a complex mapping task.
    *   **Detailed Action:**
        1.  The `Content.from_tool_results` function needs to take a list of `Altar.ADM.ToolResult` structs.
        2.  For each result, it must create a map that matches the API spec: `%{functionResponse: %{name: result.name, response: %{content: result.content}}}`. Note the nested `response` and `content` keys. This must be exact.
        3.  All results for a single turn must be aggregated into a single `Content` part with a list of `functionResponse` parts.

---

#### **Stage 3: Automatic Loop (The Concurrency & State Challenge)**

This is where the true difficulty lies, especially with streaming.

*   **Sub-Task 3.1: The Orchestrator - GenServer or Process?**
    *   **Challenge:** How do you manage the state of a single, multi-turn "automatic" call? A simple recursive function call might work for non-streaming, but for streaming and timeouts, a dedicated process is far more robust.
    *   **Decision:** Each call to `Gemini.generate_content(..., auto_execute_tools: true)` should probably spawn a temporary GenServer or a process managed by a `Task.Supervisor`. This process will manage the state machine (AWAITING_MODEL_RESPONSE, EXECUTING_TOOLS, AWAITING_FINAL_RESPONSE) for that specific request.

*   **Sub-Task 3.2: The Streaming Nightmare Re-architected.**
    *   **Challenge:** The current `UnifiedManager` is designed for a single, linear stream from the server to the client. The automatic tool loop requires a **request -> response -> process -> request -> response** flow, all while maintaining a single "stream" to the end user.
    *   **Detailed Action (This is a major undertaking):**
        1.  A new type of "Orchestrator" process is needed, spawned by the `UnifiedManager`.
        2.  When a stream starts in auto-tool mode, the `UnifiedManager` delegates to this new Orchestrator.
        3.  The Orchestrator makes the first streaming request. It buffers events internally but does *not* send them to the user yet.
        4.  When it detects a `FunctionCall` from the model's stream, it stops processing events from that stream.
        5.  It then invokes the `Altar.LATER.Executor`.
        6.  It then opens a **second, completely new streaming request** to the Gemini API, sending the `FunctionResponse`.
        7.  It then starts proxying the events from this *second* stream to the end-user who subscribed to the original stream.
    *   **Pitfalls:** How do you handle timeouts? What if the tool execution takes too long? What if the second stream request fails? What happens to errors from the first stream? This process needs to be incredibly fault-tolerant and requires careful management of multiple asynchronous states. It's a significant OTP design challenge.

This unpacked plan reveals that the initial high-level strategy was indeed too simplistic. The implementation requires deep consideration of serialization, deserialization, error handling, state management, and complex asynchronous orchestration. It is a significant but achievable engineering effort that will transform `gemini_ex` into a best-in-class client library.
