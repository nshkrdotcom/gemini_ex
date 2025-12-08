defmodule Gemini.Auth.TokenCache do
  @moduledoc """
  ETS-based token caching with automatic expiration handling.

  Provides thread-safe token caching to reduce API calls for token refresh.
  Tokens are automatically considered expired based on their TTL, with a
  configurable refresh buffer to ensure tokens are refreshed before expiration.

  ## Features

  - Thread-safe ETS-based storage
  - Automatic expiration handling
  - Refresh buffer (default 5 minutes before expiry)
  - Multiple cache key support for different credentials

  ## Usage

      # Initialize the cache (called automatically on application start)
      TokenCache.init()

      # Cache a token with 3600 second TTL
      TokenCache.put("my_key", "access_token_here", 3600)

      # Retrieve cached token (returns nil if expired)
      case TokenCache.get("my_key") do
        {:ok, token} -> {:ok, token}
        :error -> # Token expired or not found, refresh needed
      end

      # Invalidate a cached token
      TokenCache.invalidate("my_key")
  """

  require Logger

  @table_name :gemini_token_cache
  # Refresh tokens 5 minutes (300 seconds) before they expire
  @default_refresh_buffer 300

  @type cache_key :: String.t() | atom()
  @type token :: String.t()
  @type ttl :: pos_integer()
  @type cache_entry :: {cache_key(), token(), expiry_time :: integer()}

  @doc """
  Initialize the token cache table.

  Creates an ETS table for storing tokens. This is called automatically
  when the application starts, but can be called manually if needed.

  Safe to call multiple times - if the table already exists, it will
  not create a new one.

  ## Examples

      iex> Gemini.Auth.TokenCache.init()
      :ok
  """
  @spec init() :: :ok
  def init do
    case :ets.whereis(@table_name) do
      :undefined ->
        # Serialize creation so concurrent callers don't crash with :already_exists
        :global.trans({:gemini_token_cache_init, node()}, fn ->
          case :ets.whereis(@table_name) do
            :undefined ->
              try do
                :ets.new(@table_name, [
                  :set,
                  :public,
                  :named_table,
                  read_concurrency: true,
                  write_concurrency: true
                ])

                Logger.debug("[TokenCache] Initialized token cache table")
              rescue
                ArgumentError ->
                  # Another process created the table first
                  :ok
              end

            _ref ->
              :ok
          end
        end)

        :ok

      _ref ->
        # Table already exists
        :ok
    end
  end

  @doc """
  Cache a token with the specified time-to-live (TTL).

  The token will be considered expired after `ttl` seconds, minus the
  refresh buffer (default 5 minutes). This ensures tokens are refreshed
  before they actually expire.

  ## Parameters

  - `key`: Unique identifier for this token (string or atom)
  - `token`: The access token to cache
  - `ttl`: Time-to-live in seconds

  ## Options

  - `:refresh_buffer` - Seconds before expiry to consider token expired
    (default: 300 seconds / 5 minutes)

  ## Examples

      # Cache token for 1 hour
      TokenCache.put("vertex_ai_token", "ya29.abc123", 3600)

      # Cache with custom refresh buffer (refresh 10 minutes early)
      TokenCache.put("my_token", "token123", 3600, refresh_buffer: 600)
  """
  @spec put(cache_key(), token(), ttl(), keyword()) :: :ok
  def put(key, token, ttl, opts \\ []) when is_binary(token) and is_integer(ttl) and ttl > 0 do
    refresh_buffer = Keyword.get(opts, :refresh_buffer, @default_refresh_buffer)

    # Calculate actual expiry time with buffer
    effective_ttl = max(ttl - refresh_buffer, 0)
    expiry_time = System.system_time(:second) + effective_ttl

    ensure_table_exists()
    :ets.insert(@table_name, {key, token, expiry_time})

    Logger.debug(
      "[TokenCache] Cached token for #{inspect(key)} (expires in #{effective_ttl}s, buffer: #{refresh_buffer}s)"
    )

    :ok
  end

  @doc """
  Retrieve a cached token if it exists and has not expired.

  Returns `{:ok, token}` if the token is cached and still valid,
  or `:error` if the token is expired or not found.

  ## Parameters

  - `key`: The cache key used when storing the token

  ## Returns

  - `{:ok, token}` - Token is cached and still valid
  - `:error` - Token is expired, not found, or cache not initialized

  ## Examples

      case TokenCache.get("my_key") do
        {:ok, token} ->
          # Use the cached token
          {:ok, token}

        :error ->
          # Token expired or not found, need to refresh
          refresh_token()
      end
  """
  @spec get(cache_key()) :: {:ok, token()} | :error
  def get(key) do
    case :ets.whereis(@table_name) do
      :undefined ->
        Logger.warning("[TokenCache] Token cache not initialized")
        :error

      _ref ->
        case :ets.lookup(@table_name, key) do
          [{^key, token, expiry_time}] ->
            now = System.system_time(:second)

            if now < expiry_time do
              Logger.debug("[TokenCache] Cache hit for #{inspect(key)}")
              {:ok, token}
            else
              Logger.debug(
                "[TokenCache] Cache expired for #{inspect(key)} (expired #{now - expiry_time}s ago)"
              )

              # Clean up expired entry
              :ets.delete(@table_name, key)
              :error
            end

          [] ->
            Logger.debug("[TokenCache] Cache miss for #{inspect(key)}")
            :error
        end
    end
  end

  @doc """
  Invalidate (remove) a cached token.

  Useful when you know a token is no longer valid and want to force
  a refresh on the next request.

  ## Parameters

  - `key`: The cache key to invalidate

  ## Examples

      TokenCache.invalidate("my_key")
  """
  @spec invalidate(cache_key()) :: :ok
  def invalidate(key) do
    ensure_table_exists()
    :ets.delete(@table_name, key)
    Logger.debug("[TokenCache] Invalidated cache for #{inspect(key)}")
    :ok
  end

  @doc """
  Clear all cached tokens.

  Removes all entries from the cache. Useful for testing or when
  you need to force refresh all tokens.

  ## Examples

      TokenCache.clear()
  """
  @spec clear() :: :ok
  def clear do
    ensure_table_exists()
    :ets.delete_all_objects(@table_name)
    Logger.debug("[TokenCache] Cleared all cached tokens")
    :ok
  end

  @doc """
  Get statistics about the token cache.

  Returns information about the cache including number of entries
  and which tokens are cached.

  ## Returns

  Map with cache statistics:
  - `:size` - Number of cached tokens
  - `:keys` - List of cache keys

  ## Examples

      TokenCache.stats()
      #=> %{size: 2, keys: ["vertex_ai_token", "another_token"]}
  """
  @spec stats() :: %{size: non_neg_integer(), keys: [cache_key()]}
  def stats do
    case :ets.whereis(@table_name) do
      :undefined ->
        %{size: 0, keys: []}

      _ref ->
        size = :ets.info(@table_name, :size)
        keys = :ets.match(@table_name, {:"$1", :_, :_}) |> List.flatten()

        %{size: size, keys: keys}
    end
  end

  # Private helpers

  defp ensure_table_exists do
    case :ets.whereis(@table_name) do
      :undefined -> init()
      _ref -> :ok
    end
  end
end
