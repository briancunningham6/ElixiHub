defmodule Elixihub.Repo.Migrations.CreateUserRoles do
  use Ecto.Migration

  def change do
    create table(:user_roles, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role_id, references(:roles, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_roles, [:user_id])
    create index(:user_roles, [:role_id])
    create unique_index(:user_roles, [:user_id, :role_id])
  end
end
