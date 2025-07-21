defmodule TaskManager.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TaskManager.Repo,
      TaskManagerWeb.Telemetry,
      {Phoenix.PubSub, name: TaskManager.PubSub},
      TaskManager.Auth.JWTVerifier,
      TaskManagerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TaskManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TaskManagerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end