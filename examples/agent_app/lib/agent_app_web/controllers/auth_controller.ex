defmodule AgentAppWeb.AuthController do
  use AgentAppWeb, :controller

  require Logger

  def sso_callback(conn, %{"sso_token" => token}) do
    Logger.info("Received SSO callback with token")
    
    case AgentApp.Auth.verify_token(token) do
      {:ok, user} ->
        Logger.info("SSO authentication successful for user: #{user.username}")
        
        conn
        |> put_session(:auth_token, token)
        |> assign(:current_user, user)  # Also set in assigns for immediate use
        |> put_resp_cookie("auth_token", token, [
          max_age: 4 * 60 * 60, # 4 hours (matching ElixiHub token TTL)
          http_only: true,
          secure: false, # Set to true in production with HTTPS
          same_site: "Lax"
        ])
        |> redirect(to: "/chat")
      
      {:error, reason} ->
        Logger.error("SSO authentication failed: #{inspect(reason)}")
        
        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: "/")
    end
  end

  def callback(conn, %{"token" => token}) do
    Logger.info("Received manual authentication callback with token")
    
    case AgentApp.Auth.verify_token(token) do
      {:ok, user} ->
        Logger.info("Manual authentication successful for user: #{user.username}")
        
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
        Logger.error("Manual authentication failed: #{inspect(reason)}")
        
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
    
    # Get ElixiHub URL for SSO logout
    elixihub_config = Application.get_env(:agent_app, :elixihub)
    elixihub_url = elixihub_config[:elixihub_url] || "http://localhost:4005"
    agent_url = AgentAppWeb.Endpoint.url()
    return_url = "#{agent_url}/"
    sso_logout_url = "#{elixihub_url}/sso/logout?return_to=#{URI.encode(return_url)}"
    
    conn
    |> delete_session(:auth_token)
    |> delete_resp_cookie("auth_token")
    |> put_flash(:info, "You have been logged out from all ElixiHub applications.")
    |> redirect(external: sso_logout_url)
  end
end