# ElixiHub
Framework for hosting Elixir applications at home

Build an application called framework called 'ElixiHub' that utilises Elixir as a core technology to serve as a central authentication/authorization/hosting and discovery service for other internal elixir apps. The goal is to provide JWT-based Single Sign-On (SSO) and role-based access control (RBAC) for a home server platform running multiple Elixir apps. Elixir apps that conform to specification can be installed, managed and have its authentication/authorization handled by this application.  

Features:

Authentication App:
	•	Use phx_gen_auth for email/password-based login and registration.
	•	Add support for session-based login for the frontend and token-based authentication (JWT) for external apps.
	•	Use Guardian to issue and verify JWTs.
	•	Generate JWTs on login with embedded user ID and roles.

Authorization:
	•	Implement RBAC using roles and permissions:
	•	Users can have one or more roles.
	•	Roles can have many permissions (strings like "app:read", "admin:access").
	•	Provide a UI/API to manage roles and permissions.
	•	Use Bodyguard for permission checks inside the main app.
	•	External apps manage their RBAC in 
	•	External apps will send the JWT in the Authorization header (Bearer <token>).
	•	Provide a public JSON Web Key Set (JWKS) endpoint for verifying JWTs externally.
	
External Applications:
	•	Define a specification for Elixir apps that can be managed with 'ElixiHub' 
	• 	Implement a method for registering apps external apps that conform to this specification
	•	Define a specification that these apps can implement to support app management from the UI of this app (start, restart, delete).
	•	A landing page on 'ElixiHub' that lists apps that the authenticated user has access to
	•	Apps are to have MCP and agent functionality by default. A supervisor is to be implemented for each application that can accomodate multiple agents that each have their own 		context. Model context protocol functionality is provided so that Large Language Modelss can use tools defined in the application.
	•	Give an example 'hello world' application that demonstrates how to consume the authentication/authorization service.
API:
	•	Public endpoints:
	•	POST /api/login – accepts email/password, returns JWT on success.
	•	POST /api/register – registers new user.
	•	Protected endpoints:
	•	GET /api/user – returns user info from JWT.
	•	GET /api/permissions – returns user’s permissions.
	•	DELETE /api/user/{id} - deletes user
	•	All protected endpoints must use JWT auth via Guardian plug.
	•	POST /api/apps - registers new app
	•	GET /api/apps - returns list of registered apps
	•	DELETE /app/apps/{id} - deletes app

UI:
	•	Simple Phoenix LiveView UI to manage users, roles, and permissions.
	•	An 'Apps' landing page that lists apps that the authenticated user has access to
	•	The UI is to use v1.0.1 of phoenix liveview with tailwind css.

## Quick Start

### Prerequisites

- Elixir 1.14+
- Phoenix 1.7+
- PostgreSQL
- Node.js (for assets)

### Installation

1. **Clone and setup ElixiHub**:
   ```bash
   git clone <repository-url>
   cd ElixiHub
   mix deps.get
   mix ecto.setup
   ```

2. **Start ElixiHub**:
   ```bash
   mix phx.server
   ```
   ElixiHub will be available at http://localhost:4005

3. **Try the Hello World example**:
   ```bash
   # In another terminal
   cd examples/hello_world_app
   mix deps.get
   mix phx.server
   ```
   Hello World App will be available at http://localhost:4006

### Default Admin Account

- **Email**: admin@example.com
- **Password**: password123456

## Features Implemented

### ✅ Core Authentication & Authorization
- [x] Phoenix authentication with phx_gen_auth
- [x] JWT token issuing and verification with Guardian
- [x] Role-Based Access Control (RBAC) system
- [x] Permission management with Bodyguard
- [x] JWKS endpoint for external verification

### ✅ Admin Interface
- [x] User management with LiveView
- [x] Role and permission management
- [x] Application registry and management
- [x] Dashboard with statistics

### ✅ API Endpoints
- [x] Authentication endpoints (`/api/login`, `/api/register`)
- [x] User management endpoints
- [x] Application registration endpoints
- [x] Permission checking endpoints

### ✅ External App Integration
- [x] JWT verification for external apps
- [x] Permission-based access control
- [x] App registration and discovery
- [x] Hello World example app

### ✅ User Interface
- [x] Apps landing page for users
- [x] Admin management interface
- [x] Responsive design with Tailwind CSS

## Project Structure

```
ElixiHub/
├── lib/
│   ├── elixihub/
│   │   ├── accounts.ex           # User management
│   │   ├── authorization.ex      # RBAC system
│   │   ├── apps.ex              # App management
│   │   └── guardian.ex          # JWT handling
│   └── elixihub_web/
│       ├── controllers/         # API endpoints
│       ├── live/               # LiveView interfaces
│       └── plugs/              # Authentication plugs
├── examples/
│   └── hello_world_app/        # Example integration
├── priv/
│   └── repo/migrations/        # Database schema
├── INTEGRATION.md              # Integration guide
└── README.md                   # This file
```

## Integration Guide

For detailed information on how to integrate your Elixir applications with ElixiHub, see [INTEGRATION.md](INTEGRATION.md).

The integration guide covers:
- Application registration and deployment
- JWT authentication implementation
- Permission-based authorization
- Docker deployment strategies
- Production configuration
- Troubleshooting

## Hello World Example

The `examples/hello_world_app/` directory contains a complete example Phoenix application that demonstrates:

- JWT token verification using ElixiHub's JWKS endpoint
- Permission-based route protection
- API endpoint integration patterns
- Authentication middleware implementation

### Running the Example

1. Start ElixiHub (port 4005)
2. Start the Hello World app (port 4006)
3. Register the app in ElixiHub admin interface
4. Set up permissions (`hello_world:read`, `admin:access`)
5. Test the integration with curl or the web interface

See the [Hello World App README](examples/hello_world_app/README.md) for detailed instructions.

## API Documentation

### Authentication Endpoints

- `POST /api/login` - User login, returns JWT token
- `POST /api/register` - User registration
- `GET /api/user` - Current user information (requires JWT)
- `GET /api/permissions` - User permissions (requires JWT)

### Application Management

- `POST /api/apps` - Register new application (admin only)
- `GET /api/apps` - List registered applications
- `DELETE /api/apps/:id` - Remove application (admin only)

### JWKS Endpoint

- `GET /.well-known/jwks.json` - Public JSON Web Key Set for JWT verification

## Development

### Database Setup

```bash
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

### Running Tests

```bash
mix test
```

### Code Quality

```bash
mix format
mix credo
```

## Deployment

### Docker Deployment

A complete docker-compose setup is available for deploying ElixiHub with multiple applications:

```bash
docker-compose up -d
```

See [INTEGRATION.md](INTEGRATION.md) for detailed deployment instructions including:
- Docker configuration
- Nginx reverse proxy setup
- SSL/TLS configuration
- Production environment variables

### Environment Variables

Key environment variables for production:

- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix secret key
- `PHX_HOST` - Domain name for the application
- `PORT` - Port number (default: 4005)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is open source and available under the [MIT License](LICENSE). 