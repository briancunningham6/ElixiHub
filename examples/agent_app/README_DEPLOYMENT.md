# Agent App - Updated for Latest Deployment Methods

This Agent App example has been updated to work with the latest ElixiHub deployment methods, including proper support for both macOS (LaunchAgent) and Linux (systemd) deployments.

## Key Updates Made

### 1. **Phoenix LiveDashboard Compatibility** ✅
- Updated router to use modern import syntax
- Added `dev_routes` configuration for dashboard access
- Fixed deprecation warnings

### 2. **Dynamic Port Configuration** ✅
- Removed hardcoded ports and IP addresses
- Uses environment variables with sensible defaults
- Port 4003 for agent apps (configurable via `PORT` env var)
- Listens on all interfaces (0.0.0.0) for better accessibility

### 3. **Release Configuration** ✅
- Added proper release configuration in `mix.exs`
- Includes tar creation for deployment packages
- Optimized for Unix/Linux deployment

### 4. **Environment Variable Management** ✅
- **SECRET_KEY_BASE**: Auto-generated and persisted during deployment
- **OPENAI_API_KEY**: Required for chat functionality
- **ELIXIHUB_JWT_SECRET**: Auto-generated with defaults
- **ELIXIHUB_URL**: Defaults to `http://localhost:4005`
- **HELLO_WORLD_MCP_URL**: Defaults to `http://localhost:4001/api/mcp`

### 5. **Cross-Platform Support** ✅
- Works with both macOS (LaunchAgent) and Linux (systemd)
- Proper service configuration for both platforms
- Automatic service startup and management

### 6. **Updated Configuration Files** ✅
- `config/dev.exs`: Localhost defaults, dev routes enabled
- `config/prod.exs`: Flexible environment configuration
- `config/runtime.exs`: Runtime environment detection
- `mix.exs`: Added release configuration

## Deployment Instructions

### 1. **Build the Package**
```bash
./build.sh
```
This creates `agent_app-0.1.0.tar` ready for deployment.

### 2. **Deploy via ElixiHub**
1. Go to ElixiHub Admin → Applications → Deploy
2. Select your configured host
3. Upload the `agent_app-0.1.0.tar` file
4. Set deployment path (e.g., `/home/user/apps/agent`)
5. Click Deploy

### 3. **Environment Variables**
The deployment system will automatically handle most environment variables, but you may want to set:

- `OPENAI_API_KEY`: Your OpenAI API key (required for chat)
- `PORT`: Custom port if not using 4003
- `ELIXIHUB_URL`: If ElixiHub is not on localhost:4005

### 4. **Test the Deployment**
```bash
# Run the test script to verify everything is working
./test_deployment.sh
```

## Application URLs

After successful deployment:
- **Main page**: `http://localhost:4003/`
- **Health check**: `http://localhost:4003/health`
- **Chat interface**: `http://localhost:4003/chat`
- **MCP endpoint**: `http://localhost:4003/api/mcp`
- **Live Dashboard** (dev mode): `http://localhost:4003/dev/dashboard`

## Features

### 🤖 **AI Chat Interface**
- OpenAI-powered conversational AI
- JWT-based authentication with ElixiHub
- Real-time chat interface

### 🔌 **MCP (Model Context Protocol) Support**
- Discoverable MCP endpoint for other applications
- Integration with Hello World MCP server
- Tool registration and discovery

### 🔐 **Security**
- JWT authentication integration with ElixiHub
- Secure environment variable handling
- Production-ready configuration

### 📊 **Monitoring**
- Health check endpoint
- Phoenix LiveDashboard integration
- Telemetry and metrics

## Development

### **Local Development**
```bash
# Install dependencies
mix deps.get

# Start the server
mix phx.server
```

### **Environment Setup**
Create a `.env` file (not included in repository):
```bash
OPENAI_API_KEY=your_openai_api_key_here
ELIXIHUB_JWT_SECRET=your_jwt_secret_here
ELIXIHUB_URL=http://localhost:4005
HELLO_WORLD_MCP_URL=http://localhost:4001/api/mcp
```

## Troubleshooting

### **Service Not Starting**
1. Check service logs: `journalctl -u elixihub-agent` (Linux) or Console.app (macOS)
2. Verify SECRET_KEY_BASE is properly set
3. Check port availability: `lsof -i :4003`

### **Chat Not Working**
1. Verify OPENAI_API_KEY is set and valid
2. Check network connectivity to OpenAI API
3. Review application logs for API errors

### **Authentication Issues**
1. Verify ELIXIHUB_JWT_SECRET matches ElixiHub configuration
2. Check ELIXIHUB_URL is accessible
3. Ensure proper role configuration in ElixiHub

## Architecture

This app demonstrates:
- **Phoenix Framework**: Modern web application framework
- **LiveView**: Real-time web interfaces
- **MCP Protocol**: Model Context Protocol for AI tool integration
- **Service-based deployment**: Proper service management
- **Multi-platform support**: macOS and Linux compatibility

The updated deployment system ensures consistent behavior across different environments while maintaining security and proper service management.