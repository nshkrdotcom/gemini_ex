defmodule Gemini.Live.Models do
  @moduledoc """
  Live API model selection helpers.

  Live API model availability can vary by rollout. This module provides
  a consistent way to choose a suitable model, preferring newer models
  when available while falling back to stable defaults.
  """

  require Logger

  alias Gemini.APIs.Coordinator
  alias Gemini.Config

  @type modality :: :text | :audio | :image

  @default_models %{
    text: :flash_2_0_exp,
    audio: :flash_2_5_native_audio_preview_12_2025,
    image: :flash_2_0_exp_image_generation
  }

  @candidate_models %{
    text: [
      :live_2_5_flash_preview,
      :flash_2_0_live_001,
      :flash_2_0_exp
    ],
    audio: [
      :flash_2_5_native_audio_preview_12_2025,
      :flash_2_5_preview_native_audio_dialog
    ],
    image: [
      :flash_2_0_exp_image_generation,
      :flash_2_0_preview_image_generation,
      :flash_2_5_image
    ]
  }

  @doc """
  Returns the default Live API model for a modality.
  """
  @spec default(modality()) :: String.t()
  def default(modality) do
    model_key = Map.fetch!(@default_models, modality)
    Config.get_model(model_key)
  end

  @doc """
  Returns the candidate Live API models for a modality in preference order.
  """
  @spec candidates(modality()) :: [String.t()]
  def candidates(modality) do
    @candidate_models
    |> Map.fetch!(modality)
    |> Enum.map(&Config.get_model/1)
  end

  @doc """
  Resolve the most appropriate Live API model for a modality.

  Uses the Gemini API `list_models` response when available, then falls back
  to the default model if no candidates are listed.

  ## Options

  - `:auth` - Auth strategy passed to `Coordinator.list_models/1` (default: `:gemini`)
  - `:available_models` - Explicit list of available models (bypass API call)
  - `:candidates` - Override candidate list (strings)
  - `:require_method` - Supported generation method to filter on (default: `"bidiGenerateContent"`)
  """
  @spec resolve(modality(), keyword()) :: String.t()
  def resolve(modality, opts \\ []) do
    candidate_models = Keyword.get(opts, :candidates, candidates(modality))
    available_models = Keyword.get(opts, :available_models)
    require_method = Keyword.get(opts, :require_method, "bidiGenerateContent")

    selection =
      if is_list(available_models) do
        pick_from_available(candidate_models, available_models)
      else
        fetch_and_pick_model(candidate_models, require_method, opts)
      end

    case selection do
      {:ok, model} ->
        model

      :none ->
        default_model = default(modality)

        Logger.warning(
          "[Gemini.Live.Models] No candidate models matched availability; using #{default_model}."
        )

        default_model
    end
  end

  defp fetch_and_pick_model(candidate_models, require_method, opts) do
    case Coordinator.list_models(auth: Keyword.get(opts, :auth, :gemini)) do
      {:ok, response} ->
        available = filter_models_by_method(response.models, require_method)
        pick_from_available(candidate_models, available)

      {:error, reason} ->
        Logger.warning(
          "[Gemini.Live.Models] Could not list models (#{inspect(reason)}); using default."
        )

        :none
    end
  end

  defp filter_models_by_method(models, require_method) do
    models
    |> Enum.filter(&supports_method?(&1, require_method))
    |> Enum.map(&Map.get(&1, :name))
  end

  defp supports_method?(model, method) do
    model
    |> Map.get(:supported_generation_methods, [])
    |> Enum.member?(method)
  end

  @doc """
  Select the first candidate present in an available model list.

  Returns `{:ok, model}` or `:none` if no candidates match.
  """
  @spec pick_from_available([String.t()], [String.t()]) :: {:ok, String.t()} | :none
  def pick_from_available(candidates, available_models)
      when is_list(candidates) and is_list(available_models) do
    available =
      available_models
      |> Enum.map(&normalize_model_name/1)
      |> MapSet.new()

    Enum.find_value(candidates, :none, fn candidate ->
      normalized = normalize_model_name(candidate)

      if MapSet.member?(available, normalized) do
        {:ok, candidate}
      end
    end)
  end

  defp normalize_model_name(name) when is_binary(name) do
    String.replace_prefix(name, "models/", "")
  end
end
