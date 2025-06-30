defmodule Elixihub.Repo.Migrations.FixNullSshUsernames do
  use Ecto.Migration

  def up do
    # Update any existing hosts with null ssh_username to use 'root' as default
    execute "UPDATE hosts SET ssh_username = 'root' WHERE ssh_username IS NULL"
  end

  def down do
    # No need to revert this change
    :ok
  end
end