# ElixiPath Deployment Guide

## Overview

ElixiPath is a secure file server that integrates with ElixiHub for authentication and provides programmatic access for AI agents through MCP (Model Context Protocol).

## Authentication Architecture

ElixiPath uses a multi-layer authentication system:

1. **ElixiHub SSO** - Users authenticate with ElixiHub first
2. **JWT Token** - ElixiHub provides JWT tokens for authenticated sessions  
3. **Header-based Auth** - ElixiPath forwards user identity to copyparty via `X-Remote-User` header
4. **Copyparty IdP** - Copyparty validates the header and provides file access

## Deployment Process

### 1. Build and Package

```bash
# Build the release
./build.sh

# Create deployment package
./deploy.sh
```

This creates `_build/prod/rel/elixipath-v1.0.0.tar.gz`

### 2. Deploy to ElixiHub

1. Upload the package to ElixiHub admin panel
2. Configure environment variables:
   - `SECRET_KEY_BASE` (required, 64+ characters)
   - `PHX_HOST` (optional, default: localhost)
   - `PORT` (optional, default: 4011)

### 3. Post-deployment Scripts

The deployment automatically runs:

1. **`01_install_dependencies.sh`** - Installs Python dependencies including copyparty
2. **`02_configure_copyparty.sh`** - Configures and starts copyparty with proper authentication
3. **`03_verify_deployment.sh`** - Verifies the deployment is working correctly

## Configuration Details

### Router Configuration

The UI routes use the `:browser` pipeline which includes:
- Session handling (`plug :fetch_session`)
- JWT authentication (`plug ElixiPath.Auth.SessionAuth`)
- Security headers

```elixir
scope "/ui", ElixiPathWeb do
  pipe_through :browser
  
  get "/*path", CopypartyController, :proxy
  # ... other HTTP methods
end
```

### Copyparty Configuration

Copyparty is started with:
```bash
python3 -m copyparty -i 127.0.0.1 -p 8080 --idp-h-usr "X-Remote-User" -v "$ELIXIPATH_DIR:/:rwda"
```

This configuration:
- Listens on localhost:8080
- Uses `X-Remote-User` header for authentication
- Maps the ElixiPath directory to root with read/write/delete/admin permissions

### Controller Logic

The `CopypartyController` handles authentication:

1. Gets authenticated user from `conn.assigns[:current_user]`
2. Forwards requests to copyparty with `X-Remote-User` header
3. Rewrites HTML asset paths from `/.cpr/` to `/ui/.cpr/`
4. Handles file uploads with proper timeouts

## Directory Structure

```
/home/user/elixipath/          # Main data directory
├── shared/                    # Shared files accessible to all users
└── users/                     # User-specific directories
    └── user@example.com/      # Per-user isolation
```

## Verification

After deployment, run the verification script:

```bash
./scripts/03_verify_deployment.sh
```

This checks:
- ElixiPath server responsiveness
- Copyparty server and authentication
- Directory structure
- Process management
- Log files

## Troubleshooting

### Common Issues

1. **403 Forbidden from copyparty**
   - Check copyparty is started with proper volume permissions
   - Verify `X-Remote-User` header is being sent
   - Check copyparty logs in `logs/copyparty.log`

2. **JWT Authentication Failed**
   - Verify ElixiHub SSO integration is configured
   - Check JWT secret configuration matches ElixiHub
   - Review authentication logs

3. **Asset Loading Issues**
   - Ensure HTML rewriting is working in `CopypartyController`
   - Check browser network tab for failed asset requests
   - Verify static asset routes

### Log Locations

- **ElixiPath logs**: Available through ElixiHub admin panel
- **Copyparty logs**: `logs/copyparty.log` in deployment directory
- **Process IDs**: `copyparty.pid` in deployment directory

## API Endpoints

- `/ui/*` - Copyparty web interface (requires authentication)
- `/api/files/*` - File operations API
- `/mcp` - MCP server for AI agents
- `/` - Main application dashboard

## Security Features

- JWT-based authentication with ElixiHub
- User isolation via directory structure  
- Header-based authentication forwarding
- MIME type validation
- File size limits (100MB default)
- CSRF protection
- Secure browser headers

## Performance Considerations

- File uploads support up to 100MB with streaming
- Proper timeout handling for large files (5 minutes)
- HTTP/2 support via Bandit server
- Asset caching and compression