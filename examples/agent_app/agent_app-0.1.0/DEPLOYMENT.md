# Agent App Deployment

This package contains the source code for the Agent App.
The ElixiHub deployment system will automatically:

1. Build the release on the target architecture
2. Install dependencies 
3. Compile assets
4. Create the systemd service
5. Start the application

## Environment Variables Required:
- OPENAI_API_KEY: Your OpenAI API key
- ELIXIHUB_JWT_SECRET: JWT secret from ElixiHub
- ELIXIHUB_URL: URL of your ElixiHub instance
- HELLO_WORLD_MCP_URL: URL of hello world MCP endpoint

## Port Configuration:
The application will run on port 4003 by default.
