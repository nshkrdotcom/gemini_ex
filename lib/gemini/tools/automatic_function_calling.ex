defmodule Gemini.Tools.AutomaticFunctionCalling do
  @moduledoc """
  Implements the Automatic Function Calling (AFC) loop for Gemini.

  AFC automatically executes function calls from Gemini responses and continues
  the conversation until no more function calls are needed or limits are reached.

  ## How It Works

  1. Send initial request to Gemini with tools defined
  2. Check if response contains function calls
  3. If yes, execute function calls against the registry
  4. Build function response content
  5. Send new request with function results
  6. Repeat until no more function calls or max_calls reached

  ## Configuration

  Use `config/1` to create an AFC configuration:

      config = AFC.config(
        max_calls: 10,           # Maximum function calls before stopping
        ignore_call_history: false,  # Whether to track call history
        enabled: true            # Enable/disable AFC
      )

  ## Usage with Coordinator

  AFC is typically used through the high-level API:

      # Define tools
      tools = [
        %FunctionDeclaration{
          name: "get_weather",
          description: "Get current weather",
          parameters: %{type: "object", properties: %{"location" => %{type: "string"}}}
        }
      ]

      # Define registry
      registry = %{
        "get_weather" => fn args -> WeatherService.get(args["location"]) end
      }

      # Generate with AFC
      {:ok, response} = Gemini.generate(
        "What's the weather in NYC?",
        tools: tools,
        auto_execute_tools: true,
        tool_registry: registry
      )

  ## Manual AFC Loop

  For more control, you can use the AFC functions directly:

      response = initial_response
      history = []
      call_count = 0
      config = AFC.config(max_calls: 5)

      {final_response, call_count, history} =
        AFC.loop(response, contents, registry, config, call_count, history, generate_fn)

  """

  alias Altar.ADM.FunctionCall
  alias Gemini.Tools.Executor
  alias Gemini.Types.FunctionResponse

  defmodule Config do
    @moduledoc """
    Configuration for automatic function calling.
    """

    use TypedStruct

    typedstruct do
      @typedoc "AFC configuration"
      field(:max_calls, non_neg_integer(), default: 10)
      field(:ignore_call_history, boolean(), default: false)
      field(:enabled, boolean(), default: true)
      field(:parallel_execution, boolean(), default: false)
    end
  end

  @type config :: Config.t()
  @type call_history :: [FunctionCall.t()]
  @type generate_fn :: (list(), keyword() -> {:ok, map()} | {:error, term()})

  @doc """
  Create an AFC configuration.

  ## Options

  - `:max_calls` - Maximum number of function calls to execute (default: 10)
  - `:ignore_call_history` - If true, don't track call history (default: false)
  - `:enabled` - Enable or disable AFC (default: true)
  - `:parallel_execution` - Execute multiple calls in parallel (default: false)

  ## Examples

      # Default configuration
      config = AFC.config()

      # Custom configuration
      config = AFC.config(max_calls: 5, parallel_execution: true)

      # Disable AFC
      config = AFC.config(enabled: false)
  """
  @spec config(keyword()) :: Config.t()
  def config(opts \\ []) do
    %Config{
      max_calls: Keyword.get(opts, :max_calls, 10),
      ignore_call_history: Keyword.get(opts, :ignore_call_history, false),
      enabled: Keyword.get(opts, :enabled, true),
      parallel_execution: Keyword.get(opts, :parallel_execution, false)
    }
  end

  @doc """
  Extract function calls from a Gemini API response.

  ## Parameters

  - `response`: Raw API response map or GenerateContentResponse struct

  ## Returns

  List of `FunctionCall` structs.

  ## Examples

      calls = AFC.extract_function_calls(response)
      [%FunctionCall{name: "get_weather", args: %{"location" => "NYC"}}] = calls
  """
  @spec extract_function_calls(map()) :: [FunctionCall.t()]
  def extract_function_calls(response) do
    candidates = get_candidates(response)

    candidates
    |> Enum.flat_map(&extract_calls_from_candidate/1)
    |> Enum.with_index()
    |> Enum.map(fn {call_data, idx} ->
      {:ok, call} =
        FunctionCall.new(
          call_id: Map.get(call_data, "id") || "call_#{idx}",
          name: Map.get(call_data, "name"),
          args: Map.get(call_data, "args", %{})
        )

      call
    end)
  end

  defp get_candidates(%Gemini.Types.Response.GenerateContentResponse{candidates: candidates}),
    do: candidates || []

  defp get_candidates(%{"candidates" => candidates}) when is_list(candidates), do: candidates
  defp get_candidates(_), do: []

  defp extract_calls_from_candidate(%{content: %{parts: parts}}) when is_list(parts) do
    Enum.flat_map(parts, &extract_function_call_from_part/1)
  end

  defp extract_calls_from_candidate(%{"content" => %{"parts" => parts}}) when is_list(parts) do
    Enum.flat_map(parts, &extract_function_call_from_part/1)
  end

  defp extract_calls_from_candidate(_), do: []

  # Handle Gemini.Types.Part struct with function_call field
  defp extract_function_call_from_part(%Gemini.Types.Part{function_call: call})
       when is_map(call) and call != nil,
       do: [call]

  # Handle raw maps with camelCase key (from raw API response)
  defp extract_function_call_from_part(%{"functionCall" => call}) when is_map(call), do: [call]
  # Handle raw maps with atom key
  defp extract_function_call_from_part(%{functionCall: call}) when is_map(call), do: [call]
  # Handle raw maps with snake_case atom key
  defp extract_function_call_from_part(%{function_call: call}) when is_map(call) and call != nil,
    do: [call]

  defp extract_function_call_from_part(_), do: []

  @doc """
  Check if a response contains function calls.

  ## Examples

      if AFC.has_function_calls?(response) do
        # Handle function calls
      end
  """
  @spec has_function_calls?(map()) :: boolean()
  def has_function_calls?(response) do
    extract_function_calls(response) != []
  end

  @doc """
  Determine if the AFC loop should continue.

  Returns true if:
  - AFC is enabled
  - Response contains function calls
  - Call count is below max_calls limit

  ## Parameters

  - `response`: The current Gemini response
  - `config`: AFC configuration
  - `call_count`: Current number of executed calls

  ## Examples

      if AFC.should_continue?(response, config, call_count) do
        # Continue AFC loop
      end
  """
  @spec should_continue?(map(), Config.t(), non_neg_integer()) :: boolean()
  def should_continue?(response, %Config{} = config, call_count) do
    config.enabled &&
      call_count < config.max_calls &&
      has_function_calls?(response)
  end

  @doc """
  Build content containing function responses for the API.

  ## Parameters

  - `calls`: List of executed FunctionCall structs
  - `results`: List of execution results from Executor

  ## Returns

  A content map with role "function" and function response parts.
  """
  @spec build_function_response_content([FunctionCall.t()], [Executor.execution_result()]) ::
          map()
  def build_function_response_content(calls, results) do
    responses = Executor.build_responses(calls, results)

    parts =
      Enum.map(responses, fn response ->
        %{
          "functionResponse" => FunctionResponse.to_api(response)
        }
      end)

    %{
      role: "function",
      parts: parts
    }
  end

  @doc """
  Extract model content from a response in API-compatible format.

  This is useful for multi-turn conversations where you need to include
  the model's response (including function calls) in the conversation history.

  ## Parameters

  - `response`: A GenerateContentResponse struct or raw API response map

  ## Returns

  A map with `role: "model"` and `parts` in API format (camelCase keys).

  ## Examples

      # Get model content for conversation history
      model_content = AFC.extract_model_content_for_api(response)
      contents = [user_content, model_content, function_response_content]
  """
  @spec extract_model_content_for_api(map()) :: map()
  def extract_model_content_for_api(response), do: extract_model_content(response)

  @doc """
  Track function call history.

  ## Parameters

  - `history`: Current call history
  - `calls`: New calls to add

  ## Returns

  Updated history with new calls appended.
  """
  @spec track_history(call_history(), [FunctionCall.t()]) :: call_history()
  def track_history(history, calls) do
    history ++ calls
  end

  @doc """
  Execute the AFC loop.

  This is the main entry point for automatic function calling. It:
  1. Checks if response contains function calls
  2. Executes them against the registry
  3. Builds function response content
  4. Calls the generate function with updated contents
  5. Repeats until done or limits reached

  ## Parameters

  - `response`: Initial Gemini response
  - `contents`: Current conversation contents
  - `registry`: Function registry map
  - `config`: AFC configuration
  - `call_count`: Current call count (usually 0)
  - `history`: Call history (usually [])
  - `generate_fn`: Function to call Gemini API

  ## Returns

  `{final_response, final_call_count, final_history}`

  ## Examples

      generate_fn = fn contents, opts ->
        Gemini.APIs.Coordinator.generate_content(contents, opts)
      end

      {response, call_count, history} =
        AFC.loop(initial_response, contents, registry, config, 0, [], generate_fn)
  """
  @spec loop(
          map(),
          list(),
          Executor.function_registry(),
          Config.t(),
          non_neg_integer(),
          call_history(),
          generate_fn(),
          keyword()
        ) ::
          {map(), non_neg_integer(), call_history()}
  def loop(response, contents, registry, config, call_count, history, generate_fn, opts \\ [])

  def loop(response, _contents, _registry, config, call_count, history, _generate_fn, _opts)
      when not config.enabled do
    {response, call_count, history}
  end

  def loop(response, contents, registry, config, call_count, history, generate_fn, opts) do
    if should_continue?(response, config, call_count) do
      # Extract function calls
      calls = extract_function_calls(response)

      # Execute functions
      results =
        if config.parallel_execution do
          Executor.execute_all_parallel(calls, registry)
        else
          Executor.execute_all(calls, registry)
        end

      # Build function response content
      function_response_content = build_function_response_content(calls, results)

      # Extract model response content for conversation context
      model_content = extract_model_content(response)

      # Update contents with model response and function results
      updated_contents = contents ++ [model_content, function_response_content]

      # Update tracking
      new_call_count = call_count + length(calls)

      new_history =
        if config.ignore_call_history do
          history
        else
          track_history(history, calls)
        end

      # Make next API call
      case generate_fn.(updated_contents, opts) do
        {:ok, new_response} ->
          # Recurse
          loop(
            new_response,
            updated_contents,
            registry,
            config,
            new_call_count,
            new_history,
            generate_fn,
            opts
          )

        {:error, _} = error ->
          # Return error response
          {error, new_call_count, new_history}
      end
    else
      # No more function calls or limits reached
      {response, call_count, history}
    end
  end

  # Extract model content from response for conversation history
  defp extract_model_content(%Gemini.Types.Response.GenerateContentResponse{
         candidates: [first | _]
       }) do
    parts = first.content.parts || []

    %{
      role: "model",
      parts: Enum.map(parts, &part_to_api/1)
    }
  end

  defp extract_model_content(%{"candidates" => [%{"content" => content} | _]}) do
    %{
      role: "model",
      parts: Map.get(content, "parts", [])
    }
  end

  defp extract_model_content(_), do: %{role: "model", parts: []}

  # Convert a Part struct to API format for sending back to the API
  defp part_to_api(%Gemini.Types.Part{} = part) do
    result = %{}

    result =
      if part.text do
        Map.put(result, "text", part.text)
      else
        result
      end

    result =
      if part.function_call do
        Map.put(result, "functionCall", part.function_call)
      else
        result
      end

    result =
      if part.function_response do
        Map.put(result, "functionResponse", part.function_response)
      else
        result
      end

    result =
      if part.inline_data do
        Map.put(result, "inlineData", inline_data_to_api(part.inline_data))
      else
        result
      end

    result
  end

  # Pass through raw maps as-is
  defp part_to_api(part) when is_map(part), do: part

  defp inline_data_to_api(%Gemini.Types.Blob{} = blob) do
    %{"data" => blob.data, "mimeType" => blob.mime_type}
  end

  defp inline_data_to_api(other), do: other
end
