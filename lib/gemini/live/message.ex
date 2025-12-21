defmodule Gemini.Live.Message do
  @moduledoc """
  Message types for Gemini Live API WebSocket communication.

  This module defines the structure of messages sent to and received from
  the Gemini Live API WebSocket endpoint.

  ## Message Flow

  1. Client sends `setup` message to configure the session
  2. Server responds with `setupComplete`
  3. Client sends content via `clientContent` or `realtimeInput`
  4. Server responds with `serverContent` containing model responses
  5. Client can send `toolResponse` to respond to function calls

  ## Example

      # Setup message
      setup = %ClientMessage{
        setup: %LiveClientSetup{
          model: "gemini-2.5-flash",
          generation_config: %{temperature: 0.8}
        }
      }

      # Client content message
      content = %ClientMessage{
        client_content: %{
          turns: [%{role: "user", parts: [%{text: "Hello!"}]}],
          turn_complete: true
        }
      }
  """

  use TypedStruct

  alias Gemini.Types.{GenerationConfig, Content}

  # Client-to-Server Messages

  typedstruct module: LiveClientSetup do
    @moduledoc """
    Setup message sent by client to initialize the session.

    ## Fields

    - `model`: Model identifier (required)
    - `generation_config`: Generation parameters
    - `system_instruction`: System instruction
    - `tools`: Available tools/functions
    - `tool_config`: Tool configuration
    """

    field(:model, String.t(), enforce: true)
    field(:generation_config, GenerationConfig.t() | map())
    field(:system_instruction, String.t() | Content.t() | map())
    field(:tools, [map()])
    field(:tool_config, map())
  end

  typedstruct module: ClientContent do
    @moduledoc """
    Content message sent by client.

    ## Fields

    - `turns`: List of conversation turns
    - `turn_complete`: Whether the turn is complete
    """

    field(:turns, [Content.t() | map()], default: [])
    field(:turn_complete, boolean(), default: false)
  end

  typedstruct module: RealtimeInput do
    @moduledoc """
    Real-time input (audio/video) sent by client.

    ## Fields

    - `media_chunks`: List of media chunks (audio/video data)
    """

    field(:media_chunks, [map()], default: [])
  end

  typedstruct module: ToolResponse do
    @moduledoc """
    Tool/function response sent by client.

    ## Fields

    - `function_responses`: List of function call responses
    """

    field(:function_responses, [map()], default: [])
  end

  typedstruct module: ClientMessage do
    @moduledoc """
    Union type for all client-to-server messages.

    Exactly one field should be set.

    ## Fields

    - `setup`: Session setup message
    - `client_content`: Content message
    - `realtime_input`: Real-time media input
    - `tool_response`: Tool/function response
    """

    field(:setup, LiveClientSetup.t())
    field(:client_content, ClientContent.t() | map())
    field(:realtime_input, RealtimeInput.t() | map())
    field(:tool_response, ToolResponse.t() | map())
  end

  # Server-to-Client Messages

  typedstruct module: SetupComplete do
    @moduledoc """
    Setup completion confirmation from server.
    """

    field(:message, String.t(), default: "Setup complete")
  end

  typedstruct module: ServerContent do
    @moduledoc """
    Content response from server.

    ## Fields

    - `model_turn`: Model's response turn
    - `turn_complete`: Whether the turn is complete
    - `grounding_metadata`: Grounding metadata if applicable
    """

    field(:model_turn, Content.t() | map())
    field(:turn_complete, boolean(), default: false)
    field(:grounding_metadata, map())
  end

  typedstruct module: ToolCall do
    @moduledoc """
    Tool/function call request from server.

    ## Fields

    - `function_calls`: List of function calls to execute
    """

    field(:function_calls, [map()], default: [])
  end

  typedstruct module: ToolCallCancellation do
    @moduledoc """
    Tool call cancellation from server.

    ## Fields

    - `ids`: List of function call IDs to cancel
    """

    field(:ids, [String.t()], default: [])
  end

  typedstruct module: ServerMessage do
    @moduledoc """
    Union type for all server-to-client messages.

    ## Fields

    - `setup_complete`: Setup confirmation
    - `server_content`: Content response
    - `tool_call`: Function call request
    - `tool_call_cancellation`: Function call cancellation
    """

    field(:setup_complete, SetupComplete.t() | map())
    field(:server_content, ServerContent.t() | map())
    field(:tool_call, ToolCall.t() | map())
    field(:tool_call_cancellation, ToolCallCancellation.t() | map())
  end

  # API Conversion Helpers

  @doc """
  Convert ClientMessage to JSON for WebSocket transmission.
  """
  @spec to_json(ClientMessage.t()) :: {:ok, String.t()} | {:error, term()}
  def to_json(%ClientMessage{} = message) do
    api_map = to_api_map(message)
    Jason.encode(api_map)
  end

  @doc """
  Convert ClientMessage to API map format.
  """
  @spec to_api_map(ClientMessage.t()) :: map()
  def to_api_map(%ClientMessage{setup: setup}) when not is_nil(setup) do
    %{setup: setup_to_api(setup)}
  end

  def to_api_map(%ClientMessage{client_content: content}) when not is_nil(content) do
    %{clientContent: content_to_api(content)}
  end

  def to_api_map(%ClientMessage{realtime_input: input}) when not is_nil(input) do
    %{realtimeInput: realtime_input_to_api(input)}
  end

  def to_api_map(%ClientMessage{tool_response: response}) when not is_nil(response) do
    %{toolResponse: tool_response_to_api(response)}
  end

  def to_api_map(%ClientMessage{}) do
    raise ArgumentError, "ClientMessage must have exactly one field set"
  end

  @doc """
  Parse JSON from WebSocket into ServerMessage.
  """
  @spec from_json(String.t()) :: {:ok, ServerMessage.t()} | {:error, term()}
  def from_json(json) when is_binary(json) do
    with {:ok, data} <- Jason.decode(json) do
      {:ok, from_api_map(data)}
    end
  end

  @doc """
  Convert API map to ServerMessage struct.
  """
  @spec from_api_map(map()) :: ServerMessage.t()
  def from_api_map(data) when is_map(data) do
    message = %ServerMessage{}

    message =
      if Map.has_key?(data, "setupComplete") or Map.has_key?(data, :setupComplete) do
        %{message | setup_complete: %SetupComplete{}}
      else
        message
      end

    message =
      if Map.has_key?(data, "serverContent") or Map.has_key?(data, :serverContent) do
        content = Map.get(data, "serverContent") || Map.get(data, :serverContent)
        %{message | server_content: content}
      else
        message
      end

    message =
      if Map.has_key?(data, "toolCall") or Map.has_key?(data, :toolCall) do
        tool_call = Map.get(data, "toolCall") || Map.get(data, :toolCall)
        %{message | tool_call: tool_call}
      else
        message
      end

    message =
      if Map.has_key?(data, "toolCallCancellation") or Map.has_key?(data, :toolCallCancellation) do
        cancellation =
          Map.get(data, "toolCallCancellation") || Map.get(data, :toolCallCancellation)

        %{message | tool_call_cancellation: cancellation}
      else
        message
      end

    message
  end

  # Private helpers

  defp setup_to_api(%LiveClientSetup{} = setup) do
    api = %{model: setup.model}

    api =
      if setup.generation_config do
        Map.put(api, :generationConfig, setup.generation_config)
      else
        api
      end

    api =
      if setup.system_instruction do
        Map.put(api, :systemInstruction, format_system_instruction(setup.system_instruction))
      else
        api
      end

    api =
      if setup.tools do
        Map.put(api, :tools, setup.tools)
      else
        api
      end

    api =
      if setup.tool_config do
        Map.put(api, :toolConfig, setup.tool_config)
      else
        api
      end

    api
  end

  defp content_to_api(%ClientContent{} = content) do
    %{
      turns: content.turns,
      turnComplete: content.turn_complete
    }
  end

  defp content_to_api(content) when is_map(content), do: content

  defp realtime_input_to_api(%RealtimeInput{} = input) do
    %{mediaChunks: input.media_chunks}
  end

  defp realtime_input_to_api(input) when is_map(input), do: input

  defp tool_response_to_api(%ToolResponse{} = response) do
    %{functionResponses: response.function_responses}
  end

  defp tool_response_to_api(response) when is_map(response), do: response

  defp format_system_instruction(text) when is_binary(text) do
    %{parts: [%{text: text}]}
  end

  defp format_system_instruction(%Content{} = content) do
    %{
      role: content.role,
      parts: Enum.map(content.parts, &format_part/1)
    }
  end

  defp format_system_instruction(other), do: other

  defp format_part(%{text: text}), do: %{text: text}
  defp format_part(part), do: part
end
