defmodule TaskManager.Auth do
  @moduledoc """
  Authentication middleware for ElixiHub JWT integration.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_token(conn, token)
      _ ->
        unauthorized(conn)
    end
  end
  
  defp verify_token(conn, token) do
    case TaskManager.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        conn
        |> assign(:current_user, claims)
        |> assign(:user_permissions, get_user_permissions(claims))
      {:error, _reason} ->
        unauthorized(conn)
    end
  end
  
  defp get_user_permissions(claims) do
    roles = Map.get(claims, "roles", [])
    permissions = Map.get(claims, "permissions", %{})
    
    %{
      roles: roles,
      permissions: permissions,
      can_read: has_permission?(permissions, "read"),
      can_write: has_permission?(permissions, "write"),
      can_admin: has_permission?(permissions, "admin")
    }
  end
  
  defp has_permission?(permissions, action) do
    Map.get(permissions, action, false)
  end
  
  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
    |> halt()
  end
  
  def require_permission(conn, required_permission) do
    user_permissions = conn.assigns[:user_permissions]
    
    if user_permissions && Map.get(user_permissions.permissions, required_permission, false) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions"})
      |> halt()
    end
  end
end