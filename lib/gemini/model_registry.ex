defmodule Gemini.ModelRegistry do
  @moduledoc """
  Canonical model registry with capability metadata.

  The registry is sourced from the Gemini models catalog pages and provides a
  stable API for:

  - model lookup by code (including resource-style names and aliases)
  - capability checks (for example `:live_api`, `:function_calling`)
  - live-model candidate selection by modality (`:text` / `:audio`)

  This keeps model selection logic out of tests and centralizes support
  decisions in one place. Lifecycle metadata follows the linked Gemini API
  catalog; Vertex availability and retirement dates can differ. The `:caching`
  capability includes implicit caching; consult model notes before using explicit caches.
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
          track: :stable | :preview | :experimental | :deprecated | :agent | :unknown,
          latest_update: String.t() | nil,
          input_modalities: [modality()],
          output_modalities: [modality()],
          capabilities: %{optional(capability()) => support_state()},
          aliases: [String.t()],
          live_modalities: [modality()],
          live_session_response_modalities: [modality()],
          live_text_input_method: :client_content | :realtime_input | nil,
          notes: String.t() | nil
        }

  @entries [
    %{
      key: :gemini_4_carbon,
      code: "gemini-4-carbon",
      source_page: "https://aistudio.google.com/docs/models/gemini-4-carbon",
      track: :stable,
      latest_update: "November 2026",
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
      notes:
        "Implicit caching only. Extended decoding depends on API version and provider opt-in."
    },
    %{
      key: :gemini_4_hydrogen,
      code: "gemini-4-hydrogen",
      source_page: "https://aistudio.google.com/docs/models/gemini-4-hydrogen",
      track: :stable,
      latest_update: "November 2026",
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
      notes:
        "Implicit caching only. Extended decoding depends on API version and provider opt-in."
    },
    %{
      key: :gemini_4_neon,
      code: "gemini-4-neon",
      source_page: "https://aistudio.google.com/docs/models/gemini-4-neon",
      track: :stable,
      latest_update: "November 2026",
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
      notes:
        "Implicit caching only. Extended decoding depends on API version and provider opt-in. Vertex availability is limited to eligible projects and regions."
    },
    %{
      key: :antigravity_preview_05_2026,
      code: "antigravity-preview-05-2026",
      source_page: "https://aistudio.google.com/docs/models",
      track: :agent,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :antigravity_preview_09_2026,
      code: "antigravity-preview-09-2026",
      source_page: "https://aistudio.google.com/docs/models",
      track: :agent,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :antigravity_preview_latest,
      code: "antigravity-preview-latest",
      source_page: "https://aistudio.google.com/docs/models",
      track: :agent,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :aqa,
      code: "aqa",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :deep_research_max_preview_04_2026,
      code: "deep-research-max-preview-04-2026",
      source_page: "https://aistudio.google.com/docs/models",
      track: :agent,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :deep_research_preview_04_2026,
      code: "deep-research-preview-04-2026",
      source_page: "https://aistudio.google.com/docs/models",
      track: :agent,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_3_1_flash_tts_preview,
      code: "gemini-3.1-flash-tts-preview",
      source_page: "https://aistudio.google.com/docs/models",
      track: :preview,
      latest_update: nil,
      input_modalities: [:text],
      output_modalities: [:audio],
      capabilities: %{audio_generation: :supported, batch_api: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_3_5_live_translate_preview,
      code: "gemini-3.5-live-translate-preview",
      source_page: "https://aistudio.google.com/docs/models",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_3_5_transcribe,
      code: "gemini-3.5-transcribe",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [:audio],
      output_modalities: [:text],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_3_5_transcribe_live,
      code: "gemini-3.5-transcribe-live",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_3_8_flash_cyber,
      code: "gemini-3.8-flash-cyber",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/3-8-flash-cyber",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :gemini_4_argon_cyber_permissive,
      code: "gemini-4-argon-cyber-permissive",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/4-argon#cyber",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :gemini_4_carbon_cyber_permissive,
      code: "gemini-4-carbon-cyber-permissive",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/4-carbon#cyber",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :gemini_decision_1,
      code: "gemini-decision-1",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_embedding_2,
      code: "gemini-embedding-2",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/embedding-2",
      track: :stable,
      latest_update: nil,
      input_modalities: [:text, :image, :audio, :video, :pdf],
      output_modalities: [:embeddings],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_embedding_2_preview,
      code: "gemini-embedding-2-preview",
      source_page: "https://aistudio.google.com/docs/models",
      track: :preview,
      latest_update: nil,
      input_modalities: [:text, :image, :audio, :video, :pdf],
      output_modalities: [:embeddings],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_flash_latest,
      code: "gemini-flash-latest",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{batch_api: :supported, caching: :supported, thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_flash_lite_latest,
      code: "gemini-flash-lite-latest",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{batch_api: :supported, caching: :supported, thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_live_2_5_flash_native_audio,
      code: "gemini-live-2.5-flash-native-audio",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/2-5-flash-live-api",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :gemini_nano_banana_2_1,
      code: "gemini-nano-banana-2.1",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/nano-banana-2-1",
      track: :stable,
      latest_update: nil,
      input_modalities: [:text, :image],
      output_modalities: [:image],
      capabilities: %{batch_api: :supported, image_generation: :supported, thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_omni_1_1_flash,
      code: "gemini-omni-1.1-flash",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [:video],
      capabilities: %{thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_omni_1_1_flash_preview,
      code: "gemini-omni-1.1-flash-preview",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/omni-1-1-flash",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [:video],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :gemini_omni_1_2_flash,
      code: "gemini-omni-1.2-flash",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/omni-1-2-flash",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [:video],
      capabilities: %{thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_omni_flash_preview,
      code: "gemini-omni-flash-preview",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/omni-flash-preview",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [:video],
      capabilities: %{thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_pro_latest,
      code: "gemini-pro-latest",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{batch_api: :supported, caching: :supported, thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_robotics_er_2_preview,
      code: "gemini-robotics-er-2-preview",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/robotics-er-2",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{batch_api: :supported, caching: :supported, thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemini_robotics_er_2_streaming_preview,
      code: "gemini-robotics-er-2-streaming-preview",
      source_page: "https://aistudio.google.com/docs/models",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemma_4_26b_a4b_it,
      code: "gemma-4-26b-a4b-it",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :gemma_4_26b_a4b_it_maas,
      code: "gemma-4-26b-a4b-it-maas",
      source_page:
        "https://console.cloud.google.com/agent-platform/publishers/google/model-garden/gemma-4-26b-a4b-it-maas",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :gemma_4_31b_it,
      code: "gemma-4-31b-it",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :lyria_3_clip_preview,
      code: "lyria-3-clip-preview",
      source_page: "https://aistudio.google.com/docs/models",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :lyria_3_pro_preview,
      code: "lyria-3-pro-preview",
      source_page: "https://aistudio.google.com/docs/models",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :lyria_3_5,
      code: "lyria-3.5",
      source_page: "https://aistudio.google.com/docs/models",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :nano_banana_pro_preview,
      code: "nano-banana-pro-preview",
      source_page: "https://aistudio.google.com/docs/models",
      track: :preview,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [],
      capabilities: %{batch_api: :supported, thinking: :supported},
      aliases: [],
      live_modalities: [],
      notes: "Advertised by the Gemini Developer API model list."
    },
    %{
      key: :veo_3_1_fast_generate_001,
      code: "veo-3.1-fast-generate-001",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate#3.1-fast-generate-001",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [:video],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :veo_3_1_generate_001,
      code: "veo-3.1-generate-001",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate#3.1-generate-001",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [:video],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :veo_3_1_lite_generate_001,
      code: "veo-3.1-lite-generate-001",
      source_page:
        "https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate#3.1-lite-generate-001-preview",
      track: :unknown,
      latest_update: nil,
      input_modalities: [],
      output_modalities: [:video],
      capabilities: %{},
      aliases: [],
      live_modalities: [],
      notes: "Documented Vertex publisher ID; access depends on project and location."
    },
    %{
      key: :gemini_4_argon,
      code: "gemini-4-argon",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-4-argon",
      track: :stable,
      latest_update: "October 2026",
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
      notes:
        "Flagship reasoning model; 1M unified context; long decode requires provider opt-in; caching is implicit only (no explicit cachedContents)"
    },
    %{
      key: :gemini_3_8_live,
      code: "gemini-3.8-live",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.8-live",
      track: :stable,
      latest_update: "September 2026",
      input_modalities: [:text, :image, :audio],
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
      aliases: [],
      live_modalities: [:audio],
      live_session_response_modalities: [:audio],
      live_text_input_method: :client_content,
      notes: "Current Gemini 3.8 Live API model; low-latency bidirectional voice and video"
    },
    %{
      key: :gemini_3_8_live_extended_thinking,
      code: "gemini-3.8-live-extended-thinking",
      source_page:
        "https://ai.google.dev/gemini-api/docs/models/gemini-3.8-live-extended-thinking",
      track: :stable,
      latest_update: "September 2026",
      input_modalities: [:text, :image, :audio],
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
      aliases: [],
      live_modalities: [:audio],
      live_session_response_modalities: [:audio],
      live_text_input_method: :client_content,
      notes:
        "Gemini 3.8 Live model with extended background thinking for complex real-time agent tasks"
    },
    %{
      key: :gemini_3_8_flash_tts,
      code: "gemini-3.8-flash-tts",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash-tts",
      track: :stable,
      latest_update: "September 2026",
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
      notes:
        "Studio-grade creative text-to-speech with multi-speaker voice design across 130+ languages"
    },
    %{
      key: :gemini_3_8_flash_lite_tts,
      code: "gemini-3.8-flash-lite-tts",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash-lite-tts",
      track: :stable,
      latest_update: "September 2026",
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
      notes: "High-throughput, cost-efficient text-to-speech variant"
    },
    %{
      key: :gemini_3_8_flash,
      code: "gemini-3.8-flash",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash",
      track: :stable,
      latest_update: "September 2026",
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
      notes: "GA Flash model; thinking levels are low, medium, and high (not minimal)"
    },
    %{
      key: :gemini_3_7_flash,
      code: "gemini-3.7-flash",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.7-flash",
      track: :deprecated,
      latest_update: "August 2026",
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
      notes: "Deprecated on Gemini API; requests are automatically routed to gemini-3.8-flash"
    },
    %{
      key: :gemini_3_6_flash,
      code: "gemini-3.6-flash",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.6-flash",
      track: :stable,
      latest_update: "July 2026",
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
      key: :gemini_3_5_flash,
      code: "gemini-3.5-flash",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash",
      track: :stable,
      latest_update: "May 2026",
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
      key: :gemini_3_5_flash_lite,
      code: "gemini-3.5-flash-lite",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite",
      track: :stable,
      latest_update: "July 2026",
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
      notes: "Low-latency, cost-efficient stable Flash-Lite model"
    },
    %{
      key: :gemini_3_1_flash_lite,
      code: "gemini-3.1-flash-lite",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite",
      track: :stable,
      latest_update: "May 2026",
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
      notes: "Stable successor to the shut-down Gemini 3.1 Flash-Lite Preview"
    },
    %{
      key: :gemini_3_1_flash_image,
      code: "gemini-3.1-flash-image",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-image",
      track: :stable,
      latest_update: "February 2026",
      input_modalities: [:text, :image, :pdf],
      output_modalities: [:text, :image],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :not_supported,
        function_calling: :not_supported,
        image_generation: :supported,
        live_api: :not_supported,
        structured_outputs: :not_supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: "Nano Banana 2"
    },
    %{
      key: :gemini_3_1_flash_lite_image,
      code: "gemini-3.1-flash-lite-image",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite-image",
      track: :stable,
      latest_update: "June 2026",
      input_modalities: [:text, :image],
      output_modalities: [:text, :image],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :not_supported,
        function_calling: :supported,
        image_generation: :supported,
        live_api: :not_supported,
        structured_outputs: :not_supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: "Nano Banana 2 Lite"
    },
    %{
      key: :gemini_3_pro_image,
      code: "gemini-3-pro-image",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-image",
      track: :stable,
      latest_update: "November 2025",
      input_modalities: [:text, :image],
      output_modalities: [:text, :image],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :supported,
        caching: :not_supported,
        function_calling: :not_supported,
        image_generation: :supported,
        live_api: :not_supported,
        structured_outputs: :not_supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: "Nano Banana Pro"
    },
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
      key: :gemini_3_1_flash_lite_preview,
      code: "gemini-3.1-flash-lite-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite-preview",
      track: :deprecated,
      latest_update: "March 2026",
      input_modalities: [:text, :image, :video, :audio, :pdf],
      output_modalities: [:text],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :unknown,
        caching: :unknown,
        function_calling: :supported,
        image_generation: :not_supported,
        live_api: :not_supported,
        structured_outputs: :supported,
        thinking: :supported
      },
      aliases: [],
      live_modalities: [],
      notes: "Shut down May 25, 2026; use gemini-3.1-flash-lite"
    },
    %{
      key: :gemini_3_1_flash_image_preview,
      code: "gemini-3.1-flash-image-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-image-preview",
      track: :preview,
      latest_update: "March 2026",
      input_modalities: [:text, :image],
      output_modalities: [:image],
      capabilities: %{
        audio_generation: :not_supported,
        batch_api: :unknown,
        caching: :not_supported,
        function_calling: :not_supported,
        image_generation: :supported,
        live_api: :not_supported,
        structured_outputs: :unknown,
        thinking: :unknown
      },
      aliases: [],
      live_modalities: [],
      notes: "Nano Banana 2 - high-efficiency image generation and editing"
    },
    %{
      key: :gemini_3_1_flash_live_preview,
      code: "gemini-3.1-flash-live-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-live-preview",
      track: :preview,
      latest_update: "March 2026",
      input_modalities: [:text, :image, :audio, :video],
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
      aliases: [],
      live_modalities: [:audio],
      live_session_response_modalities: [:audio],
      live_text_input_method: :realtime_input,
      notes: "Current Gemini 3 Live model; use audio sessions with transcription for text UX"
    },
    %{
      key: :gemini_3_pro_preview,
      code: "gemini-3-pro-preview",
      source_page: "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-preview",
      track: :deprecated,
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
      live_session_response_modalities: [:audio],
      live_text_input_method: :client_content,
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
  Returns the explicitly supported Live session response modalities for a model.
  """
  @spec live_session_response_modalities(String.t()) :: [modality()]
  def live_session_response_modalities(model_name) when is_binary(model_name) do
    case get(model_name) do
      nil -> []
      entry -> effective_live_session_response_modalities(entry)
    end
  end

  @doc """
  Returns the preferred text input transport for a Live model.
  """
  @spec live_text_input_method(String.t()) :: :client_content | :realtime_input | nil
  def live_text_input_method(model_name) when is_binary(model_name) do
    case get(model_name) do
      %{live_text_input_method: method} when method in [:client_content, :realtime_input] ->
        method

      _ ->
        nil
    end
  end

  @doc """
  Returns preferred Live API candidates for a modality.
  """
  @spec live_candidates(:text | :audio, keyword()) :: [String.t()]
  def live_candidates(modality, _opts \\ []) when modality in [:text, :audio] do
    @entries
    |> Enum.filter(fn entry ->
      Map.get(entry.capabilities, :live_api, :unknown) == :supported and
        modality in effective_live_session_response_modalities(entry)
    end)
    |> Enum.flat_map(fn entry -> [entry.code | entry.aliases] end)
    |> Enum.uniq()
  end

  defp effective_live_session_response_modalities(%{
         live_session_response_modalities: modalities
       })
       when is_list(modalities) and modalities != [],
       do: modalities

  defp effective_live_session_response_modalities(%{live_modalities: modalities})
       when is_list(modalities) and modalities != [],
       do: modalities

  defp effective_live_session_response_modalities(_entry), do: []

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
