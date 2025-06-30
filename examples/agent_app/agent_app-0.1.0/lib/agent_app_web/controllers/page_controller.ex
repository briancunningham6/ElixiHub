defmodule AgentAppWeb.PageController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: AgentAppWeb.Layouts]
    
  import Plug.Conn

  def home(conn, _params) do
    # The home page is often custom, but we'll just redirect to the chat interface
    redirect(conn, to: "/chat")
  end

  def health(conn, _params) do
    # Simple health check endpoint
    openai_config = Application.get_env(:agent_app, :openai)
    api_key_configured = openai_config[:api_key] && openai_config[:api_key] != "your_openai_api_key_here"
    
    mcp_status = try do
      case AgentApp.MCPManager.list_available_tools() do
        {:ok, tools} -> "ok (#{length(tools)} tools)"
        {:error, reason} -> "error: #{inspect(reason)}"
      end
    catch
      kind, reason -> "error: #{kind} - #{inspect(reason)}"
    end

    status = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      openai_configured: api_key_configured,
      mcp_manager: mcp_status,
      application: "agent_app",
      version: "0.1.0"
    }

    json(conn, status)
  end
end