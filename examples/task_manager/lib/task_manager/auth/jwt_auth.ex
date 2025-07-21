defmodule TaskManager.Auth.JWTAuth do
  @moduledoc """
  JWT-only authentication plug for API routes.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
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
    IO.puts("Authenticating with JWT token...")
    case TaskManager.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        Logger.info("JWT authentication successful for user: #{claims["sub"]}")

        # Assign user info to conn
        assign(conn, :current_user, %{
          id: claims["sub"],
          email: claims["email"],
          roles: claims["roles"] || []
        })

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
