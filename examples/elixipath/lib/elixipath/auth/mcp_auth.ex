defmodule ElixiPath.Auth.MCPAuth do
  @moduledoc """
  MCP-specific authentication plug for ElixiPath that allows tools/list without auth
  but requires auth for file operations.
  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Use Phoenix-parsed params since Phoenix has already consumed the request body
    params = conn.params
    Logger.debug("MCP Auth - received params: #{inspect(params)}")
    
    case params do
      %{"method" => "tools/list"} = parsed_params ->
        Logger.debug("MCP Auth - tools/list method, skipping authentication")
        # Allow tools/list without authentication
        assign(conn, :parsed_params, parsed_params)
        
      %{"method" => method} = parsed_params ->
        Logger.debug("MCP Auth - method #{method}, requiring authentication")
        # Require authentication for all other methods
        conn = assign(conn, :parsed_params, parsed_params)
        authenticate_jwt(conn)
        
      _ ->
        Logger.error("MCP Auth - no method found in params: #{inspect(params)}")
        # No method found - let the controller handle it
        conn
    end
  end

  defp authenticate_jwt(conn) do
    case get_jwt_token(conn) do
      nil ->
        handle_unauthenticated(conn)
      token ->
        authenticate_with_jwt(conn, token)
    end
  end

  defp get_jwt_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp authenticate_with_jwt(conn, token) do
    Logger.debug("authenticate_with_jwt called with token: #{String.slice(token, 0, 20)}...")
    
    case ElixiPath.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        Logger.debug("JWT authentication successful for user: #{claims["sub"]}")
        
        user_info = %{
          id: claims["sub"],
          email: claims["email"],
          username: claims["username"] || claims["email"],
          roles: claims["roles"] || []
        }
        
        # Ensure user directories exist
        ElixiPath.Auth.ensure_user_directories(user_info.email)
        
        assign(conn, :current_user, user_info)

      {:error, reason} ->
        Logger.error("JWT authentication failed: #{inspect(reason)}")
        handle_unauthenticated(conn)
    end
  end

  defp handle_unauthenticated(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
    |> halt()
  end
end