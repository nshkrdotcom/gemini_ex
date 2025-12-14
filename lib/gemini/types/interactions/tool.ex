defmodule Gemini.Types.Interactions.AllowedTools do
  @moduledoc """
  Allowed tools configuration (`{mode, tools}`).
  """

  use TypedStruct

  alias Gemini.Types.Interactions.ToolChoiceType

  @derive Jason.Encoder
  typedstruct do
    field(:mode, ToolChoiceType.t())
    field(:tools, [String.t()])
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = allowed), do: allowed

  def from_api(%{} = data) do
    %__MODULE__{
      mode: Map.get(data, "mode"),
      tools: Map.get(data, "tools")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = allowed) do
    %{}
    |> maybe_put("mode", allowed.mode)
    |> maybe_put("tools", allowed.tools)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Function do
  @moduledoc """
  `function` tool declaration.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "function")
    field(:name, String.t(), enforce: false)
    field(:description, String.t(), enforce: false)
    field(:parameters, map(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = tool), do: tool

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "function",
      name: Map.get(data, "name"),
      description: Map.get(data, "description"),
      parameters: Map.get(data, "parameters")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = tool) do
    %{"type" => "function"}
    |> maybe_put("name", tool.name)
    |> maybe_put("description", tool.description)
    |> maybe_put("parameters", tool.parameters)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.GoogleSearch do
  @moduledoc """
  `google_search` tool declaration.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "google_search")
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = tool), do: tool
  def from_api(%{} = data), do: %__MODULE__{type: Map.get(data, "type") || "google_search"}

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map
  def to_api(%__MODULE__{}), do: %{"type" => "google_search"}
end

defmodule Gemini.Types.Interactions.CodeExecution do
  @moduledoc """
  `code_execution` tool declaration.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "code_execution")
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = tool), do: tool
  def from_api(%{} = data), do: %__MODULE__{type: Map.get(data, "type") || "code_execution"}

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map
  def to_api(%__MODULE__{}), do: %{"type" => "code_execution"}
end

defmodule Gemini.Types.Interactions.URLContext do
  @moduledoc """
  `url_context` tool declaration.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "url_context")
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = tool), do: tool
  def from_api(%{} = data), do: %__MODULE__{type: Map.get(data, "type") || "url_context"}

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map
  def to_api(%__MODULE__{}), do: %{"type" => "url_context"}
end

defmodule Gemini.Types.Interactions.ComputerUse do
  @moduledoc """
  `computer_use` tool declaration.

  Note: API key uses camelCase `excludedPredefinedFunctions`.
  """

  use TypedStruct

  @type environment :: String.t()

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "computer_use")
    field(:environment, environment(), enforce: false)
    field(:excluded_predefined_functions, [String.t()], enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = tool), do: tool

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "computer_use",
      environment: Map.get(data, "environment"),
      excluded_predefined_functions:
        Map.get(data, "excludedPredefinedFunctions") ||
          Map.get(data, "excluded_predefined_functions")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = tool) do
    %{"type" => "computer_use"}
    |> maybe_put("environment", tool.environment)
    |> maybe_put("excludedPredefinedFunctions", tool.excluded_predefined_functions)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.MCPServer do
  @moduledoc """
  `mcp_server` tool declaration.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.AllowedTools

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "mcp_server")
    field(:name, String.t(), enforce: false)
    field(:url, String.t(), enforce: false)
    field(:headers, map(), enforce: false)
    field(:allowed_tools, [AllowedTools.t()], enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = tool), do: tool

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "mcp_server",
      name: Map.get(data, "name"),
      url: Map.get(data, "url"),
      headers: Map.get(data, "headers"),
      allowed_tools: map_list(Map.get(data, "allowed_tools"), &AllowedTools.from_api/1)
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = tool) do
    %{"type" => "mcp_server"}
    |> maybe_put("name", tool.name)
    |> maybe_put("url", tool.url)
    |> maybe_put("headers", tool.headers)
    |> maybe_put("allowed_tools", map_list(tool.allowed_tools, &AllowedTools.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.FileSearch do
  @moduledoc """
  `file_search` tool declaration.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "file_search")
    field(:file_search_store_names, [String.t()], enforce: false)
    field(:metadata_filter, String.t(), enforce: false)
    field(:top_k, non_neg_integer(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = tool), do: tool

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "file_search",
      file_search_store_names: Map.get(data, "file_search_store_names"),
      metadata_filter: Map.get(data, "metadata_filter"),
      top_k: Map.get(data, "top_k")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = tool) do
    %{"type" => "file_search"}
    |> maybe_put("file_search_store_names", tool.file_search_store_names)
    |> maybe_put("metadata_filter", tool.metadata_filter)
    |> maybe_put("top_k", tool.top_k)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Tool do
  @moduledoc """
  Union type for Interactions tools.
  """

  alias Gemini.Types.Interactions.{
    CodeExecution,
    ComputerUse,
    FileSearch,
    Function,
    GoogleSearch,
    MCPServer,
    URLContext
  }

  @type t ::
          Function.t()
          | GoogleSearch.t()
          | CodeExecution.t()
          | URLContext.t()
          | ComputerUse.t()
          | MCPServer.t()
          | FileSearch.t()
          | map()

  @spec from_api(map() | t() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%_{} = tool), do: tool

  def from_api(%{} = data) do
    case Map.get(data, "type") do
      "function" -> Function.from_api(data)
      "google_search" -> GoogleSearch.from_api(data)
      "code_execution" -> CodeExecution.from_api(data)
      "url_context" -> URLContext.from_api(data)
      "computer_use" -> ComputerUse.from_api(data)
      "mcp_server" -> MCPServer.from_api(data)
      "file_search" -> FileSearch.from_api(data)
      _ -> data
    end
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map
  def to_api(%Function{} = tool), do: Function.to_api(tool)
  def to_api(%GoogleSearch{} = tool), do: GoogleSearch.to_api(tool)
  def to_api(%CodeExecution{} = tool), do: CodeExecution.to_api(tool)
  def to_api(%URLContext{} = tool), do: URLContext.to_api(tool)
  def to_api(%ComputerUse{} = tool), do: ComputerUse.to_api(tool)
  def to_api(%MCPServer{} = tool), do: MCPServer.to_api(tool)
  def to_api(%FileSearch{} = tool), do: FileSearch.to_api(tool)
end
