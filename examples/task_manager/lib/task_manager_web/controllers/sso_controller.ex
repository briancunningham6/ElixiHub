defmodule TaskManagerWeb.SSOController do
  use TaskManagerWeb, :controller
  require Logger

  def authenticate(conn, %{"token" => token}) do
    case TaskManager.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        Logger.info("SSO authentication successful for user: #{claims["sub"]}")
        
        # Store user info in session
        conn
        |> put_session(:user_id, claims["sub"])
        |> put_session(:user_email, claims["email"])
        |> put_session(:user_roles, claims["roles"] || [])
        |> put_session(:authenticated, true)
        |> redirect(to: "/app")
        
      {:error, reason} ->
        Logger.error("SSO authentication failed: #{inspect(reason)}")
        
        conn
        |> put_flash(:error, "Authentication failed. Please try logging in again.")
        |> redirect(to: "/")
    end
  end

  def authenticate(conn, _params) do
    Logger.error("SSO authentication called without token")
    
    conn
    |> put_flash(:error, "Missing authentication token")
    |> redirect(to: "/")
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out successfully.")
    |> redirect(to: "/")
  end
end