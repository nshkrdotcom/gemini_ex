defmodule Gemini.Types.PrebuiltVoiceConfig do
  @moduledoc """
  Configuration for a prebuilt voice.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:voice_name, String.t() | nil, default: nil)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      voice_name: Map.get(data, "voiceName") || Map.get(data, :voice_name)
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = config) do
    %{"voiceName" => config.voice_name}
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end

defmodule Gemini.Types.VoiceConfig do
  @moduledoc """
  Voice configuration for speech synthesis.
  """

  use TypedStruct

  alias Gemini.Types.PrebuiltVoiceConfig

  @derive Jason.Encoder
  typedstruct do
    field(:prebuilt_voice_config, PrebuiltVoiceConfig.t() | nil, default: nil)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      prebuilt_voice_config:
        data
        |> Map.get("prebuiltVoiceConfig")
        |> Kernel.||(Map.get(data, :prebuilt_voice_config))
        |> PrebuiltVoiceConfig.from_api()
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = config) do
    prebuilt = PrebuiltVoiceConfig.to_api(config.prebuilt_voice_config)

    %{"prebuiltVoiceConfig" => prebuilt}
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end

defmodule Gemini.Types.SpeechConfig do
  @moduledoc """
  Speech generation configuration.
  """

  use TypedStruct

  alias Gemini.Types.VoiceConfig

  @derive Jason.Encoder
  typedstruct do
    field(:language_code, String.t() | nil, default: nil)
    field(:voice_config, VoiceConfig.t() | nil, default: nil)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      language_code: Map.get(data, "languageCode") || Map.get(data, :language_code),
      voice_config:
        data
        |> Map.get("voiceConfig")
        |> Kernel.||(Map.get(data, :voice_config))
        |> VoiceConfig.from_api()
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = config) do
    voice = VoiceConfig.to_api(config.voice_config)

    %{
      "languageCode" => config.language_code,
      "voiceConfig" => voice
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
