defmodule Gemini.RateLimiter.Config do
  @moduledoc """
  Configuration management for the rate limiter.

  Provides configuration defaults and profile-based settings for rate limiting,
  concurrency gating, token budgeting, and retry behavior.

  ## Configuration Options

  - `:max_concurrency_per_model` - Maximum concurrent requests per model (default: 4, nil/0 disables)
  - `:max_attempts` - Maximum retry attempts (default: 3)
  - `:base_backoff_ms` - Base backoff duration in milliseconds (default: 1000)
  - `:jitter_factor` - Jitter factor for backoff (default: 0.25)
  - `:non_blocking` - Return immediately with retry_at instead of waiting (default: false)
  - `:disable_rate_limiter` - Disable all rate limiting (default: false)
  - `:adaptive_concurrency` - Enable adaptive concurrency (default: false)
  - `:adaptive_ceiling` - Maximum concurrency when adaptive mode is enabled (default: 8)
  - `:token_budget_per_window` - Maximum tokens per window (default: profile-dependent; base is 32_000, `:prod` profile sets 500_000; nil disables)
  - `:window_duration_ms` - Duration of budget window in milliseconds (default: 60_000)
  - `:max_budget_wait_ms` - Maximum time to block on over-budget windows before returning (default: nil = no cap)
  - `:budget_safety_multiplier` - Multiplier applied to estimated tokens when reserving budget (default: 1.0)
  - `:permit_timeout_ms` - Maximum time to wait for a concurrency permit before timing out (default: :infinity; set a number to cap wait)
  - `:profile` - Configuration profile (see below)

  ## Profiles

  Choose a profile matching your Google Cloud tier. Rate limits are **per-project**
  (not per-API key) and vary by model. View your actual limits in
  [AI Studio](https://aistudio.google.com/usage?timeRange=last-28-days&tab=rate-limit).

  ### Tier Qualifications

  | Tier | Qualification |
  |------|---------------|
  | Free | Users in eligible countries |
  | Tier 1 | Billing account linked to project |
  | Tier 2 | >$250 total spend + 30 days since payment |
  | Tier 3 | >$1,000 total spend + 30 days since payment |

  ### Profile Settings

  | Profile | Best For | Token Budget |
  |---------|----------|--------------|
  | `:free_tier` | Development, testing | 32,000 |
  | `:paid_tier_1` | Standard production | 1,000,000 |
  | `:paid_tier_2` | High throughput | 2,000,000 |
  | `:paid_tier_3` | Maximum throughput | 4,000,000 |
  | `:dev` | Local development | 16,000 |
  | `:prod` | Production (default) | 500,000 |
  | `:custom` | Explicit settings | - |

  **Defaults & precedence**

  - `build/0` uses the `:prod` profile by default → `token_budget_per_window` is `500_000`.
  - The base struct default (`32_000`) is overridden by the selected profile.
  - `:custom` uses the base defaults unless you explicitly override fields.
  - Order of application: base defaults → profile → app config → per-call overrides.

  ## Example Configuration

      # Select a tier profile
      config :gemini_ex, :rate_limiter, profile: :paid_tier_1

      # Or customize specific settings
      config :gemini_ex, :rate_limiter,
        profile: :prod,
        token_budget_per_window: 1_000_000,
        max_concurrency_per_model: 8

      # Disable token budgeting (not recommended)
      config :gemini_ex, :rate_limiter,
        token_budget_per_window: nil
  """

  @type profile ::
          :dev | :prod | :custom | :free_tier | :paid_tier_1 | :paid_tier_2 | :paid_tier_3
  @type t :: %__MODULE__{
          max_concurrency_per_model: non_neg_integer() | nil,
          max_attempts: pos_integer(),
          base_backoff_ms: pos_integer(),
          jitter_factor: float(),
          non_blocking: boolean(),
          disable_rate_limiter: boolean(),
          adaptive_concurrency: boolean(),
          adaptive_ceiling: pos_integer(),
          profile: profile(),
          # Token budget settings (ADR-0002)
          token_budget_per_window: non_neg_integer() | nil,
          window_duration_ms: pos_integer(),
          max_budget_wait_ms: pos_integer() | nil,
          budget_safety_multiplier: float(),
          permit_timeout_ms: pos_integer() | :infinity
        }

  defstruct max_concurrency_per_model: 4,
            max_attempts: 3,
            base_backoff_ms: 1000,
            jitter_factor: 0.25,
            non_blocking: false,
            disable_rate_limiter: false,
            adaptive_concurrency: false,
            adaptive_ceiling: 8,
            profile: :prod,
            # Base fallback defaults (overridden by profiles/app config)
            token_budget_per_window: 32_000,
            window_duration_ms: 60_000,
            # Optional cap on over-budget blocking wait (nil = no cap)
            max_budget_wait_ms: nil,
            # Safety multiplier when reserving tokens
            budget_safety_multiplier: 1.0,
            # Max wait for concurrency permit before erroring (:infinity = no cap)
            permit_timeout_ms: :infinity

  @profiles %{
    # Development profile - lower concurrency, more conservative
    dev: %{
      max_concurrency_per_model: 2,
      max_attempts: 5,
      base_backoff_ms: 2000,
      adaptive_ceiling: 4,
      token_budget_per_window: 16_000,
      adaptive_concurrency: false
    },
    # Production profile - balanced for typical usage
    prod: %{
      max_concurrency_per_model: 4,
      max_attempts: 3,
      base_backoff_ms: 1000,
      adaptive_ceiling: 8,
      token_budget_per_window: 500_000,
      adaptive_concurrency: false
    },
    # Free tier - Conservative for 15 RPM / 1M TPM limits
    free_tier: %{
      max_concurrency_per_model: 2,
      max_attempts: 5,
      base_backoff_ms: 2000,
      token_budget_per_window: 32_000,
      adaptive_concurrency: true,
      adaptive_ceiling: 4
    },
    # Paid Tier 1 - 500 RPM / 4M TPM
    paid_tier_1: %{
      max_concurrency_per_model: 10,
      max_attempts: 3,
      base_backoff_ms: 500,
      token_budget_per_window: 1_000_000,
      adaptive_concurrency: true,
      adaptive_ceiling: 15
    },
    # Paid Tier 2 - High throughput (>$250 spend qualification)
    paid_tier_2: %{
      max_concurrency_per_model: 20,
      max_attempts: 2,
      base_backoff_ms: 250,
      token_budget_per_window: 2_000_000,
      adaptive_concurrency: true,
      adaptive_ceiling: 30
    },
    # Paid Tier 3 - Maximum throughput (>$1,000 spend qualification)
    paid_tier_3: %{
      max_concurrency_per_model: 30,
      max_attempts: 2,
      base_backoff_ms: 100,
      token_budget_per_window: 4_000_000,
      adaptive_concurrency: true,
      adaptive_ceiling: 50
    },
    # Custom - uses only explicit settings, no profile defaults
    custom: %{}
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

  # Private helpers

  defp normalize_concurrency(nil), do: nil
  defp normalize_concurrency(0), do: nil
  defp normalize_concurrency(n) when is_integer(n) and n > 0, do: n
  defp normalize_concurrency(_), do: 4
end
