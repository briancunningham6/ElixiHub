defmodule Elixihub.Authorization.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  alias Elixihub.Accounts.User
  alias Elixihub.Authorization.Role
  alias Elixihub.Apps.AppRole

  @primary_key false
  schema "user_roles" do
    belongs_to :user, User
    belongs_to :role, Role
    belongs_to :app_role, AppRole

    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :app_role_id])
    |> validate_required([:user_id])
    |> validate_role_type()
    |> unique_constraint([:user_id, :role_id])
    |> unique_constraint([:user_id, :app_role_id])
  end

  # Ensure either role_id or app_role_id is present, but not both
  defp validate_role_type(changeset) do
    role_id = get_field(changeset, :role_id)
    app_role_id = get_field(changeset, :app_role_id)

    cond do
      role_id && app_role_id ->
        add_error(changeset, :base, "Cannot assign both system role and app role")
      
      !role_id && !app_role_id ->
        add_error(changeset, :base, "Must assign either system role or app role")
      
      true ->
        changeset
    end
  end
end