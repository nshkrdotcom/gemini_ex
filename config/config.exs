import Config

# Configure the Gemini client
config :gemini_ex,
  # Default model is auto-detected based on authentication:
  # - Gemini API (GEMINI_API_KEY): "gemini-flash-lite-latest"
  # - Vertex AI (VERTEX_PROJECT_ID): "gemini-2.5-flash-lite"
  # Uncomment to override: default_model: "your-model-name",

  # HTTP timeout in milliseconds
  timeout: 120_000,

  # Enable telemetry events
  telemetry_enabled: true

# Import environment specific config
import_config "#{config_env()}.exs"
