defmodule Gemini.Types.CachedContentUsageMetadata do
  @moduledoc """
  Metadata describing cached content usage.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:total_token_count, integer() | nil)
    field(:cached_content_token_count, integer() | nil)
    field(:audio_duration_seconds, integer() | nil)
    field(:image_count, integer() | nil)
    field(:text_count, integer() | nil)
    field(:video_duration_seconds, integer() | nil)
  end
end
