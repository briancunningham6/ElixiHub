defmodule Elixihub.Apps.AppRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "app_roles" do
    field :name, :string
    field :description, :string
    field :identifier, :string
    field :permissions, :map, default: %{}
    field :metadata, :map, default: %{}
    
    belongs_to :app, Elixihub.Apps.App

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(app_role, attrs) do
    app_role
    |> cast(attrs, [:name, :description, :identifier, :permissions, :metadata, :app_id])
    |> validate_required([:name, :identifier, :app_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:identifier, min: 1, max: 100)
    |> validate_format(:identifier, ~r/^[a-z0-9_]+$/, 
        message: "must contain only lowercase letters, numbers, and underscores")
    |> unique_constraint([:app_id, :identifier])
  end
end