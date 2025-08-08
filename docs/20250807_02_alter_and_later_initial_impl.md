After a thorough analysis of the `gemini_ex` codebase and the canonical requirements for Gemini tool calling, I have formulated a detailed, staged implementation plan.

This plan is designed to be **incremental, logical, and safe.** It builds functionality layer by layer, starting with the foundational data structures and progressively adding more complex logic, all while leveraging the excellent `ALTAR`/`LATER` architecture we have already designed.

### **Analysis of `gemini_ex` Codebase**

The existing `gemini_ex` library is mature, well-structured, and robust. Key strengths include:
*   **Strong Type System:** Excellent use of `TypedStruct` and well-defined request/response types.
*   **Unified Coordinator:** The `Gemini.APIs.Coordinator` provides a perfect central point for injecting new functionality.
*   **Robust Streaming:** The `UnifiedManager` is a production-grade GenServer for managing streaming, which will be essential for streaming tool calls.
*   **Clean Architecture:** Good separation of concerns between APIs, Auth, Client, and Types.

The plan will integrate with this existing architecture, not fight against it.

---

### **Staged Implementation Plan: Gemini Tool Calling**

This plan is broken into three main stages. Each stage builds upon the last and results in a testable, functional deliverable.

#### **Stage 1: Foundational Integration (`ADM` & API Payloads)**

**Goal:** Integrate the `ALTAR` Data Model (`ADM`) into `gemini_ex` and ensure the core `generate_content` API call can correctly serialize tool declarations and configurations into the JSON payload. This stage does *not* involve any execution logic.

*   **Action 1.1: Add `altar` as a Dependency.**
    *   In `mix.exs`, add `{:altar, "~> 0.1.0"}` to the dependencies. This makes the `Altar.ADM` structs available.

*   **Action 1.2: Update Request & Response Types.**
    *   **Modify `Gemini.Types.Request.GenerateContentRequest`:** Add `tools` and `tool_config` fields.
        *   `tools`: `[Altar.ADM.FunctionDeclaration.t()]` (or a new `Altar.ADM.Tool.t()` struct if we create one).
        *   `tool_config`: `Altar.ADM.ToolConfig.t() | nil`.
    *   **Modify `Gemini.Types.Response.GenerateContentResponse` & `Candidate`:**
        *   The API returns `function_calls` inside a `Part` struct. We need to update the response parsing logic to recognize and decode this.
        *   Add a `function_calls` field to `Gemini.Types.Part`, e.g., `field(:function_calls, [Altar.ADM.FunctionCall.t()] | nil)`.
        *   Update the response parser (`parse_candidate` / `parse_part`) to handle the `functionCall` key from the API's JSON response and correctly deserialize it into validated `Altar.ADM.FunctionCall` structs.

*   **Action 1.3: Update API Payload Construction.**
    *   **Modify `Gemini.APIs.Coordinator.build_generate_request/2`** (and/or `Gemini.Generate.build_generate_request/2`).
    *   This function must be updated to correctly handle the new `:tools` and `:tool_config` options.
    *   It needs to serialize the `Altar.ADM` structs into the precise `camelCase` JSON format the Gemini API expects. This will involve creating a `to_json_map/1` function for each `ADM` struct.

*   **Deliverable for Stage 1:**
    *   The `Gemini.generate_content/2` function can now accept `:tools` and `:tool_config` options with `Altar.ADM` structs.
    *   The library can make a successful API call and receive a response containing `FunctionCall`s, parsing them correctly into `Altar.ADM.FunctionCall` structs.
    *   **We can now write tests to prove that the library can *request* a function call and *parse* the model's response.**

---

#### **Stage 2: Manual Tool Execution Loop**

**Goal:** Enable developers to manually perform the tool-calling loop. This stage empowers the user to handle execution themselves, using the `LATER` runtime as a helper.

*   **Action 2.1: Introduce `Altar.LATER` Components.**
    *   The project will now depend on the `Registry` and `Executor` from `altar`. We will need to decide if `gemini_ex` should start its own named `Registry` process in its supervision tree or require the user to manage it. **Recommendation:** For simplicity, `gemini_ex` should start and supervise its own `Altar.LATER.Registry` instance.

*   **Action 2.2: Create a High-Level `Gemini.Tools` Module.**
    *   This new module will be the main entry point for tool-related functionality.
    *   `Gemini.Tools.register(declaration, fun)`: A convenience wrapper around `Altar.LATER.Registry.register_tool/3`.
    *   `Gemini.Tools.execute_calls(function_calls)`: A function that takes a list of `%FunctionCall{}` structs (from a `GenerateContentResponse`) and uses `Altar.LATER.Executor` to execute them, returning a list of `%ToolResult{}`s.

*   **Action 2.3: Implement the `FunctionResponse` Turn.**
    *   The Gemini API requires the `ToolResult`s to be sent back in a new `Content` part with a specific format.
    *   Create a new helper function, e.g., `Gemini.Types.Content.from_tool_results(results)`, that takes a list of `%ToolResult{}`s and constructs the correct `%{parts: [%{function_response: ...}]}` structure.
    *   The main `generate_content` function must be able to accept this new `Content` type.

*   **Deliverable for Stage 2:**
    *   A developer can now fully implement the tool-calling loop:
        1.  Register tools with `Gemini.Tools.register/2`.
        2.  Call `Gemini.generate_content/2` with tools.
        3.  Receive a response with `function_calls`.
        4.  Pass these calls to `Gemini.Tools.execute_calls/1` to get `tool_results`.
        5.  Create a `FunctionResponse` `Content` part from the results.
        6.  Call `Gemini.generate_content/2` again with the updated history.
        7.  Receive the final text response.
    *   **We can now write a comprehensive integration test demonstrating this entire manual loop.**

---

#### **Stage 3: Automatic Tool Execution ("The Magic Loop")**

**Goal:** Replicate the Python SDK's high-level automatic function calling feature, hiding the complexity of the loop from the user.

*   **Action 3.1: Create a New Public API Function.**
    *   Introduce a new function, perhaps `Gemini.generate_content_with_tools/2` or `Gemini.generate_content(..., auto_execute_tools: true)`. This function will orchestrate the entire loop.

*   **Action 3.2: Implement the Orchestration Logic.**
    *   This function will be a state machine that:
        1.  Takes the user's prompt and a list of registered tools.
        2.  Calls the internal `generate_content` function.
        3.  Inspects the response.
            *   If it's a text response, return it immediately.
            *   If it contains `function_calls`, proceed.
        4.  Calls `Altar.LATER.Executor` to execute the functions.
        5.  Constructs the `FunctionResponse` part.
        6.  Appends the model's `FunctionCall` turn and the user's `FunctionResponse` turn to the conversation history.
        7.  **Recursively calls itself** or an internal helper with the updated history.
        8.  Returns the final text response to the user.

*   **Action 3.3: Integrate with Streaming.**
    *   This is the most complex part. The automatic loop needs to work with the `UnifiedManager`.
    *   The manager will need to be updated to handle the tool-calling state machine. When it receives a `FunctionCall` part in a stream, it must:
        1.  Pause the SSE connection to the client.
        2.  Execute the tool via the `Executor`.
        3.  Open a *new* streaming request to the Gemini API with the `FunctionResponse`.
        4.  Proxy the events from this *second* stream back to the original client.
    *   This requires careful state management within the `UnifiedManager` GenServer.

*   **Deliverable for Stage 3:**
    *   A user can simply provide a list of tools and a prompt, and the library will handle the entire back-and-forth conversation with the model and tools automatically.
    *   This "magic loop" works for both standard and streaming requests.
    *   The `gemini_ex` library now has feature parity with the official Python SDK's core tool-calling capabilities.
