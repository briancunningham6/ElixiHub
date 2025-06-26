defmodule Elixihub.Authorization.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  alias Elixihub.Accounts.User
  alias Elixihub.Authorization.Role

  @primary_key false
  schema "user_roles" do
    belongs_to :user, User
    belongs_to :role, Role

    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id])
    |> validate_required([:user_id, :role_id])
    |> unique_constraint([:user_id, :role_id])
  end
end