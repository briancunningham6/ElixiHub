defmodule AgentAppWeb.Router do
  use Phoenix.Router
  
  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router
  
  # Import verified routes for path helpers
  use Phoenix.VerifiedRoutes,
    endpoint: AgentAppWeb.Endpoint,
    router: __MODULE__,
    statics: ~w(assets fonts images favicon.ico robots.txt)

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AgentAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    # TODO: Add authentication plug once AgentApp.Auth module is properly compiled
    # plug AgentApp.Auth, :require_authentication
  end

  # Browser routes (for testing/development)
  scope "/", AgentAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/health", PageController, :health
    live "/chat", ChatLive
  end

  # API routes
  scope "/api", AgentAppWeb do
    pipe_through :api

    post "/chat", ChatController, :create
    get "/tools", ToolsController, :index
  end

  # MCP endpoint (for other apps to discover this app's tools)
  scope "/mcp", AgentAppWeb do
    pipe_through :api

    post "/", MCPController, :handle_request
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:agent_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AgentAppWeb.Telemetry
    end
  end
end