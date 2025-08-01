import Config

config :agent_app, AgentAppWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

# OpenAI configuration for production
config :agent_app, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization: System.get_env("OPENAI_ORGANIZATION"),
  http_options: [recv_timeout: 30_000]

# ElixiHub JWT configuration for production authentication
config :agent_app, :elixihub,
  jwt_secret: System.get_env("ELIXIHUB_JWT_SECRET"),
  elixihub_url: System.get_env("ELIXIHUB_URL")

# MCP configuration for production
config :agent_app, :mcp,
  servers: [
    %{
      name: "hello_world",
      url: System.get_env("HELLO_WORLD_MCP_URL"),
      description: "Hello World MCP server"
    }
  ]