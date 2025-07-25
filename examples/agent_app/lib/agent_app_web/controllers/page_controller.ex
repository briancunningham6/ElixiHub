defmodule AgentAppWeb.PageController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: AgentAppWeb.Layouts]
    
  import Plug.Conn

  def home(conn, _params) do
    require Logger
    Logger.info("Home page accessed")
    Logger.info("Session keys: #{inspect(Map.keys(get_session(conn)))}")
    Logger.info("Current user: #{inspect(conn.assigns[:current_user])}")
    
    current_user = conn.assigns[:current_user]
    
    # Also check session as backup
    auth_token = get_session(conn, :auth_token)
    Logger.info("Auth token in session: #{inspect(auth_token != nil)}")
    
    if current_user && current_user.user_id do
      # User is authenticated, redirect to chat
      Logger.info("Redirecting authenticated user to chat")
      redirect(conn, to: "/chat")
    else
      # User is not authenticated, show welcome page with auto-redirect
      Logger.info("Showing welcome page for unauthenticated user")
      elixihub_config = Application.get_env(:agent_app, :elixihub)
      elixihub_url = elixihub_config[:elixihub_url] || "http://localhost:4005"
      
      # Build the Agent app URL dynamically from endpoint configuration
      agent_url = AgentAppWeb.Endpoint.url()
      return_url = "#{agent_url}/auth/sso_callback"
      sso_url = "#{elixihub_url}/sso/auth?return_to=#{URI.encode(return_url)}"
      
      conn
      |> assign(:sso_url, sso_url)
      |> render(:home)
    end
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