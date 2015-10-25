defmodule ElixirAmi.Supervisor.Ami do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def new(connection_data) do
    Supervisor.start_child __MODULE__, [connection_data]
  end

  def init([]) do
    children = [
      worker(ElixirAmi.Connection, [], restart: :permanent)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
