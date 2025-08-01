import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after config/prod.exs and friends.

if System.get_env("PHX_SERVER") do
  config :task_manager, TaskManagerWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :task_manager, TaskManager.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4001")

  config :task_manager, TaskManagerWeb.Endpoint,
    url: [host: host, port: port, scheme: "http"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Configure ElixiHub integration
  config :task_manager, :elixihub,
    jwks_url: System.get_env("ELIXIHUB_JWKS_URL", "http://localhost:4000/.well-known/jwks.json"),
    issuer: System.get_env("ELIXIHUB_ISSUER", "ElixiHub"),
    base_url: System.get_env("ELIXIHUB_BASE_URL", "http://localhost:4005")
end