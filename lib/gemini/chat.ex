defmodule Gemini.Chat do
  @moduledoc """
  Formalized chat session management with immutable history updates.

  This module provides a robust, immutable approach to managing multi-turn
  conversations with the Gemini API, including proper handling of tool-calling
  turns with function calls and responses.

  ## Usage

      # Create a new chat session
      chat = Gemini.Chat.new(model: "gemini-flash-lite-latest", temperature: 0.7)

      # Add turns to the conversation
      chat = chat
      |> Gemini.Chat.add_turn("user", "What's the weather like?")
      |> Gemini.Chat.add_turn("model", [%Altar.ADM.FunctionCall{...}])
      |> Gemini.Chat.add_turn("user", [%Altar.ADM.ToolResult{...}])
      |> Gemini.Chat.add_turn("model", "Based on the weather data...")

      # Generate content with the chat history
      {:ok, response} = Gemini.generate_content(chat.history, chat.opts)
  """

  alias Gemini.Types.Content
  alias Altar.ADM.{FunctionCall, ToolResult}

  @typedoc """
  A chat session containing conversation history and configuration options.
  """
  @type t :: %__MODULE__{
          history: [Content.t()],
          opts: keyword()
        }

  defstruct history: [], opts: []

  @doc """
  Create a new chat session with optional configuration.

  ## Options

  All standard Gemini API options are supported:
  - `:model` - Model name (defaults to configured default)
  - `:temperature` - Generation temperature (0.0-1.0)
  - `:max_output_tokens` - Maximum tokens to generate
  - `:generation_config` - Full GenerationConfig struct
  - `:safety_settings` - List of SafetySetting structs
  - `:system_instruction` - System instruction content
  - And more...

  ## Examples

      chat = Gemini.Chat.new()
      chat = Gemini.Chat.new(model: "gemini-2.5-pro", temperature: 0.3)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) when is_list(opts) do
    %__MODULE__{history: [], opts: opts}
  end

  @doc """
  Add a turn to the chat history.

  This function handles different types of content based on the role and message type:

  - User text messages: `add_turn(chat, "user", "Hello")`
  - Model text responses: `add_turn(chat, "model", "Hi there!")`
  - Model function calls: `add_turn(chat, "model", [%FunctionCall{...}])`
  - User function responses: `add_turn(chat, "user", [%ToolResult{...}])`

  Returns a new chat struct with the updated history, preserving immutability.
  """
  @spec add_turn(t(), String.t(), String.t() | [map()] | [FunctionCall.t()] | [ToolResult.t()]) ::
          t()
  def add_turn(%__MODULE__{} = chat, role, message) when role in ["user", "model", "tool"] do
    content = build_content(role, message)
    %{chat | history: chat.history ++ [content]}
  end

  # Build Content struct based on role and message type
  defp build_content("user", message) when is_binary(message) do
    Content.text(message, "user")
  end

  defp build_content("model", message) when is_binary(message) do
    Content.text(message, "model")
  end

  defp build_content("model", function_calls) when is_list(function_calls) do
    # Handle model's function call turn
    parts =
      Enum.map(function_calls, fn %FunctionCall{} = call ->
        %{
          function_call: %{
            name: call.name,
            args: call.args
          }
        }
      end)

    %Content{role: "model", parts: parts}
  end

  defp build_content("tool", tool_results) when is_list(tool_results) do
    # Handle tool's function response turn using the Content helper
    Content.from_tool_results(tool_results)
  end

  defp build_content(role, parts) when is_list(parts) do
    # Handle generic parts list
    %Content{role: role, parts: parts}
  end
end
