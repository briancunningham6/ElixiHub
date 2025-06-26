defmodule Elixihub.Repo.Migrations.AddNodeIdToApps do
  use Ecto.Migration

  def change do
    alter table(:apps) do
      add :node_id, references(:nodes, on_delete: :nilify_all)
    end
    
    create index(:apps, [:node_id])
  end
end
