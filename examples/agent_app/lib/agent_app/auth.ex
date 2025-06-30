defmodule AgentApp.Auth do
  @moduledoc """
  Authentication module for validating ElixiHub JWT tokens.
  """

  use Joken.Config

  @impl Joken.Config
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("user_id", nil, &is_integer/1)
    |> add_claim("username", nil, &is_binary/1)
    |> add_claim("roles", nil, &is_list/1)
  end

  def verify_token(token) do
    secret = Application.get_env(:agent_app, :elixihub)[:jwt_secret]
    
    case verify_and_validate(token, secret) do
      {:ok, claims} ->
        {:ok, %{
          user_id: claims["user_id"],
          username: claims["username"],
          roles: claims["roles"] || []
        }}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  def extract_token_from_headers(headers) do
    case List.keyfind(headers, "authorization", 0) do
      {"authorization", "Bearer " <> token} -> {:ok, token}
      _ -> {:error, :no_token}
    end
  end

  def get_current_user(conn) do
    conn.assigns[:current_user]
  end

  def require_authentication(conn, _opts) do
    import Plug.Conn

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case verify_token(token) do
          {:ok, user} ->
            assign(conn, :current_user, user)
          
          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: "Invalid or expired token"})
            |> halt()
        end
      
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Authentication required"})
        |> halt()
    end
  end

  def authenticate_browser(conn, _opts) do
    import Plug.Conn

    # Try to get token from Authorization header first
    token = case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> 
        # Fallback to session or cookie
        case get_session(conn, :auth_token) do
          nil -> get_req_cookie(conn, "auth_token")
          token -> token
        end
    end

    case token do
      nil ->
        # No token found - redirect to ElixiHub login with callback
        elixihub_config = Application.get_env(:agent_app, :elixihub)
        elixihub_url = elixihub_config[:elixihub_url] || "http://localhost:4000"
        agent_url = AgentAppWeb.Endpoint.url()
        callback_url = "#{agent_url}/auth/callback"
        login_url = "#{elixihub_url}/users/log_in?callback_url=#{URI.encode(callback_url)}"
        
        conn
        |> Phoenix.Controller.redirect(external: login_url)
        |> halt()
      
      token ->
        case verify_token(token) do
          {:ok, user} ->
            assign(conn, :current_user, user)
          
          {:error, _reason} ->
            # Invalid token - redirect to login
            elixihub_config = Application.get_env(:agent_app, :elixihub)
            elixihub_url = elixihub_config[:elixihub_url] || "http://localhost:4000"
            agent_url = AgentAppWeb.Endpoint.url()
            callback_url = "#{agent_url}/auth/callback"
            login_url = "#{elixihub_url}/users/log_in?callback_url=#{URI.encode(callback_url)}"
            
            conn
            |> Phoenix.Controller.redirect(external: login_url)
            |> halt()
        end
    end
  end

  def maybe_authenticate_browser(conn, _opts) do
    import Plug.Conn

    # Try to get token from various sources
    token = case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> 
        case get_session(conn, :auth_token) do
          nil -> get_req_cookie(conn, "auth_token")
          token -> token
        end
    end

    case token do
      nil ->
        # No token - assign nil user (allow anonymous access)
        assign(conn, :current_user, nil)
      
      token ->
        case verify_token(token) do
          {:ok, user} ->
            assign(conn, :current_user, user)
          
          {:error, _reason} ->
            # Invalid token - assign nil user
            assign(conn, :current_user, nil)
        end
    end
  end
end