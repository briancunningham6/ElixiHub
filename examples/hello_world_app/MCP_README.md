# Hello World App - MCP Integration

This document describes the Model Context Protocol (MCP) integration in the Hello World App.

## Overview

The Hello World App now includes MCP server capabilities, allowing AI agents (like the Agent App) to interact with its functionality through standardized tools.

## Available MCP Tools

### 1. get_personalized_greeting

Gets a personalized hello world greeting for a user.

**Parameters:**
- `style` (optional): The greeting style - "formal", "casual", "friendly", or "enthusiastic"
- `include_time` (optional): Boolean to include current time in the greeting

**Example Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_personalized_greeting",
    "arguments": {
      "style": "friendly",
      "include_time": true
    },
    "context": {
      "user_id": 1,
      "username": "john_doe"
    }
  }
}
```

**Example Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "greeting": "Hello john_doe! It's great to see you here in our Hello World app. The current time is 2025-06-30T14:30:45Z.",
    "user": "john_doe",
    "style": "friendly",
    "timestamp": "2025-06-30T14:30:45Z",
    "app": "hello_world_app"
  }
}
```

### 2. get_app_info

Gets information about the Hello World application.

**Parameters:** None

**Example Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_app_info",
    "arguments": {},
    "context": {
      "user_id": 1,
      "username": "john_doe"
    }
  }
}
```

**Example Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "name": "Hello World App",
    "version": "0.1.0",
    "description": "A simple Hello World application with MCP support",
    "capabilities": [
      "Personalized greetings",
      "MCP tool integration", 
      "ElixiHub authentication"
    ],
    "mcp_tools": ["get_personalized_greeting", "get_app_info"],
    "status": "active",
    "uptime": "2h 15m 30s"
  }
}
```

## MCP Endpoints

### Tool Discovery
- **GET** `/mcp/tools` - Lists available tools
- Requires authentication

### Tool Execution  
- **POST** `/mcp/` - Executes MCP JSON-RPC requests
- Requires authentication
- Accepts standard MCP JSON-RPC 2.0 format

## Authentication

All MCP endpoints require ElixiHub JWT authentication:

```bash
curl -X POST http://localhost:4001/mcp/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_personalized_greeting",
      "arguments": {"style": "friendly"}
    }
  }'
```

## Integration with Agent App

The Agent App automatically discovers and uses these tools when users ask for:
- "Get a personalized hello world for me"
- "Give me a friendly greeting"
- "What info do you have about the hello world app?"

## Configuration

The MCP server is automatically enabled when the Hello World App starts. It runs on the same port as the main application (default: 4001).

### Router Configuration

```elixir
# MCP (Model Context Protocol) endpoints
scope "/mcp", HelloWorldAppWeb do
  pipe_through :mcp_api

  post "/", MCPController, :handle_request
  get "/tools", MCPController, :tools
end
```

### Pipeline Configuration

```elixir
pipeline :mcp_api do
  plug :accepts, ["json"]
  plug HelloWorldAppWeb.MCPController, :capture_raw_body
  plug HelloWorldApp.Auth, :verify_jwt
end
```

## Testing MCP Integration

### 1. Test Tool Discovery

```bash
curl http://localhost:4001/mcp/tools \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 2. Test Tool Execution

```bash
curl -X POST http://localhost:4001/mcp/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }'
```

### 3. Test with Agent App

Start both applications and use the Agent App's chat interface:

1. Start Hello World App: `mix phx.server` (port 4001)
2. Start Agent App: `mix phx.server` (port 4003)
3. Visit `http://localhost:4003/chat`
4. Type: "Get a personalized hello world for me"

## Adding New Tools

To add new MCP tools to the Hello World App:

1. **Update the tools list** in `HelloWorldApp.MCPServer`:

```elixir
@tools [
  # existing tools...
  %{
    "name" => "your_new_tool",
    "description" => "Description of what your tool does",
    "inputSchema" => %{
      "type" => "object",
      "properties" => %{
        "param1" => %{
          "type" => "string",
          "description" => "Description of parameter"
        }
      },
      "required" => ["param1"]
    }
  }
]
```

2. **Add the tool handler** in the same module:

```elixir
defp handle_tool_call(%{"name" => "your_new_tool", "arguments" => arguments}, user_context) do
  # Implement your tool logic here
  {:ok, result}
end
```

3. **Test the new tool** using the MCP endpoints.

## Error Handling

The MCP server returns standard JSON-RPC 2.0 error responses:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Tool not found"
  }
}
```

Common error codes:
- `-32700`: Parse error
- `-32600`: Invalid Request  
- `-32601`: Method not found
- `-32602`: Invalid params (e.g., tool not found)

## Security Considerations

1. **Authentication Required**: All MCP endpoints require valid JWT tokens
2. **User Context**: Tools receive user context for personalization and access control
3. **Input Validation**: All tool parameters are validated before execution
4. **Rate Limiting**: Consider adding rate limiting for production deployments

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify JWT token is valid and not expired
   - Check that `ELIXIHUB_JWT_SECRET` is set correctly

2. **Tool Not Found**
   - Verify tool name in the request matches the tool definition
   - Check that the tool is properly registered in `@tools`

3. **Connection Refused**
   - Ensure Hello World App is running on the expected port
   - Check firewall settings if testing across networks

### Debugging

Enable detailed logging by setting log level to debug in your config:

```elixir
config :logger, level: :debug
```

Then check logs for MCP request/response details.