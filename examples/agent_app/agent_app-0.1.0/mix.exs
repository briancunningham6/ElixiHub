defmodule AgentApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :agent_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {AgentApp.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.2"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.2"},
      {:hackney, "~> 1.17"},
      {:httpoison, "~> 2.0"},
      {:finch, "~> 0.13"},
      {:joken, "~> 2.6"},
      {:jose, "~> 1.11"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:heroicons, "~> 0.5"},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind agent_app", "esbuild agent_app"],
      "assets.deploy": [
        "tailwind agent_app --minify",
        "esbuild agent_app --minify",
        "phx.digest"
      ]
    ]
  end
end
