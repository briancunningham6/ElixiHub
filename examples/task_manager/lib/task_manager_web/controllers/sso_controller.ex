defmodule TaskManagerWeb.SSOController do
  use TaskManagerWeb, :controller
  require Logger

  def authenticate(conn, %{"sso_token" => token}) do
    Logger.info("SSO authenticate called with token: #{String.slice(token, 0, 50)}...")
    Logger.info("Current session authenticated: #{get_session(conn, :authenticated)}")
    
    case TaskManager.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        Logger.info("SSO authentication successful for user: #{claims["sub"]}")
        Logger.info("Claims: #{inspect(claims)}")
        
        # Store user info in session
        conn = conn
        |> put_session(:user_id, claims["sub"])
        |> put_session(:user_email, claims["email"])
        |> put_session(:user_roles, claims["roles"] || [])
        |> put_session(:authenticated, true)
        
        Logger.info("Session stored, redirecting to /app")
        redirect(conn, to: "/app")
        
      {:error, reason} ->
        Logger.error("SSO authentication failed: #{inspect(reason)}")
        Logger.error("Token was: #{String.slice(token, 0, 100)}...")
        
        conn
        |> put_flash(:error, "Authentication failed. Please try logging in again.")
        |> redirect(to: "/")
    end
  end

  def authenticate(conn, _params) do
    Logger.error("SSO authentication called without sso_token")
    
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