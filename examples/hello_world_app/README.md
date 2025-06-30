# Hello World App - ElixiHub Integration Example

This is a demonstration Phoenix application that shows how to integrate with ElixiHub for centralized authentication and authorization using JWT tokens.

## Overview

The Hello World App demonstrates the following ElixiHub integration patterns:

- **JWT Token Verification**: Uses ElixiHub's JWKS endpoint to verify JWT tokens
- **Permission-Based Access Control**: Implements fine-grained permissions using Bodyguard-style authorization
- **Automatic Claims Enhancement**: Fetches user permissions from ElixiHub API
- **Multi-tier Authorization**: Shows public, authenticated, and permission-specific endpoints

## Architecture

```
┌─────────────┐    JWT Token     ┌────────────────────┐
│   ElixiHub  │ ◄─────────────── │ Hello World App    │
│   Port 4005 │                  │ Port 4006          │
│             │                  │                    │
│ • User Mgmt │                  │ • JWT Verification │
│ • JWT Issue │                  │ • Permission Check │
│ • RBAC      │                  │ • Business Logic   │
│ • JWKS      │                  │ • API Endpoints    │
└─────────────┘                  └────────────────────┘
```

## Quick Start

### Prerequisites

1. ElixiHub running on port 4005
2. Elixir 1.14+
3. Phoenix 1.7+

### Development Setup

```bash
# Navigate to the hello world app directory
cd examples/hello_world_app

# Install dependencies and setup
make setup

# Start the development server
make dev
```

The application will be available at http://localhost:4006

### Building for Deployment

To create a deployable package for ElixiHub:

```bash
# Create production build and deployment package
make build
```

This creates a `hello_world_app-{version}.tar` file ready for deployment.

### Testing the Integration

1. **Get a JWT Token from ElixiHub**:
   ```bash
   curl -X POST http://localhost:4005/api/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@example.com","password":"password123456"}'
   ```

2. **Test Public Endpoint**:
   ```bash
   curl http://localhost:4006/api/health
   ```

3. **Test Protected Endpoint**:
   ```bash
   curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:4006/api/hello
   ```

4. **Test Permission-Based Endpoint**:
   ```bash
   curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:4006/api/admin/info
   ```

## API Endpoints

### Public Endpoints
- `GET /api/health` - Health check endpoint

### Authenticated Endpoints (require valid JWT)
- `GET /api/hello` - Basic authenticated greeting
- `GET /api/user` - Current user information

### Permission-Based Endpoints
- `GET /api/admin/info` - Requires `admin:access` permission
- `GET /api/hello_world/features` - Requires `hello_world:read` permission

## Integration Components

### 1. JWT Verifier (`HelloWorldApp.Auth.JWTVerifier`)

Handles JWT token verification using ElixiHub's JWKS endpoint:

```elixir
# Verify a JWT token
{:ok, claims} = HelloWorldApp.Auth.JWTVerifier.verify_token(token)
```

Key features:
- JWKS caching (5-minute TTL)
- Support for RSA and HMAC signatures
- Automatic claims enhancement with user permissions
- Error handling for network and verification failures

### 2. Authentication Plug (`HelloWorldApp.Auth`)

Provides plugs for authentication and authorization:

```elixir
# In your router pipeline
pipeline :authenticated_api do
  plug :accepts, ["json"]
  plug HelloWorldApp.Auth, :verify_jwt
end

# For permission-specific routes
plug HelloWorldApp.Auth, :require_permission, "admin:access"
```

### 3. Controller Integration

Example of using authentication in controllers:

```elixir
defmodule HelloWorldAppWeb.ApiController do
  use HelloWorldAppWeb, :controller
  alias HelloWorldApp.Auth

  def protected_hello(conn, _params) do
    user = Auth.current_user(conn)
    json(conn, %{message: "Hello #{user["email"]}!"})
  end
end
```

## Configuration

### Application Configuration

Configure ElixiHub base URL in `config/config.exs`:

```elixir
config :hello_world_app,
  elixihub_base_url: "http://localhost:4005"
```

### Environment-Specific Configuration

For production deployments, update the ElixiHub URL in your environment config:

```elixir
# config/prod.exs
config :hello_world_app,
  elixihub_base_url: "https://your-elixihub-instance.com"
```

## Permission Setup in ElixiHub

To test permission-based endpoints, you need to set up permissions in ElixiHub:

1. **Admin Permission**: Create `admin:access` permission and assign to admin role
2. **App Permission**: Create `hello_world:read` permission and assign to appropriate roles
3. **User Assignment**: Ensure your test users have the required roles

### Example Permission Setup via ElixiHub Admin UI:

1. Go to http://localhost:4005/admin/roles
2. Create or edit roles
3. Add permissions: `admin:access`, `hello_world:read`
4. Assign roles to users

## Error Handling

The integration includes comprehensive error handling:

- **Invalid Tokens**: Returns 401 with error details
- **Missing Permissions**: Returns 403 with required permission
- **Network Errors**: Graceful fallback when ElixiHub is unavailable
- **JWKS Fetch Failures**: Cached fallback and retry logic

## Security Considerations

1. **Token Validation**: All JWT tokens are cryptographically verified
2. **Permission Checks**: Fine-grained permission validation
3. **Error Disclosure**: Minimal error information exposed to clients
4. **HTTPS**: Use HTTPS in production for all communications
5. **Token Expiry**: Respect JWT expiration times

## Extending the Integration

### Adding New Protected Routes

1. Add route to authenticated pipeline:
   ```elixir
   scope "/api", HelloWorldAppWeb do
     pipe_through :authenticated_api
     get "/new-endpoint", ApiController, :new_action
   end
   ```

2. Add permission check if needed:
   ```elixir
   scope "/api/protected", HelloWorldAppWeb do
     pipe_through :authenticated_api
     plug HelloWorldApp.Auth, :require_permission, "custom:permission"
     get "/resource", ApiController, :protected_action
   end
   ```

### Custom Permission Logic

For complex permission logic, extend the Auth module:

```elixir
def custom_authorization_check(conn, requirements) do
  user = current_user(conn)
  # Your custom logic here
  if meets_requirements?(user, requirements) do
    conn
  else
    # Halt with error
  end
end
```

## Troubleshooting

### Common Issues

1. **JWT Verification Fails**:
   - Check ElixiHub is running on port 4005
   - Verify JWKS endpoint is accessible: `curl http://localhost:4005/.well-known/jwks.json`
   - Check JWT token format and expiration

2. **Permission Denied**:
   - Verify user has required permissions in ElixiHub
   - Check permission string matches exactly (case-sensitive)
   - Review ElixiHub admin UI for role assignments

3. **Network Timeouts**:
   - Check ElixiHub connectivity
   - Review timeout settings in configuration
   - Check firewall and network settings

### Debug Mode

Enable debug logging by setting log level in `config/dev.exs`:

```elixir
config :logger, level: :debug
```

## Deployment to ElixiHub

### Building for Deployment

The Hello World App includes a complete build system for creating deployable packages:

```bash
# Build production release and create tar package
make build

# This creates: hello_world_app-{version}.tar
```

### Deployment Process

1. **Build the Application**:
   ```bash
   cd examples/hello_world_app
   make build
   ```

2. **Deploy via ElixiHub**:
   - Go to ElixiHub Admin → Applications → Deploy
   - Select your configured host
   - Upload the generated `.tar` file
   - Set deployment path (e.g., `/opt/apps/hello_world_app`)
   - Click Deploy

3. **Start the Service**:
   ```bash
   # ElixiHub automatically creates a systemd service
   sudo systemctl start hello_world_app
   sudo systemctl enable hello_world_app
   ```

### What's Included in the Build

The deployment package includes:
- **Production Release**: Optimized Elixir release
- **Static Assets**: Compiled CSS/JS assets  
- **Configuration Files**: Environment-specific configs
- **Role Definitions**: App-specific roles (`roles.json`)
- **Deployment Script**: Automated setup script
- **Systemd Service**: Auto-generated service file

### Build Commands

```bash
# Available make commands
make help           # Show all available commands
make build          # Build production release and create tar
make deploy-package # Alias for build
make dev            # Start development server
make test           # Run tests
make deps           # Install dependencies
make clean          # Clean build artifacts
make setup          # Development environment setup
```

### Environment Variables

The deployment automatically handles these production settings:

```bash
MIX_ENV=prod                    # Production environment
PHX_SERVER=true                 # Start Phoenix server
PORT=4006                       # Default port
ELIXIHUB_BASE_URL=...          # Configure in runtime.exs
```

### Post-Deployment

After deployment, the app will:
1. **Auto-start** via systemd
2. **Register roles** with ElixiHub (from roles.json)
3. **Accept JWT tokens** from ElixiHub
4. **Serve API endpoints** on the configured port

Monitor the service:
```bash
# Check service status
sudo systemctl status hello_world_app

# View logs
journalctl -u hello_world_app -f

# Restart if needed
sudo systemctl restart hello_world_app
```

## Contributing

This example app serves as a reference implementation. To extend it:

1. Fork the ElixiHub repository
2. Make changes to `examples/hello_world_app/`
3. Test integration with ElixiHub
4. Submit a pull request with documentation updates

## License

This example application is part of the ElixiHub project and follows the same license terms.