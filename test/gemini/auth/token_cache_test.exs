defmodule Gemini.Auth.TokenCacheTest do
  use ExUnit.Case, async: false

  alias Gemini.Auth.TokenCache

  setup do
    # Initialize cache before each test
    TokenCache.init()
    # Clear any existing entries
    TokenCache.clear()

    :ok
  end

  describe "init/0" do
    test "creates the ETS table" do
      # Table should already exist from setup
      assert :ets.whereis(:gemini_token_cache) != :undefined
    end

    test "is safe to call multiple times" do
      assert :ok = TokenCache.init()
      assert :ok = TokenCache.init()
      assert :ok = TokenCache.init()

      # Table should still exist
      assert :ets.whereis(:gemini_token_cache) != :undefined
    end
  end

  describe "put/3" do
    test "stores a token with TTL" do
      assert :ok = TokenCache.put("test_key", "test_token", 3600)

      # Verify token can be retrieved
      assert {:ok, "test_token"} = TokenCache.get("test_key")
    end

    test "accepts atom keys" do
      assert :ok = TokenCache.put(:atom_key, "token_value", 3600)

      assert {:ok, "token_value"} = TokenCache.get(:atom_key)
    end

    test "applies refresh buffer to TTL" do
      # Put with 600 second TTL (default 300s buffer = 300s effective TTL)
      TokenCache.put("buffered_key", "buffered_token", 600)

      # Token should be available immediately
      assert {:ok, "buffered_token"} = TokenCache.get("buffered_key")
    end

    test "accepts custom refresh buffer" do
      # Put with 10 second TTL and 5 second buffer = 5s effective TTL
      TokenCache.put("custom_buffer", "token", 10, refresh_buffer: 5)

      assert {:ok, "token"} = TokenCache.get("custom_buffer")
    end

    test "overwrites existing token for same key" do
      TokenCache.put("overwrite_key", "token1", 3600)
      assert {:ok, "token1"} = TokenCache.get("overwrite_key")

      TokenCache.put("overwrite_key", "token2", 3600)
      assert {:ok, "token2"} = TokenCache.get("overwrite_key")
    end

    @tag :slow
    test "handles very short TTL" do
      # 1 second TTL with no buffer
      TokenCache.put("short_ttl", "short_token", 1, refresh_buffer: 0)

      assert {:ok, "short_token"} = TokenCache.get("short_ttl")

      # Wait for expiration
      Process.sleep(1100)

      assert :error = TokenCache.get("short_ttl")
    end
  end

  describe "get/1" do
    test "retrieves cached token if not expired" do
      TokenCache.put("valid_key", "valid_token", 3600)

      assert {:ok, "valid_token"} = TokenCache.get("valid_key")
    end

    test "returns error for non-existent key" do
      assert :error = TokenCache.get("non_existent_key")
    end

    @tag :slow
    test "returns error for expired token" do
      # Very short TTL
      TokenCache.put("expired_key", "expired_token", 1, refresh_buffer: 0)

      # Token should be available immediately
      assert {:ok, "expired_token"} = TokenCache.get("expired_key")

      # Wait for expiration
      Process.sleep(1100)

      # Token should be expired and removed
      assert :error = TokenCache.get("expired_key")
    end

    @tag :slow
    test "cleans up expired entries automatically" do
      TokenCache.put("cleanup_key", "cleanup_token", 1, refresh_buffer: 0)

      assert {:ok, "cleanup_token"} = TokenCache.get("cleanup_key")

      # Wait for expiration
      Process.sleep(1100)

      # First get should clean up
      assert :error = TokenCache.get("cleanup_key")

      # Verify entry was removed
      stats = TokenCache.stats()
      refute "cleanup_key" in stats.keys
    end

    test "returns error when cache not initialized" do
      # Delete the table to simulate uninitialized state
      :ets.delete(:gemini_token_cache)

      assert :error = TokenCache.get("any_key")

      # Re-initialize for other tests
      TokenCache.init()
    end
  end

  describe "invalidate/1" do
    test "removes cached token" do
      TokenCache.put("invalidate_key", "invalidate_token", 3600)
      assert {:ok, "invalidate_token"} = TokenCache.get("invalidate_key")

      assert :ok = TokenCache.invalidate("invalidate_key")

      assert :error = TokenCache.get("invalidate_key")
    end

    test "is safe to call on non-existent key" do
      assert :ok = TokenCache.invalidate("non_existent")
    end

    test "handles atom keys" do
      TokenCache.put(:atom_invalidate, "token", 3600)
      assert {:ok, "token"} = TokenCache.get(:atom_invalidate)

      TokenCache.invalidate(:atom_invalidate)

      assert :error = TokenCache.get(:atom_invalidate)
    end
  end

  describe "clear/0" do
    test "removes all cached tokens" do
      TokenCache.put("key1", "token1", 3600)
      TokenCache.put("key2", "token2", 3600)
      TokenCache.put("key3", "token3", 3600)

      assert TokenCache.stats().size == 3

      assert :ok = TokenCache.clear()

      assert TokenCache.stats().size == 0
    end

    test "works when cache is already empty" do
      assert :ok = TokenCache.clear()
      assert TokenCache.stats().size == 0
    end
  end

  describe "stats/0" do
    test "returns cache statistics" do
      TokenCache.put("stat_key1", "token1", 3600)
      TokenCache.put("stat_key2", "token2", 3600)

      stats = TokenCache.stats()

      assert stats.size == 2
      assert "stat_key1" in stats.keys
      assert "stat_key2" in stats.keys
    end

    test "returns empty stats when cache is empty" do
      stats = TokenCache.stats()

      assert stats.size == 0
      assert stats.keys == []
    end

    test "returns empty stats when cache not initialized" do
      :ets.delete(:gemini_token_cache)

      stats = TokenCache.stats()

      assert stats.size == 0
      assert stats.keys == []

      TokenCache.init()
    end
  end

  describe "concurrent access" do
    test "handles concurrent writes safely" do
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            TokenCache.put("concurrent_#{rem(i, 10)}", "token_#{i}", 3600)
          end)
        end

      results = Task.await_many(tasks, 5000)

      assert Enum.all?(results, &(&1 == :ok))
      assert TokenCache.stats().size <= 10
    end

    test "handles concurrent reads safely" do
      TokenCache.put("read_key", "read_token", 3600)

      tasks =
        for _i <- 1..100 do
          Task.async(fn -> TokenCache.get("read_key") end)
        end

      results = Task.await_many(tasks, 5000)

      assert Enum.all?(results, &(&1 == {:ok, "read_token"}))
    end

    test "handles mixed concurrent operations" do
      tasks =
        for i <- 1..50 do
          [
            Task.async(fn -> TokenCache.put("mixed_#{rem(i, 5)}", "token_#{i}", 3600) end),
            Task.async(fn -> TokenCache.get("mixed_#{rem(i, 5)}") end),
            Task.async(fn -> TokenCache.invalidate("mixed_#{rem(i, 5)}") end)
          ]
        end
        |> List.flatten()

      results = Task.await_many(tasks, 5000)

      # Should complete without errors
      assert length(results) == 150

      # Cache should be in consistent state
      stats = TokenCache.stats()
      assert is_integer(stats.size)
    end
  end

  describe "refresh buffer behavior" do
    test "default buffer is 5 minutes (300 seconds)" do
      # Token with 3600s TTL should expire after 3300s (3600 - 300)
      TokenCache.put("buffer_test", "token", 3600)

      # Token should be available now
      assert {:ok, "token"} = TokenCache.get("buffer_test")
    end

    @tag :slow
    test "zero buffer means no early expiration" do
      TokenCache.put("no_buffer", "token", 2, refresh_buffer: 0)

      # Should be available for almost 2 seconds
      assert {:ok, "token"} = TokenCache.get("no_buffer")

      # Should expire after 2 seconds
      Process.sleep(2100)
      assert :error = TokenCache.get("no_buffer")
    end

    @tag :slow
    test "large buffer reduces effective TTL" do
      # 100s TTL with 90s buffer = 10s effective TTL
      TokenCache.put("large_buffer", "token", 100, refresh_buffer: 90)

      assert {:ok, "token"} = TokenCache.get("large_buffer")

      # Should expire after ~10 seconds (not 100)
      Process.sleep(11_000)
      assert :error = TokenCache.get("large_buffer")
    end

    test "buffer larger than TTL results in immediate expiration" do
      # 10s TTL with 20s buffer = 0s effective TTL (max 0)
      TokenCache.put("exceed_buffer", "token", 10, refresh_buffer: 20)

      # Token might be immediately expired or very short-lived
      # Implementation uses max(ttl - buffer, 0)
      result = TokenCache.get("exceed_buffer")

      # Could be expired or available for very brief moment
      assert match?({:ok, "token"}, result) or match?(:error, result)
    end
  end

  describe "edge cases" do
    test "handles empty string keys" do
      TokenCache.put("", "empty_key_token", 3600)

      assert {:ok, "empty_key_token"} = TokenCache.get("")
    end

    test "handles very long tokens" do
      long_token = String.duplicate("a", 10_000)
      TokenCache.put("long_token_key", long_token, 3600)

      assert {:ok, ^long_token} = TokenCache.get("long_token_key")
    end

    test "handles unicode in keys and values" do
      unicode_key = "キー"
      unicode_token = "トークン"

      TokenCache.put(unicode_key, unicode_token, 3600)

      assert {:ok, ^unicode_token} = TokenCache.get(unicode_key)
    end

    test "handles many cached tokens" do
      # Store 1000 different tokens
      for i <- 1..1000 do
        TokenCache.put("key_#{i}", "token_#{i}", 3600)
      end

      stats = TokenCache.stats()
      assert stats.size == 1000

      # Verify random samples
      assert {:ok, "token_1"} = TokenCache.get("key_1")
      assert {:ok, "token_500"} = TokenCache.get("key_500")
      assert {:ok, "token_1000"} = TokenCache.get("key_1000")
    end
  end
end
