defmodule HelloWorldAppWeb.ApiController do
  use HelloWorldAppWeb, :controller

  alias HelloWorldApp.Auth

  # Public endpoint - no authentication required
  def health(conn, _params) do
    json(conn, %{
      status: "ok",
      message: "Hello World App is running",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # Protected endpoint - requires valid JWT
  def protected_hello(conn, _params) do
    user = Auth.current_user(conn)
    
    json(conn, %{
      message: "Hello, authenticated user!",
      user_id: user["sub"],
      user_email: user["email"] || "Unknown",
      permissions: user["permissions"] || [],
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # Admin endpoint - requires 'admin:access' permission
  def admin_info(conn, _params) do
    user = Auth.current_user(conn)
    
    if Auth.has_permission?(user, "admin:access") do
      json(conn, %{
        message: "Welcome to the admin area!",
        user_id: user["sub"],
        admin_level: "full",
        server_info: %{
          app_name: "Hello World App",
          version: "1.0.0",
          uptime: System.system_time(:second)
        },
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions", required: "admin:access"})
    end
  end

  # App-specific endpoint - requires 'hello_world:read' permission
  def app_specific(conn, _params) do
    user = Auth.current_user(conn)
    
    if Auth.has_permission?(user, "hello_world:read") do
      json(conn, %{
        message: "You have access to Hello World app-specific features!",
        user_id: user["sub"],
        features: [
          "Feature A: Available",
          "Feature B: Available", 
          "Feature C: Available"
        ],
        app_permissions: Enum.filter(user["permissions"] || [], &String.starts_with?(&1, "hello_world:")),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions", required: "hello_world:read"})
    end
  end

  # User info endpoint
  def user_info(conn, _params) do
    user = Auth.current_user(conn)
    
    json(conn, %{
      user: %{
        id: user["sub"],
        email: user["email"],
        roles: user["roles"] || [],
        permissions: user["permissions"] || []
      },
      token_info: %{
        issued_at: user["iat"],
        expires_at: user["exp"],
        issuer: user["iss"]
      }
    })
  end
end