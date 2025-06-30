defmodule Elixihub.Repo.Migrations.AddSshUsernameToHosts do
  use Ecto.Migration

  def change do
    alter table(:hosts) do
      add :ssh_username, :string
    end
  end
end