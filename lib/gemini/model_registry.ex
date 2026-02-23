defmodule Gemini.ModelRegistry do
  @moduledoc """
  Canonical model registry with capability metadata.

  The registry is sourced from the Gemini models catalog pages and provides a
  stable API for:

  - model lookup by code (including resource-style names and aliases)
  - capability checks (for example `:live_api`, `:function_calling`)
  - live-model candidate selection by modality (`:text` / `:audio`)

  This keeps model selection logic out of tests and centralizes support
  decisions in one place.
  """

  @type support_state :: :supported | :not_supported | :experimental | :unknown

  @type capability ::
          :live_api
          | :thinking
          | :function_calling
          | :structured_outputs
          | :audio_generation
          | :image_generation
          | :batch_api
          | :caching

  @type modality :: :text | :image | :video | :audio | :pdf | :embeddings | :music

  @type entry :: %{
          key: atom(),
          code: String.t(),
          source_page: String.t(),
          track: :stable | :preview | :experimental | :deprecated | :agent,
          latest_update: String.t() | nil,
          input_modalities: [modality()],
          output_modalities: [modality()],
          capabilities: %{optional(capability()) => support_state()},
          aliases: [String.t()],
          live_modalities: [modality()],
          notes: String.t() | nil
        }

  @entries [
    %{
      key: :gemini_3_1_pro_preview,
      code: "gemini-3.1-pro-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-pro-preview",
      track: :preview,
      latest_update: "February 2026",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: ["gemini-3.1-pro-preview-customtools"],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_3_flash_preview,
      code: "gemini-3-flash-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3-flash-preview",
      track: :preview,
      latest_update: "December 2025",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_3_pro_preview,
      code: "gemini-3-pro-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-preview",
      track: :preview,
      latest_update: "November 2025",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_3_pro_image_preview,
      code: "gemini-3-pro-image-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-image-preview",
      track: :preview,
      latest_update: "November 2025",
      input_modalities: [:text, :image],
      output_modalities: [:image],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :not_supported,
        function_calling: :not_supported,
        image_generation: :supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: "Nano Banana Pro preview"
    },
    %{
      key: :gemini_2_5_flash,
      code: "gemini-2.5-flash",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash",
      track: :stable,
      latest_update: "June 2025",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_2_5_flash_lite,
      code: "gemini-2.5-flash-lite",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-lite",
      track: :stable,
      latest_update: "July 2025",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_2_5_pro,
      code: "gemini-2.5-pro",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-pro",
      track: :stable,
      latest_update: "June 2025",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_2_5_flash_native_audio_preview_12_2025,
      code: "gemini-2.5-flash-native-audio-preview-12-2025",
      source_page:
        "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-native-audio-preview-12-2025",
      track: :preview,
      latest_update: "September 2025",
      input_modalities: [:text, :audio, :video],
      output_modalities: [:text, :audio],
      capabilities: %{
        audio_generation: :supported,
        batch_api: :not_supported,
        caching: :not_supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :supported,
        structured_outputs: :not_supported,
        thinking: :supported
      },
      aliases: [
        "gemini-2.5-flash-native-audio-preview-09-2025",
        "gemini-2.5-flash-native-audio-latest"
      ],
      live_modalities: [:audio],
      notes: "Primary Live API entry from the model catalog"
    },
    %{
      key: :gemini_2_5_flash_preview_tts,
      code: "gemini-2.5-flash-preview-tts",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-preview-tts",
      track: :preview,
      latest_update: "December 2025",
      input_modalities: [:text],
      output_modalities: [:audio],
      capabilities: %{
        audio_generation: :supported,
        batch_api: :supported,
        caching: :not_supported,
        function_calling: :not_supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :not_supported,
        thinking: :not_supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_2_5_pro_preview_tts,
      code: "gemini-2.5-pro-preview-tts",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-pro-preview-tts",
      track: :preview,
      latest_update: "December 2025",
      input_modalities: [:text],
      output_modalities: [:audio],
      capabilities: %{
        audio_generation: :supported,
        batch_api: :supported,
        caching: :not_supported,
        function_calling: :not_supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :not_supported,
        thinking: :not_supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_2_5_flash_image,
      code: "gemini-2.5-flash-image",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-image",
      track: :stable,
      latest_update: "October 2025",
      input_modalities: [:text, :image],
      output_modalities: [:image],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :not_supported,
        image_generation: :supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :not_supported
      },
      aliases: [],
      live_modalities: [],
      notes: "Nano Banana"
    },
    %{
      key: :gemini_2_5_computer_use_preview_10_2025,
      code: "gemini-2.5-computer-use-preview-10-2025",
      source_page:
        "https://ai.google.dev/gemini-api/docs/models/gemini-2.5-computer-use-preview-10-2025",
      track: :preview,
      latest_update: "October 2025",
      input_modalities: [:text, :image],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :unknown,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: "Capability row not published on current model page snapshot"
    },
    %{
      key: :deep_research_pro_preview_12_2025,
      code: "deep-research-pro-preview-12-2025",
      source_page:
        "https://ai.google.dev/gemini-api/docs/models/deep-research-pro-preview-12-2025",
      track: :agent,
      latest_update: "December 2025",
      input_modalities: [:text, :image, :pdf, :audio, :video],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :unknown,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: "Interactions API agent model"
    },
    %{
      key: :gemini_embedding_001,
      code: "gemini-embedding-001",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-embedding-001",
      track: :stable,
      latest_update: "June 2025",
      input_modalities: [:text],
      output_modalities: [:embeddings],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :unknown,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: "Embedding model (not a generation model)"
    },
    %{
      key: :gemini_robotics_er_1_5_preview,
      code: "gemini-robotics-er-1.5-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-robotics-er-1.5-preview",
      track: :preview,
      latest_update: "September 2025",
      input_modalities: [:text, :image, :video],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :not_supported,
        caching: :not_supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :imagen_4_generate_001,
      code: "imagen-4.0-generate-001",
      source_page: "https://ai.google.dev/gemini-api/docs/models/imagen",
      track: :stable,
      latest_update: "June 2025",
      input_modalities: [:text],
      output_modalities: [:image],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :supported,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :imagen_4_ultra_generate_001,
      code: "imagen-4.0-ultra-generate-001",
      source_page: "https://ai.google.dev/gemini-api/docs/models/imagen",
      track: :stable,
      latest_update: "June 2025",
      input_modalities: [:text],
      output_modalities: [:image],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :supported,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :imagen_4_fast_generate_001,
      code: "imagen-4.0-fast-generate-001",
      source_page: "https://ai.google.dev/gemini-api/docs/models/imagen",
      track: :stable,
      latest_update: "June 2025",
      input_modalities: [:text],
      output_modalities: [:image],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :supported,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :lyria_realtime_exp,
      code: "lyria-realtime-exp",
      source_page: "https://ai.google.dev/gemini-api/docs/models/lyria-realtime-exp",
      track: :experimental,
      latest_update: "May 2025",
      input_modalities: [:text],
      output_modalities: [:music, :audio],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :unknown,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :veo_3_1_generate_preview,
      code: "veo-3.1-generate-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/veo-3.1-generate-preview",
      track: :preview,
      latest_update: "January 2026",
      input_modalities: [:text, :image],
      output_modalities: [:video, :audio],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :unknown,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :veo_3_1_fast_generate_preview,
      code: "veo-3.1-fast-generate-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/veo-3.1-generate-preview",
      track: :preview,
      latest_update: "January 2026",
      input_modalities: [:text, :image],
      output_modalities: [:video, :audio],
      capabilities: %{
        audio_generation: :unknown,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :unknown,
        image_generation: :unknown,
        live_api: :unknown,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_2_0_flash,
      code: "gemini-2.0-flash",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.0-flash",
      track: :deprecated,
      latest_update: "February 2025",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :experimental
      },
      aliases: ["gemini-2.0-flash-001"],
      live_modalities: [],
      notes: nil
    },
    %{
      key: :gemini_2_0_flash_lite,
      code: "gemini-2.0-flash-lite",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-2.0-flash-lite",
      track: :deprecated,
      latest_update: "February 2025",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :supported,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :not_supported
      },
      aliases: ["gemini-2.0-flash-lite-001"],
      live_modalities: [],
      notes: nil
    }
  ]

  @entry_by_key Map.new(@entries, &{&1.key, &1})

  @doc """
  Returns all registry entries.
  """
  @spec entries() :: [entry()]
  def entries, do: @entries

  @doc """
  Returns all canonical model codes.
  """
  @spec model_codes() :: [String.t()]
  def model_codes do
    @entries |> Enum.map(& &1.code) |> Enum.sort()
  end

  @doc """
  Find an entry by registry key.
  """
  @spec get_by_key(atom()) :: entry() | nil
  def get_by_key(key) when is_atom(key), do: Map.get(@entry_by_key, key)

  @doc """
  Find an entry by model code.

  Accepts plain model names, `models/...`, publisher-prefixed, project-scoped,
  and endpoint-suffixed (`:bidiGenerateContent`) forms.
  """
  @spec get(String.t()) :: entry() | nil
  def get(model_name) when is_binary(model_name) do
    normalized = normalize_model_name(model_name)

    Enum.find(@entries, fn entry ->
      [entry.code | entry.aliases]
      |> Enum.map(&normalize_model_name/1)
      |> Enum.member?(normalized)
    end)
  end

  @doc """
  Returns capability state for a model code.
  """
  @spec capability(String.t(), capability()) :: support_state()
  def capability(model_name, capability) when is_binary(model_name) and is_atom(capability) do
    case get(model_name) do
      %{capabilities: capabilities} -> Map.get(capabilities, capability, :unknown)
      nil -> :unknown
    end
  end

  @doc """
  Returns true if a model's capability matches the expected state.
  """
  @spec supports?(String.t(), capability(), support_state()) :: boolean()
  def supports?(model_name, capability, expected \\ :supported)
      when is_binary(model_name) and is_atom(capability) and is_atom(expected) do
    capability(model_name, capability) == expected
  end

  @doc """
  Returns model codes whose capability matches the expected state.
  """
  @spec with_capability(capability(), support_state()) :: [String.t()]
  def with_capability(capability, expected \\ :supported)
      when is_atom(capability) and is_atom(expected) do
    @entries
    |> Enum.filter(&(Map.get(&1.capabilities, capability, :unknown) == expected))
    |> Enum.map(& &1.code)
  end

  @doc """
  Returns preferred Live API candidates for a modality.
  """
  @spec live_candidates(:text | :audio, keyword()) :: [String.t()]
  def live_candidates(modality, _opts \\ []) when modality in [:text, :audio] do
    @entries
    |> Enum.filter(fn entry ->
      Map.get(entry.capabilities, :live_api, :unknown) == :supported and
        modality in effective_live_modalities(entry)
    end)
    |> Enum.flat_map(fn entry -> [entry.code | entry.aliases] end)
    |> Enum.uniq()
  end

  defp effective_live_modalities(%{live_modalities: modalities}) when modalities != [],
    do: modalities

  defp effective_live_modalities(entry) do
    if Map.get(entry.capabilities, :audio_generation, :unknown) == :supported do
      [:text, :audio]
    else
      [:text]
    end
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
