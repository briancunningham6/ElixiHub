defmodule ElixiPathWeb.SSOController do
  use ElixiPathWeb, :controller
  require Logger

  # Handle SSO token from ElixiHub (comes as sso_token parameter)
  def authenticate(conn, %{"sso_token" => token} = params) do
    Logger.info("SSO authenticate called with sso_token")
    handle_token_authentication(conn, token, params)
  end

  # Handle direct token parameter (fallback)
  def authenticate(conn, %{"token" => token} = params) do
    Logger.info("SSO authenticate called with token")
    handle_token_authentication(conn, token, params)
  end

  def authenticate(conn, _params) do
    Logger.warning("SSO authenticate called without token")
    
    conn
    |> put_flash(:error, "No authentication token provided")
    |> redirect(to: "/")
  end

  defp handle_token_authentication(conn, token, params) do
    case ElixiPath.Auth.verify_token(token) do
      {:ok, user} ->
        Logger.info("SSO authentication successful for user: #{user.email}")
        
        # Store token in session
        conn = put_session(conn, "auth_token", token)
        
        # Redirect to original destination or home
        redirect_to = Map.get(params, "redirect_uri", "/")
        redirect(conn, to: redirect_to)
        
      {:error, reason} ->
        Logger.error("SSO authentication failed: #{inspect(reason)}")
        Logger.error("Token received: #{String.slice(token, 0, 50)}...")
        
        # Instead of redirecting to "/" (which causes a loop), show an error response
        conn
        |> put_status(401)
        |> html("""
        <html>
        <head><title>Authentication Failed</title></head>
        <body>
          <h1>Authentication Failed</h1>
          <p>Unable to verify your authentication token.</p>
          <p>Error: #{inspect(reason)}</p>
          <p>Token (first 50 chars): #{String.slice(token, 0, 50)}...</p>
          <p><a href="http://localhost:4005">Return to ElixiHub</a></p>
        </body>
        </html>
        """)
    end
  end

  def logout(conn, _params) do
    Logger.info("User logout")
    
    conn
    |> delete_session("auth_token")
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: "/")
  end

  # Development-only bypass (remove in production)
  def dev_login(conn, _params) do
    if Mix.env() == :dev do
      Logger.info("Development login bypass")
      
      # Create a fake JWT token for development
      fake_token = create_dev_token()
      
      conn = put_session(conn, "auth_token", fake_token)
      
      conn
      |> put_flash(:info, "Development login successful")
      |> redirect(to: "/dev/home")
    else
      send_resp(conn, 404, "Not Found")
    end
  end

  defp create_dev_token do
    # Create a simple development token (not secure, dev only!)
    claims = %{
      "sub" => "dev-user",
      "email" => "dev@example.com",
      "username" => "Development User",
      "roles" => ["elixipath_user"],
      "aud" => "elixihub",
      "iss" => "elixihub",
      "exp" => System.system_time(:second) + 86400, # 24 hours
      "iat" => System.system_time(:second),
      "nbf" => System.system_time(:second)
    }
    
    case ElixiPath.Auth.JWTVerifier.generate_token(claims) do
      {:ok, token} -> 
        Logger.debug("Generated dev token successfully")
        token
      {:error, reason} -> 
        Logger.warning("Failed to generate dev token: #{inspect(reason)}")
        "fake-dev-token" # Fallback
    end
  end
end