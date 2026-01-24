defmodule Gemini.Types.Live.Setup do
  @moduledoc """
  Session setup configuration for Live API.

  Message to be sent in the first (and only in the first) client message.
  Contains configuration that applies for the duration of the streaming RPC.

  Clients should wait for a SetupComplete message before sending any
  additional messages.

  ## Fields

  - `model` - Required. The model's resource name (e.g., "models/gemini-2.0-flash-exp")
  - `generation_config` - Generation configuration for the session
  - `system_instruction` - System instructions for the model
  - `tools` - List of tools the model may use
  - `realtime_input_config` - Configuration for realtime input handling
  - `session_resumption` - Session resumption configuration
  - `context_window_compression` - Context window compression configuration
  - `input_audio_transcription` - Enable transcription of input audio
  - `output_audio_transcription` - Enable transcription of output audio
  - `proactivity` - Proactivity configuration

  ## Example

      %Setup{
        model: "models/gemini-2.0-flash-exp",
        generation_config: %{
          response_modalities: [:audio],
          speech_config: %{voice_config: %{prebuilt_voice_config: %{voice_name: "Puck"}}}
        },
        system_instruction: %{parts: [%{text: "You are a helpful assistant."}]}
      }
  """

  alias Gemini.Types.Live.{
    AudioTranscriptionConfig,
    ContextWindowCompression,
    ProactivityConfig,
    RealtimeInputConfig,
    SessionResumptionConfig
  }

  alias Gemini.Types.{Content, GenerationConfig, Modality, SpeechConfig}

  @type tool :: map()

  @type t :: %__MODULE__{
          model: String.t(),
          generation_config: GenerationConfig.t() | map() | nil,
          system_instruction: Content.t() | map() | nil,
          tools: [tool()] | nil,
          realtime_input_config: RealtimeInputConfig.t() | nil,
          session_resumption: SessionResumptionConfig.t() | nil,
          context_window_compression: ContextWindowCompression.t() | nil,
          input_audio_transcription: AudioTranscriptionConfig.t() | nil,
          output_audio_transcription: AudioTranscriptionConfig.t() | nil,
          proactivity: ProactivityConfig.t() | nil
        }

  @enforce_keys [:model]
  defstruct [
    :model,
    :generation_config,
    :system_instruction,
    :tools,
    :realtime_input_config,
    :session_resumption,
    :context_window_compression,
    :input_audio_transcription,
    :output_audio_transcription,
    :proactivity
  ]

  @doc """
  Creates a new Setup with the required model and optional configuration.
  """
  @spec new(String.t(), keyword()) :: t()
  def new(model, opts \\ []) when is_binary(model) do
    %__MODULE__{
      model: normalize_model_name(model),
      generation_config: Keyword.get(opts, :generation_config),
      system_instruction: Keyword.get(opts, :system_instruction),
      tools: Keyword.get(opts, :tools),
      realtime_input_config: Keyword.get(opts, :realtime_input_config),
      session_resumption: Keyword.get(opts, :session_resumption),
      context_window_compression: Keyword.get(opts, :context_window_compression),
      input_audio_transcription: Keyword.get(opts, :input_audio_transcription),
      output_audio_transcription: Keyword.get(opts, :output_audio_transcription),
      proactivity: Keyword.get(opts, :proactivity)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{"model" => value.model}
    |> maybe_put("generationConfig", convert_generation_config_to_api(value.generation_config))
    |> maybe_put("systemInstruction", convert_content_to_api(value.system_instruction))
    |> maybe_put("tools", value.tools)
    |> maybe_put("realtimeInputConfig", RealtimeInputConfig.to_api(value.realtime_input_config))
    |> maybe_put("sessionResumption", SessionResumptionConfig.to_api(value.session_resumption))
    |> maybe_put(
      "contextWindowCompression",
      ContextWindowCompression.to_api(value.context_window_compression)
    )
    |> maybe_put(
      "inputAudioTranscription",
      AudioTranscriptionConfig.to_api(value.input_audio_transcription)
    )
    |> maybe_put(
      "outputAudioTranscription",
      AudioTranscriptionConfig.to_api(value.output_audio_transcription)
    )
    |> maybe_put("proactivity", ProactivityConfig.to_api(value.proactivity))
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      model: data["model"],
      generation_config: parse_generation_config(data["generationConfig"]),
      system_instruction: parse_content(data["systemInstruction"]),
      tools: data["tools"],
      realtime_input_config:
        (data["realtimeInputConfig"] || data["realtime_input_config"])
        |> RealtimeInputConfig.from_api(),
      session_resumption:
        (data["sessionResumption"] || data["session_resumption"])
        |> SessionResumptionConfig.from_api(),
      context_window_compression:
        (data["contextWindowCompression"] || data["context_window_compression"])
        |> ContextWindowCompression.from_api(),
      input_audio_transcription:
        (data["inputAudioTranscription"] || data["input_audio_transcription"])
        |> AudioTranscriptionConfig.from_api(),
      output_audio_transcription:
        (data["outputAudioTranscription"] || data["output_audio_transcription"])
        |> AudioTranscriptionConfig.from_api(),
      proactivity:
        data["proactivity"]
        |> ProactivityConfig.from_api()
    }
  end

  defp convert_generation_config_to_api(nil), do: nil

  defp convert_generation_config_to_api(%GenerationConfig{} = config) do
    result = %{}

    result =
      if config.response_modalities do
        modalities =
          Enum.map(config.response_modalities, fn m ->
            Modality.to_api(m)
          end)

        Map.put(result, "responseModalities", modalities)
      else
        result
      end

    result =
      if config.speech_config do
        Map.put(result, "speechConfig", SpeechConfig.to_api(config.speech_config))
      else
        result
      end

    result = maybe_put(result, "temperature", config.temperature)
    result = maybe_put(result, "topP", config.top_p)
    result = maybe_put(result, "topK", config.top_k)
    result = maybe_put(result, "candidateCount", config.candidate_count)
    result = maybe_put(result, "maxOutputTokens", config.max_output_tokens)
    result = maybe_put(result, "presencePenalty", config.presence_penalty)
    result = maybe_put(result, "frequencyPenalty", config.frequency_penalty)

    if map_size(result) == 0, do: nil, else: result
  end

  defp convert_generation_config_to_api(%{} = config) do
    result = %{}
    result = add_response_modalities(result, config[:response_modalities])
    result = add_speech_config(result, config[:speech_config])

    result = maybe_put(result, "temperature", config[:temperature])
    result = maybe_put(result, "topP", config[:top_p])
    result = maybe_put(result, "topK", config[:top_k])
    result = maybe_put(result, "candidateCount", config[:candidate_count])
    result = maybe_put(result, "maxOutputTokens", config[:max_output_tokens])
    result = maybe_put(result, "presencePenalty", config[:presence_penalty])
    result = maybe_put(result, "frequencyPenalty", config[:frequency_penalty])

    if map_size(result) == 0, do: nil, else: result
  end

  defp add_response_modalities(result, nil), do: result

  defp add_response_modalities(result, modalities) do
    converted = Enum.map(modalities, &convert_modality/1)
    Map.put(result, "responseModalities", converted)
  end

  defp convert_modality(m) when is_atom(m), do: Modality.to_api(m)
  defp convert_modality(m), do: m

  defp add_speech_config(result, nil), do: result

  defp add_speech_config(result, %SpeechConfig{} = sc),
    do: Map.put(result, "speechConfig", SpeechConfig.to_api(sc))

  defp add_speech_config(result, other),
    do: Map.put(result, "speechConfig", convert_speech_config_to_api(other))

  defp convert_speech_config_to_api(%{voice_config: vc}) do
    %{"voiceConfig" => convert_voice_config_to_api(vc)}
  end

  defp convert_speech_config_to_api(other), do: other

  defp convert_voice_config_to_api(%{prebuilt_voice_config: pvc}) do
    %{"prebuiltVoiceConfig" => convert_prebuilt_voice_config_to_api(pvc)}
  end

  defp convert_voice_config_to_api(other), do: other

  defp convert_prebuilt_voice_config_to_api(%{voice_name: name}) do
    %{"voiceName" => name}
  end

  defp convert_prebuilt_voice_config_to_api(other), do: other

  defp convert_content_to_api(nil), do: nil

  defp convert_content_to_api(%Content{} = content) do
    %{
      "role" => content.role,
      "parts" => convert_parts_to_api(content.parts)
    }
  end

  defp convert_content_to_api(%{parts: parts} = content) do
    %{}
    |> maybe_put("role", content[:role])
    |> maybe_put("parts", convert_parts_to_api(parts))
  end

  # Handle plain strings by wrapping in Content format
  defp convert_content_to_api(text) when is_binary(text) do
    %{"parts" => [%{"text" => text}]}
  end

  defp convert_content_to_api(other), do: other

  defp convert_parts_to_api(parts) when is_list(parts) do
    Enum.map(parts, fn part ->
      case part do
        %{text: text} -> %{"text" => text}
        %{"text" => _} = m -> m
        other -> other
      end
    end)
  end

  defp convert_parts_to_api(other), do: other

  defp parse_generation_config(nil), do: nil

  defp parse_generation_config(data) when is_map(data) do
    %{
      response_modalities:
        data["responseModalities"]
        |> parse_modalities(),
      speech_config: data["speechConfig"],
      temperature: data["temperature"],
      top_p: data["topP"],
      top_k: data["topK"],
      candidate_count: data["candidateCount"],
      max_output_tokens: data["maxOutputTokens"],
      presence_penalty: data["presencePenalty"],
      frequency_penalty: data["frequencyPenalty"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp parse_modalities(nil), do: nil

  defp parse_modalities(modalities) when is_list(modalities) do
    Enum.map(modalities, &Modality.from_api/1)
  end

  defp parse_content(nil), do: nil

  defp parse_content(data) when is_map(data) do
    %{
      role: data["role"],
      parts: data["parts"]
    }
  end

  # Normalize model name to include "models/" prefix if not already present
  defp normalize_model_name(model) when is_binary(model) do
    if String.starts_with?(model, "models/") do
      model
    else
      "models/#{model}"
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
