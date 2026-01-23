defmodule Gemini.Types.Interactions.AudioMimeType do
  @moduledoc """
  Audio mime types for Interactions content.

  Python models this as a `Literal[...] | str` union; in Elixir we accept any string.
  """

  @type t :: String.t()
end

defmodule Gemini.Types.Interactions.ImageMimeType do
  @moduledoc """
  Image mime types for Interactions content.

  Python models this as a `Literal[...] | str` union; in Elixir we accept any string.
  """

  @type t :: String.t()
end

defmodule Gemini.Types.Interactions.VideoMimeType do
  @moduledoc """
  Video mime types for Interactions content.

  Python models this as a `Literal[...] | str` union; in Elixir we accept any string.
  """

  @type t :: String.t()
end

defmodule Gemini.Types.Interactions.ThinkingLevel do
  @moduledoc """
  Thinking level for Interactions generation (`"minimal"`, `"low"`, `"medium"`, `"high"`).
  """

  @type t :: String.t()
end

defmodule Gemini.Types.Interactions.ToolChoiceType do
  @moduledoc """
  Tool choice type (`"auto" | "any" | "none" | "validated"`).
  """

  @type t :: String.t()
end

defmodule Gemini.Types.Interactions.ToolChoiceConfig do
  @moduledoc """
  Tool choice configuration.
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.AllowedTools

  @derive Jason.Encoder
  typedstruct do
    field(:allowed_tools, AllowedTools.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = config), do: config

  def from_api(%{} = data) do
    %__MODULE__{
      allowed_tools: AllowedTools.from_api(Map.get(data, "allowed_tools"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = config) do
    %{}
    |> maybe_put("allowed_tools", AllowedTools.to_api(config.allowed_tools))
  end
end

defmodule Gemini.Types.Interactions.ToolChoice do
  @moduledoc """
  Tool choice union (`ToolChoiceType | ToolChoiceConfig`).
  """

  alias Gemini.Types.Interactions.{ToolChoiceConfig, ToolChoiceType}

  @type t :: ToolChoiceType.t() | ToolChoiceConfig.t() | map()

  @spec from_api(term()) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%ToolChoiceConfig{} = config), do: config
  def from_api(%{} = map), do: ToolChoiceConfig.from_api(map)
  def from_api(value) when is_binary(value), do: value
  def from_api(other), do: other

  @spec to_api(t() | nil) :: term()
  def to_api(nil), do: nil
  def to_api(value) when is_binary(value), do: value
  def to_api(%ToolChoiceConfig{} = config), do: ToolChoiceConfig.to_api(config)
  def to_api(%{} = map), do: map
  def to_api(other), do: other
end

defmodule Gemini.Types.Interactions.SpeechConfig do
  @moduledoc """
  Speech config for Interactions generation (different from generateContent).
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct do
    field(:language, String.t())
    field(:speaker, String.t())
    field(:voice, String.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = config), do: config

  def from_api(%{} = data) do
    %__MODULE__{
      language: Map.get(data, "language"),
      speaker: Map.get(data, "speaker"),
      voice: Map.get(data, "voice")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = config) do
    %{}
    |> maybe_put("language", config.language)
    |> maybe_put("speaker", config.speaker)
    |> maybe_put("voice", config.voice)
  end
end

defmodule Gemini.Types.Interactions.GenerationConfig do
  @moduledoc """
  Interactions GenerationConfig (snake_case keys).
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.{ImageConfig, SpeechConfig, ThinkingLevel, ToolChoice}

  @type thinking_summaries :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:image_config, ImageConfig.t())
    field(:max_output_tokens, non_neg_integer())
    field(:seed, integer())
    field(:speech_config, [SpeechConfig.t()])
    field(:stop_sequences, [String.t()])
    field(:temperature, float())
    field(:thinking_level, ThinkingLevel.t())
    field(:thinking_summaries, thinking_summaries())
    field(:tool_choice, ToolChoice.t())
    field(:top_p, float())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = config), do: config

  def from_api(%{} = data) do
    %__MODULE__{
      image_config: ImageConfig.from_api(Map.get(data, "image_config")),
      max_output_tokens: Map.get(data, "max_output_tokens"),
      seed: Map.get(data, "seed"),
      speech_config: map_list(Map.get(data, "speech_config"), &SpeechConfig.from_api/1),
      stop_sequences: Map.get(data, "stop_sequences"),
      temperature: Map.get(data, "temperature"),
      thinking_level: Map.get(data, "thinking_level"),
      thinking_summaries: Map.get(data, "thinking_summaries"),
      tool_choice: ToolChoice.from_api(Map.get(data, "tool_choice")),
      top_p: Map.get(data, "top_p")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = config) do
    %{}
    |> maybe_put("image_config", ImageConfig.to_api(config.image_config))
    |> maybe_put("max_output_tokens", config.max_output_tokens)
    |> maybe_put("seed", config.seed)
    |> maybe_put("speech_config", map_list(config.speech_config, &SpeechConfig.to_api/1))
    |> maybe_put("stop_sequences", config.stop_sequences)
    |> maybe_put("temperature", config.temperature)
    |> maybe_put("thinking_level", config.thinking_level)
    |> maybe_put("thinking_summaries", config.thinking_summaries)
    |> maybe_put("tool_choice", ToolChoice.to_api(config.tool_choice))
    |> maybe_put("top_p", config.top_p)
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end
