import Config

config :task_manager, TaskManager.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "task_manager_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :task_manager, TaskManagerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4010")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "task_manager_secret_key_base_dev_only_this_must_be_at_least_64_bytes_long_for_security",
  watchers: []

config :task_manager, TaskManagerWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/task_manager_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
