defmodule ElixihubWeb.Api.AuthController do
  use ElixihubWeb, :controller

  alias Elixihub.Accounts
  alias Elixihub.Guardian
  alias Elixihub.Authorization

  action_fallback ElixihubWeb.FallbackController

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user ->
        case Guardian.encode_and_sign(user) do
          {:ok, token, _claims} ->
            user_permissions = Authorization.get_user_permissions(user)
            
            conn
            |> put_status(:ok)
            |> json(%{
              token: token,
              user: %{
                id: user.id,
                email: user.email
              },
              permissions: Enum.map(user_permissions, & &1.name)
            })

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to create token"})
        end

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Assign default "user" role to new users
        user_role = Elixihub.Repo.get_by(Elixihub.Authorization.Role, name: "user")
        
        if user_role do
          Authorization.assign_role_to_user(user, user_role)
        end

        case Guardian.encode_and_sign(user) do
          {:ok, token, _claims} ->
            conn
            |> put_status(:created)
            |> json(%{
              token: token,
              user: %{
                id: user.id,
                email: user.email
              }
            })

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "User created but failed to create token"})
        end

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: transform_errors(changeset)})
    end
  end

  def user(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_permissions = Authorization.get_user_permissions(user)
    
    conn
    |> put_status(:ok)
    |> json(%{
      user: %{
        id: user.id,
        email: user.email,
        confirmed_at: user.confirmed_at
      },
      permissions: Enum.map(user_permissions, & &1.name)
    })
  end

  def permissions(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_permissions = Authorization.get_user_permissions(user)
    
    conn
    |> put_status(:ok)
    |> json(%{
      permissions: Enum.map(user_permissions, & &1.name)
    })
  end

  def token(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    token = Guardian.Plug.current_token(conn)
    
    conn
    |> put_status(:ok)
    |> json(%{
      user: %{
        id: user.id,
        username: user.username || user.email,
        email: user.email
      },
      token: token,
      instructions: "Copy the token value above and paste it into the Agent app authentication form."
    })
  end

  defp transform_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end