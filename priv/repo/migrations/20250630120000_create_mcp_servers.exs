defmodule Elixihub.Repo.Migrations.CreateMcpServers do
  use Ecto.Migration

  def change do
    create table(:mcp_servers) do
      add :name, :string, null: false
      add :url, :string, null: false
      add :description, :text
      add :version, :string
      add :status, :string, default: "active", null: false
      add :metadata, :map, default: %{}
      add :app_id, references(:apps, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_servers, [:app_id])
    create index(:mcp_servers, [:status])
    create index(:mcp_servers, [:name])
  end
end