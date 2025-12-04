defmodule Gemini.RateLimiter.Config do
  @moduledoc """
  Configuration management for the rate limiter.

  Provides configuration defaults and profile-based settings for rate limiting,
  concurrency gating, and retry behavior.

  ## Configuration Options

  - `:max_concurrency_per_model` - Maximum concurrent requests per model (default: 4, nil/0 disables)
  - `:max_attempts` - Maximum retry attempts (default: 3)
  - `:base_backoff_ms` - Base backoff duration in milliseconds (default: 1000)
  - `:jitter_factor` - Jitter factor for backoff (default: 0.25)
  - `:non_blocking` - Return immediately with retry_at instead of waiting (default: false)
  - `:disable_rate_limiter` - Disable all rate limiting (default: false)
  - `:adaptive_concurrency` - Enable adaptive concurrency (default: false)
  - `:adaptive_ceiling` - Maximum concurrency when adaptive mode is enabled (default: 8)
  - `:profile` - Configuration profile (:dev | :prod | :custom)

  ## Profiles

  - `:dev` - Lower concurrency (2), longer backoff, more verbose
  - `:prod` - Higher concurrency (4), optimized for throughput
  - `:custom` - Uses only explicitly provided settings
  """

  @type profile :: :dev | :prod | :custom
  @type t :: %__MODULE__{
          max_concurrency_per_model: non_neg_integer() | nil,
          max_attempts: pos_integer(),
          base_backoff_ms: pos_integer(),
          jitter_factor: float(),
          non_blocking: boolean(),
          disable_rate_limiter: boolean(),
          adaptive_concurrency: boolean(),
          adaptive_ceiling: pos_integer(),
          profile: profile()
        }

  defstruct max_concurrency_per_model: 4,
            max_attempts: 3,
            base_backoff_ms: 1000,
            jitter_factor: 0.25,
            non_blocking: false,
            disable_rate_limiter: false,
            adaptive_concurrency: false,
            adaptive_ceiling: 8,
            profile: :prod

  @profiles %{
    dev: %{
      max_concurrency_per_model: 2,
      max_attempts: 5,
      base_backoff_ms: 2000,
      adaptive_ceiling: 4
    },
    prod: %{
      max_concurrency_per_model: 4,
      max_attempts: 3,
      base_backoff_ms: 1000,
      adaptive_ceiling: 8
    }
  }

  @doc """
  Build a configuration struct from application config and overrides.

  ## Parameters

  - `overrides` - Keyword list of configuration overrides

  ## Examples

      config = Config.build(max_concurrency_per_model: 8, profile: :prod)
  """
  @spec build(keyword()) :: t()
  def build(overrides \\ []) do
    # Get base config from application environment
    app_config = Application.get_env(:gemini_ex, :rate_limiter, [])

    # Merge in order: defaults -> profile -> app_config -> overrides
    profile = Keyword.get(overrides, :profile) || Keyword.get(app_config, :profile, :prod)
    profile_config = Map.get(@profiles, profile, %{})

    base =
      %__MODULE__{}
      |> struct(profile_config)
      |> struct(Enum.into(app_config, %{}))
      |> struct(Enum.into(overrides, %{}))

    # Normalize nil/0 concurrency to disabled
    %{base | max_concurrency_per_model: normalize_concurrency(base.max_concurrency_per_model)}
  end

  @doc """
  Check if rate limiting is enabled.
  """
  @spec enabled?(t()) :: boolean()
  def enabled?(%__MODULE__{disable_rate_limiter: disabled}), do: not disabled

  @doc """
  Check if concurrency gating is enabled.
  """
  @spec concurrency_enabled?(t()) :: boolean()
  def concurrency_enabled?(%__MODULE__{max_concurrency_per_model: max}) do
    is_integer(max) and max > 0
  end

  @doc """
  Check if adaptive concurrency is enabled.
  """
  @spec adaptive_enabled?(t()) :: boolean()
  def adaptive_enabled?(%__MODULE__{adaptive_concurrency: adaptive}), do: adaptive

  @doc """
  Get profile-specific configuration.
  """
  @spec profile_config(profile()) :: map()
  def profile_config(profile), do: Map.get(@profiles, profile, %{})

  # Private helpers

  defp normalize_concurrency(nil), do: nil
  defp normalize_concurrency(0), do: nil
  defp normalize_concurrency(n) when is_integer(n) and n > 0, do: n
  defp normalize_concurrency(_), do: 4
end
