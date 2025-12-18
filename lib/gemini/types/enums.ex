defmodule Gemini.Types.Enums do
  @moduledoc """
  Comprehensive enumeration types for the Gemini API.

  This module provides type-safe enums for all API enumeration values,
  including safety settings, finish reasons, task types, and more.

  ## Usage

      alias Gemini.Types.Enums.{HarmCategory, HarmBlockThreshold, TaskType}

      # Create safety settings
      settings = [
        %{category: HarmCategory.to_api(:harassment), threshold: HarmBlockThreshold.to_api(:medium_and_above)}
      ]

      # Use task types for embeddings
      opts = [task_type: TaskType.to_api(:retrieval_document)]
  """

  defmodule HarmCategory do
    @moduledoc """
    Categories of harmful content that can be filtered.

    ## Values

    - `:unspecified` - Default/unknown category
    - `:harassment` - Harassment and bullying content
    - `:hate_speech` - Hate speech targeting identity groups
    - `:sexually_explicit` - Sexually explicit content
    - `:dangerous_content` - Content promoting dangerous activities
    - `:civic_integrity` - Content affecting civic integrity (elections, etc.)
    - `:derogatory` - Derogatory content (deprecated)
    - `:toxicity` - Toxic content (deprecated)
    - `:violence` - Violent content (deprecated)
    - `:sexual` - Sexual content (deprecated)
    - `:medical` - Medical misinformation (deprecated)
    - `:dangerous` - Dangerous content (deprecated)
    """

    @type t ::
            :unspecified
            | :harassment
            | :hate_speech
            | :sexually_explicit
            | :dangerous_content
            | :civic_integrity
            | :derogatory
            | :toxicity
            | :violence
            | :sexual
            | :medical
            | :dangerous

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "HARM_CATEGORY_UNSPECIFIED"
    def to_api(:harassment), do: "HARM_CATEGORY_HARASSMENT"
    def to_api(:hate_speech), do: "HARM_CATEGORY_HATE_SPEECH"
    def to_api(:sexually_explicit), do: "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    def to_api(:dangerous_content), do: "HARM_CATEGORY_DANGEROUS_CONTENT"
    def to_api(:civic_integrity), do: "HARM_CATEGORY_CIVIC_INTEGRITY"
    def to_api(:derogatory), do: "HARM_CATEGORY_DEROGATORY"
    def to_api(:toxicity), do: "HARM_CATEGORY_TOXICITY"
    def to_api(:violence), do: "HARM_CATEGORY_VIOLENCE"
    def to_api(:sexual), do: "HARM_CATEGORY_SEXUAL"
    def to_api(:medical), do: "HARM_CATEGORY_MEDICAL"
    def to_api(:dangerous), do: "HARM_CATEGORY_DANGEROUS"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("HARM_CATEGORY_UNSPECIFIED"), do: :unspecified
    def from_api("HARM_CATEGORY_HARASSMENT"), do: :harassment
    def from_api("HARM_CATEGORY_HATE_SPEECH"), do: :hate_speech
    def from_api("HARM_CATEGORY_SEXUALLY_EXPLICIT"), do: :sexually_explicit
    def from_api("HARM_CATEGORY_DANGEROUS_CONTENT"), do: :dangerous_content
    def from_api("HARM_CATEGORY_CIVIC_INTEGRITY"), do: :civic_integrity
    def from_api("HARM_CATEGORY_DEROGATORY"), do: :derogatory
    def from_api("HARM_CATEGORY_TOXICITY"), do: :toxicity
    def from_api("HARM_CATEGORY_VIOLENCE"), do: :violence
    def from_api("HARM_CATEGORY_SEXUAL"), do: :sexual
    def from_api("HARM_CATEGORY_MEDICAL"), do: :medical
    def from_api("HARM_CATEGORY_DANGEROUS"), do: :dangerous
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified

    @spec all() :: [t()]
    def all do
      [
        :harassment,
        :hate_speech,
        :sexually_explicit,
        :dangerous_content,
        :civic_integrity
      ]
    end
  end

  defmodule HarmBlockThreshold do
    @moduledoc """
    Threshold levels for blocking harmful content.

    ## Values

    - `:unspecified` - Default/unknown threshold
    - `:block_low_and_above` - Block content with low+ probability of harm
    - `:block_medium_and_above` - Block content with medium+ probability
    - `:block_only_high` - Only block high probability harmful content
    - `:block_none` - Don't block any content (for research/testing)
    - `:off` - Safety filter is completely off
    """

    @type t ::
            :unspecified
            | :block_low_and_above
            | :block_medium_and_above
            | :block_only_high
            | :block_none
            | :off

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "HARM_BLOCK_THRESHOLD_UNSPECIFIED"
    def to_api(:block_low_and_above), do: "BLOCK_LOW_AND_ABOVE"
    def to_api(:block_medium_and_above), do: "BLOCK_MEDIUM_AND_ABOVE"
    def to_api(:block_only_high), do: "BLOCK_ONLY_HIGH"
    def to_api(:block_none), do: "BLOCK_NONE"
    def to_api(:off), do: "OFF"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("HARM_BLOCK_THRESHOLD_UNSPECIFIED"), do: :unspecified
    def from_api("BLOCK_LOW_AND_ABOVE"), do: :block_low_and_above
    def from_api("BLOCK_MEDIUM_AND_ABOVE"), do: :block_medium_and_above
    def from_api("BLOCK_ONLY_HIGH"), do: :block_only_high
    def from_api("BLOCK_NONE"), do: :block_none
    def from_api("OFF"), do: :off
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule HarmProbability do
    @moduledoc """
    Probability levels of harmful content.

    Returned in SafetyRating to indicate likelihood of harm.
    """

    @type t ::
            :unspecified
            | :negligible
            | :low
            | :medium
            | :high

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "HARM_PROBABILITY_UNSPECIFIED"
    def to_api(:negligible), do: "NEGLIGIBLE"
    def to_api(:low), do: "LOW"
    def to_api(:medium), do: "MEDIUM"
    def to_api(:high), do: "HIGH"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("HARM_PROBABILITY_UNSPECIFIED"), do: :unspecified
    def from_api("NEGLIGIBLE"), do: :negligible
    def from_api("LOW"), do: :low
    def from_api("MEDIUM"), do: :medium
    def from_api("HIGH"), do: :high
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule BlockedReason do
    @moduledoc """
    Reasons why content generation was blocked.
    """

    @type t ::
            :unspecified
            | :safety
            | :other
            | :blocklist
            | :prohibited_content
            | :spii
            | :image_safety

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "BLOCKED_REASON_UNSPECIFIED"
    def to_api(:safety), do: "SAFETY"
    def to_api(:other), do: "OTHER"
    def to_api(:blocklist), do: "BLOCKLIST"
    def to_api(:prohibited_content), do: "PROHIBITED_CONTENT"
    def to_api(:spii), do: "SPII"
    def to_api(:image_safety), do: "IMAGE_SAFETY"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("BLOCKED_REASON_UNSPECIFIED"), do: :unspecified
    def from_api("SAFETY"), do: :safety
    def from_api("OTHER"), do: :other
    def from_api("BLOCKLIST"), do: :blocklist
    def from_api("PROHIBITED_CONTENT"), do: :prohibited_content
    def from_api("SPII"), do: :spii
    def from_api("IMAGE_SAFETY"), do: :image_safety
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule FinishReason do
    @moduledoc """
    Reasons why generation finished.

    ## Values

    - `:unspecified` - Default/unknown reason
    - `:stop` - Natural stopping point (EOS token)
    - `:max_tokens` - Maximum token limit reached
    - `:safety` - Blocked due to safety concerns
    - `:recitation` - Blocked due to recitation/copyright
    - `:language` - Unsupported language
    - `:other` - Other/unspecified reason
    - `:blocklist` - Content matched a blocklist
    - `:prohibited_content` - Prohibited content detected
    - `:spii` - Sensitive PII detected
    - `:malformed_function_call` - Invalid function call format
    - `:image_safety` - Image safety issue
    """

    @type t ::
            :unspecified
            | :stop
            | :max_tokens
            | :safety
            | :recitation
            | :language
            | :other
            | :blocklist
            | :prohibited_content
            | :spii
            | :malformed_function_call
            | :image_safety

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "FINISH_REASON_UNSPECIFIED"
    def to_api(:stop), do: "STOP"
    def to_api(:max_tokens), do: "MAX_TOKENS"
    def to_api(:safety), do: "SAFETY"
    def to_api(:recitation), do: "RECITATION"
    def to_api(:language), do: "LANGUAGE"
    def to_api(:other), do: "OTHER"
    def to_api(:blocklist), do: "BLOCKLIST"
    def to_api(:prohibited_content), do: "PROHIBITED_CONTENT"
    def to_api(:spii), do: "SPII"
    def to_api(:malformed_function_call), do: "MALFORMED_FUNCTION_CALL"
    def to_api(:image_safety), do: "IMAGE_SAFETY"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("FINISH_REASON_UNSPECIFIED"), do: :unspecified
    def from_api("STOP"), do: :stop
    def from_api("MAX_TOKENS"), do: :max_tokens
    def from_api("SAFETY"), do: :safety
    def from_api("RECITATION"), do: :recitation
    def from_api("LANGUAGE"), do: :language
    def from_api("OTHER"), do: :other
    def from_api("BLOCKLIST"), do: :blocklist
    def from_api("PROHIBITED_CONTENT"), do: :prohibited_content
    def from_api("SPII"), do: :spii
    def from_api("MALFORMED_FUNCTION_CALL"), do: :malformed_function_call
    def from_api("IMAGE_SAFETY"), do: :image_safety
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule TaskType do
    @moduledoc """
    Task types for embedding generation.

    Different task types optimize embeddings for specific use cases.

    ## Values

    - `:unspecified` - Default task type
    - `:retrieval_query` - Text is a search query
    - `:retrieval_document` - Text is a document being indexed
    - `:semantic_similarity` - For similarity comparison
    - `:classification` - For classification tasks
    - `:clustering` - For clustering tasks
    - `:question_answering` - For Q&A systems
    - `:fact_verification` - For fact checking
    - `:code_retrieval_query` - For code search queries
    """

    @type t ::
            :unspecified
            | :retrieval_query
            | :retrieval_document
            | :semantic_similarity
            | :classification
            | :clustering
            | :question_answering
            | :fact_verification
            | :code_retrieval_query

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "TASK_TYPE_UNSPECIFIED"
    def to_api(:retrieval_query), do: "RETRIEVAL_QUERY"
    def to_api(:retrieval_document), do: "RETRIEVAL_DOCUMENT"
    def to_api(:semantic_similarity), do: "SEMANTIC_SIMILARITY"
    def to_api(:classification), do: "CLASSIFICATION"
    def to_api(:clustering), do: "CLUSTERING"
    def to_api(:question_answering), do: "QUESTION_ANSWERING"
    def to_api(:fact_verification), do: "FACT_VERIFICATION"
    def to_api(:code_retrieval_query), do: "CODE_RETRIEVAL_QUERY"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("TASK_TYPE_UNSPECIFIED"), do: :unspecified
    def from_api("RETRIEVAL_QUERY"), do: :retrieval_query
    def from_api("RETRIEVAL_DOCUMENT"), do: :retrieval_document
    def from_api("SEMANTIC_SIMILARITY"), do: :semantic_similarity
    def from_api("CLASSIFICATION"), do: :classification
    def from_api("CLUSTERING"), do: :clustering
    def from_api("QUESTION_ANSWERING"), do: :question_answering
    def from_api("FACT_VERIFICATION"), do: :fact_verification
    def from_api("CODE_RETRIEVAL_QUERY"), do: :code_retrieval_query
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified

    @doc """
    Returns task types optimized for retrieval/search.
    """
    @spec retrieval_types() :: [t()]
    def retrieval_types, do: [:retrieval_query, :retrieval_document]

    @doc """
    Returns all task types for analysis.
    """
    @spec all() :: [t()]
    def all do
      [
        :retrieval_query,
        :retrieval_document,
        :semantic_similarity,
        :classification,
        :clustering,
        :question_answering,
        :fact_verification,
        :code_retrieval_query
      ]
    end
  end

  defmodule FunctionCallingMode do
    @moduledoc """
    Function calling configuration modes.

    ## Values

    - `:auto` - Model decides when to call functions
    - `:any` - Model must call at least one function
    - `:none` - Model cannot call functions
    """

    @type t :: :auto | :any | :none

    @spec to_api(t()) :: String.t()
    def to_api(:auto), do: "AUTO"
    def to_api(:any), do: "ANY"
    def to_api(:none), do: "NONE"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("AUTO"), do: :auto
    def from_api("ANY"), do: :any
    def from_api("NONE"), do: :none
    def from_api(nil), do: nil
    def from_api(_), do: :auto
  end

  defmodule DynamicRetrievalMode do
    @moduledoc """
    Dynamic retrieval configuration modes.
    """

    @type t :: :unspecified | :dynamic | :mode_off

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "MODE_UNSPECIFIED"
    def to_api(:dynamic), do: "MODE_DYNAMIC"
    def to_api(:mode_off), do: "MODE_OFF"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("MODE_UNSPECIFIED"), do: :unspecified
    def from_api("MODE_DYNAMIC"), do: :dynamic
    def from_api("MODE_OFF"), do: :mode_off
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule ThinkingLevel do
    @moduledoc """
    Thinking configuration levels for Gemini 3 models.

    ## Values

    - `:unspecified` - Unspecified thinking level
    - `:minimal` - Minimal thinking (Gemini 3 Flash only)
    - `:low` - Low thinking level
    - `:medium` - Medium thinking level (Gemini 3 Flash only)
    - `:high` - High thinking level (default)

    ## Model Support

    - **Gemini 3 Pro**: `:low`, `:high`
    - **Gemini 3 Flash**: `:minimal`, `:low`, `:medium`, `:high`
    """

    @type t :: :unspecified | :minimal | :low | :medium | :high

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "THINKING_LEVEL_UNSPECIFIED"
    def to_api(:minimal), do: "MINIMAL"
    def to_api(:low), do: "LOW"
    def to_api(:medium), do: "MEDIUM"
    def to_api(:high), do: "HIGH"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("THINKING_LEVEL_UNSPECIFIED"), do: :unspecified
    def from_api("MINIMAL"), do: :minimal
    def from_api("minimal"), do: :minimal
    def from_api("LOW"), do: :low
    def from_api("low"), do: :low
    def from_api("MEDIUM"), do: :medium
    def from_api("medium"), do: :medium
    def from_api("HIGH"), do: :high
    def from_api("high"), do: :high
    def from_api(nil), do: nil
    def from_api(_), do: :high
  end

  defmodule CodeExecutionOutcome do
    @moduledoc """
    Outcome of code execution.
    """

    @type t :: :unspecified | :ok | :failed | :deadline_exceeded

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "OUTCOME_UNSPECIFIED"
    def to_api(:ok), do: "OUTCOME_OK"
    def to_api(:failed), do: "OUTCOME_FAILED"
    def to_api(:deadline_exceeded), do: "OUTCOME_DEADLINE_EXCEEDED"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("OUTCOME_UNSPECIFIED"), do: :unspecified
    def from_api("OUTCOME_OK"), do: :ok
    def from_api("OUTCOME_FAILED"), do: :failed
    def from_api("OUTCOME_DEADLINE_EXCEEDED"), do: :deadline_exceeded
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule ExecutableCodeLanguage do
    @moduledoc """
    Supported languages for code execution.
    """

    @type t :: :unspecified | :python

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "LANGUAGE_UNSPECIFIED"
    def to_api(:python), do: "PYTHON"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("LANGUAGE_UNSPECIFIED"), do: :unspecified
    def from_api("PYTHON"), do: :python
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule GroundingAttributionConfidence do
    @moduledoc """
    Confidence levels for grounding attribution.
    """

    @type t :: :unspecified | :low | :medium | :high

    @spec to_api(t()) :: String.t()
    def to_api(:unspecified), do: "CONFIDENCE_UNSPECIFIED"
    def to_api(:low), do: "LOW"
    def to_api(:medium), do: "MEDIUM"
    def to_api(:high), do: "HIGH"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("CONFIDENCE_UNSPECIFIED"), do: :unspecified
    def from_api("LOW"), do: :low
    def from_api("MEDIUM"), do: :medium
    def from_api("HIGH"), do: :high
    def from_api(nil), do: nil
    def from_api(_), do: :unspecified
  end

  defmodule AspectRatio do
    @moduledoc """
    Image aspect ratios for image generation.
    """

    @type t :: :square | :portrait | :landscape | :landscape_16_9

    @spec to_api(t()) :: String.t()
    def to_api(:square), do: "1:1"
    def to_api(:portrait), do: "3:4"
    def to_api(:landscape), do: "4:3"
    def to_api(:landscape_16_9), do: "16:9"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("1:1"), do: :square
    def from_api("3:4"), do: :portrait
    def from_api("4:3"), do: :landscape
    def from_api("16:9"), do: :landscape_16_9
    def from_api(nil), do: nil
    def from_api(_), do: :square
  end

  defmodule ImageSize do
    @moduledoc """
    Output image sizes for image generation.
    """

    @type t :: :size_512 | :size_1024 | :size_2048

    @spec to_api(t()) :: String.t()
    def to_api(:size_512), do: "512x512"
    def to_api(:size_1024), do: "1024x1024"
    def to_api(:size_2048), do: "2048x2048"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("512x512"), do: :size_512
    def from_api("1024x1024"), do: :size_1024
    def from_api("2048x2048"), do: :size_2048
    def from_api(nil), do: nil
    def from_api(_), do: :size_1024
  end

  defmodule VoiceName do
    @moduledoc """
    Available voice names for text-to-speech.
    """

    @type t ::
            :aoede
            | :charon
            | :fenrir
            | :kore
            | :puck
            | :custom

    @spec to_api(t()) :: String.t()
    def to_api(:aoede), do: "Aoede"
    def to_api(:charon), do: "Charon"
    def to_api(:fenrir), do: "Fenrir"
    def to_api(:kore), do: "Kore"
    def to_api(:puck), do: "Puck"
    def to_api(:custom), do: "VOICE_UNSPECIFIED"

    @spec from_api(String.t() | nil) :: t() | nil
    def from_api("Aoede"), do: :aoede
    def from_api("Charon"), do: :charon
    def from_api("Fenrir"), do: :fenrir
    def from_api("Kore"), do: :kore
    def from_api("Puck"), do: :puck
    def from_api("VOICE_UNSPECIFIED"), do: :custom
    def from_api(nil), do: nil
    def from_api(_), do: :puck

    @spec all() :: [t()]
    def all, do: [:aoede, :charon, :fenrir, :kore, :puck]
  end
end
