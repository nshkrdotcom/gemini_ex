defmodule Gemini.Streaming.ToolOrchestrator do
  @moduledoc """
  GenServer responsible for managing a single, stateful, automatic tool-calling stream.

  This orchestrator handles the complex multi-stage streaming process:
  1. Starts the initial streaming HTTP request to the Gemini API
  2. Buffers and inspects incoming chunks for function calls
  3. When function calls are detected, stops the first stream and executes tools
  4. Starts a second streaming request with the complete history including tool results
  5. Proxies the final stream events to the original subscriber

  The orchestrator maintains state throughout this process and handles errors gracefully.
  """

  use GenServer
  require Logger

  alias Gemini.Client.HTTPStreaming
  alias Gemini.Auth.MultiAuthCoordinator
  alias Gemini.Chat
  alias Gemini.Tools
  alias Gemini.Types.Content

  @type orchestrator_state :: %{
          stream_id: String.t(),
          subscriber_pid: pid(),
          chat: Chat.t(),
          auth_strategy: :gemini | :vertex_ai,
          config: keyword(),
          phase: :awaiting_model_call | :executing_tools | :awaiting_final_response,
          first_stream_pid: pid() | nil,
          second_stream_pid: pid() | nil,
          buffered_chunks: [map()],
          turn_limit: non_neg_integer(),
          error: term() | nil
        }

  # Client API

  @doc """
  Start a new tool orchestrator for automatic streaming.

  ## Parameters
  - `stream_id`: Unique identifier for this stream
  - `subscriber_pid`: Process to receive final stream events
  - `chat`: Initial chat state with history and options
  - `auth_strategy`: Authentication strategy to use
  - `config`: Additional configuration options

  ## Returns
  - `{:ok, pid()}`: Orchestrator started successfully
  - `{:error, reason}`: Failed to start orchestrator
  """
  @spec start_link(String.t(), pid(), Chat.t(), :gemini | :vertex_ai, keyword()) ::
          GenServer.on_start()
  def start_link(stream_id, subscriber_pid, chat, auth_strategy, config) do
    GenServer.start_link(__MODULE__, {stream_id, subscriber_pid, chat, auth_strategy, config})
  end

  @doc """
  Subscribe an additional process to receive stream events.
  """
  @spec subscribe(pid(), pid()) :: :ok
  def subscribe(orchestrator_pid, subscriber_pid) do
    GenServer.cast(orchestrator_pid, {:subscribe, subscriber_pid})
  end

  @doc """
  Stop the orchestrator and all associated streams.
  """
  @spec stop(pid()) :: :ok
  def stop(orchestrator_pid) do
    GenServer.cast(orchestrator_pid, :stop)
  end

  # GenServer Callbacks

  @impl true
  def init({stream_id, subscriber_pid, chat, auth_strategy, config}) do
    turn_limit = Keyword.get(config, :turn_limit, 10)

    state = %{
      stream_id: stream_id,
      subscriber_pid: subscriber_pid,
      chat: chat,
      auth_strategy: auth_strategy,
      config: config,
      phase: :awaiting_model_call,
      first_stream_pid: nil,
      second_stream_pid: nil,
      buffered_chunks: [],
      turn_limit: turn_limit,
      error: nil
    }

    # Start the first streaming request immediately
    case start_first_stream(state) do
      {:ok, stream_pid} ->
        updated_state = %{state | first_stream_pid: stream_pid}
        {:ok, updated_state}

      {:error, reason} ->
        send(subscriber_pid, {:stream_error, stream_id, reason})
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:subscribe, _subscriber_pid}, state) do
    # For simplicity, we only support one subscriber in this implementation
    # Multiple subscribers could be added by maintaining a list
    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    cleanup_streams(state)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:stream_event, _stream_id, event}, %{phase: :awaiting_model_call} = state) do
    # Buffer events from the first stream and inspect for function calls
    updated_chunks = [event | state.buffered_chunks]
    updated_state = %{state | buffered_chunks: updated_chunks}

    case detect_function_calls(updated_chunks) do
      [] ->
        # No function calls detected yet, continue buffering
        {:noreply, updated_state}

      function_calls ->
        # Function calls detected, transition to tool execution phase
        Logger.debug("Detected #{length(function_calls)} function calls, executing tools")

        # Stop the first stream
        if state.first_stream_pid do
          Process.exit(state.first_stream_pid, :shutdown)
        end

        # Add model's function call turn to chat history
        updated_chat = Chat.add_turn(state.chat, "model", function_calls)

        new_state = %{
          updated_state
          | phase: :executing_tools,
            chat: updated_chat,
            first_stream_pid: nil
        }

        # Execute tools and send result to self
        orchestrator_pid = self()

        spawn_link(fn ->
          result = Tools.execute_calls(function_calls)
          send(orchestrator_pid, {:tool_execution_complete, result})
        end)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:stream_event, _stream_id, event}, %{phase: :awaiting_final_response} = state) do
    # Proxy events from the second stream to the subscriber
    send(state.subscriber_pid, {:stream_event, state.stream_id, event})
    {:noreply, state}
  end

  @impl true
  def handle_info({:stream_complete, _stream_id}, %{phase: :awaiting_model_call} = state) do
    # First stream completed without function calls - send buffered content to subscriber
    Enum.reverse(state.buffered_chunks)
    |> Enum.each(fn event ->
      send(state.subscriber_pid, {:stream_event, state.stream_id, event})
    end)

    send(state.subscriber_pid, {:stream_complete, state.stream_id})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:stream_complete, _stream_id}, %{phase: :awaiting_final_response} = state) do
    # Second stream completed - notify subscriber
    send(state.subscriber_pid, {:stream_complete, state.stream_id})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:stream_error, _stream_id, error}, state) do
    # Stream error occurred - notify subscriber and stop
    send(state.subscriber_pid, {:stream_error, state.stream_id, error})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:tool_execution_complete, result}, %{phase: :executing_tools} = state) do
    case result do
      {:ok, tool_results} ->
        handle_tool_execution_success(state, tool_results)

      {:error, reason} ->
        handle_tool_execution_error(state, reason)
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    # Handle process death (stream processes)
    if reason not in [:normal, :shutdown] do
      Logger.warning("Stream process died with reason: #{inspect(reason)}")
      send(state.subscriber_pid, {:stream_error, state.stream_id, reason})
    end

    {:stop, :normal, state}
  end

  # Private helper functions

  @spec start_first_stream(orchestrator_state()) :: {:ok, pid()} | {:error, term()}
  defp start_first_stream(state) do
    # Build request body from current chat history
    request_body = build_request_body(state.chat)

    # Get authentication and start stream
    case MultiAuthCoordinator.coordinate_auth(state.auth_strategy, state.config) do
      {:ok, auth_strategy, headers} ->
        case get_streaming_url_and_headers(state, auth_strategy, headers) do
          {:ok, url, final_headers} ->
            HTTPStreaming.stream_to_process(
              url,
              final_headers,
              request_body,
              state.stream_id,
              self()
            )

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "Auth failed: #{reason}"}
    end
  end

  @spec start_second_stream(orchestrator_state()) :: {:ok, pid()} | {:error, term()}
  defp start_second_stream(state) do
    # Build request body with complete chat history including tool results
    request_body = build_request_body(state.chat)

    # Get authentication and start stream
    case MultiAuthCoordinator.coordinate_auth(state.auth_strategy, state.config) do
      {:ok, auth_strategy, headers} ->
        case get_streaming_url_and_headers(state, auth_strategy, headers) do
          {:ok, url, final_headers} ->
            HTTPStreaming.stream_to_process(
              url,
              final_headers,
              request_body,
              state.stream_id,
              self()
            )

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "Auth failed: #{reason}"}
    end
  end

  @spec build_request_body(Chat.t()) :: map()
  defp build_request_body(chat) do
    %{
      contents: format_contents_for_api(chat.history),
      generationConfig: build_generation_config(chat.opts),
      tools: Keyword.get(chat.opts, :tools, []),
      toolConfig: Keyword.get(chat.opts, :tool_config)
    }
    |> Enum.filter(fn {_k, v} -> v != nil and v != [] end)
    |> Map.new()
  end

  @spec format_contents_for_api([Content.t()]) :: [map()]
  defp format_contents_for_api(contents) do
    Enum.map(contents, fn content ->
      %{
        role: content.role,
        parts: format_parts_for_api(content.parts)
      }
    end)
  end

  @spec format_parts_for_api([map()]) :: [map()]
  defp format_parts_for_api(parts) do
    Enum.map(parts, fn part ->
      cond do
        part.text != nil ->
          %{text: part.text}

        part.function_call != nil ->
          %{
            functionCall: %{
              name: part.function_call.name,
              args: part.function_call.args
            }
          }

        part.function_response != nil ->
          %{functionResponse: part.function_response}

        part.inline_data != nil ->
          %{
            inlineData: %{
              mimeType: part.inline_data.mime_type,
              data: part.inline_data.data
            }
          }

        true ->
          %{text: ""}
      end
    end)
  end

  @spec build_generation_config(keyword()) :: map()
  defp build_generation_config(opts) do
    opts
    |> Enum.reduce(%{}, fn
      {:temperature, temp}, acc when is_number(temp) ->
        Map.put(acc, :temperature, temp)

      {:max_output_tokens, max}, acc when is_integer(max) ->
        Map.put(acc, :maxOutputTokens, max)

      {:top_p, top_p}, acc when is_number(top_p) ->
        Map.put(acc, :topP, top_p)

      {:top_k, top_k}, acc when is_integer(top_k) ->
        Map.put(acc, :topK, top_k)

      _, acc ->
        acc
    end)
  end

  @spec get_streaming_url_and_headers(orchestrator_state(), :gemini | :vertex_ai, [
          {String.t(), String.t()}
        ]) ::
          {:ok, String.t(), [{String.t(), String.t()}]} | {:error, term()}
  defp get_streaming_url_and_headers(state, auth_strategy, auth_headers) do
    case MultiAuthCoordinator.get_credentials(auth_strategy, state.config) do
      {:ok, credentials} ->
        model = Keyword.get(state.config, :model, "gemini-1.5-flash")

        base_url =
          case auth_strategy do
            :gemini ->
              "https://generativelanguage.googleapis.com"

            :vertex_ai ->
              project_id = Map.get(credentials, :project_id)
              location = Map.get(credentials, :location, "us-central1")

              "https://#{location}-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/#{location}/publishers/google"
          end

        path =
          case auth_strategy do
            :gemini -> "/v1beta/models/#{model}:streamGenerateContent"
            :vertex_ai -> "/models/#{model}:streamGenerateContent"
          end

        url = base_url <> path

        final_headers =
          if List.keyfind(auth_headers, "Content-Type", 0) do
            auth_headers
          else
            [{"Content-Type", "application/json"} | auth_headers]
          end

        {:ok, url, final_headers}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec detect_function_calls([map()]) :: [Altar.ADM.FunctionCall.t()]
  defp detect_function_calls(chunks) do
    chunks
    |> Enum.reverse()
    |> Enum.flat_map(fn chunk ->
      case chunk do
        %{type: :data, data: data} ->
          extract_function_calls_from_chunk(data)

        _ ->
          []
      end
    end)
  end

  @spec extract_function_calls_from_chunk(map()) :: [Altar.ADM.FunctionCall.t()]
  defp extract_function_calls_from_chunk(data) do
    case data do
      %{"candidates" => candidates} ->
        candidates
        |> Enum.flat_map(fn candidate ->
          case candidate do
            %{"content" => %{"parts" => parts}} ->
              parts
              |> Enum.filter(&Map.has_key?(&1, "functionCall"))
              |> Enum.map(&convert_to_function_call/1)
              |> Enum.filter(&match?({:ok, _}, &1))
              |> Enum.map(fn {:ok, call} -> call end)

            _ ->
              []
          end
        end)

      _ ->
        []
    end
  end

  @spec convert_to_function_call(map()) :: {:ok, Altar.ADM.FunctionCall.t()} | {:error, term()}
  defp convert_to_function_call(%{"functionCall" => %{"name" => name, "args" => args}}) do
    call_id = "call_#{:rand.uniform(1_000_000)}"
    Altar.ADM.FunctionCall.new(%{call_id: call_id, name: name, args: args})
  end

  defp convert_to_function_call(_), do: {:error, "Invalid function call format"}

  @spec handle_tool_execution_success(orchestrator_state(), [Altar.ADM.ToolResult.t()]) ::
          {:noreply, orchestrator_state()}
  defp handle_tool_execution_success(state, tool_results) do
    if state.turn_limit <= 0 do
      error = "Maximum tool-calling turns exceeded"
      send(state.subscriber_pid, {:stream_error, state.stream_id, error})
      {:stop, :normal, state}
    else
      # Add user's function response turn to chat history
      updated_chat = Chat.add_turn(state.chat, "user", tool_results)

      # Start the second streaming request
      case start_second_stream(%{state | chat: updated_chat}) do
        {:ok, stream_pid} ->
          new_state = %{
            state
            | phase: :awaiting_final_response,
              chat: updated_chat,
              second_stream_pid: stream_pid,
              turn_limit: state.turn_limit - 1
          }

          {:noreply, new_state}

        {:error, reason} ->
          send(state.subscriber_pid, {:stream_error, state.stream_id, reason})
          {:stop, :normal, state}
      end
    end
  end

  @spec handle_tool_execution_error(orchestrator_state(), term()) ::
          {:noreply, orchestrator_state()}
  defp handle_tool_execution_error(state, reason) do
    error = "Tool execution failed: #{inspect(reason)}"
    send(state.subscriber_pid, {:stream_error, state.stream_id, error})
    {:stop, :normal, state}
  end

  @spec cleanup_streams(orchestrator_state()) :: :ok
  defp cleanup_streams(state) do
    if state.first_stream_pid && Process.alive?(state.first_stream_pid) do
      Process.exit(state.first_stream_pid, :shutdown)
    end

    if state.second_stream_pid && Process.alive?(state.second_stream_pid) do
      Process.exit(state.second_stream_pid, :shutdown)
    end

    :ok
  end
end
