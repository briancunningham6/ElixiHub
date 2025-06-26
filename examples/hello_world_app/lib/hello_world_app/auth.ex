defmodule HelloWorldApp.Auth do
  @moduledoc """
  Authentication module for integrating with ElixiHub JWT authentication.
  
  This module handles JWT token verification using ElixiHub's JWKS endpoint
  and provides middleware for protecting routes.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias HelloWorldApp.Auth.JWTVerifier

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, :verify_jwt), do: verify_jwt(conn, [])

  @doc """
  Plug to verify JWT token and set current user.
  Add this to your router pipeline or controller.
  """
  def verify_jwt(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case JWTVerifier.verify_token(token) do
          {:ok, claims} ->
            conn
            |> assign(:current_user, claims)
            |> assign(:authenticated, true)

          {:error, reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid token", details: inspect(reason)})
            |> halt()
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing or invalid authorization header"})
        |> halt()
    end
  end

  @doc """
  Plug to ensure user has specific permission.
  Usage: plug :require_permission, "app:read"
  """
  def require_permission(conn, permission) when is_binary(permission) do
    if has_permission?(conn.assigns[:current_user], permission) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions", required: permission})
      |> halt()
    end
  end

  @doc """
  Check if user has a specific permission.
  """
  def has_permission?(nil, _permission), do: false

  def has_permission?(user, permission) do
    user_permissions = get_in(user, ["permissions"]) || []
    permission in user_permissions
  end

  @doc """
  Get current user from connection assigns.
  """
  def current_user(conn), do: conn.assigns[:current_user]

  @doc """
  Check if request is authenticated.
  """
  def authenticated?(conn), do: conn.assigns[:authenticated] == true
end