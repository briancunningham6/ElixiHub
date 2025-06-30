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
end