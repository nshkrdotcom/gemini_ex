defmodule Gemini.Types.Content do
  @moduledoc """
  Content type for Gemini API requests and responses.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:role, String.t(), default: "user")
    field(:parts, [Gemini.Types.Part.t()], default: [])
  end

  @typedoc "The role of the content creator."
  @type role :: String.t()

  @typedoc "Ordered parts that constitute a single message."
  @type parts :: [Gemini.Types.Part.t()]

  @doc """
  Create content with text.
  """
  @spec text(String.t(), String.t()) :: t()
  def text(text, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [Gemini.Types.Part.text(text)]
    }
  end

  @doc """
  Create content with text and image.
  """
  @spec multimodal(String.t(), String.t(), String.t(), String.t()) :: t()
  def multimodal(text, image_data, mime_type, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [
        Gemini.Types.Part.text(text),
        Gemini.Types.Part.inline_data(image_data, mime_type)
      ]
    }
  end

  @doc """
  Create content with an image from a file path.
  """
  @spec image(String.t(), String.t()) :: t()
  def image(path, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [Gemini.Types.Part.file(path)]
    }
  end

  @doc """
  Create content from tool results for function response.

  Takes a list of validated ToolResult structs and transforms them into
  a single Content struct with role "tool" containing functionResponse parts.

  ## Parameters
    - `results` - List of Altar.ADM.ToolResult.t() structs

  ## Returns
    - Content struct with role "tool" and functionResponse parts

  ## Examples

      iex> results = [%Altar.ADM.ToolResult{call_id: "call_123", content: "result"}]
      iex> Gemini.Types.Content.from_tool_results(results)
      %Gemini.Types.Content{
        role: "tool",
        parts: [%{functionResponse: %{name: "call_123", response: %{content: "result"}}}]
      }

  """
  @spec from_tool_results([Altar.ADM.ToolResult.t()]) :: t()
  def from_tool_results(results) when is_list(results) do
    parts =
      Enum.map(results, fn result ->
        %{
          "functionResponse" => %{
            "name" => result.call_id,
            "response" => %{"content" => result.content}
          }
        }
      end)

    %__MODULE__{
      role: "tool",
      parts: parts
    }
  end
end
