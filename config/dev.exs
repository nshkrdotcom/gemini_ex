import Config

# Development configuration
config :gemini_ex,
  # Enable debug logging in development
  log_level: :debug

# Standalone development can set an API key here or use environment variables.
# Governed execution passes Gemini.GovernedAuthority instead.
# config :gemini_ex, api_key: "your_development_api_key"
