defmodule ElixihubWeb.Router do
  use ElixihubWeb, :router

  import ElixihubWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixihubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug Guardian.Plug.Pipeline,
      module: Elixihub.Guardian,
      error_handler: ElixihubWeb.GuardianErrorHandler
    plug Guardian.Plug.VerifyHeader, realm: "Bearer"
    plug Guardian.Plug.EnsureAuthenticated
    plug Guardian.Plug.LoadResource
  end

  scope "/", ElixihubWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # SSO routes for seamless authentication with deployed apps
  scope "/sso", ElixihubWeb do
    pipe_through :browser

    get "/auth", SSOController, :authenticate
    get "/logout", SSOController, :logout
  end

  # API routes
  # JWKS endpoint for JWT verification
  scope "/", ElixihubWeb do
    pipe_through :api

    get "/.well-known/jwks.json", JWKSController, :jwks
  end

  scope "/api", ElixihubWeb.Api do
    pipe_through :api

    post "/login", AuthController, :login
    post "/register", AuthController, :register
    get "/mcp/discovery", MCPController, :discovery
  end

  scope "/api", ElixihubWeb.Api do
    pipe_through :api_auth

    get "/user", AuthController, :user
    get "/permissions", AuthController, :permissions
    get "/auth/token", AuthController, :token
    
    resources "/users", UserController, only: [:index, :delete]
    resources "/apps", AppController, except: [:new, :edit]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixihub, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElixihubWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ElixihubWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", ElixihubWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
    
    # Apps Landing Page
    live "/apps", AppsLive, :index
    
    # Admin Dashboard
    live "/admin", DashboardLive, :index
    
    # Admin User Management
    live "/admin/users", Admin.UserLive.Index, :index
    live "/admin/users/:id/roles", Admin.UserLive.Roles, :show
    
    # Admin Role Management
    live "/admin/roles", Admin.RoleLive.Index, :index
    live "/admin/roles/new", Admin.RoleLive.Index, :new
    live "/admin/roles/:id/edit", Admin.RoleLive.Index, :edit
    live "/admin/roles/:id/permissions", Admin.RoleLive.Permissions, :show
    
    # Admin Permission Management
    live "/admin/permissions", Admin.PermissionLive.Index, :index
    live "/admin/permissions/new", Admin.PermissionLive.Index, :new
    live "/admin/permissions/:id/edit", Admin.PermissionLive.Index, :edit
    
    # Admin Node Management
    live "/admin/nodes", Admin.NodeLive.Index, :index
    live "/admin/nodes/new", Admin.NodeLive.Index, :new
    live "/admin/nodes/:id/edit", Admin.NodeLive.Index, :edit
    live "/admin/nodes/:node_id/shell", Admin.ShellLive.Index, :show
    
    # Admin Host Management
    live "/admin/hosts", Admin.HostLive.Index, :index
    live "/admin/hosts/new", Admin.HostLive.Index, :new
    live "/admin/hosts/:id/edit", Admin.HostLive.Index, :edit
    live "/admin/hosts/:id/restart", Admin.HostLive.Index, :restart_confirm
    live "/admin/hosts/:host_id/shell", Admin.HostLive.Shell, :show
    
    # Admin App Management
    live "/admin/apps", Admin.AppLive.Index, :index
    live "/admin/apps/new", Admin.AppLive.Index, :new
    live "/admin/apps/deploy", Admin.AppLive.Index, :deploy_select
    live "/admin/apps/:id/edit", Admin.AppLive.Index, :edit
    live "/admin/apps/:id/deploy", Admin.AppLive.Index, :deploy
    live "/admin/apps/:id/roles", Admin.AppLive.Roles, :show
  end

  scope "/", ElixihubWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
