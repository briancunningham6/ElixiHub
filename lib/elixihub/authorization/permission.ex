defmodule Elixihub.Authorization.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  alias Elixihub.Authorization.Role

  schema "permissions" do
    field :name, :string
    field :description, :string

    many_to_many :roles, Role, join_through: "role_permissions"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
    |> unique_constraint(:name)
  end
end
