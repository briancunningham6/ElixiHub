defmodule Elixihub.Repo.Migrations.AddDeploymentFieldsToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add :deployment_status, :string, default: "pending"
      add :deployment_log, :map, default: %{}
      add :deployed_at, :utc_datetime
      add :deploy_path, :string
      add :ssh_host, :string
      add :ssh_port, :integer, default: 22
      add :ssh_username, :string
    end

    create index(:apps, [:deployment_status])
    create index(:apps, [:deployed_at])
  end
end
