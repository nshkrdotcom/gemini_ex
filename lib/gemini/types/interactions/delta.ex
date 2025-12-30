defmodule Gemini.Types.Interactions.DeltaTextDelta do
  @moduledoc "Text content delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.Annotation

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "text")
    field(:text, String.t(), enforce: false)
    field(:annotations, [Annotation.t()], enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "text",
      text: Map.get(data, "text"),
      annotations: map_list(Map.get(data, "annotations"), &Annotation.from_api/1)
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "text"}
    |> maybe_put("text", delta.text)
    |> maybe_put("annotations", map_list(delta.annotations, &Annotation.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end

defmodule Gemini.Types.Interactions.DeltaImageDelta do
  @moduledoc "Image content delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @type resolution :: String.t()

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "image")
    field(:data, String.t(), enforce: false)
    field(:uri, String.t(), enforce: false)
    field(:mime_type, String.t(), enforce: false)
    field(:resolution, resolution(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "image",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type"),
      resolution: Map.get(data, "resolution")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "image"}
    |> maybe_put("data", delta.data)
    |> maybe_put("uri", delta.uri)
    |> maybe_put("mime_type", delta.mime_type)
    |> maybe_put("resolution", delta.resolution)
  end
end

defmodule Gemini.Types.Interactions.DeltaAudioDelta do
  @moduledoc "Audio content delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "audio")
    field(:data, String.t(), enforce: false)
    field(:uri, String.t(), enforce: false)
    field(:mime_type, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "audio",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "audio"}
    |> maybe_put("data", delta.data)
    |> maybe_put("uri", delta.uri)
    |> maybe_put("mime_type", delta.mime_type)
  end
end

defmodule Gemini.Types.Interactions.DeltaDocumentDelta do
  @moduledoc "Document content delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "document")
    field(:data, String.t(), enforce: false)
    field(:uri, String.t(), enforce: false)
    field(:mime_type, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "document",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "document"}
    |> maybe_put("data", delta.data)
    |> maybe_put("uri", delta.uri)
    |> maybe_put("mime_type", delta.mime_type)
  end
end

defmodule Gemini.Types.Interactions.DeltaVideoDelta do
  @moduledoc "Video content delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @type resolution :: String.t()

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "video")
    field(:data, String.t(), enforce: false)
    field(:uri, String.t(), enforce: false)
    field(:mime_type, String.t(), enforce: false)
    field(:resolution, resolution(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "video",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type"),
      resolution: Map.get(data, "resolution")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "video"}
    |> maybe_put("data", delta.data)
    |> maybe_put("uri", delta.uri)
    |> maybe_put("mime_type", delta.mime_type)
    |> maybe_put("resolution", delta.resolution)
  end
end

defmodule Gemini.Types.Interactions.DeltaThoughtSummaryDeltaContent do
  @moduledoc "Content type for thought summary delta."
  @type t ::
          Gemini.Types.Interactions.TextContent.t() | Gemini.Types.Interactions.ImageContent.t()
end

defmodule Gemini.Types.Interactions.DeltaThoughtSummaryDelta do
  @moduledoc "Thought summary delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.Content
  alias Gemini.Types.Interactions.DeltaThoughtSummaryDeltaContent

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "thought_summary")
    field(:content, DeltaThoughtSummaryDeltaContent.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "thought_summary",
      content: Content.from_api(Map.get(data, "content"))
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "thought_summary"}
    |> maybe_put("content", Content.to_api(delta.content))
  end
end

defmodule Gemini.Types.Interactions.DeltaThoughtSignatureDelta do
  @moduledoc "Thought signature delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "thought_signature")
    field(:signature, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "thought_signature",
      signature: Map.get(data, "signature")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "thought_signature"}
    |> maybe_put("signature", delta.signature)
  end
end

defmodule Gemini.Types.Interactions.DeltaFunctionCallDelta do
  @moduledoc "Function call delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "function_call")
    field(:id, String.t(), enforce: false)
    field(:name, String.t(), enforce: false)
    field(:arguments, map(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "function_call",
      id: Map.get(data, "id"),
      name: Map.get(data, "name"),
      arguments: Map.get(data, "arguments")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "function_call"}
    |> maybe_put("id", delta.id)
    |> maybe_put("name", delta.name)
    |> maybe_put("arguments", delta.arguments)
  end
end

defmodule Gemini.Types.Interactions.DeltaFunctionResultDeltaResultItemsItem do
  @moduledoc "Item type for function result delta."
  @type t :: String.t() | Gemini.Types.Interactions.ImageContent.t()
end

defmodule Gemini.Types.Interactions.DeltaFunctionResultDeltaResultItems do
  @moduledoc "Items container for function result delta."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.Content
  alias Gemini.Types.Interactions.DeltaFunctionResultDeltaResultItemsItem

  @derive Jason.Encoder
  typedstruct do
    field(:items, [DeltaFunctionResultDeltaResultItemsItem.t()])
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = items), do: items

  def from_api(%{} = data) do
    parsed =
      case Map.get(data, "items") do
        nil -> nil
        list when is_list(list) -> Enum.map(list, &parse_item/1)
        _ -> nil
      end

    %__MODULE__{items: parsed}
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = items) do
    %{}
    |> maybe_put("items", map_list(items.items, &serialize_item/1))
  end

  defp parse_item(%{} = map), do: Content.from_api(map)
  defp parse_item(value), do: value

  defp serialize_item(%{} = value) when is_struct(value), do: Content.to_api(value)
  defp serialize_item(value), do: value

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end

defmodule Gemini.Types.Interactions.DeltaFunctionResultDeltaResult do
  @moduledoc "Result type for function result delta."
  alias Gemini.Types.Interactions.DeltaFunctionResultDeltaResultItems

  @type t :: DeltaFunctionResultDeltaResultItems.t() | String.t()

  @spec from_api(term()) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%DeltaFunctionResultDeltaResultItems{} = items), do: items
  def from_api(value) when is_binary(value), do: value
  def from_api(%{} = map), do: DeltaFunctionResultDeltaResultItems.from_api(map)
  def from_api(other), do: other

  @spec to_api(t() | nil) :: term()
  def to_api(nil), do: nil
  def to_api(value) when is_binary(value), do: value

  def to_api(%DeltaFunctionResultDeltaResultItems{} = items),
    do: DeltaFunctionResultDeltaResultItems.to_api(items)

  def to_api(other), do: other
end

defmodule Gemini.Types.Interactions.DeltaFunctionResultDelta do
  @moduledoc "Function result delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.DeltaFunctionResultDeltaResult

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "function_result")
    field(:call_id, String.t(), enforce: false)
    field(:is_error, boolean(), enforce: false)
    field(:name, String.t(), enforce: false)
    field(:result, DeltaFunctionResultDeltaResult.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "function_result",
      call_id: Map.get(data, "call_id"),
      is_error: Map.get(data, "is_error"),
      name: Map.get(data, "name"),
      result: DeltaFunctionResultDeltaResult.from_api(Map.get(data, "result"))
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "function_result"}
    |> maybe_put("call_id", delta.call_id)
    |> maybe_put("is_error", delta.is_error)
    |> maybe_put("name", delta.name)
    |> maybe_put("result", DeltaFunctionResultDeltaResult.to_api(delta.result))
  end
end

defmodule Gemini.Types.Interactions.DeltaCodeExecutionCallDelta do
  @moduledoc "Code execution call delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.CodeExecutionCallArguments

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "code_execution_call")
    field(:id, String.t(), enforce: false)
    field(:arguments, CodeExecutionCallArguments.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "code_execution_call",
      id: Map.get(data, "id"),
      arguments: CodeExecutionCallArguments.from_api(Map.get(data, "arguments"))
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "code_execution_call"}
    |> maybe_put("id", delta.id)
    |> maybe_put("arguments", CodeExecutionCallArguments.to_api(delta.arguments))
  end
end

defmodule Gemini.Types.Interactions.DeltaCodeExecutionResultDelta do
  @moduledoc "Code execution result delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "code_execution_result")
    field(:call_id, String.t(), enforce: false)
    field(:is_error, boolean(), enforce: false)
    field(:result, String.t(), enforce: false)
    field(:signature, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "code_execution_result",
      call_id: Map.get(data, "call_id"),
      is_error: Map.get(data, "is_error"),
      result: Map.get(data, "result"),
      signature: Map.get(data, "signature")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "code_execution_result"}
    |> maybe_put("call_id", delta.call_id)
    |> maybe_put("is_error", delta.is_error)
    |> maybe_put("result", delta.result)
    |> maybe_put("signature", delta.signature)
  end
end

defmodule Gemini.Types.Interactions.DeltaURLContextCallDelta do
  @moduledoc "URL context call delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.URLContextCallArguments

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "url_context_call")
    field(:id, String.t(), enforce: false)
    field(:arguments, URLContextCallArguments.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "url_context_call",
      id: Map.get(data, "id"),
      arguments: URLContextCallArguments.from_api(Map.get(data, "arguments"))
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "url_context_call"}
    |> maybe_put("id", delta.id)
    |> maybe_put("arguments", URLContextCallArguments.to_api(delta.arguments))
  end
end

defmodule Gemini.Types.Interactions.DeltaURLContextResultDelta do
  @moduledoc "URL context result delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.URLContextResult

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "url_context_result")
    field(:call_id, String.t(), enforce: false)
    field(:is_error, boolean(), enforce: false)
    field(:result, [URLContextResult.t()], enforce: false)
    field(:signature, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "url_context_result",
      call_id: Map.get(data, "call_id"),
      is_error: Map.get(data, "is_error"),
      result: map_list(Map.get(data, "result"), &URLContextResult.from_api/1),
      signature: Map.get(data, "signature")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "url_context_result"}
    |> maybe_put("call_id", delta.call_id)
    |> maybe_put("is_error", delta.is_error)
    |> maybe_put("result", map_list(delta.result, &URLContextResult.to_api/1))
    |> maybe_put("signature", delta.signature)
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end

defmodule Gemini.Types.Interactions.DeltaGoogleSearchCallDelta do
  @moduledoc "Google search call delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.GoogleSearchCallArguments

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "google_search_call")
    field(:id, String.t(), enforce: false)
    field(:arguments, GoogleSearchCallArguments.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "google_search_call",
      id: Map.get(data, "id"),
      arguments: GoogleSearchCallArguments.from_api(Map.get(data, "arguments"))
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "google_search_call"}
    |> maybe_put("id", delta.id)
    |> maybe_put("arguments", GoogleSearchCallArguments.to_api(delta.arguments))
  end
end

defmodule Gemini.Types.Interactions.DeltaGoogleSearchResultDelta do
  @moduledoc "Google search result delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.GoogleSearchResult

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "google_search_result")
    field(:call_id, String.t(), enforce: false)
    field(:is_error, boolean(), enforce: false)
    field(:result, [GoogleSearchResult.t()], enforce: false)
    field(:signature, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "google_search_result",
      call_id: Map.get(data, "call_id"),
      is_error: Map.get(data, "is_error"),
      result: map_list(Map.get(data, "result"), &GoogleSearchResult.from_api/1),
      signature: Map.get(data, "signature")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "google_search_result"}
    |> maybe_put("call_id", delta.call_id)
    |> maybe_put("is_error", delta.is_error)
    |> maybe_put("result", map_list(delta.result, &GoogleSearchResult.to_api/1))
    |> maybe_put("signature", delta.signature)
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end

defmodule Gemini.Types.Interactions.DeltaMCPServerToolCallDelta do
  @moduledoc "MCP server tool call delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "mcp_server_tool_call")
    field(:id, String.t(), enforce: false)
    field(:name, String.t(), enforce: false)
    field(:server_name, String.t(), enforce: false)
    field(:arguments, map(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "mcp_server_tool_call",
      id: Map.get(data, "id"),
      name: Map.get(data, "name"),
      server_name: Map.get(data, "server_name"),
      arguments: Map.get(data, "arguments")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "mcp_server_tool_call"}
    |> maybe_put("id", delta.id)
    |> maybe_put("name", delta.name)
    |> maybe_put("server_name", delta.server_name)
    |> maybe_put("arguments", delta.arguments)
  end
end

defmodule Gemini.Types.Interactions.DeltaMCPServerToolResultDeltaResultItemsItem do
  @moduledoc "Item type for MCP server tool result delta."
  @type t :: String.t() | Gemini.Types.Interactions.ImageContent.t()
end

defmodule Gemini.Types.Interactions.DeltaMCPServerToolResultDeltaResultItems do
  @moduledoc "Items container for MCP server tool result delta."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.Content
  alias Gemini.Types.Interactions.DeltaMCPServerToolResultDeltaResultItemsItem

  @derive Jason.Encoder
  typedstruct do
    field(:items, [DeltaMCPServerToolResultDeltaResultItemsItem.t()])
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = items), do: items

  def from_api(%{} = data) do
    parsed =
      case Map.get(data, "items") do
        nil -> nil
        list when is_list(list) -> Enum.map(list, &parse_item/1)
        _ -> nil
      end

    %__MODULE__{items: parsed}
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = items) do
    %{}
    |> maybe_put("items", map_list(items.items, &serialize_item/1))
  end

  defp parse_item(%{} = map), do: Content.from_api(map)
  defp parse_item(value), do: value

  defp serialize_item(%{} = value) when is_struct(value), do: Content.to_api(value)
  defp serialize_item(value), do: value

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end

defmodule Gemini.Types.Interactions.DeltaMCPServerToolResultDeltaResult do
  @moduledoc "Result type for MCP server tool result delta."
  alias Gemini.Types.Interactions.DeltaMCPServerToolResultDeltaResultItems

  @type t :: DeltaMCPServerToolResultDeltaResultItems.t() | String.t()

  @spec from_api(term()) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%DeltaMCPServerToolResultDeltaResultItems{} = items), do: items
  def from_api(value) when is_binary(value), do: value
  def from_api(%{} = map), do: DeltaMCPServerToolResultDeltaResultItems.from_api(map)
  def from_api(other), do: other

  @spec to_api(t() | nil) :: term()
  def to_api(nil), do: nil
  def to_api(value) when is_binary(value), do: value

  def to_api(%DeltaMCPServerToolResultDeltaResultItems{} = items),
    do: DeltaMCPServerToolResultDeltaResultItems.to_api(items)

  def to_api(other), do: other
end

defmodule Gemini.Types.Interactions.DeltaMCPServerToolResultDelta do
  @moduledoc "MCP server tool result delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.DeltaMCPServerToolResultDeltaResult

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "mcp_server_tool_result")
    field(:call_id, String.t(), enforce: false)
    field(:name, String.t(), enforce: false)
    field(:server_name, String.t(), enforce: false)
    field(:result, DeltaMCPServerToolResultDeltaResult.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "mcp_server_tool_result",
      call_id: Map.get(data, "call_id"),
      name: Map.get(data, "name"),
      server_name: Map.get(data, "server_name"),
      result: DeltaMCPServerToolResultDeltaResult.from_api(Map.get(data, "result"))
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "mcp_server_tool_result"}
    |> maybe_put("call_id", delta.call_id)
    |> maybe_put("name", delta.name)
    |> maybe_put("server_name", delta.server_name)
    |> maybe_put("result", DeltaMCPServerToolResultDeltaResult.to_api(delta.result))
  end
end

defmodule Gemini.Types.Interactions.DeltaFileSearchResultDeltaResult do
  @moduledoc "Result type for file search result delta."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  @derive Jason.Encoder
  typedstruct do
    field(:file_search_store, String.t())
    field(:text, String.t())
    field(:title, String.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = result), do: result

  def from_api(%{} = data) do
    %__MODULE__{
      file_search_store: Map.get(data, "file_search_store"),
      text: Map.get(data, "text"),
      title: Map.get(data, "title")
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = result) do
    %{}
    |> maybe_put("file_search_store", result.file_search_store)
    |> maybe_put("text", result.text)
    |> maybe_put("title", result.title)
  end
end

defmodule Gemini.Types.Interactions.DeltaFileSearchResultDelta do
  @moduledoc "File search result delta for streaming responses."
  use TypedStruct

  import Gemini.Utils.MapHelpers, only: [maybe_put: 3]

  alias Gemini.Types.Interactions.DeltaFileSearchResultDeltaResult

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "file_search_result")
    field(:result, [DeltaFileSearchResultDeltaResult.t()], enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = delta), do: delta

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "file_search_result",
      result: map_list(Map.get(data, "result"), &DeltaFileSearchResultDeltaResult.from_api/1)
    }
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = delta) do
    %{"type" => "file_search_result"}
    |> maybe_put("result", map_list(delta.result, &DeltaFileSearchResultDeltaResult.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)
end

defmodule Gemini.Types.Interactions.Delta do
  @moduledoc """
  Discriminated union for `content.delta.delta` payloads (18 variants).
  """

  alias Gemini.Types.Interactions.{
    DeltaAudioDelta,
    DeltaCodeExecutionCallDelta,
    DeltaCodeExecutionResultDelta,
    DeltaDocumentDelta,
    DeltaFileSearchResultDelta,
    DeltaFunctionCallDelta,
    DeltaFunctionResultDelta,
    DeltaGoogleSearchCallDelta,
    DeltaGoogleSearchResultDelta,
    DeltaImageDelta,
    DeltaMCPServerToolCallDelta,
    DeltaMCPServerToolResultDelta,
    DeltaTextDelta,
    DeltaThoughtSignatureDelta,
    DeltaThoughtSummaryDelta,
    DeltaURLContextCallDelta,
    DeltaURLContextResultDelta,
    DeltaVideoDelta
  }

  @type t ::
          DeltaTextDelta.t()
          | DeltaImageDelta.t()
          | DeltaAudioDelta.t()
          | DeltaDocumentDelta.t()
          | DeltaVideoDelta.t()
          | DeltaThoughtSummaryDelta.t()
          | DeltaThoughtSignatureDelta.t()
          | DeltaFunctionCallDelta.t()
          | DeltaFunctionResultDelta.t()
          | DeltaCodeExecutionCallDelta.t()
          | DeltaCodeExecutionResultDelta.t()
          | DeltaURLContextCallDelta.t()
          | DeltaURLContextResultDelta.t()
          | DeltaGoogleSearchCallDelta.t()
          | DeltaGoogleSearchResultDelta.t()
          | DeltaMCPServerToolCallDelta.t()
          | DeltaMCPServerToolResultDelta.t()
          | DeltaFileSearchResultDelta.t()
          | map()

  @type_to_module %{
    "text" => DeltaTextDelta,
    "image" => DeltaImageDelta,
    "audio" => DeltaAudioDelta,
    "document" => DeltaDocumentDelta,
    "video" => DeltaVideoDelta,
    "thought_summary" => DeltaThoughtSummaryDelta,
    "thought_signature" => DeltaThoughtSignatureDelta,
    "function_call" => DeltaFunctionCallDelta,
    "function_result" => DeltaFunctionResultDelta,
    "code_execution_call" => DeltaCodeExecutionCallDelta,
    "code_execution_result" => DeltaCodeExecutionResultDelta,
    "url_context_call" => DeltaURLContextCallDelta,
    "url_context_result" => DeltaURLContextResultDelta,
    "google_search_call" => DeltaGoogleSearchCallDelta,
    "google_search_result" => DeltaGoogleSearchResultDelta,
    "mcp_server_tool_call" => DeltaMCPServerToolCallDelta,
    "mcp_server_tool_result" => DeltaMCPServerToolResultDelta,
    "file_search_result" => DeltaFileSearchResultDelta
  }

  @spec from_api(map() | t() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%_{} = delta), do: delta

  def from_api(%{} = data) do
    data
    |> Map.get("type")
    |> then(&Map.get(@type_to_module, &1))
    |> case do
      nil -> data
      module -> module.from_api(data)
    end
  end

  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map
  def to_api(%DeltaTextDelta{} = delta), do: DeltaTextDelta.to_api(delta)
  def to_api(%DeltaImageDelta{} = delta), do: DeltaImageDelta.to_api(delta)
  def to_api(%DeltaAudioDelta{} = delta), do: DeltaAudioDelta.to_api(delta)
  def to_api(%DeltaDocumentDelta{} = delta), do: DeltaDocumentDelta.to_api(delta)
  def to_api(%DeltaVideoDelta{} = delta), do: DeltaVideoDelta.to_api(delta)
  def to_api(%DeltaThoughtSummaryDelta{} = delta), do: DeltaThoughtSummaryDelta.to_api(delta)
  def to_api(%DeltaThoughtSignatureDelta{} = delta), do: DeltaThoughtSignatureDelta.to_api(delta)
  def to_api(%DeltaFunctionCallDelta{} = delta), do: DeltaFunctionCallDelta.to_api(delta)
  def to_api(%DeltaFunctionResultDelta{} = delta), do: DeltaFunctionResultDelta.to_api(delta)

  def to_api(%DeltaCodeExecutionCallDelta{} = delta),
    do: DeltaCodeExecutionCallDelta.to_api(delta)

  def to_api(%DeltaCodeExecutionResultDelta{} = delta),
    do: DeltaCodeExecutionResultDelta.to_api(delta)

  def to_api(%DeltaURLContextCallDelta{} = delta), do: DeltaURLContextCallDelta.to_api(delta)
  def to_api(%DeltaURLContextResultDelta{} = delta), do: DeltaURLContextResultDelta.to_api(delta)
  def to_api(%DeltaGoogleSearchCallDelta{} = delta), do: DeltaGoogleSearchCallDelta.to_api(delta)

  def to_api(%DeltaGoogleSearchResultDelta{} = delta),
    do: DeltaGoogleSearchResultDelta.to_api(delta)

  def to_api(%DeltaMCPServerToolCallDelta{} = delta),
    do: DeltaMCPServerToolCallDelta.to_api(delta)

  def to_api(%DeltaMCPServerToolResultDelta{} = delta),
    do: DeltaMCPServerToolResultDelta.to_api(delta)

  def to_api(%DeltaFileSearchResultDelta{} = delta), do: DeltaFileSearchResultDelta.to_api(delta)
end
