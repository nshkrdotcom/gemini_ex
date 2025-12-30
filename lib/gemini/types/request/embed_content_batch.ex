defmodule Gemini.Types.Request.EmbedContentBatch do
  @moduledoc """
  Async batch embedding job request.

  Submit a large batch of embedding requests for asynchronous processing
  at 50% cost compared to interactive API.

  ## Fields

  - `model`: Model to use (e.g., "models/gemini-embedding-001")
  - `name`: Output only - assigned by API (format: "batches/{batchId}")
  - `display_name`: Human-readable batch name (required)
  - `input_config`: Input configuration (file or inline requests)
  - `priority`: Processing priority (default 0, higher = more urgent)

  ## Examples

      # Create batch with inline requests
      EmbedContentBatch.new(
        "models/gemini-embedding-001",
        input_config,
        display_name: "Knowledge Base Embeddings"
      )

      # With priority
      EmbedContentBatch.new(
        "models/gemini-embedding-001",
        input_config,
        display_name: "Urgent Batch",
        priority: 10
      )
  """

  alias Gemini.Types.Request.InputEmbedContentConfig

  import Gemini.Utils.MapHelpers, only: [maybe_put_non_zero: 3]

  @enforce_keys [:model, :display_name, :input_config]
  defstruct [:model, :name, :display_name, :input_config, :priority]

  @type t :: %__MODULE__{
          model: String.t(),
          name: String.t() | nil,
          display_name: String.t(),
          input_config: InputEmbedContentConfig.t(),
          priority: integer() | nil
        }

  @doc """
  Creates a new async batch embedding request.

  ## Parameters

  - `model`: Model to use (e.g., "gemini-embedding-001" or full path)
  - `input_config`: Input configuration (file or inline)
  - `opts`: Optional keyword list
    - `:display_name`: Human-readable name (required)
    - `:priority`: Processing priority (default: 0)
    - `:name`: Batch identifier (output only, set by API)

  ## Examples

      EmbedContentBatch.new(
        "gemini-embedding-001",
        input_config,
        display_name: "My Batch"
      )
  """
  @spec new(String.t(), InputEmbedContentConfig.t(), keyword()) :: t()
  def new(model, %InputEmbedContentConfig{} = input_config, opts \\ []) do
    # Ensure model has proper format
    model =
      if String.starts_with?(model, "models/") do
        model
      else
        "models/#{model}"
      end

    display_name =
      Keyword.get(opts, :display_name) ||
        raise ArgumentError, "display_name is required"

    %__MODULE__{
      model: model,
      name: Keyword.get(opts, :name),
      display_name: display_name,
      input_config: input_config,
      priority: Keyword.get(opts, :priority, 0)
    }
  end

  @doc """
  Converts the batch request to API-compatible map format.

  The API expects all fields to be wrapped in a `batch` object.
  """
  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{} = batch) do
    batch_content =
      %{
        "model" => batch.model,
        "displayName" => batch.display_name,
        "inputConfig" => InputEmbedContentConfig.to_api_map(batch.input_config)
      }
      |> maybe_put_non_zero("priority", batch.priority)

    # Wrap in batch object as required by API
    %{"batch" => batch_content}
  end
end
