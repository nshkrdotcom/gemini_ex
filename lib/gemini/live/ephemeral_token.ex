defmodule Gemini.Live.EphemeralToken do
  @moduledoc """
  Creates ephemeral tokens for client-side Live API access.

  Ephemeral tokens allow secure client-side WebSocket connections by providing
  short-lived, restricted credentials. They are designed for client-to-server
  implementations where the token is used in a browser or mobile app.

  ## Security Benefits

  - Short-lived tokens reduce risk if extracted from client-side code
  - Tokens can be locked to specific configurations
  - Usage limits prevent token reuse

  ## Usage

      # Server-side: Create token
      {:ok, token} = EphemeralToken.create(
        uses: 1,
        expire_minutes: 30,
        live_connect_constraints: %{
          model: "gemini-2.5-flash-native-audio-preview-12-2025",
          config: %{response_modalities: ["AUDIO"]}
        }
      )

      # Return token.name to client
      # Client uses token.name as API key for WebSocket connection

  ## Token Lifetimes

  - `expire_time` - How long the token is valid for messages (default: 30 minutes)
  - `new_session_expire_time` - Deadline to start a new session (default: 1 minute)

  ## Constraints

  Tokens can be locked to specific configurations:
  - Model name
  - Generation config (response modalities, temperature, etc.)
  - Session resumption settings

  This prevents clients from using the token with different configurations
  than intended by the server.

  ## Note

  Ephemeral tokens are only compatible with the Live API at this time.
  """

  alias Gemini.Client.HTTP

  @type create_opts :: [
          uses: pos_integer(),
          expire_minutes: pos_integer(),
          new_session_expire_minutes: pos_integer(),
          live_connect_constraints: map()
        ]

  @doc """
  Creates an ephemeral token for Live API access.

  ## Options

  - `:uses` - Number of times token can be used (default: 1)
  - `:expire_minutes` - Token expiration in minutes (default: 30)
  - `:new_session_expire_minutes` - New session deadline in minutes (default: 1)
  - `:live_connect_constraints` - Lock token to specific config

  ## Constraints Format

  The `:live_connect_constraints` option accepts a map with:

  - `:model` - Model name to lock to
  - `:config` - Configuration map with:
    - `:response_modalities` - List of modalities (`:audio`, `:text`, or strings)
    - `:temperature` - Temperature setting
    - `:session_resumption` - Session resumption config

  ## Returns

  - `{:ok, %{name: token_string, ...}}` - Token created successfully
  - `{:error, reason}` - Token creation failed

  ## Examples

      # Simple token
      {:ok, token} = EphemeralToken.create()

      # Token with constraints
      {:ok, token} = EphemeralToken.create(
        uses: 1,
        expire_minutes: 15,
        live_connect_constraints: %{
          model: "gemini-2.5-flash-native-audio-preview-12-2025",
          config: %{
            response_modalities: [:audio],
            temperature: 0.7
          }
        }
      )

      # Use the token name as API key
      token.name  # => "authTokens/abc123..."
  """
  @spec create(create_opts()) :: {:ok, map()} | {:error, term()}
  def create(opts \\ []) do
    uses = Keyword.get(opts, :uses, 1)
    expire_minutes = Keyword.get(opts, :expire_minutes, 30)
    new_session_minutes = Keyword.get(opts, :new_session_expire_minutes, 1)
    constraints = Keyword.get(opts, :live_connect_constraints)

    now = DateTime.utc_now()
    expire_time = DateTime.add(now, expire_minutes * 60, :second)
    new_session_expire = DateTime.add(now, new_session_minutes * 60, :second)

    body =
      %{
        "uses" => uses,
        "expireTime" => DateTime.to_iso8601(expire_time),
        "newSessionExpireTime" => DateTime.to_iso8601(new_session_expire)
      }
      |> maybe_add_constraints(constraints)

    case HTTP.post("authTokens", body, api_version: "v1alpha") do
      {:ok, %{"name" => _} = response} ->
        {:ok, response}

      {:ok, response} ->
        {:error, {:unexpected_response, response}}

      {:error, _} = error ->
        error
    end
  end

  # Add constraints if provided
  @spec maybe_add_constraints(map(), map() | nil) :: map()
  defp maybe_add_constraints(body, nil), do: body

  defp maybe_add_constraints(body, constraints) when is_map(constraints) do
    Map.put(body, "liveConnectConstraints", format_constraints(constraints))
  end

  # Format constraints to API format
  @spec format_constraints(map()) :: map()
  defp format_constraints(%{model: model, config: config}) do
    %{
      "model" => model,
      "config" => format_config(config)
    }
  end

  defp format_constraints(%{model: model}) do
    %{"model" => model}
  end

  defp format_constraints(constraints), do: constraints

  # Format config to API format (camelCase keys, string values)
  @spec format_config(map()) :: map()
  defp format_config(config) when is_map(config) do
    config
    |> Enum.map(fn {k, v} -> {to_camel_case(k), format_value(v)} end)
    |> Map.new()
  end

  # Format values (atoms to strings, lists recursively)
  @spec format_value(term()) :: term()
  defp format_value(values) when is_list(values) do
    Enum.map(values, &format_value/1)
  end

  defp format_value(:audio), do: "AUDIO"
  defp format_value(:text), do: "TEXT"
  defp format_value(:image), do: "IMAGE"
  defp format_value(map) when is_map(map), do: format_config(map)
  defp format_value(v), do: v

  # Convert snake_case to camelCase
  @spec to_camel_case(atom() | String.t()) :: String.t()
  defp to_camel_case(key) when is_atom(key), do: to_camel_case(Atom.to_string(key))

  defp to_camel_case(key) when is_binary(key) do
    [first | rest] = String.split(key, "_")
    Enum.join([first | Enum.map(rest, &String.capitalize/1)])
  end
end
