defmodule AgentAppWeb.PageController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: AgentAppWeb.Layouts]
    
  import Plug.Conn

  def home(conn, _params) do
    # The home page is often custom, but we'll just redirect to the chat interface
    redirect(conn, to: "/chat")
  end
end