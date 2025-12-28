defmodule Gemini.Supervisor do
  @moduledoc """
  Top-level supervisor for the Gemini application.

  Manages the streaming infrastructure, tool execution runtime, and rate limiting,
  providing a unified supervision tree for all Gemini components.
  """

  use Supervisor

  alias Altar.LATER.Registry
  alias Gemini.RateLimiter.Manager, as: RateLimitManager
  alias Gemini.Streaming.UnifiedManager

  @doc """
  Start the Gemini supervisor.
  """
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(init_arg \\ :ok) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  @spec init(term()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(_init_arg) do
    children = [
      # Rate limiting infrastructure (must start first)
      {RateLimitManager, []},
      # Streaming infrastructure
      {UnifiedManager, []},
      # Tool execution registry with registered name for discoverability
      {Registry, name: Gemini.Tools.Registry}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
