defmodule ElixirAmi.Supervisor.Main do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      supervisor(ElixirAmi.Supervisor.Ami, [], [
        restart: :permanent,
        shutdown: :infinity
      ])
    ]

    supervise(children, strategy: :one_for_one)
  end
end