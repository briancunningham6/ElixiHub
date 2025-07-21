defmodule TaskManager.Repo.Migrations.AddPrivateToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :private, :boolean, default: false, null: false
    end
  end
end
