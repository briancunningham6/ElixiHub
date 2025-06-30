defmodule ElixihubWeb.Api.MCPController do
  use ElixihubWeb, :controller

  require Logger

  def discovery(conn, _params) do
    Logger.info("MCP discovery endpoint called")
    
    try do
      case Elixihub.MCP.get_discovery_info() do
        servers when is_list(servers) ->
          Logger.info("Returning #{length(servers)} MCP servers for discovery")
          json(conn, servers)
        
        {:error, reason} ->
          Logger.error("Failed to get MCP discovery info: #{inspect(reason)}")
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to retrieve MCP servers"})
      end
    rescue
      error ->
        Logger.error("Exception in MCP discovery: #{inspect(error)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error"})
    end
  end
end