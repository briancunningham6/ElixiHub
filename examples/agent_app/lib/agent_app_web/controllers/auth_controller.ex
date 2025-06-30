defmodule AgentAppWeb.AuthController do
  use AgentAppWeb, :controller

  require Logger

  def callback(conn, %{"token" => token}) do
    Logger.info("Received authentication callback with token")
    
    case AgentApp.Auth.verify_token(token) do
      {:ok, user} ->
        Logger.info("Authentication successful for user: #{user.username}")
        
        conn
        |> put_session(:auth_token, token)
        |> put_resp_cookie("auth_token", token, [
          max_age: 24 * 60 * 60, # 24 hours
          http_only: true,
          secure: false, # Set to true in production with HTTPS
          same_site: "Lax"
        ])
        |> redirect(to: "/chat")
      
      {:error, reason} ->
        Logger.error("Authentication failed: #{inspect(reason)}")
        
        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: "/")
    end
  end

  def callback(conn, _params) do
    Logger.warning("Authentication callback called without token")
    
    conn
    |> put_flash(:error, "No authentication token provided.")
    |> redirect(to: "/")
  end

  def logout(conn, _params) do
    Logger.info("User logout requested")
    
    conn
    |> delete_session(:auth_token)
    |> delete_resp_cookie("auth_token")
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: "/")
  end
end