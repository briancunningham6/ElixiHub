defmodule AgentAppWeb.MCPController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: AgentAppWeb.Layouts]
    
  import Plug.Conn

  def handle_request(conn, _params) do
    # This agent app doesn't provide MCP tools, it only consumes them
    # But we include this endpoint for completeness
    
    response = %{
      "jsonrpc" => "2.0",
      "id" => nil,
      "error" => %{
        "code" => -32601,
        "message" => "This agent app is a client only - it doesn't provide MCP tools"
      }
    }
    
    json(conn, response)
  end
end