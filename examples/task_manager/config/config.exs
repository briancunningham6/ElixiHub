import Config

config :task_manager,
  ecto_repos: [TaskManager.Repo]

config :task_manager, TaskManagerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: TaskManagerWeb.ErrorHTML, json: TaskManagerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TaskManager.PubSub,
  live_view: [signing_salt: "task_manager_salt_this_should_be_at_least_8_characters_long"]

config :task_manager, TaskManager.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "task_manager_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :task_manager, :elixihub,
  jwks_url: System.get_env("ELIXIHUB_JWKS_URL", "http://localhost:4000/.well-known/jwks.json"),
  issuer: System.get_env("ELIXIHUB_ISSUER", "ElixiHub")

import_config "#{config_env()}.exs"