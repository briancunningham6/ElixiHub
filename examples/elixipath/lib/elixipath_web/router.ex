defmodule ElixiPathWeb.Router do
  use ElixiPathWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixiPathWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ElixiPath.Auth.SessionAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ElixiPath.Auth.JWTAuth
  end

  pipeline :copyparty_proxy do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug ElixiPath.Auth.SessionAuth
  end

  pipeline :dev_only do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixiPathWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :mcp do
    plug :accepts, ["json"]
    plug ElixiPath.Auth.MCPAuth
  end

  scope "/", ElixiPathWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/sso/authenticate", SSOController, :authenticate
    get "/sso/logout", SSOController, :logout
  end

  # Development-only routes (no authentication required)
  if Mix.env() == :dev do
    scope "/dev", ElixiPathWeb do
      pipe_through :dev_only
      
      get "/login", SSOController, :dev_login
      get "/home", PageController, :home
    end
  end

  # Copyparty UI proxy - authenticated access
  scope "/ui", ElixiPathWeb do
    pipe_through :copyparty_proxy
    
    get "/*path", CopypartyController, :proxy
    post "/*path", CopypartyController, :proxy
    put "/*path", CopypartyController, :proxy
    delete "/*path", CopypartyController, :proxy
  end

  # API routes
  scope "/api", ElixiPathWeb do
    pipe_through :api

    get "/files/*path", FileController, :list
    post "/files/*path", FileController, :upload
    delete "/files/*path", FileController, :delete
    get "/storage/usage", FileController, :usage
  end

  # MCP Server routes
  scope "/mcp", ElixiPathWeb do
    pipe_through :mcp

    post "/", MCPController, :handle_request
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixipath, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :dev_only

      live_dashboard "/dashboard", metrics: ElixiPathWeb.Telemetry
    end
  end
end