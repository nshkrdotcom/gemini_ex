import Config

# Suppress all console log output during tests (only show test dots)
# But keep Logger enabled so ExUnit.CaptureLog can capture logs for assertions
config :logger, :console, level: :none

# Test configuration
config :gemini_ex,
  # Disable telemetry in tests
  telemetry_enabled: false,

  # Use mock endpoints in tests
  mock_mode: true
