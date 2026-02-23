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
  alias Gemini.ModelRegistry

  @type modality :: :text | :audio | :image

  @legacy_default_models %{
    text: :flash_2_5_native_audio_preview_12_2025,
    audio: :flash_2_5_native_audio_preview_12_2025,
    image: :flash_2_0_exp_image_generation
  }

  @legacy_fallback_candidates %{
    text: [
      :flash_2_5_native_audio_latest,
      :flash_2_5_native_audio_preview_12_2025,
      :flash_2_5_native_audio_preview_09_2025,
      :live_2_5_flash,
      :live_2_5_flash_preview
    ],
    audio: [
      :flash_2_5_native_audio_latest,
      :flash_2_5_native_audio_preview_12_2025,
      :flash_2_5_native_audio_preview_09_2025,
      :live_2_5_flash_native_audio,
      :live_2_5_flash_preview_native_audio_09_2025,
      :live_2_5_flash_preview_native_audio,
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
  def default(modality), do: default(modality, [])

  @spec default(modality(), keyword()) :: String.t()
  def default(modality, opts) do
    case candidates(modality, opts) do
      [model | _] ->
        model

      [] ->
        fallback_key = Map.fetch!(@legacy_default_models, modality)

        safe_get_model(fallback_key) ||
          raise ArgumentError,
                "No live default model available for modality #{inspect(modality)}"
    end
  end

  @doc """
  Returns the candidate Live API models for a modality in preference order.
  """
  @spec candidates(modality()) :: [String.t()]
  def candidates(modality), do: candidates(modality, [])

  @spec candidates(modality(), keyword()) :: [String.t()]
  def candidates(modality, opts) do
    auth = Keyword.get(opts, :auth, :gemini)

    registry_candidates =
      case modality do
        modality when modality in [:text, :audio] -> Config.live_registry_candidates(modality)
        _ -> []
      end

    legacy_candidates = legacy_candidates(modality, auth)

    (registry_candidates ++ legacy_candidates)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
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
    candidate_models = Keyword.get(opts, :candidates, candidates(modality, opts))
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
        fallback =
          if is_list(available_models) do
            fallback_from_available(modality, available_models)
          else
            :none
          end

        case fallback do
          {:ok, model} ->
            model

          :none ->
            default_model = default(modality, opts)

            Logger.warning(
              "[Gemini.Live.Models] No candidate models matched availability; using #{default_model}."
            )

            default_model
        end
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

  defp fallback_from_available(modality, available_models) do
    available_models
    |> Enum.map(&normalize_model_name/1)
    |> Enum.filter(&live_candidate_for_modality?(&1, modality))
    |> prioritize_models(modality)
    |> List.first()
    |> case do
      nil -> :none
      model -> {:ok, model}
    end
  end

  defp live_candidate_for_modality?(model_name, :text) do
    live_like_model_name?(model_name) and not String.contains?(model_name, "tts")
  end

  defp live_candidate_for_modality?(model_name, :audio) do
    live_like_model_name?(model_name) and not String.contains?(model_name, "tts")
  end

  defp live_candidate_for_modality?(model_name, :image) do
    String.contains?(model_name, "image")
  end

  defp live_like_model_name?(model_name) do
    String.contains?(model_name, "native-audio") or
      String.contains?(model_name, "-live-") or
      String.starts_with?(model_name, "gemini-live-")
  end

  defp prioritize_models(models, modality) when modality in [:text, :audio] do
    preferred =
      ModelRegistry.live_candidates(modality)
      |> Enum.map(&normalize_model_name/1)
      |> Enum.with_index()
      |> Map.new()

    Enum.sort_by(models, fn model_name ->
      Map.get(preferred, model_name, 10_000)
    end)
  end

  defp prioritize_models(models, _modality), do: models

  defp filter_models_by_method(models, require_method) do
    models
    |> Enum.filter(&supports_method?(&1, require_method))
    |> Enum.map(&model_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp model_name(model) when is_map(model) do
    Map.get(model, :name) || Map.get(model, "name")
  end

  defp supports_method?(model, method) do
    methods =
      Map.get(model, :supported_generation_methods) ||
        Map.get(model, "supported_generation_methods") ||
        Map.get(model, "supportedGenerationMethods")

    case methods do
      methods when is_list(methods) and methods != [] ->
        Enum.member?(methods, method)

      _ ->
        true
    end
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

  defp legacy_candidates(modality, auth) do
    @legacy_fallback_candidates
    |> Map.fetch!(modality)
    |> Enum.filter(&auth_compatible?(&1, auth))
    |> Enum.map(&safe_get_model/1)
  end

  defp auth_compatible?(model_key, :vertex_ai), do: Config.model_available?(model_key, :vertex_ai)
  defp auth_compatible?(_model_key, _auth), do: true

  defp safe_get_model(model_key) when is_atom(model_key) do
    Config.get_model(model_key)
  rescue
    ArgumentError -> nil
  end

  defp normalize_model_name(name) when is_binary(name) do
    name
    |> strip_endpoint_suffix()
    |> strip_known_prefixes()
  end

  defp strip_endpoint_suffix(name) do
    case String.split(name, ":", parts: 2) do
      [model_name] -> model_name
      [model_name, _endpoint] -> model_name
    end
  end

  defp strip_known_prefixes(name) do
    cond do
      String.starts_with?(name, "models/") ->
        String.replace_prefix(name, "models/", "")

      String.starts_with?(name, "publishers/google/models/") ->
        String.replace_prefix(name, "publishers/google/models/", "")

      String.contains?(name, "/models/") ->
        [_prefix, model_name] = String.split(name, "/models/", parts: 2)
        model_name

      true ->
        name
    end
  end
end
