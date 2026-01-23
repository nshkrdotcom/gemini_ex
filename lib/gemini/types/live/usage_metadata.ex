defmodule Gemini.Types.Live.UsageMetadata do
  @moduledoc """
  Usage metadata for Live API responses.

  Contains token count information about the request and response,
  including breakdowns by modality.

  ## Fields

  - `prompt_token_count` - Number of tokens in the prompt
  - `cached_content_token_count` - Number of tokens in cached content
  - `response_token_count` - Total tokens across all response candidates
  - `tool_use_prompt_token_count` - Tokens in tool-use prompts
  - `thoughts_token_count` - Tokens used for thinking
  - `total_token_count` - Total token count (prompt + response)
  - `prompt_tokens_details` - Token counts by modality for input
  - `cache_tokens_details` - Token counts by modality for cached content
  - `response_tokens_details` - Token counts by modality for response
  - `tool_use_prompt_tokens_details` - Token counts by modality for tool use

  ## Example

      %UsageMetadata{
        prompt_token_count: 100,
        response_token_count: 50,
        total_token_count: 150
      }
  """

  @type modality_token_count :: %{
          modality: String.t() | nil,
          token_count: integer() | nil
        }

  @type t :: %__MODULE__{
          prompt_token_count: integer() | nil,
          cached_content_token_count: integer() | nil,
          response_token_count: integer() | nil,
          tool_use_prompt_token_count: integer() | nil,
          thoughts_token_count: integer() | nil,
          total_token_count: integer() | nil,
          prompt_tokens_details: [modality_token_count()] | nil,
          cache_tokens_details: [modality_token_count()] | nil,
          response_tokens_details: [modality_token_count()] | nil,
          tool_use_prompt_tokens_details: [modality_token_count()] | nil
        }

  defstruct [
    :prompt_token_count,
    :cached_content_token_count,
    :response_token_count,
    :tool_use_prompt_token_count,
    :thoughts_token_count,
    :total_token_count,
    :prompt_tokens_details,
    :cache_tokens_details,
    :response_tokens_details,
    :tool_use_prompt_tokens_details
  ]

  @doc """
  Creates a new UsageMetadata.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      prompt_token_count: Keyword.get(opts, :prompt_token_count),
      cached_content_token_count: Keyword.get(opts, :cached_content_token_count),
      response_token_count: Keyword.get(opts, :response_token_count),
      tool_use_prompt_token_count: Keyword.get(opts, :tool_use_prompt_token_count),
      thoughts_token_count: Keyword.get(opts, :thoughts_token_count),
      total_token_count: Keyword.get(opts, :total_token_count),
      prompt_tokens_details: Keyword.get(opts, :prompt_tokens_details),
      cache_tokens_details: Keyword.get(opts, :cache_tokens_details),
      response_tokens_details: Keyword.get(opts, :response_tokens_details),
      tool_use_prompt_tokens_details: Keyword.get(opts, :tool_use_prompt_tokens_details)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put("promptTokenCount", value.prompt_token_count)
    |> maybe_put("cachedContentTokenCount", value.cached_content_token_count)
    |> maybe_put("responseTokenCount", value.response_token_count)
    |> maybe_put("toolUsePromptTokenCount", value.tool_use_prompt_token_count)
    |> maybe_put("thoughtsTokenCount", value.thoughts_token_count)
    |> maybe_put("totalTokenCount", value.total_token_count)
    |> maybe_put("promptTokensDetails", convert_details_to_api(value.prompt_tokens_details))
    |> maybe_put("cacheTokensDetails", convert_details_to_api(value.cache_tokens_details))
    |> maybe_put("responseTokensDetails", convert_details_to_api(value.response_tokens_details))
    |> maybe_put(
      "toolUsePromptTokensDetails",
      convert_details_to_api(value.tool_use_prompt_tokens_details)
    )
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      prompt_token_count: get_field(data, "promptTokenCount", "prompt_token_count"),
      cached_content_token_count:
        get_field(data, "cachedContentTokenCount", "cached_content_token_count"),
      response_token_count: get_field(data, "responseTokenCount", "response_token_count"),
      tool_use_prompt_token_count:
        get_field(data, "toolUsePromptTokenCount", "tool_use_prompt_token_count"),
      thoughts_token_count: get_field(data, "thoughtsTokenCount", "thoughts_token_count"),
      total_token_count: get_field(data, "totalTokenCount", "total_token_count"),
      prompt_tokens_details: get_details(data, "promptTokensDetails", "prompt_tokens_details"),
      cache_tokens_details: get_details(data, "cacheTokensDetails", "cache_tokens_details"),
      response_tokens_details:
        get_details(data, "responseTokensDetails", "response_tokens_details"),
      tool_use_prompt_tokens_details:
        get_details(data, "toolUsePromptTokensDetails", "tool_use_prompt_tokens_details")
    }
  end

  defp get_field(data, camel_key, snake_key), do: data[camel_key] || data[snake_key]

  defp get_details(data, camel_key, snake_key),
    do: parse_details(get_field(data, camel_key, snake_key))

  defp convert_details_to_api(nil), do: nil

  defp convert_details_to_api(details) when is_list(details) do
    Enum.map(details, fn detail ->
      %{
        "modality" => detail[:modality] || detail["modality"],
        "tokenCount" => detail[:token_count] || detail["tokenCount"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})
    end)
  end

  defp parse_details(nil), do: nil

  defp parse_details(details) when is_list(details) do
    Enum.map(details, fn detail ->
      %{
        modality: detail["modality"],
        token_count: detail["tokenCount"] || detail["token_count"]
      }
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
