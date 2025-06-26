defmodule Elixihub.Repo.Migrations.CreateRolePermissions do
  use Ecto.Migration

  def change do
    create table(:role_permissions, primary_key: false) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:role_permissions, [:role_id])
    create index(:role_permissions, [:permission_id])
    create unique_index(:role_permissions, [:role_id, :permission_id])
  end
end
