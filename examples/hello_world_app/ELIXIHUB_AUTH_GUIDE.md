# ElixiHub Authentication Integration Guide

This guide shows how to integrate any Phoenix application with ElixiHub's SSO authentication system using the reusable authentication modules.

## 🚀 Quick Setup

### 1. Copy Authentication Modules

Copy these modules from hello_world_app to your new app:

```bash
# Copy the entire auth directory
cp -r examples/hello_world_app/lib/hello_world_app/auth/ lib/your_app/auth/

# Update module names in all files
find lib/your_app/auth/ -name "*.ex" -exec sed -i '' 's/HelloWorldApp/YourApp/g' {} +
```

### 2. Add Dependencies

Add to your `mix.exs`:

```elixir
defp deps do
  [
    # ... your existing deps
    {:joken, "~> 2.6"},
    {:jose, "~> 1.11"}
  ]
end
```

### 3. Configure Authentication

Add to your `config/dev.exs`:

```elixir
# ElixiHub authentication configuration
config :your_app, :elixihub_auth,
  shared_secret: "dev_secret_key_32_chars_long_exactly_for_jwt_signing",
  elixihub_url: "http://localhost:4005",
  app_name: "YourAppName"
```

### 4. Update Router

Add authentication to your router:

```elixir
defmodule YourAppWeb.Router do
  use YourAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {YourAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug YourApp.Auth.ElixiHubAuth.SessionAuth  # Add this line
  end

  scope "/", YourAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/sso/authenticate", YourApp.Auth.ElixiHubAuth.SSOController, :authenticate
    get "/sso/logout", YourApp.Auth.ElixiHubAuth.SSOController, :logout
  end

  # Development-only routes (optional)
  if Mix.env() == :dev do
    scope "/dev", YourAppWeb do
      pipe_through :browser
      
      get "/login", YourApp.Auth.ElixiHubAuth.SSOController, :dev_login
    end
  end
end
```

### 5. Handle SSO Tokens in Controllers

Update your page controller to handle SSO redirects:

```elixir
defmodule YourAppWeb.PageController do
  use YourAppWeb, :controller

  def home(conn, %{"sso_token" => _token} = params) do
    # If SSO token is present, redirect to SSO authenticate
    redirect(conn, to: "/sso/authenticate?" <> URI.encode_query(params))
  end

  def home(conn, _params) do
    # Get current user from session (assigned by SessionAuth plug)
    user = conn.assigns[:current_user]
    
    render(conn, :home, user: user)
  end
end
```

### 6. Update Templates (Optional)

Show authentication status in your templates:

```heex
<%= if @user do %>
  <div class="bg-green-50 border border-green-200 rounded-lg p-4">
    <p class="text-green-800">
      ✅ <strong>Authenticated as:</strong> <%= @user.email %>
    </p>
    <div class="mt-2">
      <a href="/sso/logout" class="text-sm text-green-600 hover:text-green-500 underline">
        Logout
      </a>
    </div>
  </div>
<% else %>
  <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
    <p class="text-yellow-800">
      🔒 <strong>Not authenticated</strong> - You should be redirected to ElixiHub
    </p>
  </div>
<% end %>
```

## 📚 API Reference

### ElixiHubAuth Module

Main authentication interface:

```elixir
# Verify a JWT token
{:ok, user} = YourApp.Auth.ElixiHubAuth.verify_token(token)

# Get configuration
secret = YourApp.Auth.ElixiHubAuth.get_shared_secret()
elixihub_url = YourApp.Auth.ElixiHubAuth.get_elixihub_url()
app_name = YourApp.Auth.ElixiHubAuth.get_app_name()

# Ensure user directories exist (for file-based apps)
dirs = YourApp.Auth.ElixiHubAuth.ensure_user_directories("user@example.com")
```

### SessionAuth Plug

Automatically handles:
- Session token verification
- SSO token bypass (prevents redirect loops)
- Redirect to ElixiHub for authentication
- User assignment to `conn.assigns[:current_user]`

### SSOController

Handles SSO callbacks:
- `GET /sso/authenticate` - Process SSO tokens from ElixiHub
- `GET /sso/logout` - Clear user session
- `GET /dev/login` - Development bypass (dev environment only)

### JWTVerifier

Low-level JWT operations:
- Uses HS512 algorithm (matches ElixiHub's Guardian)
- Comprehensive error handling and logging
- Token generation for testing

## 🔧 Configuration Options

### Required Configuration

```elixir
config :your_app, :elixihub_auth,
  shared_secret: "your-jwt-secret-key",  # Must match ElixiHub
  elixihub_url: "http://localhost:4005", # ElixiHub base URL
  app_name: "YourAppName"                # Used in SSO redirects
```

### Optional Configuration

```elixir
config :your_app, :elixihub_auth,
  # Custom port for this app (default: determined by endpoint config)
  app_port: 4007,
  
  # Custom redirect paths
  login_redirect: "/dashboard",
  logout_redirect: "/goodbye"
```

## 🚦 Authentication Flow

1. **User visits protected route** → SessionAuth plug checks for session
2. **No session found** → Redirect to ElixiHub SSO with `app_id` and `return_to`
3. **ElixiHub authenticates user** → Generates JWT token
4. **ElixiHub redirects back** → To your app with `sso_token` parameter
5. **Your app processes token** → SSOController verifies JWT and creates session
6. **User is authenticated** → Can access protected resources

## 🔍 Debugging

### Enable Debug Logging

```elixir
config :logger, level: :debug
```

### Check Authentication Status

```elixir
# In your controller
def debug_auth(conn, _params) do
  user = conn.assigns[:current_user]
  session_token = get_session(conn, "auth_token")
  
  json(conn, %{
    authenticated: !!user,
    user: user,
    has_session_token: !!session_token
  })
end
```

### Common Issues

1. **JWT Verification Fails**
   - Check that `shared_secret` matches ElixiHub exactly
   - Verify algorithm is HS512
   - Check token expiration

2. **Redirect Loops**
   - Ensure SSO routes don't use SessionAuth plug
   - Check that `sso_token` parameter handling works

3. **Configuration Issues**
   - Verify `elixihub_url` is correct
   - Check `app_name` matches ElixiHub registration

## 🎯 Production Considerations

1. **Secrets Management**
   ```elixir
   # Use environment variables in production
   config :your_app, :elixihub_auth,
     shared_secret: System.get_env("ELIXIHUB_JWT_SECRET")
   ```

2. **HTTPS in Production**
   ```elixir
   config :your_app, :elixihub_auth,
     elixihub_url: "https://your-elixihub-domain.com"
   ```

3. **Session Security**
   ```elixir
   config :your_app, YourAppWeb.Endpoint,
     session: [
       store: :cookie,
       key: "_your_app_key",
       signing_salt: "your-signing-salt",
       same_site: "Lax",
       secure: true  # HTTPS only
     ]
   ```

## 📖 Example Apps

- **hello_world_app** - Basic SSO integration
- **elixipath** - File server with advanced authentication
- **task_manager** - Database app with user roles
- **agent_app** - AI chat with permissions

Each example demonstrates different aspects of ElixiHub integration.