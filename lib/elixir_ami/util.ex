defmodule ElixirAmi.Util do

  require Logger
  @doc """
  Quick way to get a unique id.
  """
  @spec unique_id() :: String.t
  def unique_id() do
    to_string :erlang.unique_integer
  end
end