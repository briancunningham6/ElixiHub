defmodule AgentAppWeb.PageController do
  use AgentAppWeb, :controller

  def home(conn, _params) do
    # The home page is often custom, but we'll just redirect to the chat interface
    redirect(conn, to: ~p"/chat")
  end
end