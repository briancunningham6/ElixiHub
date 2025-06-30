defmodule Elixihub.Repo.Migrations.AllowNullRoleIdInUserRoles do
  use Ecto.Migration

  def change do
    alter table(:user_roles) do
      modify :role_id, :bigint, null: true
    end
  end
end