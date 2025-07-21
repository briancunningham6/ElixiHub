import Config

config :task_manager, TaskManager.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "task_manager_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :task_manager, TaskManagerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "task_manager_secret_key_base_test_only_this_must_be_at_least_64_bytes_long_for_security",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime