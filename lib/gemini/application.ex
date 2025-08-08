defmodule Gemini.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Gemini.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Gemini.Application.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
