# ElixiHub Integration Guide

This guide covers how to integrate external Elixir applications with ElixiHub for centralized authentication, authorization, and application management.

## Table of Contents

1. [Overview](#overview)
2. [Application Registration](#application-registration)
3. [JWT Authentication Integration](#jwt-authentication-integration)
4. [Permission-Based Authorization](#permission-based-authorization)
5. [Deploying Apps with ElixiHub](#deploying-apps-with-elixihub)
6. [Hello World App Example](#hello-world-app-example)
7. [Production Deployment](#production-deployment)
8. [Troubleshooting](#troubleshooting)

## Overview

ElixiHub provides a centralized authentication and authorization system for Elixir applications running in your home server environment. Applications integrate with ElixiHub through:

- **JWT Token Authentication**: Using JWKS for token verification
- **Role-Based Access Control**: Fine-grained permissions system
- **Application Registration**: Central registry of available apps
- **Single Sign-On**: Users authenticate once and access all apps

### Architecture

```
┌─────────────────┐                    ┌──────────────────┐
│    ElixiHub     │                    │  External App    │
│    Port 4005    │◄──── JWT Tokens ──►│  Port 40XX       │
│                 │                    │                  │
│ • User Mgmt     │                    │ • JWT Verify     │
│ • JWT Issuing   │                    │ • Permission     │
│ • RBAC System   │                    │   Checks         │
│ • App Registry  │                    │ • Business Logic │
│ • JWKS Endpoint │                    │ • API Endpoints  │
└─────────────────┘                    └──────────────────┘
```

## Application Registration

### 1. Register Your App in ElixiHub

Applications must be registered in ElixiHub before they can be accessed by users:

1. **Via Admin UI**:
   - Go to http://localhost:4005/admin/apps
   - Click "Register New App"
   - Fill in the application details:
     - **Name**: Display name for your app
     - **Description**: Brief description of functionality
     - **URL**: Where your app is accessible (e.g., http://localhost:4006)
     - **Status**: Set to "active" to make available to users

2. **Via API**:
   ```bash
   curl -X POST http://localhost:4005/api/apps \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_ADMIN_JWT" \
     -d '{
       "app": {
         "name": "My App",
         "description": "Description of my app",
         "url": "http://localhost:4006",
         "status": "active"
       }
     }'
   ```

### 2. Set Up Permissions

Create app-specific permissions for fine-grained access control:

1. Go to http://localhost:4005/admin/roles
2. Edit existing roles or create new ones
3. Add permissions like:
   - `my_app:read` - Read access to your app
   - `my_app:write` - Write access to your app
   - `my_app:admin` - Administrative access to your app

### 3. Assign Permissions to Users

1. Go to http://localhost:4005/admin/users
2. Click "Manage Roles" for each user
3. Assign roles that include your app's permissions

## JWT Authentication Integration

### 1. Add Dependencies

Add JWT verification dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    # ... your existing deps
    {:joken, "~> 2.6"},
    {:httpoison, "~> 2.2"}
  ]
end
```

### 2. Create JWT Verifier Module

```elixir
defmodule MyApp.Auth.JWTVerifier do
  @moduledoc """
  JWT verification module that uses ElixiHub's JWKS endpoint.
  """

  use Joken.Config

  @elixihub_base_url Application.compile_env(:my_app, :elixihub_base_url, "http://localhost:4005")
  @jwks_url "#{@elixihub_base_url}/.well-known/jwks.json"
  @jwks_cache_ttl 5 * 60 * 1000  # 5 minutes

  def verify_token(token) do
    with {:ok, jwks} <- fetch_jwks(),
         {:ok, claims} <- verify_token_with_jwks(token, jwks) do
      enhance_claims_with_permissions(claims)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_jwks do
    case get_cached_jwks() do
      nil -> fetch_and_cache_jwks()
      jwks -> {:ok, jwks}
    end
  end

  defp get_cached_jwks do
    case :ets.lookup(:jwks_cache, :jwks) do
      [{:jwks, jwks, timestamp}] ->
        if System.system_time(:millisecond) - timestamp < @jwks_cache_ttl do
          jwks
        else
          :ets.delete(:jwks_cache, :jwks)
          nil
        end
      [] -> nil
    end
  end

  defp fetch_and_cache_jwks do
    ensure_ets_table()

    case HTTPoison.get(@jwks_url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, jwks} ->
            timestamp = System.system_time(:millisecond)
            :ets.insert(:jwks_cache, {:jwks, jwks, timestamp})
            {:ok, jwks}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}
      {:error, reason} -> {:error, {:network_error, reason}}
    end
  end

  defp ensure_ets_table do
    unless :ets.whereis(:jwks_cache) != :undefined do
      :ets.new(:jwks_cache, [:set, :public, :named_table])
    end
  end

  defp verify_token_with_jwks(token, jwks) do
    with {:ok, %{"keys" => keys}} <- {:ok, jwks},
         {:ok, header} <- Joken.peek_header(token),
         {:ok, key_data} <- find_key(keys, header["kid"]),
         {:ok, signer} <- create_signer(key_data) do
      
      case Joken.verify_and_validate(token, signer) do
        {:ok, claims} -> {:ok, claims}
        {:error, reason} -> {:error, {:verification_failed, reason}}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_key(keys, kid) do
    case Enum.find(keys, fn key -> key["kid"] == kid end) do
      nil -> {:error, {:key_not_found, kid}}
      key -> {:ok, key}
    end
  end

  defp create_signer(key_data) do
    case key_data do
      %{"kty" => "RSA", "n" => n, "e" => e} ->
        jwk = %{"kty" => "RSA", "n" => n, "e" => e}
        {:ok, Joken.Signer.create("RS256", jwk)}
      %{"kty" => "oct", "k" => k} ->
        {:ok, Joken.Signer.create("HS256", k)}
      _ -> {:error, :unsupported_key_type}
    end
  end

  defp enhance_claims_with_permissions(claims) do
    case fetch_user_permissions(claims["sub"]) do
      {:ok, permissions} ->
        enhanced_claims = Map.put(claims, "permissions", permissions)
        {:ok, enhanced_claims}
      {:error, _reason} ->
        {:ok, Map.put(claims, "permissions", [])}
    end
  end

  defp fetch_user_permissions(_user_id) do
    url = "#{@elixihub_base_url}/api/permissions"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{get_service_token()}"}
    ]

    case HTTPoison.get(url, headers, timeout: 5_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"permissions" => permissions}} -> {:ok, permissions}
          _ -> {:error, :invalid_response}
        end
      _ -> {:error, :permissions_fetch_failed}
    end
  end

  defp get_service_token do
    Application.get_env(:my_app, :service_token, "")
  end
end
```

### 3. Create Authentication Plug

```elixir
defmodule MyApp.Auth do
  import Plug.Conn
  import Phoenix.Controller

  alias MyApp.Auth.JWTVerifier

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, :verify_jwt), do: verify_jwt(conn, [])

  def verify_jwt(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case JWTVerifier.verify_token(token) do
          {:ok, claims} ->
            conn
            |> assign(:current_user, claims)
            |> assign(:authenticated, true)

          {:error, reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid token", details: inspect(reason)})
            |> halt()
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing or invalid authorization header"})
        |> halt()
    end
  end

  def has_permission?(user, permission) do
    user_permissions = get_in(user, ["permissions"]) || []
    permission in user_permissions
  end

  def current_user(conn), do: conn.assigns[:current_user]

  def authenticated?(conn), do: conn.assigns[:authenticated] == true
end
```

### 4. Configure Your Router

Add authentication pipelines to your router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug MyApp.Auth, :verify_jwt
  end

  # Public endpoints
  scope "/api", MyAppWeb do
    pipe_through :api
    get "/health", ApiController, :health
  end

  # Protected endpoints
  scope "/api", MyAppWeb do
    pipe_through :authenticated_api
    get "/protected", ApiController, :protected_endpoint
  end
end
```

## Permission-Based Authorization

### 1. Controller-Level Permission Checks

```elixir
defmodule MyAppWeb.ApiController do
  use MyAppWeb, :controller
  alias MyApp.Auth

  def admin_endpoint(conn, _params) do
    user = Auth.current_user(conn)
    
    if Auth.has_permission?(user, "my_app:admin") do
      json(conn, %{message: "Welcome, admin!"})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions", required: "my_app:admin"})
    end
  end
end
```

### 2. LiveView Permission Checks

```elixir
defmodule MyAppWeb.AdminLive do
  use MyAppWeb, :live_view

  def mount(_params, %{"user_token" => token}, socket) do
    case MyApp.Auth.JWTVerifier.verify_token(token) do
      {:ok, user} ->
        if MyApp.Auth.has_permission?(user, "my_app:admin") do
          {:ok, assign(socket, :current_user, user)}
        else
          {:ok, redirect(socket, to: "/")}
        end
      {:error, _} ->
        {:ok, redirect(socket, to: "/login")}
    end
  end
end
```

## Deploying Apps with ElixiHub

### 1. Local Development Deployment

For local development, you can run multiple Phoenix applications on different ports:

```bash
# Terminal 1: Start ElixiHub
cd /path/to/ElixiHub
mix phx.server  # Runs on port 4005

# Terminal 2: Start your app
cd /path/to/my_app
PORT=4006 mix phx.server

# Terminal 3: Start another app
cd /path/to/another_app  
PORT=4007 mix phx.server
```

### 2. Docker Deployment

Create a `docker-compose.yml` for managing multiple applications:

```yaml
version: '3.8'

services:
  elixihub:
    build: ./ElixiHub
    ports:
      - "4005:4005"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/elixihub_prod
      - SECRET_KEY_BASE=your-secret-key-base
    depends_on:
      - db
    networks:
      - elixihub-network

  hello_world_app:
    build: ./examples/hello_world_app
    ports:
      - "4006:4006"
    environment:
      - ELIXIHUB_BASE_URL=http://elixihub:4005
      - SECRET_KEY_BASE=another-secret-key-base
    depends_on:
      - elixihub
    networks:
      - elixihub-network

  my_custom_app:
    build: ./my_custom_app
    ports:
      - "4007:4007"
    environment:
      - ELIXIHUB_BASE_URL=http://elixihub:4005
      - SECRET_KEY_BASE=yet-another-secret-key-base
    depends_on:
      - elixihub
    networks:
      - elixihub-network

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=elixihub_prod
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - elixihub-network

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl/certs
    depends_on:
      - elixihub
      - hello_world_app
      - my_custom_app
    networks:
      - elixihub-network

volumes:
  postgres_data:

networks:
  elixihub-network:
    driver: bridge
```

### 3. Nginx Configuration

Example `nginx.conf` for proxying to multiple applications:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream elixihub {
        server elixihub:4005;
    }

    upstream hello_world_app {
        server hello_world_app:4006;
    }

    upstream my_custom_app {
        server my_custom_app:4007;
    }

    server {
        listen 80;
        server_name your-domain.com;

        # ElixiHub (main authentication service)
        location / {
            proxy_pass http://elixihub;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Hello World App
        location /hello-world/ {
            rewrite ^/hello-world/(.*)$ /$1 break;
            proxy_pass http://hello_world_app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Custom App
        location /my-app/ {
            rewrite ^/my-app/(.*)$ /$1 break;
            proxy_pass http://my_custom_app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

## Hello World App Example

### 1. Access the Hello World App

The Hello World app is already included in the ElixiHub repository as an example:

```bash
# Start ElixiHub
cd ElixiHub
mix phx.server

# In another terminal, start the Hello World app
cd ElixiHub/examples/hello_world_app
mix deps.get
mix phx.server
```

### 2. Register the Hello World App

1. Log into ElixiHub admin: http://localhost:4005/admin
2. Go to "Manage Applications"
3. Click "Register New App"
4. Fill in:
   - **Name**: Hello World App
   - **Description**: Example integration app for ElixiHub
   - **URL**: http://localhost:4006
   - **Status**: active

### 3. Set Up Permissions

1. Go to "Manage Roles" in ElixiHub admin
2. Edit the "user" role or create a new role
3. Add permission: `hello_world:read`
4. Assign the role to your test users

### 4. Test the Integration

1. **Get JWT Token**:
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
     http://localhost:4006/api/hello_world/features
   ```

### 5. Access via ElixiHub Apps Page

1. Go to http://localhost:4005/apps
2. You should see "Hello World App" listed (if you have permissions)
3. Click on it to access the application

## Production Deployment

### 1. Environment Configuration

Set up production environment variables:

```bash
# ElixiHub
export DATABASE_URL="postgresql://user:pass@localhost/elixihub_prod"
export SECRET_KEY_BASE="your-very-long-secret-key-base"
export PHX_HOST="your-domain.com"

# Apps
export ELIXIHUB_BASE_URL="https://your-domain.com"
export PORT="4006"
```

### 2. SSL/TLS Configuration

Use Let's Encrypt with Certbot for free SSL certificates:

```bash
# Install certbot
sudo apt-get install certbot

# Get certificates
sudo certbot certonly --standalone -d your-domain.com

# Update nginx configuration to use SSL
```

### 3. Database Migration

Run database migrations in production:

```bash
cd ElixiHub
mix ecto.migrate
```

### 4. Asset Compilation

For each Phoenix app, compile assets for production:

```bash
mix assets.deploy
```

### 5. Systemd Service Configuration

Create systemd services for each application:

```ini
# /etc/systemd/system/elixihub.service
[Unit]
Description=ElixiHub
After=network.target postgresql.service

[Service]
Type=simple
User=elixir
WorkingDirectory=/opt/elixihub
ExecStart=/opt/elixir/bin/mix phx.server
Environment=MIX_ENV=prod
Environment=PORT=4005
Environment=DATABASE_URL=postgresql://user:pass@localhost/elixihub_prod
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Troubleshooting

### Common Issues

1. **JWT Verification Fails**:
   - Check ElixiHub is accessible from your app
   - Verify JWKS endpoint: `curl http://localhost:4005/.well-known/jwks.json`
   - Check network connectivity between services

2. **Permission Denied Errors**:
   - Verify user has required permissions in ElixiHub admin
   - Check permission strings match exactly (case-sensitive)
   - Ensure roles are properly assigned to users

3. **App Not Visible in Apps List**:
   - Check app is registered in ElixiHub admin
   - Verify app status is "active"
   - Ensure user has appropriate permissions for the app

4. **Docker Networking Issues**:
   - Verify all services are on the same Docker network
   - Check service names in docker-compose.yml match URLs
   - Use service names (not localhost) for inter-service communication

### Debug Mode

Enable debug logging in your applications:

```elixir
# config/dev.exs or config/prod.exs
config :logger, level: :debug

# In your JWT verifier module
require Logger

def verify_token(token) do
  Logger.debug("Verifying JWT token: #{String.slice(token, 0, 20)}...")
  # ... rest of verification
end
```

### Health Checks

Implement health check endpoints for monitoring:

```elixir
def health(conn, _params) do
  elixihub_status = check_elixihub_connectivity()
  
  json(conn, %{
    status: "ok",
    timestamp: DateTime.utc_now(),
    services: %{
      elixihub: elixihub_status,
      database: "ok",
      application: "ok"
    }
  })
end

defp check_elixihub_connectivity do
  case HTTPoison.get("#{elixihub_url()}/.well-known/jwks.json", [], timeout: 5000) do
    {:ok, %{status_code: 200}} -> "ok"
    _ -> "error"
  end
end
```

## Contributing

To contribute to ElixiHub integration patterns:

1. Fork the ElixiHub repository
2. Create your integration example in `examples/`
3. Update this documentation with your patterns
4. Submit a pull request with tests and documentation

For questions or support, please open an issue on the ElixiHub GitHub repository.