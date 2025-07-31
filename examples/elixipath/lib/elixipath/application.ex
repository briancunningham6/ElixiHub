defmodule ElixiPath.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElixiPathWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:elixipath, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElixiPath.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ElixiPath.Finch},
      # Start Copyparty subprocess manager
      ElixiPath.CopypartyManager,
      # Start the Endpoint (http/https)
      ElixiPathWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElixiPath.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElixiPathWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end