# Agent App

An ElixiHub Agent application that provides a chatbot interface integrated with OpenAI's ChatGPT and MCP (Model Context Protocol) for communicating with other ElixiHub applications.

## Features

- **ChatGPT Integration**: Uses OpenAI API for natural language processing
- **MCP Client**: Communicates with other ElixiHub apps using Model Context Protocol
- **ElixiHub Authentication**: Integrates with ElixiHub's JWT-based authentication system
- **Real-time Chat Interface**: LiveView-based chat interface
- **Tool Discovery**: Automatically discovers and uses tools from connected applications

## Prerequisites

- Elixir 1.14 or later
- Phoenix 1.7 or later
- OpenAI API key
- Access to ElixiHub for authentication

## Setup

1. **Install dependencies:**
   ```bash
   mix deps.get
   ```

2. **Set environment variables:**
   ```bash
   export OPENAI_API_KEY="your-openai-api-key"
   export ELIXIHUB_JWT_SECRET="your-elixihub-jwt-secret"
   export ELIXIHUB_URL="http://localhost:4000"
   export HELLO_WORLD_MCP_URL="http://localhost:4001/mcp"
   ```

3. **Build assets:**
   ```bash
   mix assets.setup
   mix assets.build
   ```

4. **Start the server:**
   ```bash
   mix phx.server
   ```

The application will be available at `http://localhost:4003`.

## Usage

### Web Interface

Visit `http://localhost:4003/chat` to access the chat interface.

You can ask questions like:
- "Get a personalized hello world for me"
- "What tools are available?"
- "Give me info about the hello world app"

### API Endpoints

#### Chat API
```bash
curl -X POST http://localhost:4003/api/chat \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Get a personalized hello world for me"}'
```

#### List Available Tools
```bash
curl http://localhost:4003/api/tools \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## MCP Integration

The Agent App automatically connects to configured MCP servers. Currently supported:

- **Hello World App**: Provides personalized greeting tools

### Adding New MCP Servers

Update the configuration in `config/dev.exs`:

```elixir
config :agent_app, :mcp,
  servers: [
    %{
      name: "hello_world",
      url: "http://localhost:4001/mcp",
      description: "Hello World MCP server"
    },
    %{
      name: "your_new_app",
      url: "http://localhost:4002/mcp", 
      description: "Your new MCP server"
    }
  ]
```

## Authentication

The Agent App integrates with ElixiHub's authentication system. Users must have a valid JWT token from ElixiHub to access the API endpoints.

The token should include:
- `user_id`: User's ID in ElixiHub
- `username`: User's username
- `roles`: User's roles (optional)

## Development

### Running Tests
```bash
mix test
```

### Code Formatting
```bash
mix format
```

### Interactive Console
```bash
iex -S mix phx.server
```

## Production Deployment

1. **Build release:**
   ```bash
   MIX_ENV=prod mix assets.deploy
   MIX_ENV=prod mix release
   ```

2. **Set production environment variables:**
   - `SECRET_KEY_BASE`
   - `PHX_HOST`
   - `PORT`
   - `OPENAI_API_KEY`
   - `ELIXIHUB_JWT_SECRET`
   - `ELIXIHUB_URL`

3. **Start the release:**
   ```bash
   _build/prod/rel/agent_app/bin/agent_app start
   ```

## Configuration

### OpenAI Settings

Customize OpenAI behavior in your config:

```elixir
config :agent_app, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization: System.get_env("OPENAI_ORGANIZATION"),
  http_options: [recv_timeout: 30_000]
```

### MCP Settings

Configure MCP servers:

```elixir
config :agent_app, :mcp,
  servers: [
    # List of MCP servers to connect to
  ]
```

## Troubleshooting

### Common Issues

1. **OpenAI API Key Not Set**
   - Ensure `OPENAI_API_KEY` environment variable is set
   - Check that the API key is valid and has sufficient credits

2. **MCP Connection Failures**
   - Verify MCP server URLs are correct and accessible
   - Check that target applications are running and have MCP endpoints enabled

3. **Authentication Errors**
   - Ensure `ELIXIHUB_JWT_SECRET` matches ElixiHub's configuration
   - Verify JWT tokens are valid and not expired

### Logs

Check application logs for detailed error information:
```bash
tail -f log/dev.log
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request