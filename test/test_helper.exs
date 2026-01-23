ExUnit.start(exclude: [:live_api, :live_gemini, :live_vertex_ai, :slow])

# Ensure token cache table exists before async tests run
Gemini.Auth.TokenCache.init()
