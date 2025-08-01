defmodule TaskManagerWeb.UserAuth do
  @moduledoc """
  User authentication helpers for LiveViews.
  """
  
  import Phoenix.LiveView
  import Phoenix.Component
  
  def on_mount(:ensure_authenticated, _params, session, socket) do
    case get_current_user(session) do
      nil ->
        # For LiveView, we can't redirect to external URLs directly
        # Instead, redirect to a local route that will handle the SSO redirect
        socket = 
          socket
          |> put_flash(:error, "You must log in to access this page.")
          |> redirect(to: "/")
        
        {:halt, socket}
        
      user ->
        socket = assign(socket, :current_user, user)
        {:cont, socket}
    end
  end
  
  def on_mount(:maybe_authenticated, _params, session, socket) do
    user = get_current_user(session)
    socket = assign(socket, :current_user, user)
    {:cont, socket}
  end
  
  defp get_current_user(session) do
    if session[:authenticated] || session["authenticated"] do
      %{
        id: session[:user_id] || session["user_id"],
        email: session[:user_email] || session["user_email"],
        roles: session[:user_roles] || session["user_roles"] || []
      }
    else
      nil
    end
  end
  
  defp build_sso_url do
    elixihub_url = Application.get_env(:task_manager, :elixihub)[:base_url] || "http://localhost:4005"
    return_url = "http://localhost:4010/sso/authenticate"
    
    "#{elixihub_url}/sso/auth?app_id=task_manager&return_to=#{URI.encode(return_url)}"
  end
end