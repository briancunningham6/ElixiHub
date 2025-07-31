defmodule ElixiPath.Auth.JWTAuth do
  @moduledoc """
  JWT-based authentication plug for ElixiPath API requests
  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_jwt_token(conn) do
      nil ->
        handle_unauthenticated(conn)
      
      token ->
        case ElixiPath.Auth.verify_token(token) do
          {:ok, user} ->
            Logger.debug("JWT authentication successful for user: #{user.email}")
            
            # Ensure user directories exist
            ElixiPath.Auth.ensure_user_directories(user.email)
            
            assign(conn, :current_user, user)
          
          {:error, _reason} ->
            handle_unauthenticated(conn)
        end
    end
  end

  defp get_jwt_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp handle_unauthenticated(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized - valid JWT token required"})
    |> halt()
  end
end