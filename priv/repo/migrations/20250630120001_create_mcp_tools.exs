defmodule Elixihub.Repo.Migrations.CreateMcpTools do
  use Ecto.Migration

  def change do
    create table(:mcp_tools) do
      add :name, :string, null: false
      add :description, :text, null: false
      add :input_schema, :map, default: %{}
      add :metadata, :map, default: %{}
      add :server_id, references(:mcp_servers, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_tools, [:server_id, :name])
    create index(:mcp_tools, [:name])
  end
end