defmodule TaskManagerWeb.DirectAuthController do
  @moduledoc """
  Alternative direct authentication method that bypasses JWT complexity
  for debugging redirect loops.
  """
  
  use TaskManagerWeb, :controller
  require Logger

  def login(conn, %{"user_id" => user_id, "email" => email}) when user_id != "" and email != "" do
    Logger.info("Direct auth login for user: #{user_id}, email: #{email}")
    
    # Simple authentication bypass for debugging
    conn = conn
    |> put_session(:user_id, user_id)
    |> put_session(:user_email, email)
    |> put_session(:user_roles, [])
    |> put_session(:authenticated, true)
    
    Logger.info("Direct auth successful, redirecting to /app")
    redirect(conn, to: "/app")
  end

  def login(conn, params) do
    Logger.error("Direct auth failed with params: #{inspect(params)}")
    
    conn
    |> put_flash(:error, "Direct authentication failed")
    |> redirect(to: "/")
  end
end