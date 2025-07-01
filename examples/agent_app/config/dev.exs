import Config

config :agent_app, AgentAppWeb.Endpoint,
  url: [host: "192.168.0.188", port: 4003],
  http: [ip: {0, 0, 0, 0}, port: 4003],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "agent_app_dev_secret_key_base_1234567890123456789012345678901234567890",
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:agent_app, ~w(--watch)]}
  ]

config :agent_app, AgentAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/agent_app_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

# OpenAI configuration for development
config :agent_app, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization: System.get_env("OPENAI_ORGANIZATION"),
  http_options: [recv_timeout: 30_000]

# ElixiHub configuration for authentication and discovery
# Note: Replace 192.168.0.XXX with the actual IP address of the machine running ElixiHub
config :agent_app, :elixihub,
  jwt_secret: System.get_env("ELIXIHUB_JWT_SECRET", "dev_secret_key_32_chars_long_exactly_for_jwt_signing"),
  elixihub_url: System.get_env("ELIXIHUB_URL", "http://192.168.0.1:4005")

# MCP configuration
config :agent_app, :mcp,
  servers: [
    %{
      name: "hello_world",
      url: System.get_env("HELLO_WORLD_MCP_URL", "http://localhost:4001/mcp"),
      description: "Hello World MCP server"
    }
  ]