defmodule HelloWorldApp.Auth.ElixiHubAuth.SSOController do
  @moduledoc """
  SSO controller for handling ElixiHub authentication callbacks.
  
  This controller processes SSO tokens from ElixiHub and establishes
  authenticated sessions for users.
  
  ## Usage
  
  Add these routes to your router:
  ```elixir
  scope "/", MyAppWeb do
    pipe_through :browser
    
    get "/sso/authenticate", HelloWorldApp.Auth.ElixiHubAuth.SSOController, :authenticate
    get "/sso/logout", HelloWorldApp.Auth.ElixiHubAuth.SSOController, :logout
  end
  ```
  
  And handle SSO tokens in your page controller:
  ```elixir
  def home(conn, %{"sso_token" => _token} = params) do
    # If SSO token is present, redirect to SSO authenticate
    redirect(conn, to: "/sso/authenticate?" <> URI.encode_query(params))
  end
  ```
  """
  use Phoenix.Controller, formats: [:html]
  require Logger

  @doc """
  Handles SSO authentication callbacks from ElixiHub.
  
  Supports both 'sso_token' and 'token' parameter names for flexibility.
  """
  def authenticate(conn, %{"sso_token" => token} = params) do
    Logger.info("SSO authenticate called with sso_token")
    handle_token_authentication(conn, token, params)
  end

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

  @doc """
  Handles user logout by clearing the session.
  """
  def logout(conn, _params) do
    Logger.info("User logout")
    
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: "/")
  end

  @doc """
  Development-only authentication bypass.
  
  Creates a fake JWT token for testing without ElixiHub.
  Only available in development environment.
  """
  def dev_login(conn, _params) do
    if Mix.env() == :dev do
      Logger.info("Development login bypass")
      
      # Create a fake JWT token for development
      fake_token = create_dev_token()
      
      conn = put_session(conn, "auth_token", fake_token)
      
      conn
      |> put_flash(:info, "Development login successful")
      |> redirect(to: "/")
    else
      send_resp(conn, 404, "Not Found")
    end
  end

  # Private functions

  defp handle_token_authentication(conn, token, params) do
    case HelloWorldApp.Auth.ElixiHubAuth.verify_token(token) do
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
        
        # Show error page instead of redirecting (prevents loops)
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(401, authentication_error_page(reason, token))
    end
  end

  defp create_dev_token do
    claims = %{
      "sub" => "dev-user",
      "email" => "dev@example.com",
      "username" => "Development User",
      "roles" => ["app_user"],
      "aud" => "elixihub",
      "iss" => "elixihub",
      "exp" => System.system_time(:second) + 86400, # 24 hours
      "iat" => System.system_time(:second),
      "nbf" => System.system_time(:second)
    }
    
    case HelloWorldApp.Auth.ElixiHubAuth.JWTVerifier.generate_token(claims) do
      {:ok, token} -> 
        Logger.debug("Generated dev token successfully")
        token
      {:error, reason} -> 
        Logger.warning("Failed to generate dev token: #{inspect(reason)}")
        "fake-dev-token" # Fallback
    end
  end

  defp authentication_error_page(reason, token) do
    elixihub_url = HelloWorldApp.Auth.ElixiHubAuth.get_elixihub_url()
    
    """
    <html>
    <head><title>Authentication Failed</title></head>
    <body>
      <h1>Authentication Failed</h1>
      <p>Unable to verify your authentication token.</p>
      <p><strong>Error:</strong> #{inspect(reason)}</p>
      <p><strong>Token (first 50 chars):</strong> #{String.slice(token, 0, 50)}...</p>
      <hr>
      <p><a href="#{elixihub_url}">Return to ElixiHub</a></p>
      <p><em>If this error persists, please check that ElixiHub and this application are using the same JWT secret.</em></p>
    </body>
    </html>
    """
  end
end