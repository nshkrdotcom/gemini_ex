defmodule Gemini.Types.Live do
  @moduledoc """
  Types for Gemini Live API (WebSocket-based real-time communication).

  The Live API enables bidirectional streaming communication with Gemini models,
  supporting real-time text, audio, and video interactions.

  ## Features

  - Real-time bidirectional streaming
  - Audio transcription and generation
  - Video/image processing
  - Tool/function calling during conversation
  - Low-latency responses

  ## Example

      config = %LiveConfig{
        model: "gemini-2.0-flash-exp",
        generation_config: %GenerationConfig{temperature: 0.8},
        system_instruction: "You are a helpful assistant"
      }

      {:ok, session} = LiveSession.start_link(config)
      :ok = LiveSession.connect(session)
  """

  use TypedStruct

  alias Gemini.Types.{GenerationConfig, SafetySetting, Content}
  alias Gemini.Types.Live.{AudioTranscriptionConfig, SpeechConfig}

  @typedoc "Turn detection mode for automatic turn-taking"
  @type turn_detection :: :unspecified | :user_based | :model_based

  @typedoc "Audio format for input/output"
  @type audio_format :: :pcm16 | :opus | :aac | :mp3

  typedstruct module: LiveConfig do
    @moduledoc """
    Configuration for a Live API session.

    ## Fields

    - `model`: Model to use for the session (required)
    - `generation_config`: Generation parameters (optional)
    - `system_instruction`: System instruction for the model (optional)
    - `tools`: Available tools/functions (optional)
    - `tool_config`: Tool configuration (optional)
    - `safety_settings`: Safety settings (optional)
    """

    field(:model, String.t(), enforce: true)
    field(:generation_config, GenerationConfig.t())
    field(:system_instruction, String.t() | Content.t())
    field(:tools, [map()])
    field(:tool_config, map())
    field(:safety_settings, [SafetySetting.t()])
  end

  typedstruct module: AudioTranscriptionConfig do
    @moduledoc """
    Configuration for automatic audio transcription.

    ## Fields

    - `enabled`: Enable transcription (default: false)
    - `language`: Language code for transcription (e.g., "en-US")
    - `model`: Transcription model to use
    """

    field(:enabled, boolean(), default: false)
    field(:language, String.t())
    field(:model, String.t())
  end

  typedstruct module: SpeechConfig do
    @moduledoc """
    Configuration for speech generation.

    ## Fields

    - `voice_config`: Voice configuration for TTS
    - `audio_format`: Output audio format
    """

    field(:voice_config, map())
    field(:audio_format, Gemini.Types.Live.audio_format())
  end

  typedstruct module: RealtimeInputConfig do
    @moduledoc """
    Configuration for real-time input (audio/video).

    ## Fields

    - `audio_transcription`: Audio transcription settings
    - `turn_detection`: Turn detection mode
    """

    field(:audio_transcription, AudioTranscriptionConfig.t())
    field(:turn_detection, Gemini.Types.Live.turn_detection())
  end

  typedstruct module: BidiGenerateContentSetup do
    @moduledoc """
    Setup configuration for bidirectional content generation.

    ## Fields

    - `model`: Model identifier
    - `generation_config`: Generation parameters
    - `system_instruction`: System instruction
    - `tools`: Available tools
    """

    field(:model, String.t())
    field(:generation_config, GenerationConfig.t())
    field(:system_instruction, String.t() | Content.t())
    field(:tools, [map()])
  end

  # API conversion helpers

  @doc """
  Convert LiveConfig to API format for session setup.
  """
  @spec to_api_setup(LiveConfig.t()) :: map()
  def to_api_setup(%LiveConfig{} = config) do
    setup = %{
      model: config.model
    }

    setup =
      if config.generation_config do
        Map.put(setup, :generation_config, config.generation_config)
      else
        setup
      end

    setup =
      if config.system_instruction do
        Map.put(setup, :system_instruction, format_system_instruction(config.system_instruction))
      else
        setup
      end

    setup =
      if config.tools do
        Map.put(setup, :tools, config.tools)
      else
        setup
      end

    setup =
      if config.tool_config do
        Map.put(setup, :tool_config, config.tool_config)
      else
        setup
      end

    setup =
      if config.safety_settings do
        Map.put(setup, :safety_settings, config.safety_settings)
      else
        setup
      end

    setup
  end

  defp format_system_instruction(text) when is_binary(text) do
    %{parts: [%{text: text}]}
  end

  defp format_system_instruction(%Content{} = content) do
    %{
      role: content.role,
      parts: content.parts
    }
  end

  defp format_system_instruction(other), do: other
end
