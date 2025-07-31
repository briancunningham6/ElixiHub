defmodule ElixiPath.Release do
  @moduledoc """
  Used for executing release tasks.
  """
  @app :elixipath

  def migrate do
    # No database migrations needed for ElixiPath
    :ok
  end

  def rollback(version) do
    # No database rollbacks needed for ElixiPath
    {:ok, version}
  end
end