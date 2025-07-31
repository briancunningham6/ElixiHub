defmodule TaskManager.Auth.MCPAuth do
  @moduledoc """
  MCP-specific authentication plug that allows tools/list without auth but requires auth for tool calls.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Use Phoenix-parsed params instead of reading raw body
    # since Phoenix has already consumed the request body
    params = conn.params
    Logger.info("MCP Auth - received params: #{inspect(params)}")
    
    case params do
      %{"method" => "tools/list"} = parsed_params ->
        Logger.info("MCP Auth - tools/list method, skipping authentication")
        # Allow tools/list without authentication
        assign(conn, :parsed_params, parsed_params)
        
      %{"method" => method} = parsed_params ->
        Logger.info("MCP Auth - method #{method}, requiring authentication")
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
    Logger.info("authenticate_with_jwt called with token: #{String.slice(token, 0, 20)}...")
    
    case TaskManager.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        Logger.info("JWT authentication successful for user: #{claims["sub"]}")
        Logger.info("JWT claims: #{inspect(claims)}")

        user_info = %{
          id: claims["sub"],
          email: claims["email"],
          roles: claims["roles"] || []
        }
        Logger.info("Assigning user info: #{inspect(user_info)}")

        # Assign user info to conn
        assign(conn, :current_user, user_info)

      {:error, reason} ->
        Logger.error("JWT authentication failed: #{inspect(reason)}")
        handle_unauthenticated(conn)
    end
  end

  defp handle_unauthenticated(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "Unauthorized"})
    |> halt()
  end
end