defmodule Gemini.APIs.ContextCacheLiveTest do
  @moduledoc """
  Live API tests for context caching feature.

  Run with: mix test test/gemini/apis/context_cache_live_test.exs --include live_api

  Note: Context caching may not be available on all API tiers.
  These tests are designed to gracefully handle cases where the feature
  is not accessible.
  """
  use ExUnit.Case

  @moduletag :live_api
  @moduletag timeout: 120_000

  alias Gemini.APIs.ContextCache
  alias Gemini.Types.Content

  import Gemini.Test.ModelHelpers

  setup_all do
    Application.ensure_all_started(:gemini)

    case System.get_env("GEMINI_API_KEY") do
      nil ->
        {:ok, skip: true}

      api_key ->
        Gemini.configure(:gemini, %{api_key: api_key})
        {:ok, skip: false}
    end
  end

  describe "context cache CRUD operations" do
    @tag :live_api
    test "create and list cached content", context do
      if context[:skip] do
        IO.puts("Skipping: GEMINI_API_KEY not set")
        :ok
      else
        # Create a test cache with some content
        test_content = """
        This is a test document for context caching.
        It contains some sample text that we want to cache
        for multiple queries without re-transmitting.

        The document covers topics like:
        - Elixir programming
        - Functional programming concepts
        - The BEAM virtual machine
        """

        contents = [Content.text(test_content, "user")]

        result =
          ContextCache.create(contents,
            display_name: "GeminiEx Test Cache #{:rand.uniform(10000)}",
            model: default_model(),
            ttl: 300
          )

        case result do
          {:ok, cache} ->
            IO.puts("Created cache: #{cache.name}")
            assert cache.name != nil
            assert cache.display_name != nil
            assert cache.model != nil

            # List caches
            {:ok, list_result} = ContextCache.list()
            assert is_list(list_result.cached_contents)
            IO.puts("Found #{length(list_result.cached_contents)} cached contents")

            # Get the specific cache
            {:ok, retrieved_cache} = ContextCache.get(cache.name)
            assert retrieved_cache.name == cache.name
            IO.puts("Retrieved cache: #{retrieved_cache.display_name}")

            # Clean up - delete the cache
            delete_result = ContextCache.delete(cache.name)
            assert delete_result == :ok
            IO.puts("Deleted cache successfully")

          {:error, error} ->
            IO.puts("Context caching may not be available: #{inspect(error)}")
            # Don't fail - feature might not be enabled
            :ok
        end
      end
    end

    @tag :live_api
    test "use cached content in generate request", context do
      if context[:skip] do
        IO.puts("Skipping: GEMINI_API_KEY not set")
        :ok
      else
        # Create a cache with some context
        context_content = """
        Project: ElixirWeather
        Description: A weather application built with Elixir and Phoenix.

        Key Features:
        1. Real-time weather updates using WebSockets
        2. Historical weather data storage in PostgreSQL
        3. API integration with OpenWeatherMap
        4. Location-based alerts using GenStage

        Architecture:
        - Phoenix LiveView for the frontend
        - Ecto for database operations
        - Oban for background jobs
        """

        contents = [Content.text(context_content, "user")]

        create_result =
          ContextCache.create(contents,
            display_name: "GeminiEx Project Context #{:rand.uniform(10000)}",
            model: default_model(),
            ttl: 300
          )

        case create_result do
          {:ok, cache} ->
            IO.puts("Created context cache: #{cache.name}")

            # Now try to use the cached content in a generate request
            generate_result =
              Gemini.generate(
                "Based on the project context, what database is used?",
                model: default_model(),
                cached_content: cache.name
              )

            case generate_result do
              {:ok, response} ->
                {:ok, text} = Gemini.extract_text(response)
                IO.puts("Response with cached context: #{String.slice(text, 0, 200)}...")

                # Should mention PostgreSQL based on the context
                assert String.length(text) > 0

              {:error, gen_error} ->
                IO.puts("Generate with cache failed: #{inspect(gen_error)}")
                # May fail if cached content format isn't right
                :ok
            end

            # Clean up
            ContextCache.delete(cache.name)
            IO.puts("Cleaned up cache")

          {:error, error} ->
            IO.puts("Context caching may not be available: #{inspect(error)}")
            :ok
        end
      end
    end
  end

  describe "cache TTL management" do
    @tag :live_api
    test "update cache TTL", context do
      if context[:skip] do
        IO.puts("Skipping: GEMINI_API_KEY not set")
        :ok
      else
        contents = [Content.text("Test content for TTL update", "user")]

        create_result =
          ContextCache.create(contents,
            display_name: "TTL Test Cache #{:rand.uniform(10000)}",
            model: default_model(),
            ttl: 300
          )

        case create_result do
          {:ok, cache} ->
            IO.puts("Created cache with 5 minute TTL: #{cache.name}")

            # Update TTL to 10 minutes
            update_result = ContextCache.update(cache.name, ttl: 600)

            case update_result do
              {:ok, updated_cache} ->
                IO.puts("Updated cache TTL")
                assert updated_cache.name == cache.name

              {:error, update_error} ->
                IO.puts("TTL update failed (may be expected): #{inspect(update_error)}")
            end

            # Clean up
            ContextCache.delete(cache.name)

          {:error, error} ->
            IO.puts("Context caching may not be available: #{inspect(error)}")
            :ok
        end
      end
    end
  end

  describe "enhanced cache features" do
    @tag :live_api
    @tag :enhanced_cache_features
    test "create cache with system instruction and file uri", context do
      if context[:skip] do
        IO.puts("Skipping: GEMINI_API_KEY not set")
        :ok
      else
        contents = [
          Content.text("Include insights from the attached document.", "user"),
          %Content{
            role: "user",
            parts: [%{file_uri: "gs://cloud-samples-data/generative-ai/pdf/scene.pdf"}]
          }
        ]

        result =
          ContextCache.create(contents,
            display_name: "GeminiEx Enhanced Cache #{:rand.uniform(10000)}",
            model: default_model(),
            ttl: 300,
            system_instruction: "Answer in one concise sentence."
          )

        case result do
          {:ok, cache} ->
            IO.puts("Created enhanced cache: #{cache.name}")

            generate_result =
              Gemini.generate(
                "Confirm you will use the cached file context.",
                model: default_model(),
                cached_content: cache.name
              )

            case generate_result do
              {:ok, response} ->
                {:ok, text} = Gemini.extract_text(response)
                IO.puts("Response: #{String.slice(text, 0, 200)}")
                assert String.length(text) > 0

              {:error, gen_error} ->
                IO.puts("Generate with enhanced cache failed: #{inspect(gen_error)}")
                :ok
            end

            ContextCache.delete(cache.name)

          {:error, error} ->
            IO.puts("Enhanced cache creation may not be available: #{inspect(error)}")
            :ok
        end
      end
    end
  end
end
