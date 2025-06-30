defmodule Elixihub.Repo.Migrations.RemoveSshHostnameFromHosts do
  use Ecto.Migration

  def up do
    alter table(:hosts) do
      remove :ssh_hostname
    end
  end

  def down do
    alter table(:hosts) do
      add :ssh_hostname, :string
    end
  end
end