# Task Manager

A task management application designed for ElixiHub deployment with JWT authentication, role-based access control, and MCP server integration for AI agents.

## Features

- **Task Management**: Create, read, update, and delete tasks
- **User Authentication**: JWT-based authentication via ElixiHub
- **Role-Based Access Control**: Three permission levels (viewer, creator, manager)
- **Real-time Updates**: Phoenix LiveView for dynamic interfaces
- **MCP Server**: AI agent integration with task management tools
- **API Endpoints**: RESTful API for programmatic access

## Task Features

- Title, description, status, and priority
- Due dates and completion tracking
- Task assignment to users
- Tagging system
- Filtering by status and priority
- Task statistics

## ElixiHub Integration

### Authentication
- JWT token verification using ElixiHub's JWKS endpoint
- Automatic user session management
- Permission-based route protection

### Roles
- **task_viewer**: Can view assigned tasks
- **task_creator**: Can create and manage own tasks  
- **task_manager**: Can manage all tasks and assignments

### MCP Tools for AI Agents
- `list_tasks`: List user's tasks with optional status filtering
- `create_task`: Create new tasks with full metadata
- `update_task`: Modify existing tasks
- `delete_task`: Remove tasks
- `complete_task`: Mark tasks as completed
- `get_task_stats`: Get task statistics

## Installation

### Development Setup
```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start server
mix phx.server
```

### ElixiHub Deployment
```bash
# Build deployment package
./build.sh

# Upload task_manager.tar.gz to ElixiHub
# Configure through ElixiHub admin interface
```

## Configuration

### Environment Variables
- `ELIXIHUB_JWKS_URL`: JWT key endpoint (default: http://localhost:4000/.well-known/jwks.json)
- `ELIXIHUB_ISSUER`: JWT issuer (default: ElixiHub)
- `DATABASE_URL`: PostgreSQL connection string
- `PORT`: Application port (default: 4001)

### ElixiHub Configuration Files
- `roles.json`: Role definitions and permissions
- `mcp.json`: MCP server tools and schemas

## API Endpoints

### REST API
- `GET /api/tasks` - List user's tasks
- `POST /api/tasks` - Create new task
- `GET /api/tasks/:id` - Get task details
- `PUT /api/tasks/:id` - Update task
- `DELETE /api/tasks/:id` - Delete task
- `PUT /api/tasks/:id/complete` - Mark task as completed
- `GET /api/tasks/stats` - Get task statistics

### MCP Server
- `POST /mcp` - JSON-RPC 2.0 endpoint for AI agents

## Usage Examples

### Creating a Task via API
```bash
curl -X POST http://localhost:4001/api/tasks \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "title": "Complete project documentation",
      "description": "Write comprehensive docs for the project",
      "priority": "high",
      "due_date": "2024-01-15T10:00:00Z"
    }
  }'
```

### Using MCP Tools
```json
{
  "jsonrpc": "2.0",
  "method": "create_task",
  "params": {
    "title": "Review pull request",
    "priority": "medium",
    "tags": ["code-review", "urgent"]
  },
  "id": 1
}
```

## Development

### Running Tests
```bash
mix test
```

### Database Migrations
```bash
mix ecto.migrate
```

### Asset Compilation
```bash
mix assets.build
```

## Architecture

- **Phoenix Framework**: Web framework and LiveView
- **Ecto**: Database ORM with PostgreSQL
- **JWT Authentication**: Token-based auth with ElixiHub
- **MCP Server**: AI agent tool integration
- **Role-Based Access**: Permission-based security model

## License

This project is part of ElixiHub and follows the same licensing terms.