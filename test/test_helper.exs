ExUnit.start(exclude: [:live_api])

# Ensure token cache table exists before async tests run
Gemini.Auth.TokenCache.init()
