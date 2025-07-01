defmodule AgentAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :agent_app

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_agent_app_key",
    signing_salt: "agent_app_signing_salt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [session: @session_options],
      timeout: 45_000,
      compress: false,
      check_origin: ["http://192.168.0.188:4003", "http://localhost:4003"]
    ],
    longpoll: [
      connect_info: [session: @session_options],
      window_ms: 10_000,
      pubsub_timeout_ms: 2_000,
      check_origin: ["http://192.168.0.188:4003", "http://localhost:4003"]
    ]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :agent_app,
    gzip: false,
    only: AgentAppWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug AgentAppWeb.Router
end