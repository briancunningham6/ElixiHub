defmodule Elixihub.Repo.Migrations.AddDeployAsServiceToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add :deploy_as_service, :boolean, default: true
    end
  end
end