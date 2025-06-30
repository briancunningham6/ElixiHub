defmodule Elixihub.Repo.Migrations.AddAppRoleToUserRoles do
  use Ecto.Migration

  def change do
    alter table(:user_roles) do
      add :app_role_id, references(:app_roles, on_delete: :delete_all), null: true
    end

    create index(:user_roles, [:app_role_id])
    
    # Add constraint to ensure either role_id or app_role_id is present, but not both
    create constraint(:user_roles, :role_type_check, 
      check: "(role_id IS NOT NULL AND app_role_id IS NULL) OR (role_id IS NULL AND app_role_id IS NOT NULL)")
  end
end