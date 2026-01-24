defmodule Gemini.Types.Response do
  @moduledoc """
  Response types for the Gemini API.
  """

  alias Gemini.Types.{Content, Part}

  alias Gemini.Types.Response.{
    GroundingAttribution,
    ModalityTokenCount,
    SafetyRating
  }

  @doc false
  def parse_content(nil), do: nil
  def parse_content(%Content{} = content), do: content

  def parse_content(%{} = data) do
    parts =
      data
      |> Map.get("parts")
      |> Kernel.||(Map.get(data, :parts))
      |> parse_parts()

    %Content{
      role: Map.get(data, "role") || Map.get(data, :role),
      parts: parts
    }
  end

  @doc false
  def parse_parts(list) when is_list(list) do
    Enum.map(list, &Part.from_api/1)
  end

  def parse_parts(_), do: []

  @doc false
  def parse_safety_ratings(list) when is_list(list) do
    Enum.map(list, &SafetyRating.from_api/1)
  end

  def parse_safety_ratings(_), do: []

  @doc false
  def parse_modality_token_counts(list) when is_list(list) do
    Enum.map(list, &ModalityTokenCount.from_api/1)
  end

  def parse_modality_token_counts(_), do: nil

  @doc false
  def parse_grounding_attributions(list) when is_list(list) do
    Enum.map(list, &GroundingAttribution.from_api/1)
  end

  def parse_grounding_attributions(_), do: []
end

defmodule Gemini.Types.Response.GenerateContentResponse do
  @moduledoc """
  Response from content generation.
  """

  use TypedStruct

  alias Gemini.Types.Blob
  alias Gemini.Types.Response.{Candidate, PromptFeedback, UsageMetadata}

  @derive Jason.Encoder
  typedstruct do
    field(:candidates, [Candidate.t()], default: [])
    field(:prompt_feedback, PromptFeedback.t() | nil, default: nil)
    field(:usage_metadata, UsageMetadata.t() | nil, default: nil)
    field(:response_id, String.t() | nil, default: nil)
    field(:model_version, String.t() | nil, default: nil)
    field(:create_time, DateTime.t() | nil, default: nil)
  end

  @doc """
  Extract text content from the response.
  """
  @spec extract_text(t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_text(%__MODULE__{candidates: [first_candidate | _]}) do
    case first_candidate do
      %{content: %{parts: [_ | _] = parts}} ->
        parts
        |> extract_text_from_parts()

      _ ->
        {:error, "No text content found in response"}
    end
  end

  def extract_text(_), do: {:error, "No candidates found in response"}

  defp extract_text_from_parts(parts) do
    text =
      parts
      |> Enum.flat_map(&extract_text_from_part/1)
      |> Enum.join("")

    if text == "" do
      {:error, "No text content found in response"}
    else
      {:ok, text}
    end
  end

  defp extract_text_from_part(%{text: text}) when is_binary(text), do: [text]

  defp extract_text_from_part(%{inline_data: %Blob{mime_type: mime_type, data: data}}) do
    decode_inline_text(mime_type, data)
  end

  defp extract_text_from_part(_), do: []

  defp decode_inline_text(mime_type, data)
       when is_binary(mime_type) and is_binary(data) do
    if inline_text_mime?(mime_type) do
      case Base.decode64(data, ignore: :whitespace) do
        {:ok, decoded} -> [decoded]
        :error -> [data]
      end
    else
      []
    end
  end

  defp decode_inline_text(_, _), do: []

  defp inline_text_mime?(mime_type) do
    String.starts_with?(mime_type, "text/") or mime_type == "application/json"
  end

  @doc """
  Get the finish reason from the first candidate.
  """
  @spec finish_reason(t()) :: String.t() | nil
  def finish_reason(%__MODULE__{candidates: [%{finish_reason: reason} | _]}), do: reason
  def finish_reason(_), do: nil

  @doc """
  Parse a generate content response from the API payload.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      candidates:
        parse_candidates(Map.get(data, "candidates") || Map.get(data, :candidates) || []),
      prompt_feedback:
        PromptFeedback.from_api(
          Map.get(data, "promptFeedback") || Map.get(data, :prompt_feedback)
        ),
      usage_metadata:
        UsageMetadata.from_api(Map.get(data, "usageMetadata") || Map.get(data, :usage_metadata)),
      response_id: Map.get(data, "responseId") || Map.get(data, :response_id),
      model_version: Map.get(data, "modelVersion") || Map.get(data, :model_version),
      create_time: parse_datetime(Map.get(data, "createTime") || Map.get(data, :create_time))
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = value), do: value
  defp parse_datetime(_), do: nil

  defp parse_candidates(list) when is_list(list) do
    Enum.map(list, &Candidate.from_api/1)
  end

  @doc """
  Get token usage information from the response.
  """
  @spec token_usage(t()) :: map() | nil
  def token_usage(%__MODULE__{usage_metadata: %{} = usage}) do
    %{
      total: Map.get(usage, :total_token_count),
      input: Map.get(usage, :prompt_token_count),
      output: Map.get(usage, :candidates_token_count)
    }
  end

  def token_usage(_), do: nil
end

defmodule Gemini.Types.Response.CountTokensResponse do
  @moduledoc """
  Response from counting tokens.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:total_tokens, integer(), enforce: true)
  end
end

defmodule Gemini.Types.Response.Candidate do
  @moduledoc """
  Content candidate in response.
  """

  use TypedStruct

  alias Gemini.Types.Content

  alias Gemini.Types.Response, as: Response

  alias Gemini.Types.Response.{
    CitationMetadata,
    GroundingAttribution,
    SafetyRating
  }

  @derive Jason.Encoder
  typedstruct do
    field(:content, Content.t() | nil, default: nil)
    field(:finish_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])
    field(:citation_metadata, CitationMetadata.t() | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
    field(:grounding_attributions, [GroundingAttribution.t()], default: [])
    field(:index, integer() | nil, default: nil)
    field(:finish_message, String.t() | nil, default: nil)
    field(:avg_logprobs, float() | nil, default: nil)
  end

  @doc """
  Parse candidate from API payload.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      content:
        data
        |> Map.get("content")
        |> Kernel.||(Map.get(data, :content))
        |> Response.parse_content(),
      finish_reason: Map.get(data, "finishReason") || Map.get(data, :finish_reason),
      finish_message: Map.get(data, "finishMessage") || Map.get(data, :finish_message),
      safety_ratings:
        data
        |> Map.get("safetyRatings")
        |> Kernel.||(Map.get(data, :safety_ratings))
        |> Response.parse_safety_ratings(),
      citation_metadata: Map.get(data, "citationMetadata") || Map.get(data, :citation_metadata),
      token_count: Map.get(data, "tokenCount") || Map.get(data, :token_count),
      grounding_attributions:
        data
        |> Map.get("groundingAttributions")
        |> Kernel.||(Map.get(data, :grounding_attributions))
        |> Response.parse_grounding_attributions(),
      index: Map.get(data, "index") || Map.get(data, :index),
      avg_logprobs: Map.get(data, "avgLogprobs") || Map.get(data, :avg_logprobs)
    }
  end
end

defmodule Gemini.Types.Response.PromptFeedback do
  @moduledoc """
  Prompt feedback information.
  """

  use TypedStruct

  alias Gemini.Types.Response, as: Response
  alias Gemini.Types.Response.SafetyRating

  @derive Jason.Encoder
  typedstruct do
    field(:block_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])
    field(:block_reason_message, String.t() | nil, default: nil)
  end

  @doc """
  Parse prompt feedback from API payload.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      block_reason: Map.get(data, "blockReason") || Map.get(data, :block_reason),
      safety_ratings:
        data
        |> Map.get("safetyRatings")
        |> Kernel.||(Map.get(data, :safety_ratings))
        |> Response.parse_safety_ratings(),
      block_reason_message:
        Map.get(data, "blockReasonMessage") || Map.get(data, :block_reason_message)
    }
  end
end

defmodule Gemini.Types.Response.UsageMetadata do
  @moduledoc """
  Usage metadata for API calls.
  """

  use TypedStruct

  alias Gemini.Types.Response, as: Response
  alias Gemini.Types.Response.{ModalityTokenCount, TrafficType}

  @derive Jason.Encoder
  typedstruct do
    field(:prompt_token_count, integer() | nil, default: nil)
    field(:candidates_token_count, integer() | nil, default: nil)
    field(:total_token_count, integer(), enforce: true)
    field(:cached_content_token_count, integer() | nil, default: nil)
    field(:thoughts_token_count, integer() | nil, default: nil)
    field(:tool_use_prompt_token_count, integer() | nil, default: nil)
    field(:prompt_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:cache_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:response_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:tool_use_prompt_tokens_details, [ModalityTokenCount.t()] | nil, default: nil)
    field(:traffic_type, TrafficType.t() | nil, default: nil)
  end

  @doc """
  Parse usage metadata from API payload.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      prompt_token_count: Map.get(data, "promptTokenCount") || Map.get(data, :prompt_token_count),
      candidates_token_count:
        Map.get(data, "candidatesTokenCount") || Map.get(data, :candidates_token_count),
      total_token_count:
        Map.get(data, "totalTokenCount") || Map.get(data, :total_token_count) || 0,
      cached_content_token_count:
        Map.get(data, "cachedContentTokenCount") || Map.get(data, :cached_content_token_count),
      thoughts_token_count:
        Map.get(data, "thoughtsTokenCount") || Map.get(data, :thoughts_token_count),
      tool_use_prompt_token_count:
        Map.get(data, "toolUsePromptTokenCount") || Map.get(data, :tool_use_prompt_token_count),
      prompt_tokens_details:
        data
        |> Map.get("promptTokensDetails")
        |> Kernel.||(Map.get(data, :prompt_tokens_details))
        |> Response.parse_modality_token_counts(),
      cache_tokens_details:
        data
        |> Map.get("cacheTokensDetails")
        |> Kernel.||(Map.get(data, :cache_tokens_details))
        |> Response.parse_modality_token_counts(),
      response_tokens_details:
        data
        |> Map.get("responseTokensDetails")
        |> Kernel.||(Map.get(data, :response_tokens_details))
        |> Response.parse_modality_token_counts(),
      tool_use_prompt_tokens_details:
        data
        |> Map.get("toolUsePromptTokensDetails")
        |> Kernel.||(Map.get(data, :tool_use_prompt_tokens_details))
        |> Response.parse_modality_token_counts(),
      traffic_type:
        data
        |> Map.get("trafficType")
        |> Kernel.||(Map.get(data, :traffic_type))
        |> TrafficType.from_api()
    }
  end
end

defmodule Gemini.Types.Response.SafetyRating do
  @moduledoc """
  Safety rating for content.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:category, String.t(), enforce: true)
    field(:probability, String.t(), enforce: true)
    field(:blocked, boolean() | nil, default: nil)
    field(:probability_score, float() | nil, default: nil)
    field(:severity, String.t() | nil, default: nil)
    field(:severity_score, float() | nil, default: nil)
  end

  @doc """
  Parse safety rating from API payload.
  """
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      category: Map.get(data, "category") || Map.get(data, :category),
      probability: Map.get(data, "probability") || Map.get(data, :probability),
      blocked: Map.get(data, "blocked") || Map.get(data, :blocked),
      probability_score: Map.get(data, "probabilityScore") || Map.get(data, :probability_score),
      severity: Map.get(data, "severity") || Map.get(data, :severity),
      severity_score: Map.get(data, "severityScore") || Map.get(data, :severity_score)
    }
  end
end

defmodule Gemini.Types.Response.CitationMetadata do
  @moduledoc """
  Citation metadata for generated content.
  """

  use TypedStruct

  alias Gemini.Types.Response.CitationSource

  @derive Jason.Encoder
  typedstruct do
    field(:citation_sources, [CitationSource.t()], default: [])
  end
end

defmodule Gemini.Types.Response.CitationSource do
  @moduledoc """
  Citation source information.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:start_index, integer() | nil, default: nil)
    field(:end_index, integer() | nil, default: nil)
    field(:uri, String.t() | nil, default: nil)
    field(:license, String.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingAttribution do
  @moduledoc """
  Grounding attribution information.
  """

  use TypedStruct

  alias Gemini.Types.Content
  alias Gemini.Types.Response, as: Response
  alias Gemini.Types.Response.GroundingAttributionSourceId

  @derive Jason.Encoder
  typedstruct do
    field(:source_id, GroundingAttributionSourceId.t() | nil, default: nil)
    field(:content, Content.t() | nil, default: nil)
  end

  @doc false
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      source_id:
        data
        |> Map.get("sourceId")
        |> Kernel.||(Map.get(data, :source_id))
        |> GroundingAttributionSourceId.from_api(),
      content:
        data
        |> Map.get("content")
        |> Kernel.||(Map.get(data, :content))
        |> Response.parse_content()
    }
  end
end

defmodule Gemini.Types.Response.GroundingAttributionSourceId do
  @moduledoc """
  Grounding attribution source ID.
  """

  use TypedStruct

  alias Gemini.Types.Response.{GroundingPassageId, SemanticRetrieverChunk}

  @derive Jason.Encoder
  typedstruct do
    field(:grounding_passage, GroundingPassageId.t() | nil, default: nil)
    field(:semantic_retriever_chunk, SemanticRetrieverChunk.t() | nil, default: nil)
  end

  @doc false
  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(%{} = data) do
    %__MODULE__{
      grounding_passage: Map.get(data, "groundingPassage") || Map.get(data, :grounding_passage),
      semantic_retriever_chunk:
        Map.get(data, "semanticRetrieverChunk") || Map.get(data, :semantic_retriever_chunk)
    }
  end
end

defmodule Gemini.Types.Response.GroundingPassageId do
  @moduledoc """
  Grounding passage ID.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:passage_id, String.t(), enforce: true)
    field(:part_index, integer(), enforce: true)
  end
end

defmodule Gemini.Types.Response.SemanticRetrieverChunk do
  @moduledoc """
  Semantic retriever chunk information.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:source, String.t(), enforce: true)
    field(:chunk, String.t(), enforce: true)
  end
end
