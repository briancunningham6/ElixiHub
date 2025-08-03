defmodule ElixiPath.Auth.SessionAuth do
  @moduledoc """
  Session-based authentication plug for ElixiPath browser requests
  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Check if this is an SSO callback with a token - authenticate and store it
    # Check both params and query_params since sso_token comes as query parameter
    sso_token = conn.params["sso_token"] || conn.query_params["sso_token"]
    
    case sso_token do
      token when is_binary(token) ->
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
      
      nil ->
        case get_session(conn, "auth_token") do
          nil ->
            Logger.debug("No auth token in session for path: #{conn.request_path}")
            handle_unauthenticated(conn)
          
          token when is_binary(token) ->
            Logger.debug("Found auth token, verifying...")
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
    cond do
      conn.request_path == "/sso/authenticate" ->
        # Allow SSO authentication endpoint
        conn
        
      String.starts_with?(conn.request_path, "/ui/.cpr/") ->
        # Allow copyparty static assets without authentication
        Logger.debug("Allowing .cpr asset: #{conn.request_path}")
        conn
      
      String.starts_with?(conn.request_path, "/ui") ->
        # Redirect UI requests to ElixiHub for authentication
        elixihub_auth_url = "http://localhost:4005/sso/auth?app_id=ElixiPath&return_to=#{encode_redirect_uri(conn)}"
        
        conn
        |> fetch_flash()
        |> put_flash(:info, "Please log in to continue")
        |> redirect(external: elixihub_auth_url)
        |> halt()
      
      true ->
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