defmodule HelloWorldAppWeb.Router do
  use HelloWorldAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWorldAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HelloWorldApp.Auth.ElixiHubAuth.SessionAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug HelloWorldApp.Auth, :verify_jwt
  end

  pipeline :mcp_api do
    plug :accepts, ["json"]
    plug HelloWorldAppWeb.MCPController, :capture_raw_body
    plug HelloWorldApp.Auth, :verify_jwt
  end

  scope "/", HelloWorldAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/sso/authenticate", HelloWorldApp.Auth.ElixiHubAuth.SSOController, :authenticate
    get "/sso/logout", HelloWorldApp.Auth.ElixiHubAuth.SSOController, :logout
  end

  # Development-only routes (no authentication required)
  if Mix.env() == :dev do
    scope "/dev", HelloWorldAppWeb do
      pipe_through :browser
      
      get "/login", HelloWorldApp.Auth.ElixiHubAuth.SSOController, :dev_login
    end
  end

  # Public API endpoints
  scope "/api", HelloWorldAppWeb do
    pipe_through :api

    get "/health", ApiController, :health
  end

  # Protected API endpoints requiring authentication
  scope "/api", HelloWorldAppWeb do
    pipe_through :authenticated_api

    get "/hello", ApiController, :protected_hello
    get "/user", ApiController, :user_info
  end

  # Admin endpoints requiring admin:access permission
  scope "/api/admin", HelloWorldAppWeb do
    pipe_through [:authenticated_api]

    get "/info", ApiController, :admin_info
  end

  # App-specific endpoints requiring hello_world:read permission
  scope "/api/hello_world", HelloWorldAppWeb do
    pipe_through [:authenticated_api]

    get "/features", ApiController, :app_specific
  end

  # MCP (Model Context Protocol) endpoints
  scope "/mcp", HelloWorldAppWeb do
    pipe_through :mcp_api

    post "/", MCPController, :handle_request
    get "/tools", MCPController, :tools
  end
end
