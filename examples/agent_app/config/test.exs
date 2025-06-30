import Config

config :agent_app, AgentAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "agent_app_test_secret_key_base_1234567890123456789012345678901234567890",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime