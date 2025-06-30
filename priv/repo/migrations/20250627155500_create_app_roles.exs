defmodule Elixihub.Repo.Migrations.CreateAppRoles do
  use Ecto.Migration

  def change do
    create table(:app_roles) do
      add :name, :string, null: false
      add :description, :string
      add :identifier, :string, null: false
      add :permissions, :map, default: %{}
      add :metadata, :map, default: %{}
      add :app_id, references(:apps, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:app_roles, [:app_id, :identifier])
    create index(:app_roles, [:app_id])
    create index(:app_roles, [:name])
  end
end