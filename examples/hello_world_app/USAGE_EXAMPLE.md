# HelloWorldApp - Authentication Template Usage

This enhanced hello_world_app now serves as a complete template for ElixiHub SSO integration.

## 🎯 What's New

The app now includes:
- ✅ **Complete SSO Integration** - Seamless authentication with ElixiHub
- ✅ **Reusable Auth Modules** - Copy-paste ready authentication code
- ✅ **Session Management** - Proper session handling and logout
- ✅ **Development Bypass** - Test without ElixiHub running
- ✅ **Error Handling** - No more redirect loops
- ✅ **JWT Verification** - Battle-tested HS512 token verification

## 🚀 Quick Test

### 1. Start ElixiHub
```bash
cd /path/to/ElixiHub  
mix phx.server
```

### 2. Start HelloWorldApp
```bash
cd examples/hello_world_app
mix deps.get
mix phx.server
```

### 3. Test Authentication
- Visit `http://localhost:4006`
- Should redirect to ElixiHub for authentication
- After login, redirected back with user info displayed

### 4. Development Mode (Optional)
```bash
# Test without ElixiHub
curl http://localhost:4006/dev/login
```

## 📁 File Structure

```
lib/hello_world_app/auth/
├── elixihub_auth.ex              # Main authentication interface
└── elixihub_auth/
    ├── jwt_verifier.ex           # JWT token verification
    ├── session_auth.ex           # Session authentication plug
    └── sso_controller.ex         # SSO callback handling
```

## 🔄 Creating New Apps

### Method 1: Copy Template (Recommended)
```bash
# Copy the entire hello_world_app
cp -r examples/hello_world_app examples/my_new_app

# Rename throughout codebase
find examples/my_new_app -name "*.ex" -o -name "*.exs" -o -name "*.heex" | \
  xargs sed -i '' 's/HelloWorldApp/MyNewApp/g'

find examples/my_new_app -name "*.ex" -o -name "*.exs" -o -name "*.heex" | \
  xargs sed -i '' 's/hello_world_app/my_new_app/g'

# Update port in config/dev.exs
sed -i '' 's/port: 4006/port: 4007/g' examples/my_new_app/config/dev.exs
```

### Method 2: Manual Integration
Follow the step-by-step guide in `ELIXIHUB_AUTH_GUIDE.md`

## 🎨 Customization Examples

### Custom User Information
```elixir
def home(conn, _params) do
  user = conn.assigns[:current_user]
  
  # Add custom user data
  user_data = if user do
    %{
      email: user.email,
      username: user.username,
      roles: user.roles,
      last_login: get_last_login(user.user_id),
      preferences: get_user_preferences(user.user_id)
    }
  else
    nil
  end
  
  render(conn, :home, user: user_data)
end
```

### Protected Routes
```elixir
pipeline :authenticated do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug MyApp.Auth.ElixiHubAuth.SessionAuth
  plug :require_authenticated_user
end

defp require_authenticated_user(conn, _opts) do
  if conn.assigns[:current_user] do
    conn
  else
    conn
    |> put_flash(:error, "You must be logged in to access this page")
    |> redirect(to: "/")
    |> halt()
  end
end
```

### Role-Based Access
```elixir
def admin_panel(conn, _params) do
  user = conn.assigns[:current_user]
  
  if "admin" in user.roles do
    render(conn, :admin_panel)
  else
    conn
    |> put_status(403)
    |> put_flash(:error, "Access denied")
    |> redirect(to: "/")
  end
end
```

## 🔧 Configuration Examples

### Production Config
```elixir
# config/runtime.exs
if config_env() == :prod do
  config :my_app, :elixihub_auth,
    shared_secret: System.get_env("ELIXIHUB_JWT_SECRET") || 
      raise("ELIXIHUB_JWT_SECRET environment variable is missing"),
    elixihub_url: System.get_env("ELIXIHUB_URL") || "https://auth.mycompany.com",
    app_name: System.get_env("APP_NAME") || "MyApp"
end
```

### Multiple Environment Support
```elixir
# config/dev.exs
config :my_app, :elixihub_auth,
  shared_secret: "dev_secret_key_32_chars_long_exactly_for_jwt_signing",
  elixihub_url: "http://localhost:4005",
  app_name: "MyApp-Dev"

# config/test.exs  
config :my_app, :elixihub_auth,
  shared_secret: "test_secret_key",
  elixihub_url: "http://localhost:4005",
  app_name: "MyApp-Test"
```

## 📊 Monitoring and Debugging

### Health Check Endpoint
```elixir
def health(conn, _params) do
  user = conn.assigns[:current_user]
  
  status = %{
    app: "MyApp",
    status: "healthy",
    authenticated: !!user,
    elixihub_configured: !!MyApp.Auth.ElixiHubAuth.get_shared_secret(),
    timestamp: DateTime.utc_now()
  }
  
  json(conn, status)
end
```

### Authentication Status
```elixir
def auth_status(conn, _params) do
  user = conn.assigns[:current_user]
  session_token = get_session(conn, "auth_token")
  
  status = %{
    authenticated: !!user,
    user_id: user && user.user_id,
    email: user && user.email,
    roles: user && user.roles,
    has_session_token: !!session_token,
    session_id: get_session(conn, :session_id)
  }
  
  json(conn, status)
end
```

## 🎯 Next Steps

1. **Deploy to ElixiHub** - Use the build script to create deployment packages
2. **Add Business Logic** - Build your app features on top of authentication
3. **Customize UI** - Update templates and styling  
4. **Add APIs** - Create authenticated API endpoints
5. **Configure Roles** - Define app-specific roles in roles.json
6. **Set Up Monitoring** - Add logging and health checks

This template provides a solid foundation for any ElixiHub-integrated Phoenix application!