ExUnit.start(exclude: [:live_api, :slow])

# Ensure token cache table exists before async tests run
Gemini.Auth.TokenCache.init()
