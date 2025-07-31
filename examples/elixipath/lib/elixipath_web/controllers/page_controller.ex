defmodule ElixiPathWeb.PageController do
  use ElixiPathWeb, :controller

  def home(conn, %{"sso_token" => _token} = params) do
    # If SSO token is present, redirect to SSO authenticate
    redirect(conn, to: "/sso/authenticate?" <> URI.encode_query(params))
  end

  def home(conn, _params) do
    user = conn.assigns[:current_user]
    
    # Get Copyparty status
    copyparty_status = ElixiPath.CopypartyManager.get_status()
    copyparty_url = ElixiPath.CopypartyManager.get_copyparty_url()
    
    # Get user directories
    directories = if user do
      ElixiPath.Auth.get_user_directories(user.email)
    else
      %{}
    end
    
    render(conn, :home, %{
      user: user,
      copyparty_status: copyparty_status,
      copyparty_url: copyparty_url,
      directories: directories
    })
  end
end