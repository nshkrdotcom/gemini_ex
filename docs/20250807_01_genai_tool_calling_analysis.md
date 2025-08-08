### **Full Requirements for Canonical Gemini Tool Calling**

The Gemini tool calling functionality can be broken down into four main areas:

1.  **Tool & Function Declaration:** How tools are defined and presented to the model.
2.  **Tool Configuration & Execution Control:** How the user tells the model *how* and *if* to use the tools.
3.  **The Core Interaction Loop:** The turn-by-turn data flow between the client, the model, and the tools.
4.  **Automatic Function Calling (Advanced):** The SDK's ability to orchestrate the loop automatically.

---

#### **1. Tool & Function Declaration Requirements**

This is about defining the API of your tools so the model can understand them.

*   **1.1. `FunctionDeclaration`:**
    *   **Structure:** Must contain `name`, `description`, and `parameters`.
    *   **Parameters Schema:** The `parameters` field must be a valid **OpenAPI 3.0 Schema Object**. This is a critical requirement. It defines the arguments for the function, their types (`string`, `number`, `integer`, `object`, `array`, `boolean`), format, and which are required.
    *   **Serialization:** The entire declaration must be serializable into the exact JSON structure the Gemini API expects.

*   **1.2. `Tool` Object:**
    *   **Structure:** A `Tool` is fundamentally a container for a list of `FunctionDeclaration`s. The Python SDK abstracts this, but at the API level, you send a `Tool` object that contains a `function_declarations` list. A `gemini_ex` implementation must ultimately construct this structure.

*   **1.3. Multiple Tool Sources (High-Level Requirement):**
    *   The Python SDK allows tools to be defined from multiple sources and intelligently converts them into the required `FunctionDeclaration` format. A canonical implementation must support:
        *   **Python Functions:** Introspecting a standard Python function (its name, docstring, and type hints) to automatically generate a `FunctionDeclaration`. This is a major ergonomic feature.
        *   **Pydantic Models:** Using a Pydantic model to define the schema for function arguments.
        *   **Manual Dictionaries/Objects:** Allowing the user to provide a raw `FunctionDeclaration` as a dictionary or object if they need full control.

---

#### **2. Tool Configuration & Execution Control Requirements**

This area defines how the user controls the tool-calling behavior for a specific `generate_content` call.

*   **2.1. `ToolConfig` Object:**
    *   **Structure:** A `ToolConfig` object must contain a `function_calling_config`.
    *   **`FunctionCallingConfig` Structure:** This is the core of the control mechanism and has two fields:
        *   `mode`: An enum that must support three states:
            *   **`AUTO` (Default):** The model decides whether to call a function or respond with text. This is the standard mode for chat agents.
            *   **`ANY`:** The model is **forced** to call a function. It cannot respond with text directly. This is useful for "router" or "dispatcher" type agents.
            *   **`NONE`:** The model is forbidden from calling any functions and will behave as if no tools were provided.
        *   `allowed_function_names`: An optional list of function names. When `mode` is `ANY`, this constrains the model's choice to only the functions in this list.

---

#### **3. The Core Interaction Loop Requirements**

This is the stateful, turn-by-turn process of a tool-calling conversation.

*   **3.1. User to Model (First Turn):**
    *   The client sends a `contents` list (the user's prompt), a `tools` list (containing the `FunctionDeclaration`s), and an optional `tool_config`.

*   **3.2. Model to User (Function Call):**
    *   The model's response (`GenerateContentResponse`) will **not** contain text in the main `parts`.
    *   Instead, it will contain one or more `FunctionCall` objects.
    *   Each `FunctionCall` object must contain:
        *   `name`: The name of the function to be called.
        *   `args`: A dictionary of arguments, with keys and values matching the `parameters` schema of the corresponding `FunctionDeclaration`.

*   **3.3. User to Model (Function Response):**
    *   The client is now responsible for executing the functions with the provided arguments.
    *   After execution, the client must send a **new** request to the `generate_content` endpoint.
    *   This new request must include the *entire previous chat history*, plus a new `Content` part containing a `FunctionResponse`.
    *   The `FunctionResponse` object must contain:
        *   `name`: The name of the function that was called.
        *   `response`: A dictionary containing the return value of the function. The key is typically `"content"` or `"result"`, and the value is the function's output, which must be JSON-serializable.

*   **3.4. Model to User (Final Answer):**
    *   After receiving the `FunctionResponse`, the model processes the tool's output and generates a final, natural-language response to the user's original query. This response will contain text.

---

#### **4. Automatic Function Calling Requirements (The "Magic" Loop)**

The Python SDK provides a high-level "automatic function calling" feature that handles the entire loop described in section 3. This is a significant ergonomic feature that `gemini_ex` should aim to replicate.

*   **4.1. Function Mapping:** The user must provide a mapping from function names (strings) to the actual, callable Python functions.

*   **4.2. Loop Orchestration:** When automatic mode is enabled, the `generate_content` method must internally:
    1.  Send the initial request.
    2.  Check the response. If it contains `FunctionCall`s, proceed.
    3.  Look up the corresponding real functions in the user-provided map.
    4.  Execute those functions with the arguments provided by the model.
    5.  Catch any exceptions during execution and format them as an error response.
    6.  Construct the required `FunctionResponse` parts.
    7.  Append the `FunctionCall` from the model and the `FunctionResponse` from the client to the conversation history.
    8.  **Automatically send a second request** to the API with this updated history.
    9.  Return the final text response from this second call to the user, hiding the intermediate tool-calling steps.

*   **4.3. Streaming Support:** This automatic loop must also work in streaming mode. It should handle the function call, execute it, and then begin streaming the final text response from the second API call.

This detailed map covers the full scope of requirements. The next step is to strategize how to build this on top of the solid foundation that `LATER` provides.
