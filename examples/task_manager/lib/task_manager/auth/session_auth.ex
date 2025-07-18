defmodule TaskManager.Auth.SessionAuth do
  @moduledoc """
  Authentication plug that supports both JWT tokens and session-based authentication.
  """
  
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      # Check if already authenticated in session
      get_session(conn, :authenticated) ->
        assign_user_from_session(conn)
        
      # Check for JWT token in Authorization header
      jwt_token = get_jwt_token(conn) ->
        authenticate_with_jwt(conn, jwt_token)
        
      # No authentication found
      true ->
        handle_unauthenticated(conn)
    end
  end

  defp get_jwt_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp authenticate_with_jwt(conn, token) do
    case TaskManager.Auth.JWTVerifier.verify(token) do
      {:ok, claims} ->
        Logger.info("JWT authentication successful for user: #{claims["sub"]}")
        
        # Store in session and assign to conn
        conn
        |> put_session(:user_id, claims["sub"])
        |> put_session(:user_email, claims["email"])
        |> put_session(:user_roles, claims["roles"] || [])
        |> put_session(:authenticated, true)
        |> assign(:current_user, %{
          id: claims["sub"],
          email: claims["email"],
          roles: claims["roles"] || []
        })
        
      {:error, reason} ->
        Logger.error("JWT authentication failed: #{inspect(reason)}")
        handle_unauthenticated(conn)
    end
  end

  defp assign_user_from_session(conn) do
    user = %{
      id: get_session(conn, :user_id),
      email: get_session(conn, :user_email),
      roles: get_session(conn, :user_roles) || []
    }
    
    assign(conn, :current_user, user)
  end

  defp handle_unauthenticated(conn) do
    case get_format(conn) do
      "json" ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Unauthorized"})
        |> halt()
        
      _ ->
        # For HTML requests, redirect to SSO
        sso_url = build_sso_url(conn)
        
        conn
        |> Phoenix.Controller.redirect(external: sso_url)
        |> halt()
    end
  end

  defp get_format(conn) do
    conn.assigns[:phoenix_format] || 
    case get_req_header(conn, "accept") do
      [accept] -> 
        if String.contains?(accept, "application/json") do
          "json"
        else
          "html"
        end
      _ -> "html"
    end
  end

  defp build_sso_url(conn) do
    elixihub_url = Application.get_env(:task_manager, :elixihub)[:base_url] || "http://localhost:4005"
    return_url = "#{get_base_url(conn)}/sso/authenticate"
    
    "#{elixihub_url}/sso/auth?app=task_manager&return_url=#{URI.encode(return_url)}"
  end

  defp get_base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    "#{scheme}://#{conn.host}:#{conn.port}"
  end
end