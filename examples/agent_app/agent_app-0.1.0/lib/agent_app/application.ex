defmodule AgentApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AgentAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:agent_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AgentApp.PubSub},
      {Finch, name: AgentApp.Finch},
      AgentApp.MCPManager,
      AgentAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AgentApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AgentAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end