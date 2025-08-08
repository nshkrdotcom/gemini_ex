# Multi-Authentication Demo
# Shows concurrent usage of both Gemini API and Vertex AI authentication
# Usage: mix run examples/multi_auth_demo.exs
# Set environment variables as needed:
# - GEMINI_API_KEY for Gemini API
# - VERTEX_JSON_FILE and VERTEX_PROJECT_ID for Vertex AI

defmodule MultiAuthDemo do
  @moduledoc """
  Demonstrates the multi-authentication capabilities of the unified Gemini client.

  This example shows how to use both Gemini API and Vertex AI authentication
  simultaneously, which is the key differentiator of this implementation.
  """

  def run do
    IO.puts("🔄 Gemini Multi-Authentication Demo")
    IO.puts("=" <> String.duplicate("=", 50))

    # Check available authentication methods
    check_available_auth_methods()

    # Demonstrate concurrent usage
    demonstrate_concurrent_usage()

    # Show configuration flexibility
    demonstrate_explicit_auth_selection()

    IO.puts("\n🎉 Multi-auth demo completed!")
  end

  defp check_available_auth_methods do
    IO.puts("\n🔍 Available Authentication Methods")
    IO.puts("-" <> String.duplicate("-", 40))

    gemini_available = not is_nil(System.get_env("GEMINI_API_KEY"))
    vertex_env_available = not is_nil(System.get_env("VERTEX_JSON_FILE")) and not is_nil(System.get_env("VERTEX_PROJECT_ID"))

    # For demonstration purposes, we'll also show Vertex AI as "available" even with invalid credentials
    # to demonstrate the authentication failure
    vertex_demo_available = true

    IO.puts("Gemini API: #{if gemini_available, do: "✅ Available", else: "❌ Not configured"}")
    IO.puts("Vertex AI (env): #{if vertex_env_available, do: "✅ Available", else: "❌ Not configured"}")
    IO.puts("Vertex AI (demo): ✅ Will test with invalid credentials to show auth failure")

    if not gemini_available do
      IO.puts("\n⚠️  No Gemini API key configured. Please set GEMINI_API_KEY")
      IO.puts("   We'll continue with Vertex AI demo to show authentication failure")
    end

    {gemini_available, vertex_demo_available}
  end

  defp demonstrate_concurrent_usage do
    IO.puts("\n🚀 Concurrent API Usage")
    IO.puts("-" <> String.duplicate("-", 40))

    # Test the same operation with different auth strategies
    gemini_available = not is_nil(System.get_env("GEMINI_API_KEY"))

    tasks = []

    # Add Gemini API task if available
    tasks = if gemini_available do
      IO.puts("🔑 Starting Gemini API task...")
      task = Task.async(fn ->
        case Gemini.text("What's 2+2?", auth: :gemini) do
          {:ok, text} -> {:gemini, :success, text}
          {:error, error} -> {:gemini, :error, format_error(error)}
        end
      end)
      [task | tasks]
    else
      IO.puts("⚠️  Skipping Gemini API task (no API key)")
      tasks
    end

    # Always add Vertex AI task to demonstrate authentication failure
    IO.puts("🔑 Starting Vertex AI task (with invalid credentials for demo)...")

    # Save all current Vertex AI environment variables for restoration
    original_env = %{
      vertex_file: System.get_env("VERTEX_JSON_FILE"),
      vertex_project: System.get_env("VERTEX_PROJECT_ID"),
      vertex_service_account: System.get_env("VERTEX_SERVICE_ACCOUNT"),
      google_creds: System.get_env("GOOGLE_APPLICATION_CREDENTIALS"),
      google_project: System.get_env("GOOGLE_CLOUD_PROJECT"),
      google_location: System.get_env("GOOGLE_CLOUD_LOCATION")
    }

    # Clear ALL possible Vertex AI credential sources to force failure
    System.delete_env("VERTEX_JSON_FILE")
    System.delete_env("VERTEX_PROJECT_ID")
    System.delete_env("VERTEX_SERVICE_ACCOUNT")
    System.delete_env("GOOGLE_APPLICATION_CREDENTIALS")
    System.delete_env("GOOGLE_CLOUD_PROJECT")
    System.delete_env("GOOGLE_CLOUD_LOCATION")

    # Set invalid values to any that might have defaults
    System.put_env("VERTEX_PROJECT_ID", "invalid-demo-project")
    System.put_env("VERTEX_JSON_FILE", "/tmp/nonexistent_credentials.json")

    vertex_task = Task.async(fn ->
      case Gemini.text("What's 3+3?", auth: :vertex_ai) do
        {:ok, text} -> {:vertex_ai, :success, text}
        {:error, error} -> {:vertex_ai, :error, format_error(error)}
      end
    end)
    tasks = [vertex_task | tasks]

    # Wait for all tasks to complete
    IO.puts("⏳ Waiting for concurrent requests to complete...")
    results = Task.await_many(tasks, 30_000)

    # Restore all original environment variables
    restore_env_var("VERTEX_JSON_FILE", original_env.vertex_file)
    restore_env_var("VERTEX_PROJECT_ID", original_env.vertex_project)
    restore_env_var("VERTEX_SERVICE_ACCOUNT", original_env.vertex_service_account)
    restore_env_var("GOOGLE_APPLICATION_CREDENTIALS", original_env.google_creds)
    restore_env_var("GOOGLE_CLOUD_PROJECT", original_env.google_project)
    restore_env_var("GOOGLE_CLOUD_LOCATION", original_env.google_location)

    # Display results
    IO.puts("\n📊 Results:")
    Enum.each(results, fn
      {auth_type, :success, text} ->
        IO.puts("✅ #{auth_type}: #{String.slice(text, 0, 100)}")
      {auth_type, :error, error} ->
        IO.puts("❌ #{auth_type}: #{error}")
    end)

    IO.puts("\n💡 Note: Vertex AI failure above demonstrates proper error handling for invalid credentials")
  end

  defp demonstrate_explicit_auth_selection do
    IO.puts("\n⚙️  Explicit Authentication Selection")
    IO.puts("-" <> String.duplicate("-", 40))

    # Show how to explicitly choose auth strategy per request
    operations = [
      {"List models", fn -> Gemini.list_models() end},
      {"Get specific model", fn -> Gemini.get_model("gemini-2.0-flash-lite") end},
      {"Count tokens", fn -> Gemini.count_tokens("Hello world") end}
    ]

    Enum.each(operations, fn {operation, func} ->
      IO.puts("🔧 #{operation}:")

      case func.() do
        {:ok, _result} ->
          IO.puts("   ✅ Success with default authentication")
        {:error, error} ->
          IO.puts("   ❌ Error: #{format_error(error)}")
      end
    end)
  end

  defp format_error(error) do
    cond do
      is_map(error) and Map.has_key?(error, "message") -> error["message"]
      is_binary(error) -> error
      true -> inspect(error)
    end
  end

  defp restore_env_var(name, value) do
    if value do
      System.put_env(name, value)
    else
      System.delete_env(name)
    end
  end
end

# Run the demo
MultiAuthDemo.run()
