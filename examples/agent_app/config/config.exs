import Config

config :agent_app,
  generators: [timestamp_type: :utc_datetime]

config :agent_app, AgentAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AgentAppWeb.ErrorHTML, json: AgentAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AgentApp.PubSub,
  live_view: [signing_salt: "agent_app_salt"]

config :agent_app, :generators, context_app: :agent_app

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :tailwind,
  version: "3.4.3",
  agent_app: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :esbuild,
  version: "0.17.11",
  agent_app: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

import_config "#{config_env()}.exs"