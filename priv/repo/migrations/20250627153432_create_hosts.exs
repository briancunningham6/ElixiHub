defmodule Elixihub.Repo.Migrations.CreateHosts do
  use Ecto.Migration

  def change do
    create table(:hosts) do
      add :name, :string, null: false
      add :ip_address, :string, null: false
      add :ssh_hostname, :string, null: false
      add :ssh_password, :string
      add :ssh_port, :integer, default: 22, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:hosts, [:name])
    create unique_index(:hosts, [:ip_address])
    create index(:hosts, [:ssh_hostname])
  end
end
