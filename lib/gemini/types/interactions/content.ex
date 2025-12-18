defmodule Gemini.Types.Interactions.Annotation do
  @moduledoc """
  Citation information for model-generated text.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:start_index, non_neg_integer())
    field(:end_index, non_neg_integer())
    field(:source, String.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = annotation), do: annotation

  def from_api(%{} = data) do
    %__MODULE__{
      start_index: Map.get(data, "start_index"),
      end_index: Map.get(data, "end_index"),
      source: Map.get(data, "source")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = annotation) do
    %{}
    |> maybe_put("start_index", annotation.start_index)
    |> maybe_put("end_index", annotation.end_index)
    |> maybe_put("source", annotation.source)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.TextContent do
  @moduledoc """
  A text content block (`type: "text"`).
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Annotation

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "text")
    field(:text, String.t(), enforce: false)
    field(:annotations, [Annotation.t()], enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "text",
      text: Map.get(data, "text"),
      annotations: map_list(Map.get(data, "annotations"), &Annotation.from_api/1)
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "text"}
    |> maybe_put("text", content.text)
    |> maybe_put("annotations", map_list(content.annotations, &Annotation.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.ImageContent do
  @moduledoc """
  An image content block (`type: "image"`).
  """

  use TypedStruct

  @type resolution :: :low | :medium | :high | :ultra_high | String.t()

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
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "image",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type"),
      resolution: Map.get(data, "resolution")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "image"}
    |> maybe_put("data", content.data)
    |> maybe_put("uri", content.uri)
    |> maybe_put("mime_type", content.mime_type)
    |> maybe_put("resolution", content.resolution)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.AudioContent do
  @moduledoc """
  An audio content block (`type: "audio"`).
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "audio")
    field(:data, String.t(), enforce: false)
    field(:uri, String.t(), enforce: false)
    field(:mime_type, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "audio",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "audio"}
    |> maybe_put("data", content.data)
    |> maybe_put("uri", content.uri)
    |> maybe_put("mime_type", content.mime_type)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.DocumentContent do
  @moduledoc """
  A document content block (`type: "document"`).

  ## Supported MIME Types

  - `"application/pdf"` - PDF documents
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "document")
    field(:data, String.t(), enforce: false)
    field(:uri, String.t(), enforce: false)
    field(:mime_type, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "document",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "document"}
    |> maybe_put("data", content.data)
    |> maybe_put("uri", content.uri)
    |> maybe_put("mime_type", content.mime_type)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.VideoContent do
  @moduledoc """
  A video content block (`type: "video"`).
  """

  use TypedStruct

  @type resolution :: :low | :medium | :high | :ultra_high | String.t()

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
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "video",
      data: Map.get(data, "data"),
      uri: Map.get(data, "uri"),
      mime_type: Map.get(data, "mime_type"),
      resolution: Map.get(data, "resolution")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "video"}
    |> maybe_put("data", content.data)
    |> maybe_put("uri", content.uri)
    |> maybe_put("mime_type", content.mime_type)
    |> maybe_put("resolution", content.resolution)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.ThoughtContent do
  @moduledoc """
  A thought content block (`type: "thought"`).
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Content

  @type summary_item ::
          Gemini.Types.Interactions.TextContent.t() | Gemini.Types.Interactions.ImageContent.t()

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "thought")
    field(:signature, String.t(), enforce: false)
    field(:summary, [summary_item()], enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    summary =
      case Map.get(data, "summary") do
        nil -> nil
        list when is_list(list) -> Enum.map(list, &Content.from_api/1)
        _ -> nil
      end

    %__MODULE__{
      type: Map.get(data, "type") || "thought",
      signature: Map.get(data, "signature"),
      summary: summary
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "thought"}
    |> maybe_put("signature", content.signature)
    |> maybe_put("summary", map_list(content.summary, &Content.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.FunctionCallContent do
  @moduledoc """
  A function tool call content block (`type: "function_call"`).
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:id, String.t())
    field(:name, String.t())
    field(:arguments, map())
    field(:type, String.t(), enforce: true, default: "function_call")
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      name: Map.get(data, "name"),
      arguments: Map.get(data, "arguments") || %{},
      type: Map.get(data, "type") || "function_call"
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{
      "type" => "function_call",
      "id" => content.id,
      "name" => content.name,
      "arguments" => content.arguments
    }
  end
end

defmodule Gemini.Types.Interactions.FunctionResultContent do
  @moduledoc """
  A function tool result content block (`type: "function_result"`).

  The `result` payload may include strings, image content blocks, or arbitrary
  structured data returned by tools.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Content

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:call_id, String.t())
    field(:result, term())
    field(:type, String.t(), enforce: true, default: "function_result")
    field(:is_error, boolean(), enforce: false)
    field(:name, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      call_id: Map.get(data, "call_id"),
      result: parse_result(Map.get(data, "result")),
      type: Map.get(data, "type") || "function_result",
      is_error: Map.get(data, "is_error"),
      name: Map.get(data, "name")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{
      "type" => "function_result",
      "call_id" => content.call_id,
      "result" => serialize_result(content.result)
    }
    |> maybe_put("is_error", content.is_error)
    |> maybe_put("name", content.name)
  end

  defp parse_result(%{"items" => items} = value) when is_list(items) do
    Map.put(value, "items", Enum.map(items, &parse_result_item/1))
  end

  defp parse_result(value), do: value

  defp parse_result_item(%{} = map), do: Content.from_api(map)
  defp parse_result_item(value), do: value

  defp serialize_result(%{"items" => items} = value) when is_list(items) do
    Map.put(value, "items", Enum.map(items, &serialize_result_item/1))
  end

  defp serialize_result(value), do: value

  defp serialize_result_item(%{} = map) when is_struct(map), do: Content.to_api(map)
  defp serialize_result_item(value), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.CodeExecutionCallArguments do
  @moduledoc """
  Arguments for a `code_execution_call` content block.
  """

  use TypedStruct

  @type language :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:code, String.t())
    field(:language, language())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = args), do: args

  def from_api(%{} = data) do
    %__MODULE__{
      code: Map.get(data, "code"),
      language: Map.get(data, "language")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = args) do
    %{}
    |> maybe_put("code", args.code)
    |> maybe_put("language", args.language)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.CodeExecutionCallContent do
  @moduledoc """
  Code execution call content block (`type: "code_execution_call"`).
  """

  use TypedStruct

  alias Gemini.Types.Interactions.CodeExecutionCallArguments

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "code_execution_call")
    field(:id, String.t(), enforce: false)
    field(:arguments, CodeExecutionCallArguments.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "code_execution_call",
      id: Map.get(data, "id"),
      arguments: CodeExecutionCallArguments.from_api(Map.get(data, "arguments"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "code_execution_call"}
    |> maybe_put("id", content.id)
    |> maybe_put("arguments", CodeExecutionCallArguments.to_api(content.arguments))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.CodeExecutionResultContent do
  @moduledoc """
  Code execution result content block (`type: "code_execution_result"`).
  """

  use TypedStruct

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
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "code_execution_result",
      call_id: Map.get(data, "call_id"),
      is_error: Map.get(data, "is_error"),
      result: Map.get(data, "result"),
      signature: Map.get(data, "signature")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "code_execution_result"}
    |> maybe_put("call_id", content.call_id)
    |> maybe_put("is_error", content.is_error)
    |> maybe_put("result", content.result)
    |> maybe_put("signature", content.signature)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.URLContextCallArguments do
  @moduledoc """
  Arguments for a `url_context_call` content block.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:urls, [String.t()])
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = args), do: args

  def from_api(%{} = data) do
    %__MODULE__{
      urls: Map.get(data, "urls")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = args) do
    %{}
    |> maybe_put("urls", args.urls)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.URLContextCallContent do
  @moduledoc """
  URL context call content block (`type: "url_context_call"`).
  """

  use TypedStruct

  alias Gemini.Types.Interactions.URLContextCallArguments

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "url_context_call")
    field(:id, String.t(), enforce: false)
    field(:arguments, URLContextCallArguments.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "url_context_call",
      id: Map.get(data, "id"),
      arguments: URLContextCallArguments.from_api(Map.get(data, "arguments"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "url_context_call"}
    |> maybe_put("id", content.id)
    |> maybe_put("arguments", URLContextCallArguments.to_api(content.arguments))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.URLContextResult do
  @moduledoc """
  URL context result item (`{status, url}`).
  """

  use TypedStruct

  @type status :: String.t()

  @derive Jason.Encoder
  typedstruct do
    field(:status, status())
    field(:url, String.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = result), do: result

  def from_api(%{} = data) do
    %__MODULE__{
      status: Map.get(data, "status"),
      url: Map.get(data, "url")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = result) do
    %{}
    |> maybe_put("status", result.status)
    |> maybe_put("url", result.url)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.URLContextResultContent do
  @moduledoc """
  URL context result content block (`type: "url_context_result"`).
  """

  use TypedStruct

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
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "url_context_result",
      call_id: Map.get(data, "call_id"),
      is_error: Map.get(data, "is_error"),
      result: map_list(Map.get(data, "result"), &URLContextResult.from_api/1),
      signature: Map.get(data, "signature")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "url_context_result"}
    |> maybe_put("call_id", content.call_id)
    |> maybe_put("is_error", content.is_error)
    |> maybe_put("result", map_list(content.result, &URLContextResult.to_api/1))
    |> maybe_put("signature", content.signature)
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.GoogleSearchCallArguments do
  @moduledoc """
  Arguments for a `google_search_call` content block.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:queries, [String.t()])
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = args), do: args

  def from_api(%{} = data) do
    %__MODULE__{
      queries: Map.get(data, "queries")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = args) do
    %{}
    |> maybe_put("queries", args.queries)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.GoogleSearchCallContent do
  @moduledoc """
  Google Search call content block (`type: "google_search_call"`).
  """

  use TypedStruct

  alias Gemini.Types.Interactions.GoogleSearchCallArguments

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "google_search_call")
    field(:id, String.t(), enforce: false)
    field(:arguments, GoogleSearchCallArguments.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "google_search_call",
      id: Map.get(data, "id"),
      arguments: GoogleSearchCallArguments.from_api(Map.get(data, "arguments"))
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "google_search_call"}
    |> maybe_put("id", content.id)
    |> maybe_put("arguments", GoogleSearchCallArguments.to_api(content.arguments))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.GoogleSearchResult do
  @moduledoc """
  A Google Search result item.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:rendered_content, String.t())
    field(:title, String.t())
    field(:url, String.t())
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = result), do: result

  def from_api(%{} = data) do
    %__MODULE__{
      rendered_content: Map.get(data, "rendered_content"),
      title: Map.get(data, "title"),
      url: Map.get(data, "url")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = result) do
    %{}
    |> maybe_put("rendered_content", result.rendered_content)
    |> maybe_put("title", result.title)
    |> maybe_put("url", result.url)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.GoogleSearchResultContent do
  @moduledoc """
  Google Search result content block (`type: "google_search_result"`).
  """

  use TypedStruct

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
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "google_search_result",
      call_id: Map.get(data, "call_id"),
      is_error: Map.get(data, "is_error"),
      result: map_list(Map.get(data, "result"), &GoogleSearchResult.from_api/1),
      signature: Map.get(data, "signature")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "google_search_result"}
    |> maybe_put("call_id", content.call_id)
    |> maybe_put("is_error", content.is_error)
    |> maybe_put("result", map_list(content.result, &GoogleSearchResult.to_api/1))
    |> maybe_put("signature", content.signature)
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.MCPServerToolCallContent do
  @moduledoc """
  MCP server tool call content block (`type: "mcp_server_tool_call"`).
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:id, String.t())
    field(:name, String.t())
    field(:server_name, String.t())
    field(:arguments, map())
    field(:type, String.t(), enforce: true, default: "mcp_server_tool_call")
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      name: Map.get(data, "name"),
      server_name: Map.get(data, "server_name"),
      arguments: Map.get(data, "arguments") || %{},
      type: Map.get(data, "type") || "mcp_server_tool_call"
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{
      "type" => "mcp_server_tool_call",
      "id" => content.id,
      "name" => content.name,
      "server_name" => content.server_name,
      "arguments" => content.arguments
    }
  end
end

defmodule Gemini.Types.Interactions.MCPServerToolResultContent do
  @moduledoc """
  MCP server tool result content block (`type: "mcp_server_tool_result"`).

  The `result` payload may include strings, image content blocks, or arbitrary
  structured data returned by the MCP server.
  """

  use TypedStruct

  alias Gemini.Types.Interactions.Content

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:call_id, String.t())
    field(:result, term())
    field(:type, String.t(), enforce: true, default: "mcp_server_tool_result")
    field(:name, String.t(), enforce: false)
    field(:server_name, String.t(), enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      call_id: Map.get(data, "call_id"),
      result: parse_result(Map.get(data, "result")),
      type: Map.get(data, "type") || "mcp_server_tool_result",
      name: Map.get(data, "name"),
      server_name: Map.get(data, "server_name")
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{
      "type" => "mcp_server_tool_result",
      "call_id" => content.call_id,
      "result" => serialize_result(content.result)
    }
    |> maybe_put("name", content.name)
    |> maybe_put("server_name", content.server_name)
  end

  defp parse_result(%{"items" => items} = value) when is_list(items) do
    Map.put(value, "items", Enum.map(items, &parse_result_item/1))
  end

  defp parse_result(value), do: value

  defp parse_result_item(%{} = map), do: Content.from_api(map)
  defp parse_result_item(value), do: value

  defp serialize_result(%{"items" => items} = value) when is_list(items) do
    Map.put(value, "items", Enum.map(items, &serialize_result_item/1))
  end

  defp serialize_result(value), do: value

  defp serialize_result_item(%{} = map) when is_struct(map), do: Content.to_api(map)
  defp serialize_result_item(value), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.FileSearchResult do
  @moduledoc """
  An item inside `file_search_result` results.
  """

  use TypedStruct

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

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = result) do
    %{}
    |> maybe_put("file_search_store", result.file_search_store)
    |> maybe_put("text", result.text)
    |> maybe_put("title", result.title)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.FileSearchResultContent do
  @moduledoc """
  File Search result content block (`type: "file_search_result"`).
  """

  use TypedStruct

  alias Gemini.Types.Interactions.FileSearchResult

  @derive Jason.Encoder
  typedstruct enforce: true do
    field(:type, String.t(), enforce: true, default: "file_search_result")
    field(:result, [FileSearchResult.t()], enforce: false)
  end

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%__MODULE__{} = content), do: content

  def from_api(%{} = data) do
    %__MODULE__{
      type: Map.get(data, "type") || "file_search_result",
      result: map_list(Map.get(data, "result"), &FileSearchResult.from_api/1)
    }
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%__MODULE__{} = content) do
    %{"type" => "file_search_result"}
    |> maybe_put("result", map_list(content.result, &FileSearchResult.to_api/1))
  end

  defp map_list(nil, _fun), do: nil
  defp map_list(list, fun) when is_list(list), do: Enum.map(list, fun)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Gemini.Types.Interactions.Content do
  @moduledoc """
  Union type for Interactions input/output content blocks.
  """

  alias Gemini.Types.Interactions.{
    AudioContent,
    CodeExecutionCallContent,
    CodeExecutionResultContent,
    DocumentContent,
    FileSearchResultContent,
    FunctionCallContent,
    FunctionResultContent,
    GoogleSearchCallContent,
    GoogleSearchResultContent,
    ImageContent,
    MCPServerToolCallContent,
    MCPServerToolResultContent,
    TextContent,
    ThoughtContent,
    URLContextCallContent,
    URLContextResultContent,
    VideoContent
  }

  @type t ::
          TextContent.t()
          | ImageContent.t()
          | AudioContent.t()
          | DocumentContent.t()
          | VideoContent.t()
          | ThoughtContent.t()
          | FunctionCallContent.t()
          | FunctionResultContent.t()
          | CodeExecutionCallContent.t()
          | CodeExecutionResultContent.t()
          | URLContextCallContent.t()
          | URLContextResultContent.t()
          | GoogleSearchCallContent.t()
          | GoogleSearchResultContent.t()
          | MCPServerToolCallContent.t()
          | MCPServerToolResultContent.t()
          | FileSearchResultContent.t()

  @spec from_api(map() | t() | nil) :: t() | nil
  def from_api(nil), do: nil
  def from_api(%_{} = content), do: content

  def from_api(%{} = data) do
    case Map.get(data, "type") do
      "text" -> TextContent.from_api(data)
      "image" -> ImageContent.from_api(data)
      "audio" -> AudioContent.from_api(data)
      "document" -> DocumentContent.from_api(data)
      "video" -> VideoContent.from_api(data)
      "thought" -> ThoughtContent.from_api(data)
      "function_call" -> FunctionCallContent.from_api(data)
      "function_result" -> FunctionResultContent.from_api(data)
      "code_execution_call" -> CodeExecutionCallContent.from_api(data)
      "code_execution_result" -> CodeExecutionResultContent.from_api(data)
      "url_context_call" -> URLContextCallContent.from_api(data)
      "url_context_result" -> URLContextResultContent.from_api(data)
      "google_search_call" -> GoogleSearchCallContent.from_api(data)
      "google_search_result" -> GoogleSearchResultContent.from_api(data)
      "mcp_server_tool_call" -> MCPServerToolCallContent.from_api(data)
      "mcp_server_tool_result" -> MCPServerToolResultContent.from_api(data)
      "file_search_result" -> FileSearchResultContent.from_api(data)
      _ -> nil
    end
  end

  @spec to_api(t() | map() | nil) :: map() | nil
  def to_api(nil), do: nil
  def to_api(%{} = map) when not is_struct(map), do: map

  def to_api(%TextContent{} = content), do: TextContent.to_api(content)
  def to_api(%ImageContent{} = content), do: ImageContent.to_api(content)
  def to_api(%AudioContent{} = content), do: AudioContent.to_api(content)
  def to_api(%DocumentContent{} = content), do: DocumentContent.to_api(content)
  def to_api(%VideoContent{} = content), do: VideoContent.to_api(content)
  def to_api(%ThoughtContent{} = content), do: ThoughtContent.to_api(content)
  def to_api(%FunctionCallContent{} = content), do: FunctionCallContent.to_api(content)
  def to_api(%FunctionResultContent{} = content), do: FunctionResultContent.to_api(content)
  def to_api(%CodeExecutionCallContent{} = content), do: CodeExecutionCallContent.to_api(content)

  def to_api(%CodeExecutionResultContent{} = content),
    do: CodeExecutionResultContent.to_api(content)

  def to_api(%URLContextCallContent{} = content), do: URLContextCallContent.to_api(content)
  def to_api(%URLContextResultContent{} = content), do: URLContextResultContent.to_api(content)
  def to_api(%GoogleSearchCallContent{} = content), do: GoogleSearchCallContent.to_api(content)

  def to_api(%GoogleSearchResultContent{} = content),
    do: GoogleSearchResultContent.to_api(content)

  def to_api(%MCPServerToolCallContent{} = content), do: MCPServerToolCallContent.to_api(content)

  def to_api(%MCPServerToolResultContent{} = content),
    do: MCPServerToolResultContent.to_api(content)

  def to_api(%FileSearchResultContent{} = content), do: FileSearchResultContent.to_api(content)
end
