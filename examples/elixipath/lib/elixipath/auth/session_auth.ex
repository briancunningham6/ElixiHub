defmodule ElixiPath.Auth.SessionAuth do
  @moduledoc """
  Session-based authentication plug for ElixiPath browser requests
  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Check if this is an SSO callback with a token - let it pass through
    case conn.params do
      %{"sso_token" => _token} ->
        Logger.debug("SSO token detected, allowing request to pass through")
        conn
      
      _ ->
        case get_session(conn, "auth_token") do
          nil ->
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
    case conn.request_path do
      "/sso/authenticate" ->
        # Allow SSO authentication endpoint
        conn
      
      _ ->
        # Redirect to ElixiHub for authentication
        elixihub_auth_url = "http://localhost:4005/sso/auth?app_id=ElixiPath&return_to=#{encode_redirect_uri(conn)}"
        
        conn
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