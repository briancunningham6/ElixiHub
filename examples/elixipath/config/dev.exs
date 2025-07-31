import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :elixipath, ElixiPathWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4011],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "elixipath_secret_key_base_for_development_this_must_be_at_least_64_bytes_long_to_work_properly_change_in_production_environment",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:elixipath, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:elixipath, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :elixipath, ElixiPathWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/elixipath_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :elixipath, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Include HEEx debug annotations as HTML comments in rendered markup
config :phoenix_live_view, :debug_heex_annotations, true