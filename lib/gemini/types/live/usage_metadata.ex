defmodule Gemini.Types.Live.UsageMetadata do
  @moduledoc """
  Usage metadata for Live API responses.

  Contains token count information about the request and response,
  including breakdowns by modality.

  ## Fields

  - `prompt_token_count` - Number of tokens in the prompt
  - `cached_content_token_count` - Number of tokens in cached content
  - `candidates_token_count` - Canonical output token count across Gemini Live and Vertex Live
  - `response_token_count` - Backwards-compatible alias for Gemini Live `responseTokenCount`
  - `tool_use_prompt_token_count` - Tokens in tool-use prompts
  - `thoughts_token_count` - Tokens used for thinking
  - `total_token_count` - Total token count (prompt + response)
  - `prompt_tokens_details` - Token counts by modality for input
  - `cache_tokens_details` - Token counts by modality for cached content
  - `candidates_tokens_details` - Canonical output token details across Gemini Live and Vertex Live
  - `response_tokens_details` - Backwards-compatible alias for Gemini Live `responseTokensDetails`
  - `tool_use_prompt_tokens_details` - Token counts by modality for tool use

  ## Example

      %UsageMetadata{
        prompt_token_count: 100,
        candidates_token_count: 50,
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
          candidates_token_count: integer() | nil,
          response_token_count: integer() | nil,
          tool_use_prompt_token_count: integer() | nil,
          thoughts_token_count: integer() | nil,
          total_token_count: integer() | nil,
          prompt_tokens_details: [modality_token_count()] | nil,
          cache_tokens_details: [modality_token_count()] | nil,
          candidates_tokens_details: [modality_token_count()] | nil,
          response_tokens_details: [modality_token_count()] | nil,
          tool_use_prompt_tokens_details: [modality_token_count()] | nil
        }

  defstruct [
    :prompt_token_count,
    :cached_content_token_count,
    :candidates_token_count,
    :response_token_count,
    :tool_use_prompt_token_count,
    :thoughts_token_count,
    :total_token_count,
    :prompt_tokens_details,
    :cache_tokens_details,
    :candidates_tokens_details,
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
      candidates_token_count: Keyword.get(opts, :candidates_token_count),
      response_token_count: Keyword.get(opts, :response_token_count),
      tool_use_prompt_token_count: Keyword.get(opts, :tool_use_prompt_token_count),
      thoughts_token_count: Keyword.get(opts, :thoughts_token_count),
      total_token_count: Keyword.get(opts, :total_token_count),
      prompt_tokens_details: Keyword.get(opts, :prompt_tokens_details),
      cache_tokens_details: Keyword.get(opts, :cache_tokens_details),
      candidates_tokens_details: Keyword.get(opts, :candidates_tokens_details),
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
    |> maybe_put("candidatesTokenCount", output_token_count(value))
    |> maybe_put("toolUsePromptTokenCount", value.tool_use_prompt_token_count)
    |> maybe_put("thoughtsTokenCount", value.thoughts_token_count)
    |> maybe_put("totalTokenCount", value.total_token_count)
    |> maybe_put("promptTokensDetails", convert_details_to_api(value.prompt_tokens_details))
    |> maybe_put("cacheTokensDetails", convert_details_to_api(value.cache_tokens_details))
    |> maybe_put("candidatesTokensDetails", convert_details_to_api(output_tokens_details(value)))
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
      candidates_token_count:
        get_output_field(
          data,
          "candidatesTokenCount",
          "candidates_token_count",
          "responseTokenCount",
          "response_token_count"
        ),
      response_token_count:
        get_output_field(
          data,
          "responseTokenCount",
          "response_token_count",
          "candidatesTokenCount",
          "candidates_token_count"
        ),
      tool_use_prompt_token_count:
        get_field(data, "toolUsePromptTokenCount", "tool_use_prompt_token_count"),
      thoughts_token_count: get_field(data, "thoughtsTokenCount", "thoughts_token_count"),
      total_token_count: get_field(data, "totalTokenCount", "total_token_count"),
      prompt_tokens_details: get_details(data, "promptTokensDetails", "prompt_tokens_details"),
      cache_tokens_details: get_details(data, "cacheTokensDetails", "cache_tokens_details"),
      candidates_tokens_details:
        get_output_details(
          data,
          "candidatesTokensDetails",
          "candidates_tokens_details",
          "responseTokensDetails",
          "response_tokens_details"
        ),
      response_tokens_details:
        get_output_details(
          data,
          "responseTokensDetails",
          "response_tokens_details",
          "candidatesTokensDetails",
          "candidates_tokens_details"
        ),
      tool_use_prompt_tokens_details:
        get_details(data, "toolUsePromptTokensDetails", "tool_use_prompt_tokens_details")
    }
  end

  @doc """
  Returns the normalized output token count for either Gemini Live
  (`responseTokenCount`) or Vertex Live (`candidatesTokenCount`) payloads.
  """
  @spec output_token_count(t() | nil) :: integer() | nil
  def output_token_count(nil), do: nil

  def output_token_count(%__MODULE__{} = value) do
    value.candidates_token_count || value.response_token_count
  end

  @doc """
  Returns the normalized output token details for either Gemini Live
  (`responseTokensDetails`) or Vertex Live (`candidatesTokensDetails`) payloads.
  """
  @spec output_tokens_details(t() | nil) :: [modality_token_count()] | nil
  def output_tokens_details(nil), do: nil

  def output_tokens_details(%__MODULE__{} = value) do
    value.candidates_tokens_details || value.response_tokens_details
  end

  defp get_field(data, camel_key, snake_key), do: data[camel_key] || data[snake_key]

  defp get_details(data, camel_key, snake_key),
    do: parse_details(get_field(data, camel_key, snake_key))

  defp get_output_field(data, primary_camel, primary_snake, fallback_camel, fallback_snake) do
    get_field(data, primary_camel, primary_snake) ||
      get_field(data, fallback_camel, fallback_snake)
  end

  defp get_output_details(data, primary_camel, primary_snake, fallback_camel, fallback_snake) do
    get_details(data, primary_camel, primary_snake) ||
      get_details(data, fallback_camel, fallback_snake)
  end

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
