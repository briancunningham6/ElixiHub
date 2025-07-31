defmodule HelloWorldApp.Auth.ElixiHubAuth.SessionAuth do
  @moduledoc """
  Session-based authentication plug for ElixiHub integration.
  
  This plug handles:
  1. Session token verification
  2. SSO token bypass (prevents redirect loops)
  3. Automatic redirect to ElixiHub for authentication
  4. User assignment to connection
  
  ## Usage
  
  Add to your router pipeline:
  ```elixir
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HelloWorldApp.Auth.ElixiHubAuth.SessionAuth
  end
  ```
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
            case HelloWorldApp.Auth.ElixiHubAuth.verify_token(token) do
              {:ok, user} ->
                Logger.debug("Session authentication successful for user: #{user.email}")
                assign(conn, :current_user, user)
              
              {:error, _reason} ->
                Logger.debug("Session token invalid, redirecting to ElixiHub")
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
        app_name = HelloWorldApp.Auth.ElixiHubAuth.get_app_name()
        elixihub_url = HelloWorldApp.Auth.ElixiHubAuth.get_elixihub_url()
        return_url = encode_redirect_uri(conn)
        
        auth_url = "#{elixihub_url}/sso/auth?app_id=#{app_name}&return_to=#{return_url}"
        
        conn
        |> put_flash(:info, "Please log in to continue")
        |> redirect(external: auth_url)
        |> halt()
    end
  end

  defp encode_redirect_uri(conn) do
    # Get the current app's base URL (assumes standard Phoenix setup)
    port = case conn.port do
      80 -> ""
      443 -> ""
      p -> ":#{p}"
    end
    
    scheme = if conn.scheme == :https, do: "https", else: "http"
    host = conn.host
    path = conn.request_path
    query = if conn.query_string != "", do: "?#{conn.query_string}", else: ""
    
    original_url = "#{scheme}://#{host}#{port}#{path}#{query}"
    URI.encode(original_url)
  end
end