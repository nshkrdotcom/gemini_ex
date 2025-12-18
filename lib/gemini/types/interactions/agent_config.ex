defmodule Gemini.Types.Interactions.DynamicAgentConfig do
  @moduledoc """
  Dynamic agent configuration (`type: "dynamic"`).

  Python allows arbitrary extra keys; in Elixir we store them under `config`.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:type, String.t(), default: "dynamic")
    field(:config, map(), default: %{})
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = config), do: config

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "dynamic",
      config: Map.drop(data, ["type"])
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = config) do
    Map.merge(%{"type" => "dynamic"}, config.config || %{})
  end
end

defmodule Gemini.Types.Interactions.DeepResearchAgentConfig do
  @moduledoc """
  Deep Research agent configuration (`type: "deep-research"`).

  ## Fields

  - `thinking_summaries` - `"auto"` or `"none"`
  """

  use TypedStruct

  @type thinking_summaries :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:type, String.t(), default: "deep-research")
    field(:thinking_summaries, thinking_summaries())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = config), do: config

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "deep-research",
      thinking_summaries: Map.get(data, "thinking_summaries")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = config) do
    %{"type" => "deep-research"}
    |> maybe_put("thinking_summaries", config.thinking_summaries)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.AgentConfig do
  @moduledoc """
  Agent config union (`DynamicAgentConfig | DeepResearchAgentConfig`).
  """

  alias Gemini.Types.Interactions.{DeepResearchAgentConfig, DynamicAgentConfig}

  @type t :: DynamicAgentConfig.t() | DeepResearchAgentConfig.t() | map()

  @spec from_api(map() | t() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%DynamicAgentConfig{} = cfg), do: cfg
  def from_api(%DeepResearchAgentConfig{} = cfg), do: cfg

  def from_api(%{} = data) do
    case Map.get(data, "type") do
      "deep-research" -> DeepResearchAgentConfig.from_api(data)
      "dynamic" -> DynamicAgentConfig.from_api(data)
      _ -> DynamicAgentConfig.from_api(data)
    end
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map
  def to_api(%DynamicAgentConfig{} = cfg), do: DynamicAgentConfig.to_api(cfg)
  def to_api(%DeepResearchAgentConfig{} = cfg), do: DeepResearchAgentConfig.to_api(cfg)
end
