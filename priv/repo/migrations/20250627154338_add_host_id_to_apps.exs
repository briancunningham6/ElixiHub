defmodule Elixihub.Repo.Migrations.AddHostIdToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add :host_id, references(:hosts, on_delete: :nilify_all), null: true
    end

    create index(:apps, [:host_id])
  end
end
