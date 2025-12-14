defmodule Gemini.Types.Interactions.Params.BaseCreateModelInteraction do
  @moduledoc """
  Base parameter struct for model-based interaction creation.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.{GenerationConfig, Input, Tool}

  @type response_modality :: String.t()

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:input, Input.t())
    field(:model, String.t())
    field(:stream, boolean(), enforce: false)
    field(:background, boolean(), enforce: false)
    field(:generation_config, GenerationConfig.t(), enforce: false)
    field(:previous_interaction_id, String.t(), enforce: false)
    field(:response_format, map(), enforce: false)
    field(:response_mime_type, String.t(), enforce: false)
    field(:response_modalities, [response_modality()], enforce: false)
    field(:store, boolean(), enforce: false)
    field(:system_instruction, String.t(), enforce: false)
    field(:tools, [Tool.t()], enforce: false)
  end

  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = params) do
    %{}
    |> Map.put("input", Input.to_api(params.input))
    |> Map.put("model", params.model)
    |> maybe_put("stream", params.stream)
    |> maybe_put("background", params.background)
    |> maybe_put("generation_config", GenerationConfig.to_api(params.generation_config))
    |> maybe_put("previous_interaction_id", params.previous_interaction_id)
    |> maybe_put("response_format", params.response_format)
    |> maybe_put("response_mime_type", params.response_mime_type)
    |> maybe_put("response_modalities", params.response_modalities)
    |> maybe_put("store", params.store)
    |> maybe_put("system_instruction", params.system_instruction)
    |> maybe_put("tools", map_list(params.tools, &Tool.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Params.BaseCreateAgentInteraction do
  @moduledoc """
  Base parameter struct for agent-based interaction creation.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.{AgentConfig, Input, Tool}

  @type response_modality :: String.t()

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:agent, String.t())
    field(:input, Input.t())
    field(:stream, boolean(), enforce: false)
    field(:agent_config, AgentConfig.t(), enforce: false)
    field(:background, boolean(), enforce: false)
    field(:previous_interaction_id, String.t(), enforce: false)
    field(:response_format, map(), enforce: false)
    field(:response_mime_type, String.t(), enforce: false)
    field(:response_modalities, [response_modality()], enforce: false)
    field(:store, boolean(), enforce: false)
    field(:system_instruction, String.t(), enforce: false)
    field(:tools, [Tool.t()], enforce: false)
  end

  @spec to_api(t()) :: map()
  def to_api(%__MODULE__{} = params) do
    %{}
    |> Map.put("agent", params.agent)
    |> Map.put("input", Input.to_api(params.input))
    |> maybe_put("stream", params.stream)
    |> maybe_put("agent_config", AgentConfig.to_api(params.agent_config))
    |> maybe_put("background", params.background)
    |> maybe_put("previous_interaction_id", params.previous_interaction_id)
    |> maybe_put("response_format", params.response_format)
    |> maybe_put("response_mime_type", params.response_mime_type)
    |> maybe_put("response_modalities", params.response_modalities)
    |> maybe_put("store", params.store)
    |> maybe_put("system_instruction", params.system_instruction)
    |> maybe_put("tools", map_list(params.tools, &Tool.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Params.CreateModelNonStreaming do
  @moduledoc false

  @type t :: Gemini.Types.Interactions.Params.BaseCreateModelInteraction.t()
end

defmodule Gemini.Types.Interactions.Params.CreateModelStreaming do
  @moduledoc false

  @type t :: Gemini.Types.Interactions.Params.BaseCreateModelInteraction.t()
end

defmodule Gemini.Types.Interactions.Params.CreateAgentNonStreaming do
  @moduledoc false

  @type t :: Gemini.Types.Interactions.Params.BaseCreateAgentInteraction.t()
end

defmodule Gemini.Types.Interactions.Params.CreateAgentStreaming do
  @moduledoc false

  @type t :: Gemini.Types.Interactions.Params.BaseCreateAgentInteraction.t()
end

defmodule Gemini.Types.Interactions.Params.InteractionGetBase do
  @moduledoc """
  Base parameter struct for interaction retrieval.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:api_version, String.t())
    field(:last_event_id, String.t())
    field(:stream, boolean())
  end
end

defmodule Gemini.Types.Interactions.Params.InteractionGetNonStreaming do
  @moduledoc false

  @type t :: Gemini.Types.Interactions.Params.InteractionGetBase.t()
end

defmodule Gemini.Types.Interactions.Params.InteractionGetStreaming do
  @moduledoc false

  @type t :: Gemini.Types.Interactions.Params.InteractionGetBase.t()
end
