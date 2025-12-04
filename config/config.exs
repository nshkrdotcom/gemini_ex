import Config

# Configure the Gemini client
config :gemini_ex,
  # Default model to use if not specified (can also use Gemini.Config.get_model(:default))
  default_model: "gemini-flash-lite-latest",

  # HTTP timeout in milliseconds
  timeout: 30_000,

  # Enable telemetry events
  telemetry_enabled: true

# Import environment specific config
import_config "#{config_env()}.exs"
