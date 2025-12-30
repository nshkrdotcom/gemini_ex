defmodule Gemini.Types.Interactions.CachedTokensByModality do
  @moduledoc """
  Cached token count for a response modality.
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @type modality :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:modality, modality())
    field(:tokens, non_neg_integer())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = value), do: value

  def from_api(%{} = data) do
    %__MODULE__{
      modality: Map.get(data, "modality"),
      tokens: Map.get(data, "tokens")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("modality", value.modality)
    |> maybe_put("tokens", value.tokens)
  end
end

defmodule Gemini.Types.Interactions.InputTokensByModality do
  @moduledoc """
  Input token count for a response modality.
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @type modality :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:modality, modality())
    field(:tokens, non_neg_integer())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = value), do: value

  def from_api(%{} = data) do
    %__MODULE__{
      modality: Map.get(data, "modality"),
      tokens: Map.get(data, "tokens")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("modality", value.modality)
    |> maybe_put("tokens", value.tokens)
  end
end

defmodule Gemini.Types.Interactions.OutputTokensByModality do
  @moduledoc """
  Output token count for a response modality.
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @type modality :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:modality, modality())
    field(:tokens, non_neg_integer())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = value), do: value

  def from_api(%{} = data) do
    %__MODULE__{
      modality: Map.get(data, "modality"),
      tokens: Map.get(data, "tokens")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("modality", value.modality)
    |> maybe_put("tokens", value.tokens)
  end
end

defmodule Gemini.Types.Interactions.ToolUseTokensByModality do
  @moduledoc """
  Tool-use token count for a response modality.
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @type modality :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:modality, modality())
    field(:tokens, non_neg_integer())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = value), do: value

  def from_api(%{} = data) do
    %__MODULE__{
      modality: Map.get(data, "modality"),
      tokens: Map.get(data, "tokens")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("modality", value.modality)
    |> maybe_put("tokens", value.tokens)
  end
end

defmodule Gemini.Types.Interactions.Usage do
  @moduledoc """
  Token usage statistics for an Interaction.
  """

  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.{
    CachedTokensByModality,
    InputTokensByModality,
    OutputTokensByModality,
    ToolUseTokensByModality
  }

  @derive Jason.Encoder
  typedstruct do
    field(:cached_tokens_by_modality, [CachedTokensByModality.t()])
    field(:input_tokens_by_modality, [InputTokensByModality.t()])
    field(:output_tokens_by_modality, [OutputTokensByModality.t()])
    field(:tool_use_tokens_by_modality, [ToolUseTokensByModality.t()])
    field(:total_cached_tokens, non_neg_integer())
    field(:total_input_tokens, non_neg_integer())
    field(:total_output_tokens, non_neg_integer())
    field(:total_thought_tokens, non_neg_integer())
    field(:total_tokens, non_neg_integer())
    field(:total_tool_use_tokens, non_neg_integer())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = usage), do: usage

  def from_api(%{} = data) do
    %__MODULE__{
      cached_tokens_by_modality:
        map_list(Map.get(data, "cached_tokens_by_modality"), &CachedTokensByModality.from_api/1),
      input_tokens_by_modality:
        map_list(Map.get(data, "input_tokens_by_modality"), &InputTokensByModality.from_api/1),
      output_tokens_by_modality:
        map_list(Map.get(data, "output_tokens_by_modality"), &OutputTokensByModality.from_api/1),
      tool_use_tokens_by_modality:
        map_list(
          Map.get(data, "tool_use_tokens_by_modality"),
          &ToolUseTokensByModality.from_api/1
        ),
      total_cached_tokens: Map.get(data, "total_cached_tokens"),
      total_input_tokens: Map.get(data, "total_input_tokens"),
      total_output_tokens: Map.get(data, "total_output_tokens"),
      total_thought_tokens: Map.get(data, "total_thought_tokens"),
      total_tokens: Map.get(data, "total_tokens"),
      total_tool_use_tokens: Map.get(data, "total_tool_use_tokens")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = usage) do
    %{}
    |> maybe_put(
      "cached_tokens_by_modality",
      map_list(usage.cached_tokens_by_modality, &CachedTokensByModality.to_api/1)
    )
    |> maybe_put(
      "input_tokens_by_modality",
      map_list(usage.input_tokens_by_modality, &InputTokensByModality.to_api/1)
    )
    |> maybe_put(
      "output_tokens_by_modality",
      map_list(usage.output_tokens_by_modality, &OutputTokensByModality.to_api/1)
    )
    |> maybe_put(
      "tool_use_tokens_by_modality",
      map_list(usage.tool_use_tokens_by_modality, &ToolUseTokensByModality.to_api/1)
    )
    |> maybe_put("total_cached_tokens", usage.total_cached_tokens)
    |> maybe_put("total_input_tokens", usage.total_input_tokens)
    |> maybe_put("total_output_tokens", usage.total_output_tokens)
    |> maybe_put("total_thought_tokens", usage.total_thought_tokens)
    |> maybe_put("total_tokens", usage.total_tokens)
    |> maybe_put("total_tool_use_tokens", usage.total_tool_use_tokens)
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end
