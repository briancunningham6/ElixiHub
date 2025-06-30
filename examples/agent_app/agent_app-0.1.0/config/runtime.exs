import Config

if System.get_env("PHX_SERVER") do
  config :agent_app, AgentAppWeb.Endpoint, server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4003")

  config :agent_app, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :agent_app, AgentAppWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # OpenAI configuration with better error handling
  openai_api_key = System.get_env("OPENAI_API_KEY")
  if openai_api_key && openai_api_key != "your_openai_api_key_here" do
    config :agent_app, :openai,
      api_key: openai_api_key,
      organization: System.get_env("OPENAI_ORGANIZATION"),
      http_options: [recv_timeout: 30_000]
  else
    IO.puts("WARNING: OPENAI_API_KEY not configured. Chat functionality will be limited.")
  end

  # ElixiHub JWT configuration with defaults
  elixihub_jwt_secret = System.get_env("ELIXIHUB_JWT_SECRET") || "default_jwt_secret_change_me"
  elixihub_url = System.get_env("ELIXIHUB_URL") || "http://localhost:4000"
  
  config :agent_app, :elixihub,
    jwt_secret: elixihub_jwt_secret,
    elixihub_url: elixihub_url

  # MCP configuration with defaults
  hello_world_mcp_url = System.get_env("HELLO_WORLD_MCP_URL") || "http://localhost:4001/api/mcp"
  
  config :agent_app, :mcp,
    servers: [
      %{
        name: "hello_world",
        url: hello_world_mcp_url,
        description: "Hello World MCP server"
      }
    ]
end