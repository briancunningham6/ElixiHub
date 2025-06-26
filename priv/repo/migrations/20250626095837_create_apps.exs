defmodule Elixihub.Repo.Migrations.CreateApps do
  use Ecto.Migration

  def change do
    create table(:apps) do
      add :name, :string
      add :description, :string
      add :url, :string
      add :api_key, :string
      add :status, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:apps, [:api_key])
    create unique_index(:apps, [:name])
  end
end
