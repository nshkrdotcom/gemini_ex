defmodule Gemini.Types.Live.GroundingMetadata do
  @moduledoc """
  Grounding metadata for Live API responses.

  Contains information about sources and attributions for grounded content.

  ## Fields

  - `grounding_attributions` - List of grounding attributions
  - `web_search_queries` - Search queries used for grounding
  - `search_entry_point` - Entry point for search
  - `retrieval_queries` - Retrieval queries used

  ## Example

      %GroundingMetadata{
        web_search_queries: ["weather today"],
        grounding_attributions: [%{source: "...", confidence: "HIGH"}]
      }
  """

  @type grounding_attribution :: %{
          source_id: map() | nil,
          content: map() | nil,
          segment: map() | nil,
          confidence_score: float() | nil
        }

  @type search_entry_point :: %{
          rendered_content: String.t() | nil,
          sdk_blob: String.t() | nil
        }

  @type t :: %__MODULE__{
          grounding_attributions: [grounding_attribution()] | nil,
          web_search_queries: [String.t()] | nil,
          search_entry_point: search_entry_point() | nil,
          retrieval_queries: [String.t()] | nil
        }

  defstruct [
    :grounding_attributions,
    :web_search_queries,
    :search_entry_point,
    :retrieval_queries
  ]

  @doc """
  Creates a new GroundingMetadata.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      grounding_attributions: Keyword.get(opts, :grounding_attributions),
      web_search_queries: Keyword.get(opts, :web_search_queries),
      search_entry_point: Keyword.get(opts, :search_entry_point),
      retrieval_queries: Keyword.get(opts, :retrieval_queries)
    }
  end

  @doc """
  Converts to API format (camelCase).
  """
  @spec to_api(t() | nil) :: map() | nil
  def to_api(nil), do: nil

  def to_api(%__MODULE__{} = value) do
    %{}
    |> maybe_put(
      "groundingAttributions",
      convert_attributions_to_api(value.grounding_attributions)
    )
    |> maybe_put("webSearchQueries", value.web_search_queries)
    |> maybe_put("searchEntryPoint", convert_search_entry_point_to_api(value.search_entry_point))
    |> maybe_put("retrievalQueries", value.retrieval_queries)
  end

  @doc """
  Parses from API response.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      grounding_attributions:
        parse_attributions(data["groundingAttributions"] || data["grounding_attributions"]),
      web_search_queries: data["webSearchQueries"] || data["web_search_queries"],
      search_entry_point:
        parse_search_entry_point(data["searchEntryPoint"] || data["search_entry_point"]),
      retrieval_queries: data["retrievalQueries"] || data["retrieval_queries"]
    }
  end

  defp convert_attributions_to_api(nil), do: nil

  defp convert_attributions_to_api(attributions) when is_list(attributions) do
    Enum.map(attributions, fn attr ->
      %{}
      |> maybe_put("sourceId", attr[:source_id])
      |> maybe_put("content", attr[:content])
      |> maybe_put("segment", attr[:segment])
      |> maybe_put("confidenceScore", attr[:confidence_score])
    end)
  end

  defp convert_search_entry_point_to_api(nil), do: nil

  defp convert_search_entry_point_to_api(entry) do
    %{}
    |> maybe_put("renderedContent", entry[:rendered_content])
    |> maybe_put("sdkBlob", entry[:sdk_blob])
  end

  defp parse_attributions(nil), do: nil

  defp parse_attributions(attributions) when is_list(attributions) do
    Enum.map(attributions, fn attr ->
      %{
        source_id: attr["sourceId"] || attr["source_id"],
        content: attr["content"],
        segment: attr["segment"],
        confidence_score: attr["confidenceScore"] || attr["confidence_score"]
      }
    end)
  end

  defp parse_search_entry_point(nil), do: nil

  defp parse_search_entry_point(entry) do
    %{
      rendered_content: entry["renderedContent"] || entry["rendered_content"],
      sdk_blob: entry["sdkBlob"] || entry["sdk_blob"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
