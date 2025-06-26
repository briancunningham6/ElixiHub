defmodule Elixihub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixihubWeb.Telemetry,
      Elixihub.Repo,
      {DNSCluster, query: Application.get_env(:elixihub, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Elixihub.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Elixihub.Finch},
      # Start the nodes startup worker to ensure current node is registered
      Elixihub.Nodes.StartupWorker,
      # Start to serve requests, typically the last entry
      ElixihubWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elixihub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixihubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
