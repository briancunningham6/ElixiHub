# ElixiPath File & Media Server

ElixiPath is a secure file and media server that wraps the Python-based Copyparty file server, integrating it seamlessly with the ElixiHub ecosystem for authenticated file management.

## Features

### 🔐 ElixiHub Integration
- **Authentication**: All access gated through ElixiHub's authentication system
- **Single Sign-On**: Users log in through ElixiHub and get passed to ElixiPath with authenticated sessions
- **Token Forwarding**: Requests to Copyparty are authorized through a secure proxy layer
- **Standard Deployment**: Follows ElixiHub deployment model on port 4011

### 📁 Organized Directory Structure
- **Shared Directory**: `/elixipath/shared/{app_name}/` - accessible by all authenticated users
- **User-Specific Directory**: `/elixipath/users/{user_email}/{app_name}/` - private to each user
- **App Isolation**: Each application gets its own subdirectory in both shared and user spaces

### 🌐 Copyparty Integration
- **Subprocess Management**: Launches and manages Copyparty Python server as a subprocess
- **Web UI**: Native Copyparty interface exposed on `/ui` route with authentication
- **File Operations**: Full read/write/delete support where authorized
- **External Auth**: Uses Copyparty's `--auth-cgi` for ElixiHub token validation

### 🤖 MCP Server
Provides programmatic access for AI agents and other applications:
- `list_files` - List shared/user files with optional app filtering
- `upload_file` - Upload files with base64 content
- `delete_file` - Delete files and directories
- `get_file_info` - Get file metadata and information
- `create_directory` - Create new directories
- `get_storage_usage` - Query storage usage statistics

### 🛡️ Security Controls
- **Directory Isolation**: Strict path validation prevents traversal attacks
- **File Size Limits**: Maximum 100MB per upload
- **MIME Type Validation**: Only allowed file types can be uploaded
- **Access Control**: All operations scoped by app name and user permissions

## Installation

### Prerequisites
1. Elixir 1.14+ and Erlang 26+
2. Phoenix Framework 1.7+
3. Python 3.8+ with pip
4. Running ElixiHub instance on port 4005

### Setup Steps

1. **Install Copyparty**:
   ```bash
   pip install copyparty
   ```

2. **Install Dependencies**:
   ```bash
   cd elixipath
   mix deps.get
   ```

3. **Setup Assets**:
   ```bash
   mix assets.setup
   mix assets.build
   ```

4. **Directory Structure** (created automatically):
   The app will automatically create the following structure in your home directory:
   ```
   ~/elixipath/
   ├── shared/     # Shared files for all users
   └── users/      # User-specific directories
   ```

5. **Start the Server**:
   ```bash
   mix phx.server
   ```

The server will start on `http://localhost:4011`

## Usage

### Web Interface
1. Navigate to `http://localhost:4011`
2. Login through ElixiHub authentication
3. Use the web interface to browse your files
4. Access Copyparty UI at `/ui` for advanced file operations

### MCP Integration
Add to your MCP client configuration:
```json
{
  "name": "elixipath",
  "url": "http://localhost:4011/mcp",
  "description": "File and media server with secure file operations"
}
```

### API Access
Use JWT tokens from ElixiHub for API access:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"method":"list_files","params":{"path":"shared"},"id":1}' \
     http://localhost:4011/mcp
```

## Directory Structure

```
~/elixipath/
├── shared/                    # Shared files for all users
│   ├── agent_app/            # Agent app shared files
│   ├── task_manager/         # Task manager shared files
│   └── hello_world_app/      # Hello world shared files
└── users/                    # User-specific directories
    └── user@example.com/     # Per-user directory
        ├── agent_app/        # User's agent files
        ├── task_manager/     # User's task files
        └── hello_world_app/  # User's hello world files
```

## Configuration

### Environment Variables
- `SECRET_KEY_BASE` - Phoenix secret key for sessions
- `PHX_HOST` - Hostname for production deployment
- `PORT` - Port override (default: 4011)

### Security Settings
File size and MIME type restrictions can be configured in `lib/elixipath/file_operations.ex`:

```elixir
@max_file_size 100 * 1024 * 1024 # 100MB
@allowed_mime_types [
  "text/plain", "text/csv", "application/json",
  "image/jpeg", "image/png", "application/pdf"
  # Add more as needed
]
```

## Development

### Running Tests
```bash
mix test
```

### Code Quality
```bash
mix format
mix credo
```

### Development Server
```bash
iex -S mix phx.server
```

## Deployment

### Building for ElixiHub

1. **Build the release:**
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

2. **Deploy via ElixiHub UI:**
   - Go to ElixiHub Admin → Applications → Deploy
   - Select your configured host
   - Upload the generated `.tar` file
   - Set deployment path to: `/tmp/elixipath`
   - Check "Deploy as Service" (recommended)
   - Click Deploy

3. **ElixiHub handles automatically:**
   - **Pre-deployment**: Install Python 3.8+, pip3, and copyparty
   - **Source extraction**: Extract to `/tmp/elixipath`
   - **Dependency installation**: Elixir dependencies and asset compilation
   - **Post-deployment**: Configure copyparty with authentication integration
   - **Service creation**: Create systemd/LaunchAgent services
   - **Application startup**: Start ElixiPath with copyparty subprocess
   - **Environment configuration**: Set required environment variables

### Docker Deployment (Alternative)

```bash
# Build Docker image
docker build -t elixipath .

# Run container
docker run -d \
  -p 4011:4011 \
  -e SECRET_KEY_BASE="your-secret" \
  -e PHX_HOST="your-domain.com" \
  -e PHX_SERVER=true \
  -v /path/to/storage:/app/elixipath \
  elixipath
```

## Troubleshooting

### Common Issues

1. **Copyparty not starting**: Ensure Python 3 and copyparty package are installed
2. **Permission errors**: Check `/elixipath` directory permissions
3. **Authentication failures**: Verify ElixiHub is running and JWT secrets match
4. **File upload errors**: Check file size limits and MIME type restrictions

### Logs
Check logs for detailed error information:
```bash
tail -f logs/dev.log
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For issues and support, please create an issue in the ElixiHub repository.