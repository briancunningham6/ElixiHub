import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.

config :task_manager, TaskManagerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Configures Swoosh API Client
config :swoosh, :api_client, false

# Do not print debug messages in production
config :logger, level: :info

# Runtime configuration will be loaded from config/runtime.exs
