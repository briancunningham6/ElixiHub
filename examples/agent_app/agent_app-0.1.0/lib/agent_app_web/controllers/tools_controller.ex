defmodule AgentAppWeb.ToolsController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: AgentAppWeb.Layouts]
    
  import Plug.Conn

  def index(conn, _params) do
    case AgentApp.MCPManager.list_available_tools() do
      {:ok, tools} ->
        json(conn, %{
          status: "success",
          tools: tools,
          count: length(tools)
        })
      
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{
          status: "error",
          error: inspect(reason)
        })
    end
  end
end