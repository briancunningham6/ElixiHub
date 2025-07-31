defmodule HelloWorldAppWeb.PageController do
  use HelloWorldAppWeb, :controller

  def home(conn, %{"sso_token" => _token} = params) do
    # If SSO token is present, redirect to SSO authenticate
    redirect(conn, to: "/sso/authenticate?" <> URI.encode_query(params))
  end

  def home(conn, _params) do
    # Get current user from session (assigned by SessionAuth plug)
    user = conn.assigns[:current_user]
    
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false, user: user)
  end
end
