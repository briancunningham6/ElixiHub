defmodule ElixihubWeb.SSOController do
  use ElixihubWeb, :controller

  require Logger

  @doc """
  Handles SSO authentication requests from deployed applications.
  
  Flow:
  1. App redirects user to ElixiHub with return URL
  2. ElixiHub checks if user is logged in
  3. If logged in, generates token and redirects back to app with token
  4. If not logged in, redirects to login then back to app
  """
  def authenticate(conn, %{"return_to" => return_url, "app_id" => app_id}) do
    Logger.info("SSO authenticate request for app_id: #{app_id}, return_to: #{return_url}")
    
    case get_session(conn, :user_token) do
      nil ->
        # User not logged in - redirect to login with SSO continuation
        login_url = ~p"/users/log_in" <> 
          "?return_to=" <> URI.encode("#{~p"/sso/auth"}?app_id=#{app_id}&return_to=#{URI.encode(return_url)}")
        
        redirect(conn, to: login_url)
      
      user_token ->
        # User is logged in - verify token and create app token
        case Elixihub.Accounts.get_user_by_session_token(user_token) do
          %Elixihub.Accounts.User{} = user ->
            # Verify user has access to this app
            case verify_app_access(user, app_id) do
              :ok ->
                generate_sso_token_and_redirect(conn, user, return_url)
              
              {:error, reason} ->
                Logger.warning("User #{user.id} denied access to app #{app_id}: #{reason}")
                conn
                |> put_flash(:error, "You don't have access to this application.")
                |> redirect(to: "/")
            end
          
          nil ->
            Logger.warning("Invalid user session token")
            # Invalid session - redirect to login
            login_url = ~p"/users/log_in" <> 
              "?return_to=" <> URI.encode("#{~p"/sso/auth"}?app_id=#{app_id}&return_to=#{URI.encode(return_url)}")
            
            redirect(conn, to: login_url)
        end
    end
  end

  def authenticate(conn, %{"return_to" => return_url}) do
    # No app_id specified - generic SSO for any ElixiHub app
    authenticate(conn, %{"return_to" => return_url, "app_id" => "generic"})
  end

  def authenticate(conn, _params) do
    conn
    |> put_flash(:error, "Invalid SSO request - missing return URL.")
    |> redirect(to: "/")
  end

  @doc """
  Handles logout requests from applications - logs out from ElixiHub and redirects back
  """
  def logout(conn, %{"return_to" => return_url}) do
    Logger.info("SSO logout request, return_to: #{return_url}")
    
    conn
    |> ElixihubWeb.UserAuth.log_out_user()
    |> redirect(external: return_url)
  end

  def logout(conn, _params) do
    conn
    |> ElixihubWeb.UserAuth.log_out_user()
    |> redirect(to: "/")
  end

  # Private functions

  defp verify_app_access(user, "generic"), do: :ok
  
  defp verify_app_access(user, app_id) do
    # Check if the app exists and user has access to it
    case Elixihub.Apps.get_app(app_id) do
      nil ->
        {:error, :app_not_found}
      
      app ->
        # For now, allow access to all apps for all users
        # You can implement role-based access control here
        # case Elixihub.Authorization.user_can_access_app?(user, app) do
        #   true -> :ok
        #   false -> {:error, :access_denied}
        # end
        :ok
    end
  end

  defp generate_sso_token_and_redirect(conn, user, return_url) do
    Logger.info("Generating SSO token for user: #{user.id}")
    
    # Debug: Log the Guardian secret being used
    guardian_config = Application.get_env(:elixihub, Elixihub.Guardian)
    secret = guardian_config[:secret_key]
    Logger.info("ElixiHub Guardian secret: #{inspect(secret)}")
    
    # Generate a JWT token for the user
    case Elixihub.Guardian.encode_and_sign(user) do
      {:ok, token, claims} ->
        Logger.info("Successfully generated SSO token")
        Logger.info("Token claims: #{inspect(claims)}")
        Logger.info("Token (first 50 chars): #{String.slice(token, 0, 50)}...")
        
        # Parse return URL to add token parameter
        uri = URI.parse(return_url)
        
        # Build query parameters
        existing_query = if uri.query, do: URI.decode_query(uri.query), else: %{}
        new_query = Map.put(existing_query, "sso_token", token)
        
        # Reconstruct URL with token
        final_url = %{uri | query: URI.encode_query(new_query)} |> URI.to_string()
        
        Logger.info("Redirecting to: #{final_url}")
        redirect(conn, external: final_url)
      
      {:error, reason} ->
        Logger.error("Failed to generate SSO token: #{inspect(reason)}")
        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: "/")
    end
  end
end