defmodule Elixihub.Repo.Migrations.AddArchitectureToHosts do
  use Ecto.Migration

  def change do
    alter table(:hosts) do
      add :architecture, :string, default: "MacOs(Apple Silicon)"
    end
  end
end
