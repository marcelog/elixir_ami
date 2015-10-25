defmodule ElixirAmi do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(ElixirAmi.Supervisor.Main, [])
    ]

    opts = [strategy: :one_for_one]
    Supervisor.start_link children, opts
  end
end
