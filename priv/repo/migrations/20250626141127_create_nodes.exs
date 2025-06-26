defmodule Elixihub.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:nodes) do
      add :name, :string, null: false
      add :host, :string, null: false
      add :port, :integer, null: false
      add :cookie, :string, null: false
      add :description, :text
      add :status, :string, default: "disconnected", null: false
      add :is_current, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
    
    create unique_index(:nodes, [:name])
    create index(:nodes, [:status])
    create index(:nodes, [:is_current])
  end
end
