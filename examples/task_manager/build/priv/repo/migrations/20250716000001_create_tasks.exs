defmodule TaskManager.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "pending", null: false
      add :priority, :string, default: "medium", null: false
      add :user_id, :string, null: false
      add :assignee_id, :string
      add :due_date, :utc_datetime
      add :completed_at, :utc_datetime
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:user_id])
    create index(:tasks, [:assignee_id])
    create index(:tasks, [:status])
    create index(:tasks, [:priority])
    create index(:tasks, [:due_date])
    create index(:tasks, [:inserted_at])
  end
end