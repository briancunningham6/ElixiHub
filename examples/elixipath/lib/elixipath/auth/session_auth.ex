defmodule ElixiPath.Auth.SessionAuth do
  @moduledoc """
  Session-based authentication plug for ElixiPath browser requests
  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.debug("SessionAuth called for path: #{conn.request_path}")
    
    # Check if this is an SSO callback with a token - authenticate and store it
    case conn.params do
      %{"sso_token" => token} ->
        Logger.debug("SSO token detected, authenticating user")
        case ElixiPath.Auth.verify_token(token) do
          {:ok, user} ->
            Logger.debug("SSO authentication successful for user: #{user.email}")
            
            # Store token in session for future requests
            conn = put_session(conn, "auth_token", token)
            
            # Ensure user directories exist
            ElixiPath.Auth.ensure_user_directories(user.email)
            
            assign(conn, :current_user, user)
          
          {:error, reason} ->
            Logger.warning("SSO token verification failed: #{inspect(reason)}")
            handle_unauthenticated(conn)
        end
      
      _ ->
        case get_session(conn, "auth_token") do
          nil ->
            Logger.debug("No auth token in session, checking if unauthenticated access allowed")
            handle_unauthenticated(conn)
          
          token when is_binary(token) ->
            case ElixiPath.Auth.verify_token(token) do
              {:ok, user} ->
                Logger.debug("Session authentication successful for user: #{user.email}")
                
                # Ensure user directories exist
                ElixiPath.Auth.ensure_user_directories(user.email)
                
                assign(conn, :current_user, user)
              
              {:error, _reason} ->
                handle_unauthenticated(conn)
            end
          
          _ ->
            handle_unauthenticated(conn)
        end
    end
  end

  defp handle_unauthenticated(conn) do
    Logger.debug("Session auth checking path: #{conn.request_path}")
    
    cond do
      conn.request_path == "/sso/authenticate" ->
        # Allow SSO authentication endpoint
        conn
        
      String.starts_with?(conn.request_path, "/ui/.cpr/") ->
        # Allow copyparty static assets without authentication
        Logger.debug("Allowing .cpr asset: #{conn.request_path}")
        conn
      
      String.starts_with?(conn.request_path, "/ui") ->
        # TEMPORARY: Allow UI access with a test user for debugging
        Logger.debug("Temporarily allowing UI access with test user")
        test_user = %{email: "admin@example.com", id: 3}
        assign(conn, :current_user, test_user)
      
      true ->
        Logger.debug("Redirecting unauthenticated request: #{conn.request_path}")
        # Redirect to ElixiHub for authentication
        elixihub_auth_url = "http://localhost:4005/sso/auth?app_id=ElixiPath&return_to=#{encode_redirect_uri(conn)}"
        
        conn
        |> fetch_flash()
        |> put_flash(:info, "Please log in to continue")
        |> redirect(external: elixihub_auth_url)
        |> halt()
    end
  end

  defp encode_redirect_uri(conn) do
    original_url = "http://localhost:4011#{conn.request_path}"
    if conn.query_string != "" do
      original_url <> "?" <> conn.query_string
    else
      original_url
    end
    |> URI.encode()
  end
end