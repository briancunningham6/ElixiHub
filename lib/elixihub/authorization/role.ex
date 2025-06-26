defmodule Elixihub.Authorization.Role do
  use Ecto.Schema
  import Ecto.Changeset

  alias Elixihub.Accounts.User
  alias Elixihub.Authorization.Permission

  schema "roles" do
    field :name, :string
    field :description, :string

    many_to_many :users, User, join_through: "user_roles"
    many_to_many :permissions, Permission, join_through: "role_permissions"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
    |> unique_constraint(:name)
  end
end
