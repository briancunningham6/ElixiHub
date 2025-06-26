defmodule ElixihubWeb.Api.UserController do
  use ElixihubWeb, :controller

  alias Elixihub.Accounts
  alias Elixihub.Authorization
  alias Elixihub.Authorization.Policy
  alias Elixihub.Guardian

  action_fallback ElixihubWeb.FallbackController

  def index(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    
    with :ok <- Bodyguard.permit(Policy, :list_users, current_user) do
      users = Accounts.list_users()
      
      users_with_roles = 
        Enum.map(users, fn user ->
          user = Elixihub.Repo.preload(user, :roles)
          %{
            id: user.id,
            email: user.email,
            confirmed_at: user.confirmed_at,
            roles: Enum.map(user.roles, & &1.name)
          }
        end)
      
      conn
      |> put_status(:ok)
      |> json(%{users: users_with_roles})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user = Accounts.get_user!(id)
    
    with :ok <- Bodyguard.permit(Policy, :delete_user, current_user, user) do
      case Accounts.delete_user(user) do
        {:ok, _user} ->
          conn
          |> put_status(:ok)
          |> json(%{message: "User deleted successfully"})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: transform_errors(changeset)})
      end
    end
  end

  defp transform_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end