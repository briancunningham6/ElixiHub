defmodule TaskManagerWeb.Router do
  use TaskManagerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TaskManagerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :authenticated do
    plug TaskManager.Auth.SessionAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug TaskManager.Auth.JWTAuth
  end

  scope "/", TaskManagerWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/sso/authenticate", SSOController, :authenticate
    get "/sso/logout", SSOController, :logout
    # Alternative direct auth for debugging
    get "/direct/login", DirectAuthController, :login
  end

  scope "/api", TaskManagerWeb do
    pipe_through :api

    resources "/tasks", TaskController, except: [:new, :edit]
    get "/tasks/stats", TaskController, :stats
    put "/tasks/:id/complete", TaskController, :complete
  end

  scope "/app", TaskManagerWeb do
    pipe_through [:browser, :authenticated]

    live "/", TaskLive.Index, :index
    live "/tasks/new", TaskLive.Index, :new
    live "/tasks/:id/edit", TaskLive.Index, :edit
  end

  scope "/mcp", TaskManagerWeb do
    pipe_through :api

    post "/", MCPController, :handle_request
  end

  if Application.compile_env(:task_manager, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TaskManagerWeb.Telemetry
    end
  end
end