import Config

config :elixipath, ElixiPathWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4011],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "elixipath_secret_key_base_change_in_production_this_must_be_at_least_64_bytes_long_for_security",
  server: true

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.